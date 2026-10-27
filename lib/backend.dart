import 'dart:io';
import 'dart:math';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'captures.dart';

/// Conexión al backend (Supabase): sube las capturas de cada participante y lee
/// el feed común. Las llaves son públicas por diseño (van en el cliente).
class Backend {
  Backend._();

  static const String url = 'https://dlhjfaiichoesjjokpjc.supabase.co';
  static const String anonKey = 'sb_publishable_42O2RsaN7REFxlkfftIkHA_1hQvK7RA';

  static bool _ok = false;
  static bool get ready => _ok;

  static SupabaseClient get _db => Supabase.instance.client;

  static Future<void> init() async {
    try {
      await Supabase.initialize(url: url, publishableKey: anonKey);
      _ok = true;
    } catch (_) {
      _ok = false; // la app sigue funcionando en local si no hay red/backend
    }
  }

  // ── Identidad del participante (alias, sin email → privacidad) ────────────
  static Future<String> alias() async {
    final prefs = await SharedPreferences.getInstance();
    var a = prefs.getString('alias');
    if (a == null) {
      a = _randomAlias();
      await prefs.setString('alias', a);
    }
    return a;
  }

  static Future<String> deviceId() async {
    final prefs = await SharedPreferences.getInstance();
    var d = prefs.getString('device_id');
    if (d == null) {
      d = '${DateTime.now().millisecondsSinceEpoch}_${Random().nextInt(99999)}';
      await prefs.setString('device_id', d);
    }
    return d;
  }

