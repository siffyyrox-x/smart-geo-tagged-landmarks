import 'dart:io';
import 'package:flutter/foundation.dart';
import '../models/landmark.dart';
import '../services/api_service.dart';
import '../services/database_service.dart';

enum SortMode { none, scoreHighToLow, scoreLowToHigh }


class LandmarksProvider extends ChangeNotifier {
  final ApiService _api;
  final DatabaseService _db;

  LandmarksProvider({ApiService? api, DatabaseService? db})
      : _api = api ?? ApiService(),
        _db = db ?? DatabaseService.instance;

  List<Landmark> _landmarks = [];
  List<Landmark> _managedIncludingDeleted = [];

  bool isLoading = false;
  bool isFirstLoadDone = false;
  String? errorMessage;
  bool lastLoadWasFromCache = false;

  SortMode sortMode = SortMode.none;
  double minScoreFilter = 0;

  List<Landmark> get managedIncludingDeleted => _managedIncludingDeleted;

  /// Every currently-loaded active landmark, unfiltered and unsorted.
  /// Requirement 2 (Map View) says the map must "show all landmarks" -
  /// deliberately a SEPARATE getter from [visibleLandmarks] so that
  /// changing the score filter/sort on the Landmarks List screen (which
  /// shares this same provider instance) never hides markers on the Map
  /// screen. Only the List screen's Requirement 4 calls for filter/sort.
  List<Landmark> get allActiveLandmarks => List.unmodifiable(_landmarks);

  /// The list screens should actually render: filtered by the minimum
  /// score, then sorted (Requirement 4: "Sorting by score, Filtering by
  /// minimum score").
  List<Landmark> get visibleLandmarks {
    var list = _landmarks.where((l) => l.score >= minScoreFilter).toList();
    switch (sortMode) {
      case SortMode.scoreHighToLow:
        list.sort((a, b) => b.score.compareTo(a.score));
        break;
      case SortMode.scoreLowToHigh:
        list.sort((a, b) => a.score.compareTo(b.score));
        break;
      case SortMode.none:
        break;
    }
    return list;
  }

  /// Min/max score across the currently loaded landmarks, used by the Map
  /// screen to color markers on a relative red -> green scale (the exam
  /// notes the scoring formula/weights vary per student key, so we can't
  /// hard-code absolute thresholds).
  (double, double) get scoreRange {
    if (_landmarks.isEmpty) return (0, 1);
    double min = _landmarks.first.score;
    double max = _landmarks.first.score;
    for (final l in _landmarks) {
      if (l.score < min) min = l.score;
      if (l.score > max) max = l.score;
    }
    if (min == max) max = min + 1; // avoid divide-by-zero in the color math
    return (min, max);
  }

  /// Call once on app/screen start: show cached data instantly, then try
  /// to get fresh data from the network.
  Future<void> loadInitial() async {
    final cached = await _db.getCachedLandmarks();
    if (cached.isNotEmpty) {
      _landmarks = cached;
      lastLoadWasFromCache = true;
      notifyListeners();
    }
    await refresh();
  }

  Future<void> refresh() async {
    isLoading = true;
    notifyListeners();
    try {
      final fresh = await _api.getLandmarks();
      _landmarks = fresh;
      lastLoadWasFromCache = false;
      errorMessage = null;
      await _db.upsertLandmarksFromServer(fresh);
    } catch (e) {
      // Network / server problem: fall back to whatever is cached so the
      // app still shows something (Requirement 8: Offline Support).
      final cached = await _db.getCachedLandmarks();
      if (cached.isNotEmpty) {
        _landmarks = cached;
        lastLoadWasFromCache = true;
      }
      errorMessage = _friendlyMessage(e);
    } finally {
      isLoading = false;
      isFirstLoadDone = true;
      notifyListeners();
    }
  }

  /// Loads the "My Landmarks" management list (active + soft-deleted) for
  /// the Add/View screen, so the user can Restore something they deleted.
  Future<void> loadManagedList() async {
    _managedIncludingDeleted = await _db.getCachedLandmarksIncludingDeleted();
    notifyListeners();
  }

  Future<void> createLandmark({
    required String title,
    required double lat,
    required double lon,
    File? imageFile,
  }) async {
    await _api.createLandmark(title: title, lat: lat, lon: lon, imageFile: imageFile);
    await refresh();
    await loadManagedList();
  }

  Future<void> deleteLandmark(int id) async {
    await _api.deleteLandmark(id);
    _landmarks.removeWhere((l) => l.id == id);
    await _db.setCachedLandmarkActive(id, false);
    await loadManagedList();
    notifyListeners();
  }

  Future<void> restoreLandmark(int id) async {
    await _api.restoreLandmark(id);
    await _db.setCachedLandmarkActive(id, true);
    await refresh();
    await loadManagedList();
  }

  String _friendlyMessage(Object e) {
    if (e is ApiException) return e.message;
    return 'Could not reach the server. Showing your last saved data.';
  }

  @override
  void dispose() {
    _api.dispose();
    super.dispose();
  }
}
