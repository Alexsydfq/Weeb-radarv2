import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/event.dart';
import '../models/song.dart';
import 'defaults.dart';

class ParsedFeed {
  final List<RadarEvent> events;
  final DateTime? updated;
  const ParsedFeed(this.events, this.updated);
}

class FetchResult {
  final List<RadarEvent> events;
  final DateTime? feedUpdated;

  /// Nazwa źródła -> „ok (N)” albo „błąd: ...”.
  final Map<String, String> status;
  const FetchResult(this.events, this.feedUpdated, this.status);
}

/// Pobiera eventy ze wszystkich źródeł i skleja je w jedną listę.
class FeedService {
  FeedService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;
  static const _timeout = Duration(seconds: 20);

  Future<FetchResult> fetchAll({
    required String feedUrl,
    required List<String> extraFeeds,
    required bool useVocaDb,
    required bool vocaDbEuropeOnly,
    String? githubToken,
  }) async {
    final status = <String, String>{};
    final all = <String, RadarEvent>{};
    DateTime? updated;

    Future<void> grabFeed(String name, String url, EventOrigin origin) async {
      try {
        final (uri, headers) = githubRequest(url, githubToken);
        final res = await _client.get(uri, headers: headers).timeout(_timeout);
        if (res.statusCode == 404 && uri.host == 'raw.githubusercontent.com') {
          throw 'HTTP 404 (repo prywatne? wklej token GitHub w Wygląd → Synchronizacja)';
        }
        if (res.statusCode != 200) throw 'HTTP ${res.statusCode}';
        final parsed = parseFeed(utf8.decode(res.bodyBytes), origin);
        for (final e in parsed.events) {
          all[e.id] = e;
        }
        if (origin == EventOrigin.feed) updated = parsed.updated;
        status[name] = 'ok (${parsed.events.length})';
      } catch (e) {
        status[name] = 'błąd: $e';
      }
    }

    await Future.wait([
      grabFeed('Weeb Radar feed', feedUrl, EventOrigin.feed),
      for (final (i, url) in extraFeeds.indexed)
        grabFeed('Dodatkowy feed ${i + 1}', url, EventOrigin.custom),
      if (useVocaDb)
        _fetchVocaDb(europeOnly: vocaDbEuropeOnly).then((list) {
          for (final e in list) {
            all.putIfAbsent(e.id, () => e);
          }
          status['VocaDB'] = 'ok (${list.length})';
        }).catchError((Object e) {
          status['VocaDB'] = 'błąd: $e';
        }),
    ]);

    return FetchResult(all.values.toList(), updated, status);
  }

  /// Nowa muzyka z music.json (obok events.json). Brak pliku = pusta lista.
  Future<List<Song>> fetchMusic({required String feedUrl, String? githubToken}) async {
    final (uri, headers) = githubRequest(Song.feedUrlFor(feedUrl), githubToken);
    final res = await _client.get(uri, headers: headers).timeout(_timeout);
    if (res.statusCode == 404) return const [];
    if (res.statusCode != 200) throw 'HTTP ${res.statusCode}';
    return Song.parseFeed(utf8.decode(res.bodyBytes));
  }

  /// Feed z GitHuba przy podanym tokenie czytamy przez API, żeby działał też
  /// z prywatnego repo. Bez tokena zwykły raw.githubusercontent.com.
  static (Uri, Map<String, String>) githubRequest(String url, String? token) {
    final uri = Uri.parse(url);
    final seg = uri.pathSegments;
    if (token == null || token.isEmpty || uri.host != 'raw.githubusercontent.com' || seg.length < 4) {
      return (uri, const {});
    }
    // raw.githubusercontent.com/<owner>/<repo>/<gałąź>/<ścieżka>; gałąź może być też refs/heads/<gałąź>.
    var rest = seg.sublist(2);
    var ref = rest.first;
    if (rest.length > 3 && rest[0] == 'refs' && rest[1] == 'heads') {
      ref = rest[2];
      rest = rest.sublist(2);
    }
    final path = rest.sublist(1).map(Uri.encodeComponent).join('/');
    return (
      Uri.parse('https://api.github.com/repos/${seg[0]}/${seg[1]}/contents/$path?ref=${Uri.encodeQueryComponent(ref)}'),
      {
        'Authorization': 'Bearer $token',
        'Accept': 'application/vnd.github.raw',
        'X-GitHub-Api-Version': '2022-11-28',
        'User-Agent': 'weeb-radar',
      },
    );
  }

