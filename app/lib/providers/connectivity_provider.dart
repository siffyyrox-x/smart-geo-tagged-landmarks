import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import '../services/sync_engine.dart';

/// Tracks online/offline state and is the trigger for "sync now" the
/// moment the device comes back online, instead of waiting for the next
/// 15-minute WorkManager periodic run. WorkManager remains the guaranteed
/// fallback (Requirement 10); this is just a nicer, faster experience
/// while the app happens to be open.
class ConnectivityProvider extends ChangeNotifier {
  bool _isOnline = true;
  bool get isOnline => _isOnline;

  StreamSubscription<List<ConnectivityResult>>? _subscription;

  /// Extra callback fired only on the offline -> online transition, so
  /// screens can refresh (e.g. re-fetch landmarks) without polling.
  VoidCallback? onBecameOnline;

  Future<void> init() async {
    final initial = await Connectivity().checkConnectivity();
    _isOnline = _hasConnection(initial);

    _subscription = Connectivity().onConnectivityChanged.listen((results) {
      final wasOnline = _isOnline;
      _isOnline = _hasConnection(results);
      if (_isOnline != wasOnline) {
        notifyListeners();
        if (_isOnline && !wasOnline) {
          // Just came back online: drain the offline queue / poll pending
          // jobs right away instead of waiting for the periodic task.
          unawaited(SyncEngine.runFullSyncPass());
          onBecameOnline?.call();
        }
      }
    });
  }

  bool _hasConnection(List<ConnectivityResult> results) {
    return results.any((r) => r != ConnectivityResult.none);
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
