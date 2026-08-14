import 'api_service.dart';
import 'database_service.dart';
import '../models/job.dart';
import '../models/visit.dart';

/// The actual "what do we do to move one visit forward" logic.
///
/// This is deliberately kept separate from workers/background_worker.dart
/// so the exact same code path runs whether it's:
///   - triggered from the background isolate by WorkManager, or
///   - triggered from the foreground (e.g. right after the user taps
///     "Visit" while online, so they see a result fast instead of waiting
///     for WorkManager's own scheduling).
///
/// A max retry count guards against a visit being retried forever if the
/// server (or the network) never cooperates.
class SyncEngine {
  static const int maxRetries = 30;

  /// Tries to send ONE queued-offline visit to the server.
  /// On success it becomes `pendingServer` (with a job_id).
  /// On failure it stays `queuedOffline` so the next sync pass retries it,
  /// unless it has already failed [maxRetries] times.
  static Future<void> submitQueuedVisit(
    VisitRecord visit, {
    required ApiService api,
    required DatabaseService db,
  }) async {
    try {
      final jobId = await api.visitLandmark(
        landmarkId: visit.landmarkId,
        userLat: visit.userLat,
        userLon: visit.userLon,
      );
      await db.updateVisit(
        visit.copyWith(serverJobId: jobId, status: VisitStatus.pendingServer),
      );
    } catch (e) {
      final retryCount = visit.retryCount + 1;
      if (retryCount > maxRetries) {
        await db.updateVisit(
          visit.copyWith(
            status: VisitStatus.failed,
            errorMessage: 'Could not sync after $maxRetries attempts: $e',
            retryCount: retryCount,
          ),
        );
      } else {
        await db.updateVisit(
          visit.copyWith(errorMessage: '$e', retryCount: retryCount),
        );
      }
    }
  }

  /// Checks the status of ONE job once.
  /// Returns true when the job reached a terminal state (done/failed) and
  /// no further polling is needed; false when it's still pending and
  /// should be checked again later.
  static Future<bool> pollJobOnce(
    String localVisitId,
    int jobId, {
    required ApiService api,
    required DatabaseService db,
  }) async {
    final visit = await db.getVisit(localVisitId);
    if (visit == null) return true; // record is gone, nothing left to do

    try {
      final VisitJob job = await api.getJobStatus(jobId);
      switch (job.status) {
        case JobStatus.done:
          await db.updateVisit(
            visit.copyWith(status: VisitStatus.done, distance: job.distance),
          );
          return true;
        case JobStatus.failed:
          await db.updateVisit(
            visit.copyWith(
              status: VisitStatus.failed,
              errorMessage: job.error ?? 'The server could not process this visit.',
            ),
          );
          return true;
        case JobStatus.pending:
        case JobStatus.unknown:
          return false; // keep polling
      }
    } catch (e) {
      final retryCount = visit.retryCount + 1;
      if (retryCount > maxRetries) {
        await db.updateVisit(
          visit.copyWith(
            status: VisitStatus.failed,
            errorMessage: 'Gave up polling after $maxRetries attempts: $e',
            retryCount: retryCount,
          ),
        );
        return true;
      }
      await db.updateVisit(
        visit.copyWith(errorMessage: '$e', retryCount: retryCount),
      );
      return false;
    }
  }

  /// Runs one full "catch up" pass:
  ///   1. try to submit every visit still queued offline
  ///   2. poll every visit that already has a job_id but no result yet
  /// This is what the periodic WorkManager task calls, and it's also safe
  /// to call from the foreground whenever connectivity comes back.
  static Future<void> runFullSyncPass() async {
    final db = DatabaseService.instance;
    final api = ApiService();
    try {
      final queued = await db.getQueuedOfflineVisits();
      for (final visit in queued) {
        await submitQueuedVisit(visit, api: api, db: db);
      }

      final pending = await db.getPendingServerVisits();
      for (final visit in pending) {
        if (visit.serverJobId != null) {
          await pollJobOnce(visit.localId, visit.serverJobId!, api: api, db: db);
        }
      }
    } finally {
      api.dispose();
    }
  }
}
