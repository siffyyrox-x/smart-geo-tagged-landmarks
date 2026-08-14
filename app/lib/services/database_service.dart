import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import '../models/landmark.dart';
import '../models/visit.dart';

/// Single source of truth for everything persisted on-device.
///
/// Two tables:
///   landmarks_cache  -> the last successful GET get_landmarks response,
///                       so the Map/List screens still have something to
///                       show when the device is offline (Requirement 8).
///   visits           -> every visit the user ever made or attempted,
///                       across its whole lifecycle (see VisitRecord docs).
///                       Doubles as the offline queue: a row with
///                       status == queuedOffline IS a queued request.
///
/// Kept as a plain singleton (not a full Repository class with streams)
/// on purpose - simple, easy to read, easy to explain in a viva/interview,
/// which is exactly what a beginner-friendly exam project needs.
class DatabaseService {
  DatabaseService._internal();
  static final DatabaseService instance = DatabaseService._internal();

  Database? _db;

  Future<Database> get database async {
    _db ??= await _initDb();
    return _db!;
  }

  Future<Database> _initDb() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'smart_landmarks.db');
    return openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE landmarks_cache (
            id INTEGER PRIMARY KEY,
            title TEXT NOT NULL,
            lat REAL NOT NULL,
            lon REAL NOT NULL,
            image TEXT,
            is_active INTEGER NOT NULL DEFAULT 1,
            visit_count INTEGER NOT NULL DEFAULT 0,
            avg_distance REAL NOT NULL DEFAULT 0,
            score REAL NOT NULL DEFAULT 0
          )
        ''');
        await db.execute('''
          CREATE TABLE visits (
            local_id TEXT PRIMARY KEY,
            landmark_id INTEGER NOT NULL,
            landmark_title TEXT NOT NULL,
            user_lat REAL NOT NULL,
            user_lon REAL NOT NULL,
            visit_time TEXT NOT NULL,
            server_job_id INTEGER,
            distance REAL,
            status TEXT NOT NULL,
            error_message TEXT,
            retry_count INTEGER NOT NULL DEFAULT 0
          )
        ''');
      },
    );
  }

  // ---------------------------------------------------------------------
  // Landmarks cache
  // ---------------------------------------------------------------------

  /// Upserts (insert-or-replace, by id) every landmark from a fresh
  /// get_landmarks response into the cache.
  ///
  /// Deliberately does NOT delete rows that are missing from the new list.
  /// The server only ever returns ACTIVE landmarks, so a landmark we
  /// soft-deleted locally (is_active = 0) simply won't be in `landmarks`
  /// here - and since we don't wipe the table, that row (and the fact that
  /// the user can Restore it) survives a refresh and even an app restart.
  Future<void> upsertLandmarksFromServer(List<Landmark> landmarks) async {
    final db = await database;
    final batch = db.batch();
    for (final landmark in landmarks) {
      batch.insert(
        'landmarks_cache',
        landmark.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
  }

  /// Reads whatever is currently cached (used when offline, or as the
  /// instant "show something while the network call is in flight" data).
  /// Only returns active (non soft-deleted) landmarks, same as the API.
  Future<List<Landmark>> getCachedLandmarks() async {
    final db = await database;
    final rows = await db.query(
      'landmarks_cache',
      where: 'is_active = 1',
      orderBy: 'title COLLATE NOCASE ASC',
    );
    return rows.map((row) => Landmark.fromMap(row)).toList();
  }

  Future<void> updateCachedLandmark(Landmark landmark) async {
    final db = await database;
    await db.update(
      'landmarks_cache',
      landmark.toMap(),
      where: 'id = ?',
      whereArgs: [landmark.id],
    );
  }

  /// Same as [getCachedLandmarks] but also includes soft-deleted ones.
  /// Used by the "My Landmarks" management list on the Add/View screen so
  /// the user can Restore something they deleted (Requirement 7).
  Future<List<Landmark>> getCachedLandmarksIncludingDeleted() async {
    final db = await database;
    final rows = await db.query(
      'landmarks_cache',
      orderBy: 'is_active DESC, title COLLATE NOCASE ASC',
    );
    return rows.map((row) => Landmark.fromMap(row)).toList();
  }

  /// Flip just the is_active flag for one cached landmark - used right
  /// after a successful delete/restore API call so the UI updates
  /// instantly without waiting for the next full refresh.
  Future<void> setCachedLandmarkActive(int id, bool isActive) async {
    final db = await database;
    await db.update(
      'landmarks_cache',
      {'is_active': isActive ? 1 : 0},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // ---------------------------------------------------------------------
  // Visits (activity history + offline queue + job tracking, all-in-one)
  // ---------------------------------------------------------------------

  Future<void> insertVisit(VisitRecord visit) async {
    final db = await database;
    await db.insert(
      'visits',
      visit.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> updateVisit(VisitRecord visit) async {
    final db = await database;
    await db.update(
      'visits',
      visit.toMap(),
      where: 'local_id = ?',
      whereArgs: [visit.localId],
    );
  }

  Future<VisitRecord?> getVisit(String localId) async {
    final db = await database;
    final rows = await db.query(
      'visits',
      where: 'local_id = ?',
      whereArgs: [localId],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return VisitRecord.fromMap(rows.first);
  }

  /// All visits, newest first - what the Activity screen shows.
  Future<List<VisitRecord>> getAllVisits() async {
    final db = await database;
    final rows = await db.query('visits', orderBy: 'visit_time DESC');
    return rows.map((row) => VisitRecord.fromMap(row)).toList();
  }

  /// Visits that were made while offline and still haven't been sent to
  /// the server. Drained by the periodic WorkManager task once the device
  /// is back online (Requirement 8: "Sync queued requests when internet
  /// is available").
  Future<List<VisitRecord>> getQueuedOfflineVisits() async {
    final db = await database;
    final rows = await db.query(
      'visits',
      where: 'status = ?',
      whereArgs: [VisitStatus.queuedOffline.name],
      orderBy: 'visit_time ASC',
    );
    return rows.map((row) => VisitRecord.fromMap(row)).toList();
  }

  /// Visits that were successfully sent (we have a server job_id) but
  /// whose result we haven't received yet. These are what the WorkManager
  /// job-poller needs to keep checking on - including any that were still
  /// pending the last time the app was killed/restarted.
  Future<List<VisitRecord>> getPendingServerVisits() async {
    final db = await database;
    final rows = await db.query(
      'visits',
      where: 'status = ?',
      whereArgs: [VisitStatus.pendingServer.name],
      orderBy: 'visit_time ASC',
    );
    return rows.map((row) => VisitRecord.fromMap(row)).toList();
  }
}
