import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../models/visit.dart';
import '../services/api_service.dart';
import '../services/database_service.dart';
import '../workers/background_worker.dart';

/// Drives Requirement 3 (Visit Feature) and Requirement 5 (Activity
/// Screen / Visit History), and is also where offline visits get queued
/// for Requirement 8 (Offline Support).
class ActivityProvider extends ChangeNotifier {
  final DatabaseService _db;
  final ApiService _api;

  ActivityProvider({DatabaseService? db, ApiService? api})
      : _db = db ?? DatabaseService.instance,
        _api = api ?? ApiService();

  List<VisitRecord> _visits = [];
  List<VisitRecord> get visits => _visits;
  bool isLoading = false;

  Timer? _localRefreshTimer;

  Future<void> loadVisits() async {
    isLoading = true;
    notifyListeners();
    _visits = await _db.getAllVisits();
    isLoading = false;
    notifyListeners();
    _manageLocalRefreshTimer();
  }

  /// While anything is still in-flight (queued offline or waiting on a
  /// job result), refresh from the local DB every few seconds so the UI
  /// picks up whatever the WorkManager background isolate just wrote -
  /// this only re-reads SQLite, it never touches the network itself.
  void _manageLocalRefreshTimer() {
    final hasInFlight = _visits.any(
      (v) => v.status == VisitStatus.queuedOffline || v.status == VisitStatus.pendingServer,
    );
    if (hasInFlight && _localRefreshTimer == null) {
      _localRefreshTimer = Timer.periodic(const Duration(seconds: 3), (_) async {
        _visits = await _db.getAllVisits();
        notifyListeners();
        if (!_visits.any(
          (v) => v.status == VisitStatus.queuedOffline || v.status == VisitStatus.pendingServer,
        )) {
          _localRefreshTimer?.cancel();
          _localRefreshTimer = null;
        }
      });
    } else if (!hasInFlight) {
      _localRefreshTimer?.cancel();
      _localRefreshTimer = null;
    }
  }

  /// Creates a new visit record and either submits it immediately (online)
  /// or leaves it queued for the background sync to pick up (offline).
  /// Returns the resulting record so the caller (the Visit button's
  /// onPressed) can show an immediate success/queued Toast/Snackbar.
  Future<VisitRecord> recordVisit({
    required int landmarkId,
    required String landmarkTitle,
    required double userLat,
    required double userLon,
    required bool isOnline,
  }) async {
    final visit = VisitRecord(
      localId: const Uuid().v4(),
      landmarkId: landmarkId,
      landmarkTitle: landmarkTitle,
      userLat: userLat,
      userLon: userLon,
      visitTime: DateTime.now(),
      status: isOnline ? VisitStatus.submitting : VisitStatus.queuedOffline,
    );
    await _db.insertVisit(visit);
    await loadVisits();

    if (isOnline) {
      try {
        final jobId = await _api.visitLandmark(
          landmarkId: landmarkId,
          userLat: userLat,
          userLon: userLon,
        );
        await _db.updateVisit(
          visit.copyWith(serverJobId: jobId, status: VisitStatus.pendingServer),
        );
        // Fast path: poll this specific job right away instead of waiting
        // for the 15-minute periodic task.
        await BackgroundWorker.schedulePollForJob(
          localVisitId: visit.localId,
          jobId: jobId,
        );
      } catch (e) {
        // We thought we were online but the request still failed (flaky
        // network, server hiccup, etc) - fall back to the offline queue so
        // the periodic WorkManager task retries it with backoff instead of
        // losing it.
        await _db.updateVisit(
          visit.copyWith(status: VisitStatus.queuedOffline, errorMessage: '$e'),
        );
      }
      await loadVisits();
    }

    return (await _db.getVisit(visit.localId))!;
  }

  @override
  void dispose() {
    _localRefreshTimer?.cancel();
    _api.dispose();
    super.dispose();
  }
}
