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
  test('nowości: pierwszy raz cisza, potem tylko nowe i ważne zmiany', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final s = AppState(prefs)..loadSettings();

    final miku = ev('miku', 'Hatsune Miku');
    final metal = ev('metal', 'Zespół Metalowy');
    expect(await collectNews(s, prefs, [miku, metal]), isEmpty, reason: 'pierwsze sprawdzenie tylko zapamiętuje');

    final deco = ev('deco', 'DECO*27');
    final other = ev('other', 'Ktoś Obcy');
    final nope = ev('nope', 'Nanahira');
    s.setPlan('nope', Plan.notGoing);
    final news = await collectNews(s, prefs, [miku, metal, deco, other, nope]);
    expect(news.map((n) => n.event.id), ['deco'], reason: 'tylko nowe, „dla mnie”, bez „Nie idę”');
    expect(news.single.rank, 3);

    // Zmiana w evencie z planem → powiadomienie; drugi raz ta sama zmiana już nie.
    s.setPlan('miku', Plan.going);
    final changed = ev('miku', 'Hatsune Miku', change: 'Doszedł koncert w Pradze');
    final n2 = await collectNews(s, prefs, [changed, metal, deco, other, nope]);
    expect(n2.single.change, 'Doszedł koncert w Pradze');
    expect(await collectNews(s, prefs, [changed, metal, deco, other, nope]), isEmpty);

    // Tryb „tylko Spotify”: nowy konwent bez Twoich artystów nie dzwoni.
    s.setNotify(spotifyOnly: true);
    final con = ev('con', 'Jakiś Konwent', kind: 'konwent');
    final kanaria = ev('kan', 'Kanaria');
    final n3 = await collectNews(s, prefs, [con, kanaria]);
    expect(n3.map((n) => n.event.id), ['kan']);
  });
}
