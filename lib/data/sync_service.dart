import 'dart:convert';

import 'package:http/http.dart' as http;

/// Czy idziesz na event.
enum Plan { going, maybe, interested, notGoing }

/// Twoje decyzje dla jednego eventu. `at` to czas ostatniej zmiany
/// (ms od epoki): przy łączeniu telefonu z komputerem wygrywa nowsza zmiana.
class PlanEntry {
  const PlanEntry({this.plan, this.fav = false, this.hidden = false, required this.at});

  final Plan? plan;
  final bool fav;
  final bool hidden;
  final int at;

  bool get isEmpty => plan == null && !fav && !hidden;

  PlanEntry copyWith({Plan? Function()? plan, bool? fav, bool? hidden, required int at}) => PlanEntry(
        plan: plan == null ? this.plan : plan(),
        fav: fav ?? this.fav,
        hidden: hidden ?? this.hidden,
        at: at,
      );

  factory PlanEntry.fromJson(Map<String, dynamic> j) => PlanEntry(
        plan: Plan.values.where((p) => p.name == j['plan']).firstOrNull,
        fav: j['fav'] == true,
        hidden: j['hidden'] == true,
        at: (j['at'] as num?)?.toInt() ?? 0,
      );

  Map<String, dynamic> toJson() => {
        if (plan != null) 'plan': plan!.name,
        if (fav) 'fav': true,
        if (hidden) 'hidden': true,
        'at': at,
      };

  @override
  bool operator ==(Object other) =>
      other is PlanEntry && other.plan == plan && other.fav == fav && other.hidden == hidden && other.at == at;

  @override
  int get hashCode => Object.hash(plan, fav, hidden, at);
}

/// Łączy dwa zestawy decyzji: dla każdego eventu wygrywa nowsza zmiana.
/// Puste wpisy zostają (z czasem), żeby „odznaczenie” też się synchronizowało.
Map<String, PlanEntry> mergeEntries(Map<String, PlanEntry> a, Map<String, PlanEntry> b) {
  final out = {...a};
  b.forEach((id, e) {
    final mine = out[id];
    if (mine == null || e.at > mine.at) out[id] = e;
  });
  return out;
}

Map<String, PlanEntry> decodeEntries(String? raw) {
  if (raw == null || raw.isEmpty) return {};
  try {
    final j = jsonDecode(raw);
    final m = (j is Map && j['entries'] is Map) ? j['entries'] as Map : j as Map;
    return {
      for (final e in m.entries)
        if (e.value is Map) e.key as String: PlanEntry.fromJson((e.value as Map).cast<String, dynamic>()),
    };
  } catch (_) {
    return {};
  }
}

String encodeEntries(Map<String, PlanEntry> entries) => jsonEncode({
      'app': 'weeb-radar',
      'version': 1,
      'updated': DateTime.now().toUtc().toIso8601String(),
      'entries': {for (final e in entries.entries) e.key: e.value.toJson()},
    });

class SyncException implements Exception {
  SyncException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Synchronizacja przez prywatny GitHub Gist: bez serwera, wystarczy token
/// z uprawnieniem do gistów, wklejony na telefonie i na komputerze.
class SyncService {
  SyncService({http.Client? client}) : _client = client ?? http.Client();

  static const fileName = 'weeb-radar-sync.json';
  static const _api = 'https://api.github.com';

  final http.Client _client;

  Map<String, String> _headers(String token) => {
        'Authorization': 'Bearer $token',
        'Accept': 'application/vnd.github+json',
        'X-GitHub-Api-Version': '2022-11-28',
        'User-Agent': 'weeb-radar',
      };

  Never _fail(http.Response r) {
    if (r.statusCode == 401) throw SyncException('Token nie działa (401). Sprawdź, czy go dobrze wkleiłeś.');
    if (r.statusCode == 403 || r.statusCode == 404) {
      throw SyncException('Token nie ma dostępu do gistów (${r.statusCode}). Potrzebne „Gists: read and write”.');
    }
    throw SyncException('GitHub odpowiedział ${r.statusCode}.');
  }

  /// Szuka gista z plikiem synchronizacji na koncie tokena.
  Future<String?> findGist(String token) async {
    for (var page = 1; page <= 5; page++) {
      final r = await _client.get(Uri.parse('$_api/gists?per_page=100&page=$page'), headers: _headers(token));
      if (r.statusCode != 200) _fail(r);
      final list = jsonDecode(r.body) as List;
      for (final g in list) {
        final files = (g as Map)['files'] as Map?;
        if (files != null && files.containsKey(fileName)) return g['id'] as String;
      }
      if (list.length < 100) break;
    }
    return null;
  }

  Future<String> createGist(String token, Map<String, PlanEntry> entries) async {
    final r = await _client.post(
      Uri.parse('$_api/gists'),
      headers: _headers(token),
      body: jsonEncode({
        'description': 'Weeb Radar: synchronizacja planów (Idę / Może / Zainteresowany / Nie idę)',
        'public': false,
        'files': {fileName: {'content': encodeEntries(entries)}},
      }),
    );
    if (r.statusCode != 201) _fail(r);
    return (jsonDecode(r.body) as Map)['id'] as String;
  }

  Future<Map<String, PlanEntry>?> read(String token, String gistId) async {
    final r = await _client.get(Uri.parse('$_api/gists/$gistId'), headers: _headers(token));
    if (r.statusCode == 404) return null;
    if (r.statusCode != 200) _fail(r);
    final file = ((jsonDecode(r.body) as Map)['files'] as Map?)?[fileName] as Map?;
    if (file == null) return null;
    var content = file['content'] as String?;
    if (file['truncated'] == true && file['raw_url'] != null) {
      final raw = await _client.get(Uri.parse(file['raw_url'] as String), headers: _headers(token));
      if (raw.statusCode == 200) content = raw.body;
    }
    return decodeEntries(content);
  }

  Future<void> write(String token, String gistId, Map<String, PlanEntry> entries) async {
    final r = await _client.patch(
      Uri.parse('$_api/gists/$gistId'),
      headers: _headers(token),
      body: jsonEncode({
        'files': {fileName: {'content': encodeEntries(entries)}},
      }),
    );
    if (r.statusCode != 200) _fail(r);
  }

  /// Pełna runda: pobierz, połącz, odeślij. Zwraca połączony stan i id gista.
  Future<({Map<String, PlanEntry> entries, String gistId})> sync(
    String token,
    String? gistId,
    Map<String, PlanEntry> local,
  ) async {
    String? id = gistId;
    Map<String, PlanEntry>? remote = id == null ? null : await read(token, id);
    if (remote == null) {
      // Pierwsze połączenie albo gist zniknął: szukamy go na koncie, a jak nie ma, zakładamy nowy.
      id = await findGist(token);
      remote = id == null ? null : await read(token, id);
    }
    if (id == null || remote == null) {
      return (entries: local, gistId: await createGist(token, local));
    }
    final theirs = remote;
    final merged = mergeEntries(local, theirs);
    final changed = merged.length != theirs.length ||
        merged.entries.any((e) => theirs[e.key] != e.value);
    if (changed) await write(token, id, merged);
    return (entries: merged, gistId: id);
  }
}
