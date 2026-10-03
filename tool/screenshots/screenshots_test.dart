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
    SharedPreferences.setMockInitialValues({
      'plans.entries': jsonEncode({
        'entries': {
          '2026-11-hatsune-miku-expo-europe': {'plan': 'going', 'fav': true, 'stop': '2026-11-20|Düsseldorf', 'at': 1},
          'fest-primavera-2027': {'plan': 'going', 'at': 1},
          '2026-10-yoko-kanno-lucca-milan': {'plan': 'maybe', 'at': 1},
          'fest-pohoda-2027': {'plan': 'interested', 'at': 1},
          '2026-12-manga-barcelona': {'fav': true, 'at': 1},
          '2026-10-spyair-europe': {'plan': 'notGoing', 'at': 1},
        },
      }),
    });
    // Przykładowy line-up i info, żeby było widać, jak wyglądają w szczegółach eventu.
    final raw = jsonDecode(File('assets/events_fallback.json').readAsStringSync()) as Map;
    for (final e in raw['events'] as List) {
      if (e['id'] == '2026-11-hatsune-miku-expo-europe') {
        e['lineup'] = ['Hatsune Miku', 'Kagamine Rin', 'Kagamine Len', 'Megurine Luka', 'KAITO', 'MEIKO', 'DJ Sample'];
        e['facts'] = [
          {'k': 'Bilety', 'v': 'od 49 £, sprzedaż trwa'},
          {'k': 'Godziny', 'v': 'drzwi 18:30, start 19:30'},
          {'k': 'Wiek', 'v': 'bez ograniczeń'},
        ];
        e['updatedAt'] = '2026-10-01';
        e['changeNote'] = 'Doszedł koncert w Lizbonie';
        e['about'] = 'Wirtualna piosenkarka Vocaloid od Crypton Future Media. Znasz ją z tysięcy piosenek producentów '
            'takich jak DECO*27, ryo (supercell) czy wowaka, z Project SEKAI i z Magical Mirai.';
        e['hits'] = ['Ievan Polkka', 'World is Mine', 'Rolling Girl', 'Senbonzakura', 'Vampire'];
      }
    }
    (raw['events'] as List).addAll([
      {
        'id': '2027-03-sana-natori-bakutan', 'artist': 'Natori Sana', 'title': 'BAKUTAN 2027', 'kind': 'koncert',
        'tier': 3, 'region': 'JP', 'dateStart': '2027-03-14',
        'stops': [{'date': '2027-03-14', 'city': 'Tokio', 'cc': 'JP', 'venue': 'Ariake Arena'}],
        'about': 'VTuberka i „przedszkolanka” znana z hitu „Hoshi ni Natte”; Bakutan to jej coroczny wielki lajw.',
        'hits': ['Hoshi ni Natte', 'Mahou no Kotoba'],
      },
      {
        'id': '2027-03-hololive-fes', 'artist': 'hololive 6th fes.', 'title': 'Color Rise Harmony', 'kind': 'festiwal',
        'tier': 3, 'region': 'JP', 'dateStart': '2027-03-20', 'dateEnd': '2027-03-21',
        'stops': [{'date': '2027-03-20', 'city': 'Chiba', 'cc': 'JP', 'venue': 'Makuhari Messe'}],
        'lineup': ['Laplus Darknesss', 'Hakui Koyori', 'Sakura Miko', 'Usada Pekora'],
      },
    ]);
    final feed = jsonEncode(raw);
    final client = MockClient((req) async => req.url.host.contains('github')
        ? http.Response.bytes(utf8Bytes(feed), 200)
        : http.Response('{"items":[]}', 200));
    final s = AppState(await SharedPreferences.getInstance(), feed: FeedService(client: client));
    await s.init();
    while (s.loading) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
    return s;
  }

  for (final (name, size, tab) in [
    ('phone_radar', const Size(412, 915), null),
    ('phone_japan', const Size(412, 915), 'Japonia'),
    ('phone_calendar', const Size(412, 915), 'Kalendarz'),
    ('phone_artists', const Size(412, 915), 'Artyści'),
    ('phone_plans', const Size(412, 915), 'Plany'),
    ('phone_event', const Size(412, 915), 'Plany'),
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
        if (const ['Artyści', 'Wygląd', 'Źródła'].contains(tab)) {
          await tester.tap(find.byIcon(Icons.more_horiz_rounded).first);
          await tester.pump(const Duration(seconds: 1));
          await tester.tap(find.text(tab).last);
        } else {
          await tester.tap(find.byIcon(_iconFor(tab)).first);
        }
        await tester.pump(const Duration(seconds: 1));
      }
      if (name == 'phone_event') {
        await tester.tap(find.text('MIKU EXPO 2026 Europe').first);
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
      'Japonia' => Icons.temple_buddhist_outlined,
      'Artyści' => Icons.headphones_outlined,
      'Wygląd' => Icons.palette_outlined,
      'Plany' => Icons.event_available_outlined,
      _ => Icons.radar_outlined,
    };
