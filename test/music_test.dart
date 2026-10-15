import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:weeb_radar/data/app_state.dart';
import 'package:weeb_radar/data/news.dart';
import 'package:weeb_radar/models/song.dart';

Song song(String id, String artist, {bool pick = false, String released = '2026-10-01'}) =>
    Song.fromJson({'id': id, 'title': 'Kawałek $id', 'artist': artist, 'released': released, 'pick': pick});

void main() {
  test('music.json: obiekt albo lista, najnowsze pierwsze', () {
    final a = Song.parseFeed(
      '{"updated":"2026-10-03","songs":['
      '{"id":"a","title":"A","artist":"X","released":"2026-09-01"},'
      '{"id":"b","title":"B","artist":"Y","released":"2026-10-01"}]}',
    );
    expect(a.map((x) => x.id), ['b', 'a']);
    expect(Song.parseFeed('[{"id":"c","title":"C","artist":"Z"}]').single.key, 'song:c');
    expect(Song.parseFeed('nie json'), isEmpty);
    expect(
      Song.feedUrlFor('https://raw.githubusercontent.com/a/b/main/events.json'),
      'https://raw.githubusercontent.com/a/b/main/music.json',
    );
  });

  test('nowa muzyka: moi artyści i propozycje, nic dwa razy, da się wyłączyć', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final s = AppState(prefs)..loadSettings();
    expect(s.notifyMusic, isTrue);

    final deco = song('deco', 'DECO*27');
    final obcy = song('obcy', 'Ktoś Obcy');
    final pick = song('pick', 'La+ Darknesss & IOSYS', pick: true);
    final first = await collectSongNews(s, [deco, obcy, pick]);
    expect(first.map((x) => x.id), ['deco', 'pick'], reason: 'mój artysta z rankingiem przed propozycją');
    expect(await collectSongNews(s, [deco, obcy, pick]), isEmpty);

    s.setNotify(music: false);
    expect(await collectSongNews(s, [deco, song('deco2', 'DECO*27')]), isEmpty);
    expect(prefs.getStringList('notify.seen'), contains('song:deco2'), reason: 'wyłączone: nie dzwoni później hurtem');
  });
}
