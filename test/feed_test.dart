import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:weeb_radar/data/app_state.dart';
import 'package:weeb_radar/data/feed_service.dart';
import 'package:weeb_radar/models/event.dart';

void main() {
  test('parsuje wbudowany feed weeb-radar', () {
    final raw = File('assets/events_fallback.json').readAsStringSync();
    final feed = FeedService.parseFeed(raw, EventOrigin.feed);
    expect(feed.events, isNotEmpty);
    expect(feed.updated, isNotNull);
    final miku = feed.events.firstWhere((e) => e.artist == 'Hatsune Miku');
    expect(miku.stops.length, greaterThan(3));
    expect(miku.countries, contains('UK'));
    // Przystanki są posortowane po dacie.
    for (var i = 1; i < miku.stops.length; i++) {
      expect(miku.stops[i].date.isBefore(miku.stops[i - 1].date), isFalse);
    }
  });

  test('zepsuty wpis nie psuje całego feedu', () {
    const raw = '{"events":[{"artist":"A","dateStart":"2030-01-02","stops":[]}, 5, {"stops":"zle"}]}';
    final feed = FeedService.parseFeed(raw, EventOrigin.custom);
    expect(feed.events.length, 1);
    expect(feed.events.first.artist, 'A');
  });

  test('parsuje odpowiedź VocaDB i filtruje Europę', () {
    const raw = '''{"items":[
      {"id":1,"name":"Vocafest London","date":"2030-03-21T00:00:00Z","category":"Concert",
       "venueName":"O2 Academy","venue":{"name":"O2","address":"Brixton, London, UK","addressCountryCode":"GB"}},
      {"id":2,"name":"Magical Mirai","date":"2030-08-30T00:00:00Z","venue":{"addressCountryCode":"JP"}}
    ],"totalCount":2}''';
    final eu = FeedService.parseVocaDb(raw, europeOnly: true);
    expect(eu.length, 1);
    expect(eu.first.stops.first.cc, 'UK');
    expect(eu.first.stops.first.city, 'London');
    expect(eu.first.url, 'https://vocadb.net/E/1');
    expect(FeedService.parseVocaDb(raw, europeOnly: false).length, 2);
  });

  test('dopasowanie do artystów podbija wynik', () async {
    SharedPreferences.setMockInitialValues({});
    final s = AppState(await SharedPreferences.getInstance());
    final mine = RadarEvent.fromJson({
      'id': 'a', 'artist': 'Hatsune Miku', 'title': 'MIKU EXPO', 'tier': 1,
      'dateStart': '2030-01-01', 'stops': [{'cc': 'PL', 'city': 'Warszawa', 'date': '2030-01-01', 'venue': 'X'}],
    });
    final other = RadarEvent.fromJson({
      'id': 'b', 'artist': 'Ktoś', 'title': 'Metal', 'tier': 1, 'dateStart': '2030-01-01', 'stops': [],
    });
    expect(s.matchedArtists(mine), contains('Hatsune Miku'));
    expect(s.isForYou(mine), isTrue);
    expect(s.isForYou(other), isFalse);
    expect(s.score(mine), greaterThan(s.score(other)));
  });

  test('festiwale Awexa i konwenty trafiają do „Dla mnie”', () async {
    SharedPreferences.setMockInitialValues({});
    final s = AppState(await SharedPreferences.getInstance());
    final ids = s.events.map((e) => e.id);
    expect(ids, containsAll(['fest-primavera-2027', 'fest-pohoda-2027']));
    final con = RadarEvent.fromJson({'id': 'c', 'artist': 'Pyrkon', 'kind': 'konwent', 'dateStart': '2030-06-01', 'stops': []});
    expect(s.isForYou(con), isTrue);
    s.setConventionsAlwaysForYou(false);
    expect(s.isForYou(con), isFalse);
    expect(s.artists, containsAll(['Gorillaz', 'YOASOBI', 'LCD Soundsystem']));
  });

  test('krótkie nazwy pasują tylko jako osobne słowa', () async {
    SharedPreferences.setMockInitialValues({});
    final s = AppState(await SharedPreferences.getInstance());
    expect(s.mentions('a true story', 'TRUE'), isTrue);
    expect(s.mentions('construed tiptoe', 'TRUE'), isFalse);
    expect(s.mentions('construed tiptoe', 'toe'), isFalse);
    expect(s.mentions('live: マサラダ w berlinie', 'マサラダ'), isTrue);
    expect(s.homeCountry, 'EU');
    expect(s.isHome('PL') && s.isHome('UK'), isTrue);
    expect(s.isHome('JP'), isFalse);
  });

  test('feed z prywatnego repo idzie przez API GitHuba z tokenem', () {
    const url = 'https://raw.githubusercontent.com/Alexsydfq/weeb-radar/main/events.json';
    final (plain, h0) = FeedService.githubRequest(url, null);
    expect(plain.toString(), url);
    expect(h0, isEmpty);
    final (api, h) = FeedService.githubRequest(url, 'tok');
    expect(api.toString(), 'https://api.github.com/repos/Alexsydfq/weeb-radar/contents/events.json?ref=main');
    expect(h['Authorization'], 'Bearer tok');
    expect(h['Accept'], 'application/vnd.github.raw');
    final (refs, _) = FeedService.githubRequest(
        'https://raw.githubusercontent.com/a/b/refs/heads/dev/data/x.json', 'tok');
    expect(refs.toString(), 'https://api.github.com/repos/a/b/contents/data/x.json?ref=dev');
    final (other, h2) = FeedService.githubRequest('https://example.com/feed.json', 'tok');
    expect(other.host, 'example.com');
    expect(h2, isEmpty, reason: 'token nie wycieka do obcych stron');
  });

  test('Spotify: miejsce w topce i słowa-pułapki', () async {
    SharedPreferences.setMockInitialValues({});
    final s = AppState(await SharedPreferences.getInstance());
    RadarEvent ev(String artist, String note) => RadarEvent.fromJson(
        {'id': artist, 'artist': artist, 'note': note, 'dateStart': '2030-01-01', 'stops': []});
    final miku = ev('Hatsune Miku', 'MIKU EXPO');
    expect(s.spotifyRank(miku), 1);
    expect(s.isSpotify(miku), isTrue);
    // „Queen” w opisie innego koncertu nie robi z niego Twojego artysty…
    final other = ev('Ktoś', 'Covery Queen i występ na New Year\'s Eve, tak jest');
    expect(s.isSpotify(other), isFalse);
    expect(s.spotifyRank(other), isNull);
    // …ale koncert samego Queen już tak.
    expect(s.isSpotify(ev('Queen', 'Trasa')), isTrue);
    expect(s.score(miku), greaterThan(s.score(ev('Ktoś inny', 'Vocaloid'))));
  });

  test('line-up i najważniejsze info z feedu', () async {
    SharedPreferences.setMockInitialValues({});
    final s = AppState(await SharedPreferences.getInstance());
    final e = RadarEvent.fromJson({
      'id': 'f', 'artist': 'Jakiś Festiwal 2027', 'kind': 'festiwal', 'dateStart': '2030-07-01', 'stops': [],
      'lineup': ['Gorillaz', 'Ktoś Obcy', 'Queen', '  '],
      'facts': [{'k': 'Bilety', 'v': 'od 99 €'}, {'k': '', 'v': 'pusto'}],
      'changeNote': 'Ogłosili line-up', 'updatedAt': '2030-01-02',
    });
    expect(e.lineup, ['Gorillaz', 'Ktoś Obcy', 'Queen']);
    expect(e.facts.single.label, 'Bilety');
    expect(e.changeNote, 'Ogłosili line-up');
    // Artysta z line-upu liczy się jak z tytułu, a „Queen” jako dokładna pozycja line-upu też.
    expect(s.matchedArtists(e), containsAll(['Gorillaz', 'Queen']));
    expect(s.artistsIn('Ktoś Obcy'), isEmpty);
    expect(s.rankOfEntry('Hatsune Miku'), 1);
    expect(RadarEvent.fromJson(e.toJson()).lineup, e.lineup);
  });

  test('setlista przechodzi przez feed i cache', () {
    final e = RadarEvent.fromJson({
      'id': 'x', 'artist': 'Hatsune Miku', 'kind': 'trasa', 'dateStart': '2030-01-01', 'stops': [],
      'setlist': ['Melt', ' ', 'Vampire'], 'setlistFrom': 'MIKU EXPO 2025',
    });
    expect(e.setlist, ['Melt', 'Vampire']);
    final back = RadarEvent.fromJson(e.toJson());
    expect(back.setlist, e.setlist);
    expect(back.setlistFrom, 'MIKU EXPO 2025');
    expect(back.withChosen(null).setlist, e.setlist);
  });
}
