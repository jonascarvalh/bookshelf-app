import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

/// Agenda o lembrete diário de leitura.
abstract interface class ReminderScheduler {
  /// Agendamento diário só existe no Android/iOS; no desktop o app funciona
  /// sem lembrete.
  bool get isSupported;

  /// Pede permissão de notificação (Android 13+). Retorna se foi concedida.
  Future<bool> requestPermission();

  Future<void> scheduleDaily({required int hour, required int minute});

  Future<void> cancel();
}

class LocalNotificationsReminderScheduler implements ReminderScheduler {
  LocalNotificationsReminderScheduler([FlutterLocalNotificationsPlugin? plugin])
    : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  static const _reminderId = 1;

  final FlutterLocalNotificationsPlugin _plugin;
  Future<void>? _init;

  @override
  bool get isSupported => !kIsWeb && (Platform.isAndroid || Platform.isIOS);

  Future<void> _ensureInitialized() => _init ??= () async {
    tz_data.initializeTimeZones();
    final zone = await FlutterTimezone.getLocalTimezone();
    tz.setLocalLocation(tz.getLocation(zone.identifier));
    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(),
      ),
    );
  }();

  @override
  Future<bool> requestPermission() async {
    if (!isSupported) return false;
    await _ensureInitialized();
    final android = _plugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    if (android != null) return await android.requestNotificationsPermission() ?? false;
    final ios = _plugin.resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>();
    return await ios?.requestPermissions(alert: true, sound: true) ?? false;
  }

  @override
  Future<void> scheduleDaily({required int hour, required int minute}) async {
    if (!isSupported) return;
    await _ensureInitialized();
    await _plugin.cancel(id: _reminderId);

    final now = tz.TZDateTime.now(tz.local);
    var next = tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);
    if (!next.isAfter(now)) next = next.add(const Duration(days: 1));

    await _plugin.zonedSchedule(
      id: _reminderId,
      scheduledDate: next,
      title: 'Hora da leitura',
      body: 'Que tal algumas páginas hoje? Sua meta agradece.',
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          'reading_reminder',
          'Lembrete de leitura',
          channelDescription: 'Lembrete diário para manter a meta de leitura',
        ),
        iOS: DarwinNotificationDetails(),
      ),
      // Não exige a permissão de alarme exato; alguns minutos de atraso
      // não fazem diferença para um lembrete de leitura.
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  @override
  Future<void> cancel() async {
    if (!isSupported) return;
    await _ensureInitialized();
    await _plugin.cancel(id: _reminderId);
  }
}
