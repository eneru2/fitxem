import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'linux_location_banner.dart';

const _prefsKeyGpsEnabled = 'clock_gps_enabled';

final locationServiceProvider = Provider((_) => LocationService());

class GpsForClockNotifier extends StateNotifier<bool> {
  GpsForClockNotifier() : super(true) {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    state = prefs.getBool(_prefsKeyGpsEnabled) ?? true;
  }

  Future<void> setEnabled(bool enabled) async {
    state = enabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefsKeyGpsEnabled, enabled);
  }
}

final gpsForClockEnabledProvider =
    StateNotifierProvider<GpsForClockNotifier, bool>((ref) {
  return GpsForClockNotifier();
});

/// Linux-only banner when GeoClue or system location services are unavailable.
final linuxLocationBannerProvider =
    FutureProvider<LinuxLocationBanner>((ref) async {
  return getLinuxLocationBanner();
});

class GeoPosition {
  const GeoPosition({required this.latitude, required this.longitude});

  final double latitude;
  final double longitude;
}

enum LocationCaptureStatus {
  captured,
  skippedUnavailable,
  skippedImprecise,
  skippedDesktopUnreliable,
}

class LocationCaptureResult {
  const LocationCaptureResult({
    required this.status,
    this.position,
    this.accuracyMeters,
  });

  final LocationCaptureStatus status;
  final GeoPosition? position;
  final double? accuracyMeters;
}

class LocationService {
  /// GeoClue WiFi/IP fixes are often city-level; unsuitable for compliance GPS.
  static const maxAccuracyMeters = 200.0;

  bool get _isSupported {
    if (kIsWeb) return true;
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
      case TargetPlatform.iOS:
      case TargetPlatform.macOS:
      case TargetPlatform.windows:
      case TargetPlatform.linux:
        return true;
      case TargetPlatform.fuchsia:
        return false;
    }
  }

  bool get _usesGeoCluePortal =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.linux;

  LocationSettings _locationSettings(Duration timeout) {
    if (kIsWeb) {
      return WebSettings(
        accuracy: LocationAccuracy.best,
        timeLimit: timeout,
        maximumAge: Duration.zero,
      );
    }
    return LocationSettings(
      accuracy: LocationAccuracy.high,
      timeLimit: timeout,
    );
  }

  Future<LocationCaptureResult> capturePosition({
    Duration timeout = const Duration(seconds: 8),
  }) async {
    if (!_isSupported) {
      return const LocationCaptureResult(
        status: LocationCaptureStatus.skippedUnavailable,
      );
    }

    if (_usesGeoCluePortal) {
      return const LocationCaptureResult(
        status: LocationCaptureStatus.skippedDesktopUnreliable,
      );
    }

    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        return const LocationCaptureResult(
          status: LocationCaptureStatus.skippedUnavailable,
        );
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return const LocationCaptureResult(
          status: LocationCaptureStatus.skippedUnavailable,
        );
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: _locationSettings(timeout),
      ).timeout(timeout);

      if (position.accuracy <= 0 ||
          position.accuracy > maxAccuracyMeters) {
        return LocationCaptureResult(
          status: LocationCaptureStatus.skippedImprecise,
          accuracyMeters: position.accuracy > 0 ? position.accuracy : null,
        );
      }

      return LocationCaptureResult(
        status: LocationCaptureStatus.captured,
        position: GeoPosition(
          latitude: position.latitude,
          longitude: position.longitude,
        ),
        accuracyMeters: position.accuracy,
      );
    } on MissingPluginException {
      return const LocationCaptureResult(
        status: LocationCaptureStatus.skippedUnavailable,
      );
    } catch (_) {
      return const LocationCaptureResult(
        status: LocationCaptureStatus.skippedUnavailable,
      );
    }
  }
}
