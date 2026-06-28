import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:geolocator/geolocator.dart';

/// Your own connectivity, used as the signal indicator.
///
/// Honest note: cross-platform "cellular bars" isn't available — true signal
/// strength is Android-only and needs extra permissions. We derive a level from
/// the active connection type, which is reliable everywhere (mobile/wifi/web).
class SignalStatus {
  final String connectionType; // cellular | wifi | none | other
  final int level; // 0-4
  final bool online;

  const SignalStatus(this.connectionType, this.level, this.online);

  String get label {
    switch (connectionType) {
      case 'cellular':
        return 'Cellular';
      case 'wifi':
        return 'Wi-Fi';
      case 'none':
        return 'No signal';
      default:
        return online ? 'Connected' : 'Offline';
    }
  }

  static const offline = SignalStatus('none', 0, false);
}

class SignalService {
  final _connectivity = Connectivity();

  SignalStatus _fromResults(List<ConnectivityResult> results) {
    if (results.isEmpty || results.every((r) => r == ConnectivityResult.none)) {
      return SignalStatus.offline;
    }
    if (results.contains(ConnectivityResult.mobile)) {
      return const SignalStatus('cellular', 3, true);
    }
    if (results.contains(ConnectivityResult.wifi)) {
      return const SignalStatus('wifi', 4, true);
    }
    return const SignalStatus('other', 4, true);
  }

  Future<SignalStatus> current() async {
    try {
      return _fromResults(await _connectivity.checkConnectivity());
    } catch (_) {
      return SignalStatus.offline;
    }
  }

  Stream<SignalStatus> watch() =>
      _connectivity.onConnectivityChanged.map(_fromResults);
}

/// Best-effort current location. Returns null if unavailable or denied — the
/// app degrades gracefully (you just don't appear on the map).
Future<({double lat, double lng})?> tryGetLocation() async {
  try {
    if (!await Geolocator.isLocationServiceEnabled()) return null;
    var perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
    }
    if (perm == LocationPermission.denied ||
        perm == LocationPermission.deniedForever) {
      return null;
    }
    final pos = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.low),
    );
    return (lat: pos.latitude, lng: pos.longitude);
  } catch (_) {
    return null;
  }
}
