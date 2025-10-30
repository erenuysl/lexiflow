import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

class NotificationService {
  NotificationService._();
  static final NotificationService _instance = NotificationService._();
  factory NotificationService() => _instance;

  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  bool _initialized = false;
  GlobalKey<NavigatorState>? _navigatorKey;

  void registerNavigatorKey(GlobalKey<NavigatorState> key) {
    _navigatorKey = key;
  }

  // Channel definitions
  static const AndroidNotificationChannel _defaultChannel = AndroidNotificationChannel(
    'lexiflow_general',
    'LexiFlow Bildirimleri',
    description: 'Genel uygulama bildirimleri',
    importance: Importance.defaultImportance,
  );

  // Fixed IDs for scheduled notifications
  static const int idDailyWord = 1001;
  static const int idStreak = 1002;
  static const int idReview = 1003;

  Future<void> init() async {
    if (_initialized) return;

    // Timezone init (safe-guarded)
    try {
      tz.initializeTimeZones();
      final localName = DateTime.now().timeZoneName;
      try {
        tz.setLocalLocation(tz.getLocation(localName));
      } catch (_) {
        // Fallback to default local if mapping fails
        tz.setLocalLocation(tz.local);
      }
    } catch (_) {}

    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInit = DarwinInitializationSettings();
    const initSettings = InitializationSettings(android: androidInit, iOS: iosInit);

    await _plugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (resp) async {
        final payload = resp.payload;
        if (payload != null && payload.isNotEmpty) {
          _handlePayload(payload);
        }
      },
    );

    // Create default channel on Android
    if (Platform.isAndroid) {
      await _plugin
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(_defaultChannel);
    }

