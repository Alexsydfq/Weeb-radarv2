import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:weeb_radar/data/app_state.dart';
import 'package:weeb_radar/data/feed_service.dart';
import 'package:weeb_radar/data/sync_service.dart';

/// Udawany GitHub z gistami w pamięci.
class FakeGitHub {
  final gists = <String, String>{};
  var calls = 0;

  late final client = MockClient((r) async {
    calls++;
    if (r.headers['Authorization'] != 'Bearer good') return http.Response('{}', 401);
    final path = r.url.path;
    if (r.method == 'GET' && path == '/gists') {
      return http.Response(
        jsonEncode([
          {'id': 'other', 'files': {'notes.md': {}}},
          for (final id in gists.keys) {'id': id, 'files': {SyncService.fileName: {}}},
        ]),
        200,
      );
    }
    if (r.method == 'POST' && path == '/gists') {
      final body = jsonDecode(r.body) as Map;
      expect(body['public'], isFalse);
      final id = 'g${gists.length + 1}';
      gists[id] = body['files'][SyncService.fileName]['content'] as String;
      return http.Response(jsonEncode({'id': id}), 201);
    }
    final id = path.split('/').last;
    if (!gists.containsKey(id)) return http.Response('{}', 404);
    if (r.method == 'GET') {
      return http.Response(
        jsonEncode({'id': id, 'files': {SyncService.fileName: {'content': gists[id]}}}),
        200,
      );
    }
    if (r.method == 'PATCH') {
      gists[id] = (jsonDecode(r.body) as Map)['files'][SyncService.fileName]['content'] as String;
      return http.Response(jsonEncode({'id': id}), 200);
    }
    return http.Response('{}', 405);
  });
}

Future<AppState> device(FakeGitHub gh, {Map<String, Object> prefs = const {}}) async {
  SharedPreferences.setMockInitialValues({...prefs});
  final feed = FeedService(client: MockClient((_) async => http.Response('{"events": []}', 200)));
  final s = AppState(await SharedPreferences.getInstance(), feed: feed, sync: SyncService(client: gh.client));
  await s.init();
  return s;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('łączenie: nowsza zmiana wygrywa, odznaczenie też', () {
    final a = {
      'x': const PlanEntry(plan: Plan.going, at: 10),
      'y': const PlanEntry(fav: true, at: 5),
    };
    final b = {
      'x': const PlanEntry(plan: Plan.notGoing, at: 20),
      'y': const PlanEntry(at: 3),
      'z': const PlanEntry(plan: Plan.maybe, at: 1),
    };
    final m = mergeEntries(a, b);
    expect(m['x']!.plan, Plan.notGoing);
    expect(m['y']!.fav, isTrue);
    expect(m['z']!.plan, Plan.maybe);
    expect(mergeEntries(b, a), m);
    expect(decodeEntries(encodeEntries(m)), m);
  });

  test('telefon i komputer widzą te same plany', () async {
    final gh = FakeGitHub();
    final pc = await device(gh, prefs: {'sync.token': 'good'});
    await pc.syncNow();
    expect(gh.gists.length, 1, reason: 'pierwsza synchronizacja zakłada prywatny gist');

    pc.setPlan('vocafest-2027', Plan.going);
    pc.toggleFavourite('miku-expo');
    await pc.syncNow();

    final phone = await device(gh, prefs: {'sync.token': 'good'});
    await phone.syncNow();
    expect(gh.gists.length, 1, reason: 'drugie urządzenie znajduje ten sam gist');
    expect(phone.planOf('vocafest-2027'), Plan.going);
    expect(phone.favourites, contains('miku-expo'));

    phone.setPlan('vocafest-2027', Plan.notGoing);
    phone.setPlan('pohoda-2027', Plan.maybe);
    phone.setPlan('animecon-2027', Plan.interested);
    await phone.syncNow();
    await pc.syncNow();
    expect(pc.planOf('vocafest-2027'), Plan.notGoing);
    expect(pc.planOf('pohoda-2027'), Plan.maybe);
    expect(pc.planOf('animecon-2027'), Plan.interested);

    // Ten sam plan drugi raz go zdejmuje, i to też się synchronizuje.
    pc.setPlan('pohoda-2027', Plan.maybe);
    await pc.syncNow();
    await phone.syncNow();
    expect(phone.planOf('pohoda-2027'), isNull);


  });

  test('lista „już powiadomione” sumuje się między urządzeniami', () async {
    final gh = FakeGitHub();
    final phone = await device(gh, prefs: {'sync.token': 'good'});
    await phone.markNotified(['miku', 'deco']);
    final pc = await device(gh, prefs: {'sync.token': 'good'});
    await pc.syncNow();
    expect(pc.notified, {'miku', 'deco'});
    await pc.markNotified(['vocafest']);
    await phone.syncNow();
    expect(phone.notified, {'miku', 'deco', 'vocafest'});
  });

  test('nowi domyślni artyści dochodzą, usunięci nie wracają', () async {
    final old = await device(FakeGitHub(), prefs: {'taste.artists': ['Ado', 'Moja Kapela']});
    expect(old.artists, containsAll(['Ado', 'Moja Kapela', 'Nilfruits', 'DECO*27']));
    // Użytkownik usuwa Nilfruits: po ponownym starcie nie wraca.
    final p = await SharedPreferences.getInstance();
    final kept = old.artists.where((a) => a != 'Nilfruits').toList();
    final again = await device(FakeGitHub(), prefs: {
      'taste.artists': kept,
      'taste.knownDefaults': p.getStringList('taste.knownDefaults')!,
    });
    expect(again.artists, isNot(contains('Nilfruits')));
    expect(again.artists.length, kept.length);
  });

  test('zły token daje czytelny błąd i nie psuje lokalnych planów', () async {
    final gh = FakeGitHub();
    final s = await device(gh, prefs: {'sync.token': 'bad'});
    s.setPlan('a', Plan.going);
    await s.syncNow();
    expect(s.syncError, contains('401'));
    expect(s.planOf('a'), Plan.going);

  });

  test('stare ulubione i ukryte przechodzą do nowego formatu', () async {
    final s = await device(FakeGitHub(), prefs: {
      'taste.favourites': ['f1'],
      'taste.hidden': ['h1'],
    });
    expect(s.favourites, {'f1'});
    expect(s.hidden, {'h1'});
    expect(s.syncEnabled, isFalse);
    s.unhideAll();
    expect(s.hidden, isEmpty);

  });

  test('„Nie idę” spada w wyniku, „Idę” zawsze jest dla mnie', () async {
    final s = await device(FakeGitHub());
    final e = s.events.first;
    final base = s.score(e);
    s.setPlan(e.id, Plan.notGoing);
    expect(s.score(e), lessThan(base));
    s.setHideNotGoing(true);
    expect(s.isForYou(e), isFalse);
    s.setPlan(e.id, Plan.going);
    expect(s.isForYou(e), isTrue);

  });
}
