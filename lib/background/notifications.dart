import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../data/news.dart';
import '../edition.dart';
import '../models/song.dart';
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

  /// Nowa muzyka: osobny, cichy kanał (bez dźwięku, nie wyskakuje na ekran).
  static const _music = AndroidNotificationDetails(
    'weeb_radar_music',
    'Nowa muzyka',
    channelDescription: 'Nowe kawałki Twoich artystów i propozycje, mniej ważne niż eventy',
    importance: Importance.low,
    priority: Priority.low,
    icon: 'ic_stat_radar',
    color: spotifyGreen,
  );

  static Future<void> showSongs(List<Song> songs) async {
    if (songs.isEmpty || !supported) return;
    await init();
    String line(Song x) => '${x.pick ? '✨' : '🎵'} ${x.artist} – ${x.title}';
    final title = songs.length == 1
        ? 'Nowy kawałek: ${songs.single.artist}'
        : 'Nowa muzyka: ${songs.length} ${songs.length < 5 ? 'kawałki' : 'kawałków'}';
    final lines = songs.take(6).map(line).toList();
    await _plugin.show(
      id: 2,
      title: title,
      body: songs.length == 1 ? songs.single.title : lines.join('\n'),
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          _music.channelId,
          _music.channelName,
          channelDescription: _music.channelDescription,
          importance: _music.importance,
          priority: _music.priority,
          icon: _music.icon,
          color: _music.color,
          styleInformation: InboxStyleInformation(lines, contentTitle: title),
        ),
        windows: const WindowsNotificationDetails(),
      ),
    );
  }

  static bool get supported => !kIsWeb && (Platform.isAndroid || Platform.isWindows);

  static Future<void> init({void Function()? onTap}) async {
    if (_ready || !supported) return;
    await _plugin.initialize(
      settings: InitializationSettings(
        android: const AndroidInitializationSettings('ic_stat_radar'),
        windows: WindowsInitializationSettings(
          appName: appName,
          appUserModelId: friendsEdition ? 'Awex.RadarKoncertow.App' : 'Awex.WeebRadar.App',
          guid: friendsEdition ? '0d4c8e1a-3f6b-4a2d-9c5e-7b1a2f3e4d5c' : '6b2f1c3e-8a4d-4e5f-9b7a-2c1d0e3f4a5b',
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
      title = '$appName: ${[
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
