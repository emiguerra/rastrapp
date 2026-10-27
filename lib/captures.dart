import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Una captura diaria del usuario: la foto + la ubicación tomada **en el origen**
/// (en el momento de la foto, no leída después del EXIF).
class Capture {
  final String id;
  final String imagePath; // foto principal (trasera)
  final String? frontPath; // selfie (frontal), si hubo cámara dual
  final DateTime takenAt;
  final double? lat;
  final double? lng;
  final double? accuracy;

  const Capture({
    required this.id,
    required this.imagePath,
    this.frontPath,
    required this.takenAt,
    this.lat,
    this.lng,
    this.accuracy,
  });

  bool get hasGps => lat != null && lng != null;
  bool get hasFront => frontPath != null;

  Map<String, dynamic> toJson() => {
        'id': id,
        'imagePath': imagePath,
        'frontPath': frontPath,
        'takenAt': takenAt.toIso8601String(),
        'lat': lat,
        'lng': lng,
        'accuracy': accuracy,
      };

  factory Capture.fromJson(Map<String, dynamic> j) => Capture(
        id: j['id'] as String,
        imagePath: j['imagePath'] as String,
        frontPath: j['frontPath'] as String?,
        takenAt: DateTime.parse(j['takenAt'] as String),
        lat: (j['lat'] as num?)?.toDouble(),
        lng: (j['lng'] as num?)?.toDouble(),
        accuracy: (j['accuracy'] as num?)?.toDouble(),
      );
}

/// Guarda las capturas localmente: la imagen en el directorio de la app y un
/// índice en SharedPreferences. (El envío al backend es un paso aparte.)
class CaptureStore {
  static const _key = 'captures_v1';

  static Future<Directory> imagesDir() async {
    final base = await getApplicationDocumentsDirectory();
    final dir = Directory('${base.path}/capturas');
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  static Future<List<Capture>> all() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_key) ?? <String>[];
    final list = raw
        .map((s) => Capture.fromJson(jsonDecode(s) as Map<String, dynamic>))
        .toList();
    list.sort((a, b) => b.takenAt.compareTo(a.takenAt));
    return list;
  }

  static Future<void> add(Capture c) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_key) ?? <String>[];
    raw.add(jsonEncode(c.toJson()));
    await prefs.setStringList(_key, raw);
  }

  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
    final dir = await imagesDir();
    if (await dir.exists()) await dir.delete(recursive: true);
  }

  /// Exporta todo como JSON (para revisar en modo dev / armar el expediente).
  static Future<String> exportJson() async {
    final list = await all();
    return const JsonEncoder.withIndent('  ')
        .convert(list.map((c) => c.toJson()).toList());
  }
}
