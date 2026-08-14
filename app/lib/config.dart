
const String kApiKey = '24341229';

/// The API is a single script that routes by an `action` query parameter.
/// Physical endpoint is always /api.php.
const String kApiBaseUrl = 'https://labs.anontech.info/cse489/exm3';

/// Landmark images are returned as paths relative to the server
/// (e.g. "uploads/123_456.jpg"). Prefix with this to get a loadable URL.
String resolveImageUrl(String? relativePath) {
  if (relativePath == null || relativePath.isEmpty) return '';
  if (relativePath.startsWith('http')) return relativePath;
  return '$kApiBaseUrl/$relativePath';
}

/// Bangladesh's rough geographic center, used to center the map on first
/// launch (before any landmarks / GPS fix are available).
const double kBangladeshCenterLat = 23.6850;
const double kBangladeshCenterLon = 90.3563;
const double kDefaultMapZoom = 6.6;

/// Unique name for the periodic WorkManager task (queue drain + orphaned
/// job polling). Android requires this to be stable across app restarts.
const String kPeriodicSyncTaskName = 'smart_landmarks_periodic_sync';
const String kPeriodicSyncTaskTag = 'periodic_sync';

/// Unique name prefix for the one-off "poll this specific job" WorkManager
/// task that gets enqueued right after a successful visit_landmark call.
const String kJobPollTaskPrefix = 'poll_job_';
