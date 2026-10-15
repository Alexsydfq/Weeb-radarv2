import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:weeb_radar/data/app_state.dart';
import 'package:weeb_radar/data/defaults.dart';
import 'package:weeb_radar/edition.dart';
import 'package:weeb_radar/models/event.dart';

RadarEvent event(String artist) => RadarEvent.fromJson({
  'id': 'e-$artist',
  'artist': artist,
  'title': 'Trasa',
  'kind': 'trasa',
  'tier': 2,
  'dateStart': '2027-01-10',
  'stops': [
    {'city': 'Berlin', 'cc': 'DE'},
  ],
}, origin: EventOrigin.feed);

void main() {
  tearDown(() => friendsEdition = false);

  test(
    'wydanie dla znajomych: pusta lista artystów, bez sync, bez rankingu Spotify, powiadomienia wyłączone',
    () async {
      friendsEdition = true;
      SharedPreferences.setMockInitialValues({'sync.token': 'ghp_cudzy'});
      final s = AppState(await SharedPreferences.getInstance())..loadSettings();
      expect(appName, 'Radar koncertów');
      expect(s.artists, unorderedEquals(defaultArtists), reason: 'ta sama lista artystów');
    expect(s.artists, isNot(orderedEquals(defaultArtists)), reason: 'ale bez kolejności z rankingu Spotify');
      expect(s.notifyEnabled, isFalse);
      expect(s.syncEnabled, isFalse, reason: 'token z ustawień nie włącza synchronizacji');

        final e = event('DECO*27');
      expect(s.isSpotify(e), isTrue, reason: 'artystów z listy dalej widać');
      expect(s.spotifyRank(e), isNull, reason: 'ale bez miejsc ze Spotify Awexa');
    },
  );

  test('pełne wydanie bez zmian', () async {
    SharedPreferences.setMockInitialValues({'sync.token': 'ghp_x'});
    final s = AppState(await SharedPreferences.getInstance())..loadSettings();
    expect(appName, 'Weeb Radar');
    expect(s.artists, isNotEmpty);
    expect(s.notifyEnabled, isTrue);
    expect(s.syncEnabled, isTrue);
  });
}
