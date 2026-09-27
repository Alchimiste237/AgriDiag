import 'dart:async';

import 'package:geolocator/geolocator.dart';

/// Why a mandatory GPS fix could not be obtained.
enum LocationFailure {
  /// The user denied the location permission.
  permissionDenied,

  /// The user denied the location permission permanently (do not ask again).
  permissionDeniedForever,

  /// The device location services (GPS) are switched off.
  serviceDisabled,

  /// Location services are on and permission granted, but no fix could be
  /// obtained in time (cold GPS start, indoors). Distinct from [serviceDisabled]
  /// so the user is not told to enable GPS when it is already enabled.
  noFix,

  /// Any other failure: unsupported platform, etc.
  unavailable,
}

/// Thrown by [LocationService.capture] when a GPS position cannot be obtained.
///
/// GPS is mandatory for scans, so callers must surface this to the user
/// instead of silently continuing without coordinates.
class LocationException implements Exception {
  final LocationFailure failure;
  const LocationException(this.failure);

  @override
  String toString() => 'LocationException($failure)';
}

/// Captures the current GPS position with a short time limit.
///
/// Throws [LocationException] when permission is denied, GPS is off, the
/// platform doesn't support it, or the fix times out — a scan must always
/// have coordinates, so failures are surfaced instead of swallowed silently.
class LocationService {
  static Future<({double latitude, double longitude})> capture() async {
    try {
      // Fail fast when location services are off; otherwise the position
      // request below can fail in ways that look like other errors.
      if (!await Geolocator.isLocationServiceEnabled()) {
        throw const LocationException(LocationFailure.serviceDisabled);
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied) {
        throw const LocationException(LocationFailure.permissionDenied);
      }
      if (permission == LocationPermission.deniedForever) {
        throw const LocationException(LocationFailure.permissionDeniedForever);
      }

      try {
        final pos = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.medium,
            timeLimit: Duration(seconds: 15),
          ),
        );
        return (latitude: pos.latitude, longitude: pos.longitude);
      } on TimeoutException {
        // A cold GPS start (first fix after launch, indoors…) can exceed the
        // time limit even with GPS on — fall back to the most recent cached
        // fix rather than blocking the scan.
        final last = await Geolocator.getLastKnownPosition();
        if (last != null) {
          return (latitude: last.latitude, longitude: last.longitude);
        }
        throw const LocationException(LocationFailure.noFix);
      }
    } on LocationException {
      rethrow;
    } on LocationServiceDisabledException {
      throw const LocationException(LocationFailure.serviceDisabled);
    } catch (_) {
      // Timeout, unsupported platform, or any other failure to get a fix.
      throw const LocationException(LocationFailure.unavailable);
    }
  }
}