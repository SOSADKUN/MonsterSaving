import '../localization/strings.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

class NightlyReminder {
  static final instance = NightlyReminder._();
  NightlyReminder._();
  final plugin = FlutterLocalNotificationsPlugin();
  final opened = ValueNotifier<int>(0);
  bool initialized = false;
  static const id = 1001;
  bool get supported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);
  Future<void> initialize() async {
    if (initialized || !supported) return;
    tzdata.initializeTimeZones();
    tz.setLocalLocation(
      tz.getLocation(await FlutterTimezone.getLocalTimezone()),
    );
    await plugin.initialize(
      const InitializationSettings(
        android: AndroidInitializationSettings('ic_notification'),
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
      ),
      onDidReceiveNotificationResponse: (_) => opened.value++,
    );
    final launch = await plugin.getNotificationAppLaunchDetails();
    if (launch?.didNotificationLaunchApp ?? false) opened.value++;
    initialized = true;
  }

  Future<bool> configure({
    required bool enabled,
    required int minute,
    bool requestPermission = false,
  }) async {
    if (!supported) return false;
    await initialize();
    if (!enabled) {
      await plugin.cancel(id);
      return false;
    }
    if (requestPermission) {
      final android = plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      final ios = plugin
          .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin
          >();
      if (android != null &&
          await android.requestNotificationsPermission() != true) {
        return false;
      }
      if (ios != null &&
          await ios.requestPermissions(
                alert: true,
                badge: false,
                sound: true,
              ) !=
              true) {
        return false;
      }
    }
    final android = plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    if (android != null && await android.areNotificationsEnabled() != true) {
      return false;
    }
    if (android != null) {
      await android.createNotificationChannel(
        AndroidNotificationChannel(
          'nightly_recording',
          tr('nightly_reminder.003'),
          description: tr('nightly_reminder.004'),
        ),
      );
    }
    final now = tz.TZDateTime.now(tz.local);
    var next = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      minute ~/ 60,
      minute % 60,
    );
    if (!next.isAfter(now)) {
      next = tz.TZDateTime(
        tz.local,
        now.year,
        now.month,
        now.day + 1,
        minute ~/ 60,
        minute % 60,
      );
    }
    await plugin.zonedSchedule(
      id,
      tr('nightly_reminder.001'),
      tr('nightly_reminder.002'),
      next,
      NotificationDetails(
        android: AndroidNotificationDetails(
          'nightly_recording',
          tr('nightly_reminder.003'),
          channelDescription: tr('nightly_reminder.004'),
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority,
        ),
        iOS: DarwinNotificationDetails(),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
      payload: 'daily-recording',
    );
    return true;
  }
}
