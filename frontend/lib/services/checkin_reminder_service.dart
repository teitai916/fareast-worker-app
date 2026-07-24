import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

/// 打卡提醒服务
/// 周一至周六 08:30、16:30 各提醒一次，带声音和震动
class CheckinReminderService {
  static const String _prefKeyScheduled = 'checkin_reminder_scheduled';

  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  // Android 通知通道
  static const String _channelId = 'checkin_reminder';
  static const String _channelName = '打卡提醒';
  static const String _channelDesc = '每日两次打卡提醒（周一至周六 08:30 / 16:30）';

  // 通知 ID 范围：100-111 共 12 条
  static const int _idBase = 100;

  /// 初始化通知插件（app 启动时调用一次）
  static Future<void> init() async {
    // 初始化时区数据
    tz.initializeTimeZones();

    // Android 通知通道配置
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    // iOS 设置
    const iosSettings = DarwinInitializationSettings(
      requestSoundPermission: true,
      requestBadgePermission: false,
      requestAlertPermission: true,
    );

    await _plugin.initialize(
      const InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
      ),
    );

    // 请求 Android 13+ 通知权限
    if (Platform.isAndroid) {
      final androidPlugin = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      await androidPlugin?.requestNotificationsPermission();
    }
  }

  /// 调度所有提醒（工人登录后调用）
  static Future<void> schedule() async {
    // 避免重复调度
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(_prefKeyScheduled) == true) return;

    // 取消已有通知（覆盖旧调度）
    for (int i = 0; i < 12; i++) {
      await _plugin.cancel(_idBase + i);
    }

    final hk = tz.getLocation('Asia/Hong_Kong');

    // 周一到周六的 WeekDay 编号（DateTime: Monday=1 ... Saturday=6）
    const days = [DateTime.monday, DateTime.tuesday, DateTime.wednesday,
                  DateTime.thursday, DateTime.friday, DateTime.saturday];
    // 两个提醒时间
    const times = [
      (hour: 8, minute: 30, label: '上午'),
      (hour: 16, minute: 30, label: '下午'),
    ];

    int id = _idBase;

    for (final day in days) {
      for (final time in times) {
        // 构造 TZDateTime：今天对应的星期几 + 指定时间
        var scheduledDate = _nextInstanceOf(hk, day, time.hour, time.minute);

        await _plugin.zonedSchedule(
          id++,
          '打卡提醒',
          '${time.label} ${time.hour}:${time.minute.toString().padLeft(2, '0')} 到了，请打开 App 打卡！',
          scheduledDate,
          _notificationDetails(),
          androidScheduleMode: AndroidScheduleMode.alarmClock,
          matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
        );
      }
    }

    await prefs.setBool(_prefKeyScheduled, true);
    debugPrint('[CheckinReminder] 已调度 12 条打卡提醒通知');
  }

  /// 取消所有提醒
  static Future<void> cancel() async {
    for (int i = 0; i < 12; i++) {
      await _plugin.cancel(_idBase + i);
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefKeyScheduled);
    debugPrint('[CheckinReminder] 已取消所有打卡提醒');
  }

  /// 计算下一个星期几 + 指定时间的 TZDateTime
  static tz.TZDateTime _nextInstanceOf(
      tz.Location location, int weekday, int hour, int minute) {
    final now = tz.TZDateTime.now(location);
    tz.TZDateTime scheduled = tz.TZDateTime(location, now.year, now.month,
        now.day, hour, minute);

    // 找到下一个目标星期几
    while (scheduled.weekday != weekday || scheduled.isBefore(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    return scheduled;
  }

  /// 通知详情（声音 + 震动）
  static NotificationDetails _notificationDetails() {
    const androidDetails = AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: _channelDesc,
      importance: Importance.max,
      priority: Priority.high,
      playSound: true,
      enableVibration: true,
    );
    const iosDetails = DarwinNotificationDetails(
      presentSound: true,
      presentAlert: true,
    );
    return const NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );
  }
}