    _initialized = true;
  }

  Future<bool> requestPermission() async {
    if (Platform.isAndroid) {
      final androidImpl = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      final granted = await androidImpl?.requestNotificationsPermission() ?? true; // pre-Android 13 returns null
      return granted;
    } else {
      final ios = _plugin.resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>();
      final result = await ios?.requestPermissions(alert: true, badge: true, sound: true);
      return result ?? false;
    }
  }

  Future<void> showInstant({required String title, required String body, String? payload}) async {
    final android = AndroidNotificationDetails(
      _defaultChannel.id,
      _defaultChannel.name,
      channelDescription: _defaultChannel.description,
      importance: Importance.defaultImportance,
      priority: Priority.defaultPriority,
    );
    const ios = DarwinNotificationDetails();
    final details = NotificationDetails(android: android, iOS: ios);
    await _plugin.show(DateTime.now().millisecondsSinceEpoch.remainder(100000), title, body, details, payload: payload);
  }

  Future<void> scheduleDaily({
    required int id,
    required String title,
    required String body,
    required TimeOfDay time,
    String? payload,
    Set<int>? weekdays, // 1=Mon ... 7=Sun
  }) async {
    final android = AndroidNotificationDetails(
      _defaultChannel.id,
      _defaultChannel.name,
      channelDescription: _defaultChannel.description,
      importance: Importance.defaultImportance,
      priority: Priority.defaultPriority,
    );
    const ios = DarwinNotificationDetails();
    final details = NotificationDetails(android: android, iOS: ios);

    if (weekdays == null || weekdays.isEmpty) {
      final now = tz.TZDateTime.now(tz.local);
      var scheduled = tz.TZDateTime(tz.local, now.year, now.month, now.day, time.hour, time.minute);
      if (scheduled.isBefore(now)) {
        scheduled = scheduled.add(const Duration(days: 1));
      }
      await _plugin.zonedSchedule(
        id,
        title,
        body,
        scheduled,
        details,
        androidScheduleMode: AndroidScheduleMode.inexact,
        matchDateTimeComponents: DateTimeComponents.time,
        payload: payload,
      );
    } else {
      // Schedule per weekday with unique IDs (id * 10 + weekday)
      for (final w in weekdays) {
        final scheduled = _nextInstanceOfWeekday(time, w);
        await _plugin.zonedSchedule(
          id * 10 + w,
          title,
          body,
          scheduled,
        details,
        androidScheduleMode: AndroidScheduleMode.inexact,
        matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
          payload: payload,
        );
      }
    }
  }

  tz.TZDateTime _nextInstanceOfWeekday(TimeOfDay time, int weekday) {
    final now = tz.TZDateTime.now(tz.local);
    var scheduled = tz.TZDateTime(tz.local, now.year, now.month, now.day, time.hour, time.minute);
    while (scheduled.weekday != weekday || scheduled.isBefore(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    return scheduled;
  }

  Future<void> cancel(int id) => _plugin.cancel(id);
  Future<void> cancelAll() => _plugin.cancelAll();

  // Preferences helpers
  static const _kDailyWordEnabled = 'notif_daily_word_enabled';
  static const _kDailyWordHour = 'notif_daily_word_hour';
  static const _kDailyWordMin = 'notif_daily_word_min';
  static const _kDailyWordWeekdaysOnly = 'notif_daily_word_weekdays_only';

  static const _kStreakEnabled = 'notif_streak_enabled';
  static const _kStreakHour = 'notif_streak_hour';
  static const _kStreakMin = 'notif_streak_min';
  static const _kStreakWeekdaysOnly = 'notif_streak_weekdays_only';

  static const _kReviewEnabled = 'notif_review_enabled';
  static const _kReviewHour = 'notif_review_hour';
  static const _kReviewMin = 'notif_review_min';
  static const _kReviewWeekdaysOnly = 'notif_review_weekdays_only';

  static const _kQuietStartHour = 'notif_quiet_start_h';
  static const _kQuietStartMin = 'notif_quiet_start_m';
  static const _kQuietEndHour = 'notif_quiet_end_h';
  static const _kQuietEndMin = 'notif_quiet_end_m';

  Future<void> saveDailyWordPref(bool enabled, TimeOfDay time) async {
    final sp = await SharedPreferences.getInstance();
    await sp.setBool(_kDailyWordEnabled, enabled);
    await sp.setInt(_kDailyWordHour, time.hour);
    await sp.setInt(_kDailyWordMin, time.minute);
  }

  Future<(bool enabled, TimeOfDay time)> loadDailyWordPref() async {
    final sp = await SharedPreferences.getInstance();
    final enabled = sp.getBool(_kDailyWordEnabled) ?? false;
    final hour = sp.getInt(_kDailyWordHour) ?? 9;
    final min = sp.getInt(_kDailyWordMin) ?? 0;
    return (enabled, TimeOfDay(hour: hour, minute: min));
  }
  Future<void> saveDailyWordWeekdaysOnly(bool weekdaysOnly) async {
    final sp = await SharedPreferences.getInstance();
    await sp.setBool(_kDailyWordWeekdaysOnly, weekdaysOnly);
  }
  Future<bool> loadDailyWordWeekdaysOnly() async {
    final sp = await SharedPreferences.getInstance();
    return sp.getBool(_kDailyWordWeekdaysOnly) ?? false;
  }

  Future<void> saveStreakPref(bool enabled, TimeOfDay time) async {
    final sp = await SharedPreferences.getInstance();
    await sp.setBool(_kStreakEnabled, enabled);
    await sp.setInt(_kStreakHour, time.hour);
    await sp.setInt(_kStreakMin, time.minute);
  }

  Future<(bool enabled, TimeOfDay time)> loadStreakPref() async {
    final sp = await SharedPreferences.getInstance();
    final enabled = sp.getBool(_kStreakEnabled) ?? false;
    final hour = sp.getInt(_kStreakHour) ?? 20;
    final min = sp.getInt(_kStreakMin) ?? 0;
    return (enabled, TimeOfDay(hour: hour, minute: min));
  }
  Future<void> saveStreakWeekdaysOnly(bool weekdaysOnly) async {
    final sp = await SharedPreferences.getInstance();
    await sp.setBool(_kStreakWeekdaysOnly, weekdaysOnly);
  }
  Future<bool> loadStreakWeekdaysOnly() async {
    final sp = await SharedPreferences.getInstance();
    return sp.getBool(_kStreakWeekdaysOnly) ?? false;
  }

  Future<void> saveReviewPref(bool enabled, TimeOfDay time) async {
    final sp = await SharedPreferences.getInstance();
    await sp.setBool(_kReviewEnabled, enabled);
    await sp.setInt(_kReviewHour, time.hour);
    await sp.setInt(_kReviewMin, time.minute);
  }

  Future<(bool enabled, TimeOfDay time)> loadReviewPref() async {
    final sp = await SharedPreferences.getInstance();
    final enabled = sp.getBool(_kReviewEnabled) ?? false;
    final hour = sp.getInt(_kReviewHour) ?? 18;
    final min = sp.getInt(_kReviewMin) ?? 0;
    return (enabled, TimeOfDay(hour: hour, minute: min));
  }
  Future<void> saveReviewWeekdaysOnly(bool weekdaysOnly) async {
    final sp = await SharedPreferences.getInstance();
    await sp.setBool(_kReviewWeekdaysOnly, weekdaysOnly);
  }
  Future<bool> loadReviewWeekdaysOnly() async {
    final sp = await SharedPreferences.getInstance();
    return sp.getBool(_kReviewWeekdaysOnly) ?? false;
  }

  Future<void> saveQuietHours(TimeOfDay start, TimeOfDay end) async {
    final sp = await SharedPreferences.getInstance();
    await sp.setInt(_kQuietStartHour, start.hour);
    await sp.setInt(_kQuietStartMin, start.minute);
    await sp.setInt(_kQuietEndHour, end.hour);
    await sp.setInt(_kQuietEndMin, end.minute);
  }
  Future<(TimeOfDay start, TimeOfDay end)> loadQuietHours() async {
    final sp = await SharedPreferences.getInstance();
    final sh = sp.getInt(_kQuietStartHour) ?? 23;
    final sm = sp.getInt(_kQuietStartMin) ?? 0;
    final eh = sp.getInt(_kQuietEndHour) ?? 7;
    final em = sp.getInt(_kQuietEndMin) ?? 0;
    return (TimeOfDay(hour: sh, minute: sm), TimeOfDay(hour: eh, minute: em));
  }

  Future<void> applySchedulesFromPrefs() async {
    await init();
    final (dwEnabled, dwTime) = await loadDailyWordPref();
    final (stEnabled, stTime) = await loadStreakPref();
    final (rvEnabled, rvTime) = await loadReviewPref();
    final dwWeekdays = await loadDailyWordWeekdaysOnly();
    final stWeekdays = await loadStreakWeekdaysOnly();
    final rvWeekdays = await loadReviewWeekdaysOnly();

    if (dwEnabled) {
      await scheduleDaily(
        id: idDailyWord,
        title: 'GÃ¼nÃ¼n Kelimesi',
        body: 'BugÃ¼nÃ¼n kelimesini keÅŸfet!',
        time: dwTime,
        weekdays: dwWeekdays ? {1, 2, 3, 4, 5} : {1, 2, 3, 4, 5, 6, 7},
        payload: '/daily_word',
      );
    } else {
      await cancel(idDailyWord);
    }

    if (stEnabled) {
      await scheduleDaily(
        id: idStreak,
        title: 'Serini Koru',
        body: 'BugÃ¼nkÃ¼ hedefini kaÃ§Ä±rma!',
        time: stTime,
        weekdays: stWeekdays ? {1, 2, 3, 4, 5} : {1, 2, 3, 4, 5, 6, 7},
        payload: '/quiz',
      );
    } else {
      await cancel(idStreak);
    }

    if (rvEnabled) {
      await scheduleDaily(
        id: idReview,
        title: 'GÃ¶zden GeÃ§irme ZamanÄ±',
        body: 'Bekleyen kelimelerini tekrar et!',
        time: rvTime,
        weekdays: rvWeekdays ? {1, 2, 3, 4, 5} : {1, 2, 3, 4, 5, 6, 7},
        payload: '/favorites',
      );
    } else {
      await cancel(idReview);
    }
  }

  void _handlePayload(String route) {
    final nav = _navigatorKey?.currentState;
    if (nav == null) return;
    try {
      nav.pushNamed(route);
    } catch (_) {}
  }
}



