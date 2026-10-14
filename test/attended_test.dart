import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:weeb_radar/data/app_state.dart';
import 'package:weeb_radar/data/feed_service.dart';
import 'package:weeb_radar/data/sync_service.dart';
import 'package:weeb_radar/models/attended.dart';
import 'package:weeb_radar/models/event.dart';
import 'package:weeb_radar/ui/app_scope.dart';
import 'package:weeb_radar/ui/attended_page.dart';
import 'package:weeb_radar/ui/favorites_page.dart';

import 'sync_test.dart' show FakeGitHub, device;

RadarEvent tour() => RadarEvent.fromJson({
  'id': 'nier-2026',
  'artist': 'NieR:Orchestra Concert',
  'title': 'Europe Tour',
  'kind': 'symfoniczny',
  'dateStart': '2026-10-01',
  'dateEnd': '2026-10-20',
  'stops': [
    {'date': '2026-10-01', 'city': 'Londyn', 'cc': 'UK'},
    {'date': '2026-10-13', 'city': 'Warszawa', 'cc': 'PL', 'venue': 'Torwar'},
    {'date': '2026-10-20', 'city': 'Berlin', 'cc': 'DE'},
  ],
});

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('wpis z trasy bierze ostatni miniony przystanek', () {
    final a = Attended.fromEvent(tour(), at: 1, today: DateTime(2026, 10, 14));
    expect(a.id, 'ev-nier-2026');
    expect(a.city, 'Warszawa');
    expect(a.venue, 'Torwar');
    expect(a.date, DateTime(2026, 10, 13));
    expect(a.kind, 'symfoniczny');
  });

  test('historia: nowsza zmiana wygrywa, usunięcie też, i przechodzi przez plik gista', () {
    final a = {'x': Attended(id: 'x', artist: 'TAK', date: DateTime(2026, 5, 1), at: 10)};
    final b = {
      'x': Attended(id: 'x', artist: 'TAK', date: DateTime(2026, 5, 1), at: 20, deleted: true),
      'y': Attended(id: 'y', artist: 'Aiobahn', date: DateTime(2026, 6, 1), rating: 5, note: 'bomba', at: 1),
    };
    final m = mergeAttended(a, b);
    expect(m['x']!.deleted, isTrue);
    expect(m['y']!.rating, 5);
    final back = decodeAttended(encodeEntries({}, attended: m));
    expect(back, m);
    expect(back['y']!.note, 'bomba');
    expect(decodeAttended(encodeEntries({})), isEmpty);
  });

  test('„Byłem” synchronizuje się między telefonem i komputerem', () async {
    final gh = FakeGitHub();
    final phone = await device(gh, prefs: {'sync.token': 'good'});
    phone.toggleAttended(tour());
    expect(phone.wasAt('nier-2026'), isTrue);
    phone.saveAttended(Attended(id: 'own-1', artist: 'Vocafest', date: DateTime(2025, 4, 5), city: 'Londyn', at: 0));
    await phone.syncNow();

    final pc = await device(gh, prefs: {'sync.token': 'good'});
    await pc.syncNow();
    expect(pc.attended.map((a) => a.artist), ['NieR:Orchestra Concert', 'Vocafest']);

    // Ocena dodana na komputerze i usunięcie na telefonie spotykają się w gistcie.
    final nier = pc.attended.first;
    pc.saveAttended(nier.copyWith(rating: 5, at: nier.at));
    await pc.syncNow();
    phone.removeAttended('own-1');
    await phone.syncNow();
    await pc.syncNow();
    expect(phone.attended.single.rating, 5);
    expect(pc.attended.map((a) => a.id), ['ev-nier-2026']);

    // Drugie „Byłem” zdejmuje wpis.
    pc.toggleAttended(tour());
    expect(pc.wasAt('nier-2026'), isFalse);
  });

  testWidgets('karta „Byłem” pokazuje historię, a formularz dopisuje koncert', (t) async {
    await initializeDateFormatting('pl');
    SharedPreferences.setMockInitialValues({});
    final s = AppState(await SharedPreferences.getInstance())..loadSettings();
    s.saveAttended(
      Attended(
        id: 'own-1',
        artist: 'NieR:Orchestra',
        date: DateTime(2026, 10, 13),
        city: 'Warszawa',
        cc: 'PL',
        rating: 5,
        note: 'Weight of the World na bis',
        at: 0,
      ),
    );
    await t.pumpWidget(
      AppScope(
        notifier: s,
        child: const MaterialApp(home: Scaffold(body: FavoritesPage())),
      ),
    );
    await t.tap(find.textContaining('Byłem ('));
    await t.pumpAndSettle();
    expect(find.text('NieR:Orchestra'), findsOneWidget);
    expect(find.text('★★★★★'), findsOneWidget);
    await t.ensureVisible(find.textContaining('Dopisz ręcznie'));
    await t.pump();
    await t.tap(find.textContaining('Dopisz ręcznie'));
    await t.pump();
    await t.pump(const Duration(seconds: 1));
    await t.enterText(find.byType(TextFormField).first, 'TAK');
    await t.tap(find.text('Zapisz'), warnIfMissed: false);
    await t.pump(const Duration(seconds: 1));
    expect(s.attended.map((a) => a.artist), containsAll(['NieR:Orchestra', 'TAK']));
  });

  test('archiwum z feedu parsuje się i trafia do listy minionych', () {
    final list = FeedService.parseArchive(
      '{"events": [{"id": "past-nier", "artist": "NieR:Orchestra Concert", '
      '"kind": "symfoniczny", "dateStart": "2026-10-13", "stops": [{"date": "2026-10-13", "city": "Warszawa", "cc": "PL"}]},'
      ' {"id": "zly"}]}',
    );
    expect(list.single.id, 'past-nier');
    expect(FeedService.parseArchive('śmieci'), isEmpty);
  });

  testWidgets('„Byłem” wybrane z wyszukiwarki minionych koncertów', (t) async {
    await initializeDateFormatting('pl');
    SharedPreferences.setMockInitialValues({});
    final s = AppState(await SharedPreferences.getInstance())..loadSettings();
    s.archive = [
      tour(),
      RadarEvent.fromJson({
        'id': 'past-babymetal',
        'artist': 'BABYMETAL',
        'kind': 'koncert',
        'dateStart': '2025-02-01',
        'stops': [
          {'date': '2025-02-01', 'city': 'Kraków', 'cc': 'PL'},
        ],
      }),
      RadarEvent.fromJson({
        'id': 'past-animatsuri',
        'artist': 'Animatsuri 2026',
        'kind': 'konwent',
        'dateStart': '2026-07-17',
        'lineup': ['VocaFest UK', 'Shota Nakama'],
        'stops': [
          {'date': '2026-07-17', 'city': 'Warszawa', 'cc': 'PL'},
        ],
      }),
    ];
    await t.pumpWidget(
      AppScope(
        notifier: s,
        child: const MaterialApp(home: PastEventPicker()),
      ),
    );
    await t.pump();
    expect(find.text('BABYMETAL'), findsOneWidget);
    // Konwent znajduje się też po kimś z line-upu.
    await t.enterText(find.byType(TextField), 'vocafest');
    await t.pump();
    expect(find.text('Animatsuri 2026'), findsOneWidget);
    expect(find.text('BABYMETAL'), findsNothing);
    await t.enterText(find.byType(TextField), 'krakow');
    await t.pump();
    expect(find.text('NieR:Orchestra Concert'), findsNothing);
    await t.tap(find.text('BABYMETAL'));
    await t.pump();
    expect(s.wasAt('past-babymetal'), isTrue);
  });
}
