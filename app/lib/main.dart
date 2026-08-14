import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/activity_provider.dart';
import 'providers/connectivity_provider.dart';
import 'providers/landmarks_provider.dart';
import 'screens/home_screen.dart';
import 'workers/background_worker.dart';

Future<void> main() async {
  // Needed before calling any plugin (workmanager, sqflite, etc) code.
  WidgetsFlutterBinding.ensureInitialized();

  // Requirement 10: register the guaranteed background-work mechanism
  // (WorkManager) that polls visit jobs and drains the offline queue.
  await BackgroundWorker.init();
  await BackgroundWorker.registerPeriodicSync();

  // Create the app's three ChangeNotifiers up front (instead of inside
  // build()) so we can wire them together - e.g. "when we come back
  // online, refresh the landmarks list" - before the UI ever mounts.
  final landmarksProvider = LandmarksProvider();
  final activityProvider = ActivityProvider();
  final connectivityProvider = ConnectivityProvider();

  connectivityProvider.onBecameOnline = () {
    landmarksProvider.refresh();
    activityProvider.loadVisits();
  };
  await connectivityProvider.init();

  // Kick off the first load. Not awaited - loadInitial() already shows
  // cached data instantly and updates the UI itself once the network
  // call finishes, so there's no reason to delay the first frame for it.
  landmarksProvider.loadInitial();
  activityProvider.loadVisits();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<LandmarksProvider>.value(value: landmarksProvider),
        ChangeNotifierProvider<ActivityProvider>.value(value: activityProvider),
        ChangeNotifierProvider<ConnectivityProvider>.value(value: connectivityProvider),
      ],
      child: const SmartLandmarksApp(),
    ),
  );
}

class SmartLandmarksApp extends StatelessWidget {
  const SmartLandmarksApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Smart Geo-Tagged Landmarks',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
        useMaterial3: true,
      ),
      home: const HomeScreen(),
    );
  }
}
