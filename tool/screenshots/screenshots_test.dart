// ignore_for_file: invalid_use_of_visible_for_testing_member
// Generuje podglądy ekranów do README:
//   flutter test tool/screenshots/screenshots_test.dart --update-goldens
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:weeb_radar/data/app_state.dart';
import 'package:weeb_radar/data/feed_service.dart';
import 'package:weeb_radar/main.dart';
import 'package:weeb_radar/ui/theme.dart';

Future<void> _font(String family, List<String> files) async {
  final loader = FontLoader(family);
  for (final f in files) {
    loader.addFont(Future.value(ByteData.sublistView(File(f).readAsBytesSync())));
  }
  await loader.load();
}

void main() {
  final flutterRoot = Platform.environment['FLUTTER_ROOT'] ?? '/home/claude/flutter';
  final fonts = '$flutterRoot/bin/cache/artifacts/material_fonts';

  setUpAll(() async {
    await initializeDateFormatting('pl');
    await _font('Roboto', ['$fonts/Roboto-Regular.ttf', '$fonts/Roboto-Bold.ttf', '$fonts/Roboto-Black.ttf']);
    await _font('MaterialIcons', ['$fonts/MaterialIcons-Regular.otf']);
    const emoji = '/usr/share/fonts/truetype/noto/NotoColorEmoji.ttf';
    if (File(emoji).existsSync()) await _font('Emoji', [emoji]);
    fontOverride = 'Roboto';
  });

  Future<AppState> state() async {
    SharedPreferences.setMockInitialValues({'taste.favourites': ['2026-11-miku-expo']});
    final feed = File('assets/events_fallback.json').readAsStringSync();
    final client = MockClient((req) async => req.url.host.contains('github')
        ? http.Response.bytes(utf8Bytes(feed), 200)
        : http.Response('{"items":[]}', 200));
    final s = AppState(await SharedPreferences.getInstance(), feed: FeedService(client: client));
    await s.init();
    return s;
  }

  for (final (name, size, tab) in [
    ('phone_radar', const Size(412, 915), null),
    ('phone_calendar', const Size(412, 915), 'Kalendarz'),
    ('phone_artists', const Size(412, 915), 'Artyści'),
    ('phone_look', const Size(412, 915), 'Wygląd'),
    ('windows_radar', const Size(1400, 900), null),
  ]) {
    testWidgets(name, (tester) async {
      tester.view.physicalSize = size * 2;
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.reset);
      final s = await tester.runAsync(state);
      await tester.pumpWidget(WeebRadarApp(state: s!));
      await tester.pump(const Duration(seconds: 1));
      if (tab != null) {
        await tester.tap(find.byIcon(_iconFor(tab)).first);
        await tester.pump(const Duration(seconds: 1));
      }
      await tester.runAsync(() => Future.delayed(const Duration(milliseconds: 200)));
      await tester.pump(const Duration(milliseconds: 500));
      await expectLater(find.byType(WeebRadarApp), matchesGoldenFile('../../docs/screenshots/$name.png'));
    });
  }
}

List<int> utf8Bytes(String s) => const Utf8Encoder().convert(s);

IconData _iconFor(String tab) => switch (tab) {
      'Kalendarz' => Icons.calendar_month_outlined,
      'Artyści' => Icons.headphones_outlined,
      'Wygląd' => Icons.palette_outlined,
      _ => Icons.radar_outlined,
    };
