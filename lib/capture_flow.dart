import 'dart:io';

import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';

import 'captures.dart';

/// Canal al código nativo de la cámara dual simultánea (AVCaptureMultiCamSession).
const _multicam = MethodChannel('rastro/multicam');

/// Pide la ubicación del teléfono en el momento (el dato en el origen).
Future<Position?> _currentPosition() async {
  if (!await Geolocator.isLocationServiceEnabled()) return null;
  var perm = await Geolocator.checkPermission();
  if (perm == LocationPermission.denied) {
    perm = await Geolocator.requestPermission();
  }
  if (perm == LocationPermission.denied ||
      perm == LocationPermission.deniedForever) {
    return null;
  }
  try {
    return await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
    );
  } catch (_) {
    return null;
  }
}

/// ¿El permiso de ubicación sigue activo?
Future<bool> locationOk() async {
  try {
    final p = await Geolocator.checkPermission();
    return p == LocationPermission.whileInUse || p == LocationPermission.always;
  } catch (_) {
    return false;
  }
}

Future<bool> multiCamSupported() async {
  try {
    return await _multicam.invokeMethod<bool>('isSupported') ?? false;
  } catch (_) {
    return false;
  }
}

/// Lanza el escáner facial nativo interactivo (preview en vivo + detección de
/// rostro). Devuelve la ruta de la foto del rostro, o null si canceló.
/// Lanza excepción si el método no está disponible (para hacer respaldo).
Future<String?> scanFaceNative() async {
  return _multicam.invokeMethod<String>('scanFace');
}

/// Dispara la cámara dual nativa. Devuelve {back, front} o null si canceló/falló.
Future<Map<String, String>?> _captureDualNative() async {
  try {
    final res = await _multicam.invokeMethod<Map<dynamic, dynamic>>('captureDual');
    if (res == null) return null;
    return res.map((k, v) => MapEntry(k.toString(), v.toString()));
  } catch (_) {
    return null;
  }
}

/// Toma la foto (dual si se puede, simple si no) y captura el GPS en el momento.
/// Devuelve la [Capture] guardada, o `null` si el usuario canceló.
Future<Capture?> captureMomento() async {
  // Ubicación en paralelo mientras se abre la cámara.
  final posFuture = _currentPosition();

  final dir = await CaptureStore.imagesDir();
  final id = DateTime.now().millisecondsSinceEpoch.toString();

  String backDest;
  String? frontDest;

  if (await multiCamSupported()) {
    final dual = await _captureDualNative();
    if (dual == null || dual['back'] == null) {
      posFuture.ignore();
      return null;
    }
    backDest = '${dir.path}/${id}_back.jpg';
    await File(dual['back']!).copy(backDest);
    if (dual['front'] != null) {
      frontDest = '${dir.path}/${id}_front.jpg';
      await File(dual['front']!).copy(frontDest);
    }
  } else {
    // Respaldo: cámara simple.
    final x = await ImagePicker().pickImage(
      source: ImageSource.camera,
      imageQuality: 90,
    );
    if (x == null) {
      posFuture.ignore();
      return null;
    }
    backDest = '${dir.path}/$id.jpg';
    await File(x.path).copy(backDest);
  }

  Position? pos;
  try {
    pos = await posFuture;
  } catch (_) {
    pos = null;
  }

  final capture = Capture(
    id: id,
    imagePath: backDest,
    frontPath: frontDest,
    takenAt: DateTime.now(),
    lat: pos?.latitude,
    lng: pos?.longitude,
    accuracy: pos?.accuracy,
  );
  await CaptureStore.add(capture);
  return capture;
}
