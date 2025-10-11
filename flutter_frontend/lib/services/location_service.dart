import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';

class LocationService {
  static Future<Position> getCurrentLocation() async {
    // Check if location services are enabled
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw Exception(
          'Location services are disabled. Please enable location services.');
    }

    // Check permissions
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        throw Exception('Location permissions are denied');
      }
    }

    if (permission == LocationPermission.deniedForever) {
      throw Exception(
          'Location permissions are permanently denied, we cannot request permissions.');
    }

    // Get current position with high accuracy
    return await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.best,
      timeLimit: const Duration(seconds: 15),
    );
  }

  static Future<bool> checkLocationPermission() async {
    final status = await Permission.location.status;
    return status.isGranted;
  }

  static Future<bool> checkLocationServices() async {
    return await Geolocator.isLocationServiceEnabled();
  }

  static Future<void> requestLocationPermission() async {
    final status = await Permission.location.request();
    if (!status.isGranted) {
      throw Exception('Location permission denied by user');
    }
  }

  static Future<void> openLocationSettings() async {
    await Geolocator.openLocationSettings();
  }

  static Future<void> openAppSettings() async {
    await openAppSettings();
  }

  static Stream<Position> getLocationStream() {
    return Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.best,
        distanceFilter: 10, // meters
      ),
    );
  }

  // FIXED: Added async and await for calculateDistance
  static Future<double> calculateDistance(
      double startLat, double startLng, double endLat, double endLng) async {
    return Geolocator.distanceBetween(startLat, startLng, endLat, endLng);
  }
}
