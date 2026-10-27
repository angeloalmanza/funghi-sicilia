import 'package:geolocator/geolocator.dart';

/// Posizione GPS corrente. Funziona offline (usa il GPS del telefono, non la rete).
/// Il permesso viene chiesto solo qui, quando l'utente sceglie di salvare la posizione.
/// Restituisce `null` se negato, GPS spento o nessun fix entro il timeout.
Future<({double lat, double lon})?> currentPosition() async {
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
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        timeLimit: Duration(seconds: 20),
      ),
    );
    return (lat: pos.latitude, lon: pos.longitude);
  } catch (_) {
    return Geolocator.getLastKnownPosition()
        .then((p) => p == null ? null : (lat: p.latitude, lon: p.longitude))
        .catchError((_) => null);
  }
}
