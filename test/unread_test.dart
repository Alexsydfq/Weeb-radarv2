import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:weeb_radar/data/app_state.dart';
import 'package:weeb_radar/data/sync_service.dart';
import 'package:weeb_radar/models/event.dart';
import 'package:weeb_radar/models/song.dart';

String day(int ago) => todayDate().subtract(Duration(days: ago)).toIso8601String().substring(0, 10);

RadarEvent ev(String id, {required int foundAgo, String? change, int? changedAgo}) => RadarEvent.fromJson({
      'id': id,
      'artist': id,
      'kind': 'koncert',
      'dateStart': '2030-05-01',
      'stops': [],
      'foundAt': day(foundAgo),
      'changeNote': ?change,
      if (changedAgo != null) 'updatedAt': day(changedAgo),
    });

Song song(String id, int foundAgo) => Song(id: id, title: id, artist: 'X', foundAt: DateTime.parse(day(foundAgo)));

void main() {
  test('nowe jak nieprzeczytane maile: stare po aktualizacji nie krzyczą, otwarcie czyta', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final s = AppState(prefs)..loadSettings();
    expect(prefs.getString('read.since'), day(0), reason: 'punkt startowy to dzień pierwszego uruchomienia');

    final old = ev('old', foundAgo: 10);
    final fresh = ev('fresh', foundAgo: 1);
    expect(s.isUnread(old), isFalse, reason: 'znalezione dawno przed aktualizacją = stare');
    expect(s.isUnreadNew(fresh), isTrue);

    s.markRead(fresh);
    expect(s.isUnread(fresh), isFalse);
    expect(prefs.getStringList('read.ids'), contains('fresh'));

    // Świeża zmiana w przeczytanym evencie znowu go wyróżnia, ale jako ZMIANA.
    final changed = ev('fresh', foundAgo: 1, change: 'Doszła Praga', changedAgo: 0);
    expect(s.isUnreadChange(changed), isTrue);
    expect(s.isUnreadNew(changed), isFalse);
    s.markRead(changed);
    expect(s.isUnread(changed), isFalse);

    // Stara zmiana w starym evencie nie wraca.
    expect(s.isUnread(ev('old', foundAgo: 10, change: 'coś', changedAgo: 9)), isFalse);

    // Licznik pomija „Nie idę”, „oznacz wszystko” czyści.
    final a = ev('a', foundAgo: 0), b = ev('b', foundAgo: 0);
    expect(s.unreadCount([a, b, old]), 2);
    s.setPlan('b', Plan.notGoing);
    expect(s.unreadCount([a, b, old]), 1);
    s.markAllRead([a, b]);
    expect(s.unreadCount([a, b]), 0);
  });

  test('kawałki: nowe do przesłuchania, przejrzane znikają z licznika', () async {
    SharedPreferences.setMockInitialValues({'read.since': day(0)});
    final s = AppState(await SharedPreferences.getInstance())..loadSettings();
    s.songs = [song('nowy', 0), song('stary', 12)];
    expect(s.unreadSongs, 1);
    s.markSongRead(s.songs.first);
    expect(s.unreadSongs, 0);
  });

  test('przejrzane jadą w pliku synchronizacji', () {
    final raw = encodeEntries({}, read: {'miku', 'song:x'});
    expect(decodeRead(raw), {'miku', 'song:x'});
    expect(decodeRead(encodeEntries({})), isEmpty);
  });
}
