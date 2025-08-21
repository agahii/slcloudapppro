import 'package:geolocator/geolocator.dart';

class LocationHelper {
  static Future<Position> getCurrentPosition({Duration timeout = const Duration(seconds: 12)}) async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      // Try prompting the user to enable it
      await Geolocator.openLocationSettings();
      throw Exception('Location services are disabled.');
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        throw Exception('Location permission denied.');
      }
    }

    if (permission == LocationPermission.deniedForever) {
      throw Exception('Location permission permanently denied in settings.');
    }

    return await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.best,
      timeLimit: timeout,
    );
  }
}
