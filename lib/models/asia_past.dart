import 'dart:convert';

import 'event.dart';

/// Miniony koncert z Japonii/Azji do szukania nagrań (Bilibili, YouTube):
/// oryginalna nazwa, tagi (Miku, Teto, VocaP…) i gotowe frazy do wyszukiwarki.
class AsiaPast {
  const AsiaPast({
    required this.id,
    required this.name,
    this.nameOrig = '',
    this.title = '',
    this.kind = 'koncert',
    this.region = 'JP',
    required this.start,
    required this.end,
    this.stops = const [],
    this.tags = const [],
    this.search = const [],
    this.url,
  });

  final String id;
  final String name;
  final String nameOrig;
  final String title;
  final String kind;
  final String region;
  final DateTime start;
  final DateTime end;
  final List<EventStop> stops;
  final List<String> tags;

  /// Frazy, pod którymi ludzie wrzucają nagrania (np. „魔法未来2024”).
  final List<String> search;
  final String? url;

  factory AsiaPast.fromJson(Map<String, dynamic> j) {
    List<String> strings(Object? v) => [
      for (final x in (v is List ? v : const []))
        if (x.toString().trim().isNotEmpty) x.toString().trim(),
    ];
    final stops = [
      for (final s in (j['stops'] as List?) ?? const [])
        if (s is Map) EventStop.fromJson(s.cast<String, dynamic>()),
    ]..sort((a, b) => a.date.compareTo(b.date));
    final start =
        DateTime.tryParse((j['dateStart'] ?? '').toString()) ?? (stops.isNotEmpty ? stops.first.date : DateTime(1970));
    final end = DateTime.tryParse((j['dateEnd'] ?? '').toString()) ?? (stops.isNotEmpty ? stops.last.date : start);
    final name = (j['artist'] ?? '').toString().trim();
    final orig = (j['nameOrig'] ?? '').toString().trim();
    return AsiaPast(
      id: (j['id'] ?? '').toString(),
      name: name,
      nameOrig: orig,
      title: (j['title'] ?? '').toString().trim(),
      kind: (j['kind'] ?? 'koncert').toString(),
      region: (j['region'] ?? 'JP').toString().toUpperCase(),
      start: start,
      end: end.isBefore(start) ? start : end,
      stops: stops,
      tags: strings(j['tags']),
      // Oryginalna nazwa zawsze jako pierwsza fraza, bez powtórek.
      search: {if (orig.isNotEmpty) orig, ...strings(j['search']), if (name.isNotEmpty) name}.toList(),
      url: (j['url'] ?? '').toString().trim().isEmpty ? null : j['url'].toString().trim(),
    );
  }

  String get searchable =>
      '$name $nameOrig $title ${tags.join(' ')} ${search.join(' ')} ${stops.map((s) => '${s.city} ${s.venue}').join(' ')} ${start.year}'
          .toLowerCase();

  static List<AsiaPast> parseList(String raw) {
    try {
      final j = jsonDecode(raw);
      final list = j is Map ? j['events'] : j;
      if (list is! List) return const [];
      return [
        for (final e in list)
          if (e is Map && e['id'] != null && e['artist'] != null) AsiaPast.fromJson(e.cast<String, dynamic>()),
      ]..sort((a, b) => b.start.compareTo(a.start));
    } catch (_) {
      return const [];
    }
  }
}

/// Wyszukiwanie frazy na Bilibili / YouTube.
String bilibiliSearch(String q) => 'https://search.bilibili.com/all?keyword=${Uri.encodeQueryComponent(q)}';
String youtubeSearch(String q) => 'https://www.youtube.com/results?search_query=${Uri.encodeQueryComponent(q)}';
