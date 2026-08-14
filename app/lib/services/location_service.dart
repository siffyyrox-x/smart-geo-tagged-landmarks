import 'package:geolocator/geolocator.dart';

/// Thrown when we can't get a GPS fix (permission denied, service off, etc).
/// Screens catch this and show a message instead of crashing
/// (Requirement 9: Error Handling / Requirement 8: don't crash on data issues).
class LocationException implements Exception {
  final String message;
  LocationException(this.message);
  @override
  String toString() => message;
}

/// Wraps `geolocator` so the rest of the app just calls
/// `LocationService.getCurrentLocation()` without worrying about
/// permission prompts or whether GPS is even turned on.
class LocationService {
  /// Returns the device's current GPS position, requesting permission
  /// first if needed. Used by:
  ///  - the Visit feature (Requirement 3: "Get current GPS location")
  ///  - the Add Landmark screen (Requirement 6: "Auto-fetch GPS location")
  static Future<Position> getCurrentLocation() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw LocationException(
        'Location services are turned off. Please enable GPS and try again.',
      );
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        throw LocationException(
          'Location permission was denied. Grant it in Settings to use this feature.',
        );
      }
    }
    if (permission == LocationPermission.deniedForever) {
      throw LocationException(
        'Location permission is permanently denied. Enable it from app settings.',
      );
    }

    try {
      return await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 15),
        ),
      );
    } catch (e) {
      throw LocationException('Could not get your current location: $e');
    }
  }
}
