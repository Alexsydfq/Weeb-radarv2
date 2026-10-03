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
}
