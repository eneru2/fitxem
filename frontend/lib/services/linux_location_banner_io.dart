import 'dart:io';

import 'package:dbus/dbus.dart';
import 'package:geoclue/geoclue.dart';
import 'package:geolocator/geolocator.dart';

import 'linux_location_banner_type.dart';

Future<LinuxLocationBanner> getLinuxLocationBanner() async {
  if (!Platform.isLinux) return LinuxLocationBanner.none;

  final manager = GeoClueManager();
  try {
    await manager.connect().timeout(const Duration(seconds: 2));
    await manager.close();
  } on DBusServiceUnknownException {
    return LinuxLocationBanner.geoclueUnavailable;
  } catch (_) {
    return LinuxLocationBanner.geoclueUnavailable;
  }

  try {
    final enabled = await Geolocator.isLocationServiceEnabled();
    if (!enabled) return LinuxLocationBanner.locationDisabled;
  } catch (_) {
    return LinuxLocationBanner.locationDisabled;
  }

  return LinuxLocationBanner.desktopUnreliable;
}
