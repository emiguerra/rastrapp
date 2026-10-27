import 'dart:math';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import 'backend.dart';

/// Notificaciones locales: un recordatorio diario a una hora aleatoria, 7 días.
/// No necesita servidor; cada teléfono se programa sus propios avisos.
class Notifications {
  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  static bool _ready = false;

  static Future<void> init() async {
    if (_ready) return;
    tzdata.initializeTimeZones();
    try {
      tz.setLocalLocation(tz.getLocation('America/Santiago'));
    } catch (_) {
      // Si falla, queda en UTC; no es crítico para un recordatorio.
    }
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const ios = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    await _plugin.initialize(
      settings: const InitializationSettings(android: android, iOS: ios),
    );
    _ready = true;
  }

  /// Pide permiso de notificaciones (iOS y Android 13+).
  static Future<bool> requestPermissions() async {
    await init();
    final ios = _plugin.resolvePlatformSpecificImplementation<
        IOSFlutterLocalNotificationsPlugin>();
    final iosOk = await ios?.requestPermissions(
      alert: true,
      badge: true,
      sound: true,
    );
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    final androidOk = await android?.requestNotificationsPermission();
    return iosOk ?? androidOk ?? true;
  }

  static const NotificationDetails _details = NotificationDetails(
    android: AndroidNotificationDetails(
      'rastro_daily',
      'Recordatorio diario',
      channelDescription: 'Tu momento del día',
      importance: Importance.high,
      priority: Priority.high,
    ),
    iOS: DarwinNotificationDetails(),
  );

  /// Programa [days] notificaciones, una por día, a una hora aleatoria dentro de
  /// la ventana [startHour]–[endHour]. Reemplaza cualquier programación previa.
  static Future<void> scheduleWeek({
    int days = 7,
    int startHour = 10,
    int endHour = 21,
  }) async {
    await init();
    await _plugin.cancelAll();
    final rnd = Random();
    final now = DateTime.now();

    for (var i = 0; i < days; i++) {
      final hour = startHour + rnd.nextInt(endHour - startHour);
      final minute = rnd.nextInt(60);
      var when = DateTime(now.year, now.month, now.day + i, hour, minute);
      if (when.isBefore(now)) when = when.add(const Duration(days: 1));
      await _plugin.zonedSchedule(
        id: i,
        title: '¡Es tu momento! ✨',
        body: 'Captura tu día antes de que se te pase.',
        scheduledDate: tz.TZDateTime.from(when, tz.local),
        notificationDetails: _details,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      );
    }
  }

  /// Programa la semana leyendo la **agenda** de Supabase (misma hora para todos),
  /// con un jitter aleatorio de ±[jitterMin] minutos para que siga pareciendo
  /// espontáneo. Si no hay agenda, cae a horas random locales.
  static Future<void> scheduleFromAgenda({int jitterMin = 20}) async {
    await init();
    final agenda = await Backend.fetchAgenda();
    if (agenda.isEmpty) return scheduleWeek();

    await _plugin.cancelAll();
    final slots = [...agenda]..sort((a, b) => a.dia.compareTo(b.dia));
    final rnd = Random();
    final now = DateTime.now();

    for (var i = 0; i < slots.length && i < 7; i++) {
      final s = slots[i];
      final jitter = rnd.nextInt(jitterMin * 2 + 1) - jitterMin;
      var when = DateTime(now.year, now.month, now.day + i, s.hora, s.minuto)
          .add(Duration(minutes: jitter));
      if (when.isBefore(now)) when = when.add(const Duration(days: 1));
      await _plugin.zonedSchedule(
        id: i,
        title: '¡Es tu momento! ✨',
        body: 'Captura tu día antes de que se te pase.',
        scheduledDate: tz.TZDateTime.from(when, tz.local),
        notificationDetails: _details,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      );
    }
  }

  /// ¿El usuario tiene las notificaciones activas (no las revocó)?
  static Future<bool> permisoActivo() async {
    await init();
    try {
      final ios = _plugin.resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin>();
      final r = await ios?.checkPermissions();
      if (r != null) return r.isEnabled;
      final android = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      final ra = await android?.areNotificationsEnabled();
      return ra ?? false;
    } catch (_) {
      return false;
    }
  }

  static Future<List<PendingNotificationRequest>> pending() async {
    await init();
    return _plugin.pendingNotificationRequests();
  }

  static Future<void> cancelAll() async {
    await init();
    await _plugin.cancelAll();
  }
}
