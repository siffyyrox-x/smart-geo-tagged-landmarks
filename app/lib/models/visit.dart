/// A single "visit" the user made (or tried to make) to a landmark.
///
/// One record covers the WHOLE lifecycle of a visit, which is what lets the
/// Activity screen, the offline queue, and the background job-poller all
/// share one table (Room/SQLite-as-single-source-of-truth, per the exam's
/// suggested architecture):
///
///   1. User taps "Visit" -> a VisitRecord is inserted immediately with
///      status = queuedOffline (if no internet) or submitting (if online).
///   2. Once the visit_landmark POST succeeds, we store the server's
///      job_id and move to status = pendingServer.
///   3. A WorkManager task polls get_job_status for that job_id.
///        - status becomes done   -> we store `distance`, status = done
///        - status becomes failed -> we store `error`,    status = failed
///   4. If the device was offline at step 1, a periodic WorkManager task
///      re-attempts step 2 (with backoff) once connectivity returns.
enum VisitStatus {
  queuedOffline, // saved locally, waiting for internet to even send it
  submitting, // actively trying to POST visit_landmark right now
  pendingServer, // server accepted it, we have a job_id, polling for result
  done, // job finished, distance is available
  failed, // job failed OR we could not submit it after repeated retries
}

class VisitRecord {
  final String localId; // uuid, generated on-device the moment user taps Visit
  final int landmarkId;
  final String landmarkTitle;
  final double userLat;
  final double userLon;
  final DateTime visitTime;
  final int? serverJobId; // null until visit_landmark succeeds
  final double? distance; // null until job status == done
  final VisitStatus status;
  final String? errorMessage;
  final int retryCount; // how many sync attempts so far (for backoff/logging)

  VisitRecord({
    required this.localId,
    required this.landmarkId,
    required this.landmarkTitle,
    required this.userLat,
    required this.userLon,
    required this.visitTime,
    this.serverJobId,
    this.distance,
    required this.status,
    this.errorMessage,
    this.retryCount = 0,
  });

  VisitRecord copyWith({
    int? serverJobId,
    double? distance,
    VisitStatus? status,
    String? errorMessage,
    int? retryCount,
  }) {
    return VisitRecord(
      localId: localId,
      landmarkId: landmarkId,
      landmarkTitle: landmarkTitle,
      userLat: userLat,
      userLon: userLon,
      visitTime: visitTime,
      serverJobId: serverJobId ?? this.serverJobId,
      distance: distance ?? this.distance,
      status: status ?? this.status,
      errorMessage: errorMessage ?? this.errorMessage,
      retryCount: retryCount ?? this.retryCount,
    );
  }

  factory VisitRecord.fromMap(Map<String, dynamic> map) {
    return VisitRecord(
      localId: map['local_id'] as String,
      landmarkId: map['landmark_id'] as int,
      landmarkTitle: map['landmark_title'] as String? ?? '',
      userLat: (map['user_lat'] as num).toDouble(),
      userLon: (map['user_lon'] as num).toDouble(),
      visitTime: DateTime.parse(map['visit_time'] as String),
      serverJobId: map['server_job_id'] as int?,
      distance: map['distance'] == null ? null : (map['distance'] as num).toDouble(),
      status: VisitStatus.values.firstWhere(
        (s) => s.name == map['status'],
        orElse: () => VisitStatus.failed,
      ),
      errorMessage: map['error_message'] as String?,
      retryCount: map['retry_count'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'local_id': localId,
      'landmark_id': landmarkId,
      'landmark_title': landmarkTitle,
      'user_lat': userLat,
      'user_lon': userLon,
      'visit_time': visitTime.toIso8601String(),
      'server_job_id': serverJobId,
      'distance': distance,
      'status': status.name,
      'error_message': errorMessage,
      'retry_count': retryCount,
    };
  }
}