  /// Format feedu weeb-radar: {"updated": ..., "events": [...]} albo sama lista.
  static ParsedFeed parseFeed(String raw, EventOrigin origin) {
    final decoded = jsonDecode(raw);
    final List list;
    DateTime? updated;
    if (decoded is Map) {
      list = (decoded['events'] as List?) ?? const [];
      updated = DateTime.tryParse((decoded['updated'] ?? '').toString());
    } else if (decoded is List) {
      list = decoded;
    } else {
      list = const [];
    }
    final events = <RadarEvent>[];
    for (final item in list) {
      if (item is! Map) continue;
      try {
        events.add(RadarEvent.fromJson(item.cast<String, dynamic>(), origin: origin));
      } catch (_) {
        // Jeden zepsuty wpis nie psuje całego feedu.
      }
    }
    return ParsedFeed(events, updated);
  }

  Future<List<RadarEvent>> _fetchVocaDb({required bool europeOnly}) async {
    final today = todayDate();
    final uri = Uri.parse(vocaDbEventsUrl).replace(queryParameters: {
      'afterDate': today.toIso8601String().substring(0, 10),
      'beforeDate': today.add(const Duration(days: 400)).toIso8601String().substring(0, 10),
      'maxResults': '100',
      'sort': 'Date',
      'fields': 'Venue,WebLinks,Series',
      'lang': 'English',
    });
    final res = await _client
        .get(uri, headers: {'Accept': 'application/json'}).timeout(_timeout);
    if (res.statusCode != 200) throw 'HTTP ${res.statusCode}';
    return parseVocaDb(utf8.decode(res.bodyBytes), europeOnly: europeOnly);
  }

  /// VocaDB /api/releaseEvents -> nasze eventy. Pola opcjonalne czytamy ostrożnie.
  static List<RadarEvent> parseVocaDb(String raw, {required bool europeOnly}) {
    final decoded = jsonDecode(raw);
    final items = decoded is Map ? (decoded['items'] as List? ?? const []) : const [];
    final out = <RadarEvent>[];
    for (final it in items) {
      if (it is! Map) continue;
      final date = DateTime.tryParse((it['date'] ?? '').toString());
      if (date == null) continue;
      final end = DateTime.tryParse((it['endDate'] ?? '').toString()) ?? date;
      final venue = it['venue'] is Map ? it['venue'] as Map : const {};
      var cc = (venue['addressCountryCode'] ?? '').toString().toUpperCase();
      if (cc == 'GB') cc = 'UK';
      if (europeOnly && !europeCodes.contains(cc)) continue;
      final venueName = (it['venueName'] ?? venue['name'] ?? '').toString();
      final address = (venue['address'] ?? '').toString();
      final series = it['series'] is Map ? (it['series'] as Map)['name']?.toString() : null;
      final id = it['id'];
      final name = (it['name'] ?? '').toString();
      final day = DateTime(date.year, date.month, date.day);
      out.add(RadarEvent(
        id: 'vocadb-$id',
        artist: series ?? name,
        title: name,
        kind: 'vocaloid',
        tier: 2,
        start: day,
        end: DateTime(end.year, end.month, end.day),
        note: [
          if ((it['category'] ?? '').toString().isNotEmpty) 'Kategoria: ${it['category']}',
          if (address.isNotEmpty) address,
          'Z bazy VocaDB.',
        ].join(' · '),
        stops: [
          EventStop(cc: cc, city: _cityFrom(address), date: day, venue: venueName),
        ],
        url: 'https://vocadb.net/E/$id',
        origin: EventOrigin.vocadb,
      ));
    }
    return out;
  }

  static String _cityFrom(String address) {
    if (address.isEmpty) return '';
    final parts = address.split(',').map((p) => p.trim()).where((p) => p.isNotEmpty).toList();
    return parts.length >= 2 ? parts[parts.length - 2] : parts.first;
  }
}
