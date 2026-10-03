import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:weeb_radar/data/app_state.dart';
import 'package:weeb_radar/data/news.dart';
import 'package:weeb_radar/data/sync_service.dart';
import 'package:weeb_radar/models/event.dart';

RadarEvent ev(String id, String artist, {String kind = 'koncert', String? change}) => RadarEvent.fromJson({
      'id': id, 'artist': artist, 'kind': kind, 'dateStart': '2030-05-01', 'stops': [],
      'changeNote': ?change,
    });

void main() {
  test('nowości: pierwszy raz wszystko, potem tylko nowe i ważne zmiany, nic dwa razy', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final s = AppState(prefs)..loadSettings();
    expect(s.notifyHours, 24);

    final miku = ev('miku', 'Hatsune Miku');
    final metal = ev('metal', 'Zespół Metalowy');
    final first = await collectNews(s, [miku, metal]);
    expect(first.map((n) => n.event.id), ['miku'], reason: 'pierwsze sprawdzenie: wszystko, co pasuje');
    expect(await collectNews(s, [miku, metal]), isEmpty, reason: 'drugi raz to samo już nie dzwoni');
    expect(prefs.getStringList('notify.seen'), containsAll(['miku', 'metal']));

    final deco = ev('deco', 'DECO*27');
    final other = ev('other', 'Ktoś Obcy');
    final nope = ev('nope', 'Nanahira');
    s.setPlan('nope', Plan.notGoing);
    final news = await collectNews(s, [miku, metal, deco, other, nope]);
    expect(news.map((n) => n.event.id), ['deco'], reason: 'tylko nowe, „dla mnie”, bez „Nie idę”');
    expect(news.single.rank, 3);

    // Zmiana w evencie z planem → powiadomienie; drugi raz ta sama zmiana już nie.
    s.setPlan('miku', Plan.going);
    final changed = ev('miku', 'Hatsune Miku', change: 'Doszedł koncert w Pradze');
    final n2 = await collectNews(s, [changed, metal, deco, other, nope]);
    expect(n2.single.change, 'Doszedł koncert w Pradze');
    expect(await collectNews(s, [changed, metal, deco, other, nope]), isEmpty);

    // Tryb „tylko Spotify”: nowy konwent bez Twoich artystów nie dzwoni.
    s.setNotify(spotifyOnly: true);
    final con = ev('con', 'Jakiś Konwent', kind: 'konwent');
    final kanaria = ev('kan', 'Kanaria');
    final n3 = await collectNews(s, [con, kanaria]);
    expect(n3.map((n) => n.event.id), ['kan']);
  });

  test('to, o czym powiadomił drugi sprzęt, nie dzwoni drugi raz', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final s = AppState(prefs)..loadSettings();
    // Tak jakby synchronizacja przyniosła listę z telefonu.
    await s.markNotified(['miku'], sync: false);
    final news = await collectNews(s, [ev('miku', 'Hatsune Miku'), ev('deco', 'DECO*27')]);
    expect(news.map((n) => n.event.id), ['deco']);
  });

  test('gist trzyma listę powiadomionych', () {
    final raw = encodeEntries({}, notified: {'b', 'a'});
    expect(decodeNotified(raw), {'a', 'b'});
    expect(decodeNotified(encodeEntries({})), isEmpty);
  });

  test('Japonia: osobno od Europy i z własnym przełącznikiem powiadomień', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final s = AppState(prefs)..loadSettings();
    final jp = RadarEvent.fromJson({
      'id': 'bakutan', 'artist': 'DECO*27', 'kind': 'koncert', 'dateStart': '2030-03-14',
      'stops': [{'date': '2030-03-14', 'city': 'Tokio', 'cc': 'JP'}],
    });
    expect(jp.isJapan, isTrue);
    expect(ev('x', 'DECO*27').isJapan, isFalse);
    expect(RadarEvent.fromJson({'id': 'r', 'artist': 'a', 'region': 'JP', 'dateStart': '2030-01-01'}).isJapan, isTrue);
    s.setNotify(japan: false);
    expect(await collectNews(s, [jp]), isEmpty);
    s.setNotify(japan: true);
    // Ta sama runda już go zapamiętała, więc nowy event z Japonii:
    final jp2 = RadarEvent.fromJson({
      'id': 'bakutan2', 'artist': 'DECO*27', 'kind': 'koncert', 'dateStart': '2030-03-15',
      'stops': [{'date': '2030-03-15', 'city': 'Osaka', 'cc': 'JP'}],
    });
    expect((await collectNews(s, [jp2])).map((n) => n.event.id), ['bakutan2']);
  });
}
