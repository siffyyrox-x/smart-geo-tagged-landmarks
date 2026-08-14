import 'package:workmanager/workmanager.dart';
import '../config.dart';
import '../services/api_service.dart';
import '../services/database_service.dart';
import '../services/sync_engine.dart';

/// Requirement 10 (Background Job Queue) says the app must use WorkManager
/// (or an equivalent guaranteed/constrained background API) instead of a
/// manual Thread/Timer loop, for two jobs that are really the same problem:
///
///   A) Poll get_job_status for a visit until it resolves.
///   B) Drain the offline visit queue once connectivity returns, with
///      retry/backoff on failure.
///
/// This file is the ONLY place that talks to the `workmanager` plugin.
/// The actual "what to do" logic lives in services/sync_engine.dart so it
/// can be unit-reasoned-about without dragging WorkManager into it.
///
/// Two kinds of tasks are registered:
///  - ONE periodic task (every 15 minutes, Android's minimum interval)
///    that runs a full sync pass: submit anything still queued offline,
///    and poll anything still waiting on a job result. This is the safety
///    net that guarantees nothing is ever lost, even if the app was fully
///    closed.
///  - ONE one-off task PER visit, enqueued immediately after visit_landmark
///    succeeds, so the user sees their distance appear within seconds
///    instead of waiting up to 15 minutes for the next periodic run. It
///    re-enqueues itself (via WorkManager's own backoff policy) until the
///    job is done or failed.
class BackgroundWorker {
  /// Call once, early in main(), before runApp().
  static Future<void> init() async {
    await Workmanager().initialize(callbackDispatcher);
  }

  /// Registers the periodic "catch everything" safety-net task.
  /// Safe to call every app start - `keep` means "if it's already
  /// scheduled, leave it alone" instead of creating duplicates.
  static Future<void> registerPeriodicSync() async {
    await Workmanager().registerPeriodicTask(
      kPeriodicSyncTaskName,
      kPeriodicSyncTaskName,
      tag: kPeriodicSyncTaskTag,
      frequency: const Duration(minutes: 15),
      existingWorkPolicy: ExistingPeriodicWorkPolicy.keep,
      constraints: Constraints(networkType: NetworkType.connected),
      backoffPolicy: BackoffPolicy.linear,
      backoffPolicyDelay: const Duration(seconds: 30),
    );
  }

  /// Enqueues a fast one-off poll for a single visit's job.
  /// Called right after visit_landmark returns a job_id (see
  /// providers/activity_provider.dart), and also re-armed automatically
  /// by WorkManager itself (via backoff) as long as the job stays pending.
  static Future<void> schedulePollForJob({
    required String localVisitId,
    required int jobId,
  }) async {
    final uniqueName = '$kJobPollTaskPrefix$jobId';
    await Workmanager().registerOneOffTask(
      uniqueName,
      uniqueName,
      tag: 'job_poll',
      inputData: {
        'job_id': jobId,
        'local_visit_id': localVisitId,
      },
      initialDelay: const Duration(seconds: 4),
      constraints: Constraints(networkType: NetworkType.connected),
      // Job resolution takes "a few seconds" per the API docs. 10s is
      // Android WorkManager's own minimum backoff, so this polls about as
      // fast as the platform allows without a manual loop.
      backoffPolicy: BackoffPolicy.linear,
      backoffPolicyDelay: const Duration(seconds: 10),
      existingWorkPolicy: ExistingWorkPolicy.replace,
    );
  }
}

/// Entry point WorkManager calls in a separate background isolate.
/// Must be a top-level (or static) function annotated like this so it
/// survives tree-shaking / can be found after an app restart.
@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    final api = ApiService();
    final db = DatabaseService.instance;
    try {
      if (task == kPeriodicSyncTaskName) {
        await SyncEngine.runFullSyncPass();
        return true; // periodic tasks just run again next period regardless
      }

      if (task.startsWith(kJobPollTaskPrefix)) {
        final rawJobId = inputData?['job_id'];
        final rawLocalVisitId = inputData?['local_visit_id'];
        final jobId = int.tryParse(rawJobId?.toString() ?? '') ?? -1;
        final localVisitId = rawLocalVisitId?.toString() ?? '';
        if (jobId <= 0 || localVisitId.isEmpty) return true; // malformed, drop it

        final isTerminal = await SyncEngine.pollJobOnce(
          localVisitId,
          jobId,
          api: api,
          db: db,
        );
        // Returning false tells WorkManager "not done yet, retry me later
        // according to the backoff policy this task was registered with" -
        // this IS the polling loop, just done by the OS instead of a
        // manual Timer/Thread.
        return isTerminal;
      }

      return true;
    } catch (_) {
      // Unexpected error (e.g. no network at all) - ask WorkManager to
      // retry with backoff rather than crashing the isolate.
      return false;
    } finally {
      api.dispose();
    }
  });
}
