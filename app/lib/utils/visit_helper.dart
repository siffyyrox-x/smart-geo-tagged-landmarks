import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/landmark.dart';
import '../models/visit.dart';
import '../providers/activity_provider.dart';
import '../providers/connectivity_provider.dart';
import '../services/location_service.dart';

/// Shared "Visit" button logic (Requirement 3), used from both the Map
/// screen's marker popup and the Landmarks List detail sheet so the flow
/// only needs to be written - and gotten right - once.
///
/// Steps:
///  1. Get current GPS location.
///  2. Hand off to ActivityProvider, which either submits immediately
///     (online) or queues it (offline) - Requirement 8.
///  3. Show a Toast/Snackbar with the outcome (Requirement 9).
Future<void> performVisit(BuildContext context, Landmark landmark) async {
  final messenger = ScaffoldMessenger.of(context);
  messenger.showSnackBar(
    const SnackBar(content: Text('Getting your location...'), duration: Duration(seconds: 2)),
  );

  try {
    final position = await LocationService.getCurrentLocation();
    if (!context.mounted) return;

    final isOnline = context.read<ConnectivityProvider>().isOnline;
    final activityProvider = context.read<ActivityProvider>();

    final result = await activityProvider.recordVisit(
      landmarkId: landmark.id,
      landmarkTitle: landmark.title,
      userLat: position.latitude,
      userLon: position.longitude,
      isOnline: isOnline,
    );

    if (!context.mounted) return;
    messenger.hideCurrentSnackBar();

    switch (result.status) {
      case VisitStatus.queuedOffline:
        messenger.showSnackBar(
          const SnackBar(
            content: Text("You're offline - visit saved and will sync automatically."),
            backgroundColor: Colors.orange,
          ),
        );
        break;
      case VisitStatus.pendingServer:
      case VisitStatus.submitting:
        messenger.showSnackBar(
          SnackBar(
            content: Text('Visit to "${landmark.title}" sent! Calculating distance...'),
            backgroundColor: Colors.blue,
          ),
        );
        break;
      case VisitStatus.done:
        messenger.showSnackBar(
          SnackBar(
            content: Text('Visited! Distance: ${result.distance?.toStringAsFixed(1)} m'),
            backgroundColor: Colors.green,
          ),
        );
        break;
      case VisitStatus.failed:
        messenger.showSnackBar(
          SnackBar(
            content: Text('Visit failed: ${result.errorMessage ?? "unknown error"}'),
            backgroundColor: Colors.red,
          ),
        );
        break;
    }
  } on LocationException catch (e) {
    if (!context.mounted) return;
    messenger.hideCurrentSnackBar();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Location error'),
        content: Text(e.message),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('OK')),
        ],
      ),
    );
  } catch (e) {
    if (!context.mounted) return;
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(content: Text('Something went wrong: $e'), backgroundColor: Colors.red),
    );
  }
}
