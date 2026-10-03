import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../data/news.dart';
import '../ui/util.dart';

/// Powiadomienia systemowe na Androidzie i Windowsie.
class Notifier {
  static final _plugin = FlutterLocalNotificationsPlugin();
  static bool _ready = false;

  static const _channel = AndroidNotificationDetails(
    'weeb_radar_news',
    'Nowe eventy',
    channelDescription: 'Nowe koncerty, konwenty i zmiany w eventach, które Cię obchodzą',
    importance: Importance.high,
    priority: Priority.high,
    icon: 'ic_stat_radar',
    color: spotifyGreen,
  );

  static bool get supported => !kIsWeb && (Platform.isAndroid || Platform.isWindows);

  static Future<void> init({void Function()? onTap}) async {
    if (_ready || !supported) return;
    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('ic_stat_radar'),
        windows: WindowsInitializationSettings(
          appName: 'Weeb Radar',
          appUserModelId: 'Awex.WeebRadar.App',
          guid: '6b2f1c3e-8a4d-4e5f-9b7a-2c1d0e3f4a5b',
        ),
      ),
      onDidReceiveNotificationResponse: (_) => onTap?.call(),
    );
    _ready = true;
  }

  static const _battery = MethodChannel('weeb_radar/battery');

  /// Android: czy apka jest zwolniona z oszczędzania baterii
  /// (wtedy codzienne sprawdzanie w tle nie jest ubijane).
  static Future<bool> batteryUnrestricted() async {
    if (kIsWeb || !Platform.isAndroid) return true;
    try {
      return await _battery.invokeMethod<bool>('isIgnoring') ?? true;
    } catch (_) {
      return true;
    }
  }

  /// Android: systemowe okienko „Zezwolić na działanie w tle?”.
  static Future<void> requestBatteryUnrestricted() async {
    if (kIsWeb || !Platform.isAndroid) return;
    try {
      await _battery.invokeMethod<void>('request');
    } catch (_) {}
  }

  /// Android 13+: pytamy o zgodę na powiadomienia.
  static Future<void> requestPermission() async {
    if (!supported || !Platform.isAndroid) return;
    await init();
    await _plugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
  }

  static String _line(NewsItem n) {
    final e = n.event;
    final who = n.rank != null ? '🎧 ${e.artist} (#${n.rank})' : e.artist;
    if (n.isChange) return '$who: ${n.change}';
    final st = e.nextStop;
    final where = st == null ? '' : ' · ${st.city}';
    return '$who · ${formatDay(e.nextDate)}$where';
  }

  static Future<void> show(List<NewsItem> news) async {
    if (news.isEmpty || !supported) return;
    await init();
    final String title;
    final String body;
    if (news.length == 1) {
      final n = news.single;
      title = n.isChange ? 'Zmiana: ${n.event.artist}' : 'Nowy event: ${n.event.artist}';
      body = n.isChange ? n.change! : [n.event.displayTitle, _line(n)].where((x) => x.isNotEmpty).join('\n');
    } else {
      final fresh = news.where((n) => !n.isChange).length;
      final changed = news.length - fresh;
      title = 'Weeb Radar: ${[
        if (fresh > 0) '$fresh ${fresh == 1 ? 'nowy event' : fresh < 5 ? 'nowe eventy' : 'nowych eventów'}',
        if (changed > 0) '$changed ${changed == 1 ? 'zmiana' : changed < 5 ? 'zmiany' : 'zmian'}',
      ].join(', ')}';
      body = news.take(6).map(_line).join('\n');
    }
    await _plugin.show(
      id: 1,
      title: title,
      body: body,
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          _channel.channelId,
          _channel.channelName,
          channelDescription: _channel.channelDescription,
          importance: _channel.importance,
          priority: _channel.priority,
          icon: _channel.icon,
          color: _channel.color,
          styleInformation: news.length > 1
              ? InboxStyleInformation(news.take(6).map(_line).toList(), contentTitle: title)
              : BigTextStyleInformation(body),
        ),
        windows: const WindowsNotificationDetails(),
      ),
    );
  }
}