  static Future<void> setAlias(String a) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('alias', a);
  }

  /// Ruta local del rostro escaneado (biométrico, llave de la investigadora).
  static Future<void> setRostroLocal(String path) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('rostro_local', path);
  }

  static Future<String?> rostroLocal() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('rostro_local');
  }

  /// Foto de perfil ELEGIDA por el usuario (pública, distinta del biométrico).
  static Future<void> setAvatarLocal(String path) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('avatar_local', path);
  }

  static Future<String?> avatarLocal() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('avatar_local');
  }

  /// Sube la foto de perfil elegida y la asocia al perfil (avatar_url).
  static Future<String?> uploadAvatar(File f) async {
    if (!_ok) return null;
    try {
      final d = await deviceId();
      final name = 'avatars/$d.jpg';
      await _db.storage.from('capturas').upload(name, f,
          fileOptions: const FileOptions(upsert: true));
      final url = _db.storage.from('capturas').getPublicUrl(name);
      await _db.from('perfiles').upsert({
        'device_id': d,
        'alias': await alias(),
        'avatar_url': url,
      }, onConflict: 'device_id');
      return url;
    } catch (_) {
      return null;
    }
  }

  /// Fija el nombre de usuario elegido (reemplaza el alias random) y lo guarda
  /// en el perfil.
  static Future<void> setUsername(String name) async {
    await setAlias(name);
    if (!_ok) return;
    try {
      final d = await deviceId();
      await _db.from('perfiles').upsert({
        'alias': name,
        'device_id': d,
        'nombre': name,
      }, onConflict: 'device_id');
    } catch (_) {}
  }

  // ── Conexiones entre participantes ────────────────────────────────────────
  /// Todos los participantes registrados (para buscar y agregar).
  static Future<List<Map<String, dynamic>>> participantes() async {
    if (!_ok) return [];
    try {
      final rows = await _db.from('perfiles').select();
      return (rows as List).cast<Map<String, dynamic>>();
    } catch (_) {
      return [];
    }
  }

  /// device_ids que YO agregué como amigos.
  static Future<Set<String>> amigos() async {
    if (!_ok) return {};
    try {
      final d = await deviceId();
      final rows = await _db.from('amistades').select('a').eq('de', d);
      return (rows as List).map((r) => r['a'] as String).toSet();
    } catch (_) {
      return {};
    }
  }

  static Future<void> agregarAmigo(String targetDevice) async {
    if (!_ok) return;
    try {
      final d = await deviceId();
      await _db.from('amistades')
          .upsert({'de': d, 'a': targetDevice}, onConflict: 'de,a');
    } catch (_) {}
  }

  static Future<void> quitarAmigo(String targetDevice) async {
    if (!_ok) return;
    try {
      final d = await deviceId();
      await _db.from('amistades').delete().eq('de', d).eq('a', targetDevice);
    } catch (_) {}
  }

  static String _randomAlias() {
    const nombres = ['anónimo', 'rastro', 'testigo', 'sujeto', 'nadie'];
    return '${nombres[Random().nextInt(nombres.length)]}-${Random().nextInt(9000) + 1000}';
  }

  /// Registra/actualiza el perfil del participante.
  static Future<void> ensureProfile({String? rostroUrl}) async {
    if (!_ok) return;
    try {
      final a = await alias();
      final d = await deviceId();
      await _db.from('perfiles').upsert({
        'alias': a,
        'device_id': d,
        if (rostroUrl != null) 'rostro_url': rostroUrl,
      }, onConflict: 'device_id');
    } catch (_) {}
  }

  /// Sube el rostro de registro (verificación biométrica) y devuelve su URL.
  static Future<String?> uploadRostro(File f) async {
    if (!_ok) return null;
    try {
      final d = await deviceId();
      final name = 'rostros/$d.jpg';
      await _db.storage.from('capturas').upload(name, f,
          fileOptions: const FileOptions(upsert: true));
      return _db.storage.from('capturas').getPublicUrl(name);
    } catch (_) {
      return null;
    }
  }

  // ── Subida de una captura (2 fotos + GPS) ─────────────────────────────────
  static Future<bool> uploadCapture(Capture c) async {
    if (!_ok) return false;
    try {
      final a = await alias();
      final d = await deviceId();
      final bucket = _db.storage.from('capturas');

      final backName = '$d/${c.id}_back.jpg';
      await bucket.upload(backName, File(c.imagePath),
          fileOptions: const FileOptions(upsert: true));
      final backUrl = bucket.getPublicUrl(backName);

      String? frontUrl;
      if (c.frontPath != null && File(c.frontPath!).existsSync()) {
        final frontName = '$d/${c.id}_front.jpg';
        await bucket.upload(frontName, File(c.frontPath!),
            fileOptions: const FileOptions(upsert: true));
        frontUrl = bucket.getPublicUrl(frontName);
      }

      await _db.from('capturas').insert({
        'alias': a,
        'device_id': d,
        'back_url': backUrl,
        'front_url': frontUrl,
        'lat': c.lat,
        'lng': c.lng,
        'accuracy': c.accuracy,
        'taken_at': c.takenAt.toIso8601String(),
      });
      return true;
    } catch (_) {
      return false;
    }
  }

  // ── Feed común (capturas recientes de todos) ──────────────────────────────
  static Future<List<RemoteCapture>> fetchFeed({int limit = 50}) async {
    if (!_ok) return [];
    try {
      final rows = await _db
          .from('capturas')
          .select()
          .order('taken_at', ascending: false)
          .limit(limit);
      return (rows as List)
          .map((r) => RemoteCapture.fromJson(r as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  // ── Latido / estado del participante (para medir post-revelación) ─────────
  /// Registra que la app está viva: última vez vista + permisos + nº de capturas.
  /// No toca el campo `revelado` (lo marca la investigadora desde el panel).
  static Future<void> heartbeat({
    required bool notifOk,
    required bool locOk,
    required int capturas,
  }) async {
    if (!_ok) return;
    try {
      final d = await deviceId();
      final a = await alias();
      await _db.from('estado').upsert({
        'device_id': d,
        'alias': a,
        'last_seen': DateTime.now().toIso8601String(),
        'notif_ok': notifOk,
        'loc_ok': locOk,
        'capturas': capturas,
        'updated_at': DateTime.now().toIso8601String(),
      }, onConflict: 'device_id');
    } catch (_) {}
  }

  // ── Perfil / capturas de otro participante ────────────────────────────────
  static Future<Map<String, dynamic>?> perfilDe(String alias) async {
    if (!_ok) return null;
    try {
      final rows = await _db.from('perfiles').select().eq('alias', alias).limit(1);
      final l = rows as List;
      return l.isNotEmpty ? l.first as Map<String, dynamic> : null;
    } catch (_) {
      return null;
    }
  }

  static Future<List<RemoteCapture>> capturasDe(String alias) async {
    if (!_ok) return [];
    try {
      final rows = await _db
          .from('capturas')
          .select()
          .eq('alias', alias)
          .order('taken_at', ascending: false);
      return (rows as List)
          .map((r) => RemoteCapture.fromJson(r as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  // ── Agenda de notificaciones (misma hora para todos) ──────────────────────
  /// Devuelve la lista de horarios programados por el investigador.
  static Future<List<AgendaSlot>> fetchAgenda() async {
    if (!_ok) return [];
    try {
      final rows = await _db.from('agenda').select().order('dia');
      return (rows as List)
          .map((r) => AgendaSlot.fromJson(r as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }
}

/// Una captura leída del backend (de cualquier participante).
class RemoteCapture {
  final String alias;
  final String? deviceId;
  final String backUrl;
  final String? frontUrl;
  final double? lat;
  final double? lng;
  final DateTime takenAt;

  RemoteCapture({
    required this.alias,
    this.deviceId,
    required this.backUrl,
    this.frontUrl,
    this.lat,
    this.lng,
    required this.takenAt,
  });

  factory RemoteCapture.fromJson(Map<String, dynamic> j) => RemoteCapture(
        alias: (j['alias'] ?? 'anónimo') as String,
        deviceId: j['device_id'] as String?,
        backUrl: (j['back_url'] ?? '') as String,
        frontUrl: j['front_url'] as String?,
        lat: (j['lat'] as num?)?.toDouble(),
        lng: (j['lng'] as num?)?.toDouble(),
        takenAt: DateTime.parse(j['taken_at'] as String),
      );
}

class AgendaSlot {
  final int dia;
  final int hora;
  final int minuto;
  AgendaSlot({required this.dia, required this.hora, required this.minuto});
  factory AgendaSlot.fromJson(Map<String, dynamic> j) => AgendaSlot(
        dia: (j['dia'] as num).toInt(),
        hora: (j['hora'] as num).toInt(),
        minuto: (j['minuto'] as num).toInt(),
      );
}
