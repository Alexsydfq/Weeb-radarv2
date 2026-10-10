import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:weeb_radar/data/app_state.dart';
import 'package:weeb_radar/data/feed_service.dart';

void main() {
  test('artyści dopisani do listy skanu trafiają do apki, usunięci nie wracają', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final s = AppState(prefs)..loadSettings();
    final base = [for (var i = 0; i < 30; i++) 'Artysta $i'];

    s.mergeWatchArtists(base);
    expect(s.artists, isNot(contains('Artysta 0')), reason: 'pierwszy raz tylko zapamiętujemy stan listy');

    s.mergeWatchArtists([...base, 'tofubeats', 'Hatsune Miku']);
    expect(s.artists, contains('tofubeats'));
    expect(s.artists.where((a) => a.toLowerCase() == 'hatsune miku'), hasLength(1), reason: 'bez duplikatów');

    s.artists = s.artists.where((a) => a != 'tofubeats').toList();
    s.mergeWatchArtists([...base, 'tofubeats', 'Hatsune Miku']);
    expect(s.artists, isNot(contains('tofubeats')), reason: 'usuniętego przez użytkownika nie wskrzeszamy');

    s.mergeWatchArtists(['tylko', 'kilka']);
    expect(prefs.getStringList('taste.knownWatch'), contains('tofubeats'), reason: 'ucięty plik nie psuje stanu');
  });

  test('watch.json: bierze listę artists, śmieci daje pustą listę', () {
    expect(FeedService.parseWatchArtists('{"artists": ["Ado", " ", 3, "Eve"], "cons": ["Pyrkon"]}'), ['Ado', 'Eve']);
    expect(FeedService.parseWatchArtists('nie json'), isEmpty);
  });
}
