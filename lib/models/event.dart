/// Jeden przystanek trasy (albo jedyny termin koncertu).
class EventStop {
  final String cc;
  final String city;
  final DateTime date;
  final String venue;

  const EventStop({
    required this.cc,
    required this.city,
    required this.date,
    required this.venue,
  });

  factory EventStop.fromJson(Map<String, dynamic> j) => EventStop(
        cc: (j['cc'] ?? '').toString(),
        city: (j['city'] ?? '').toString(),
        date: _parseDate(j['date']) ?? DateTime(1970),
        venue: (j['venue'] ?? '').toString(),
      );

  Map<String, dynamic> toJson() => {
        'cc': cc,
        'city': city,
        'date': _fmt(date),
        'venue': venue,
      };
}

/// Skąd przyszedł event: wspólny feed, VocaDB, dodatkowy feed albo dodany ręcznie.
enum EventOrigin { feed, vocadb, custom, manual }

class RadarEvent {
  final String id;
  final String artist;
  final String title;

  /// trasa, koncert, konwent, rave, vocaloid, inne
  final String kind;

  /// 1..3, im wyżej, tym bardziej w Twoim guście.
  final int tier;
  final DateTime start;
  final DateTime end;
  final String note;
  final List<EventStop> stops;
  final String? url;
  final String? tickets;
  final DateTime? foundAt;
  final EventOrigin origin;

  const RadarEvent({
    required this.id,
    required this.artist,
    required this.title,
    required this.kind,
    required this.tier,
    required this.start,
    required this.end,
    required this.note,
    required this.stops,
    this.url,
    this.tickets,
    this.foundAt,
    this.origin = EventOrigin.feed,
  });

  factory RadarEvent.fromJson(Map<String, dynamic> j,
      {EventOrigin origin = EventOrigin.feed}) {
    final stops = ((j['stops'] as List?) ?? const [])
        .whereType<Map>()
        .map((s) => EventStop.fromJson(s.cast<String, dynamic>()))
        .toList()
      ..sort((a, b) => a.date.compareTo(b.date));
    final start = _parseDate(j['dateStart']) ??
        (stops.isNotEmpty ? stops.first.date : DateTime(1970));
    final end = _parseDate(j['dateEnd']) ??
        (stops.isNotEmpty ? stops.last.date : start);
    return RadarEvent(
      id: (j['id'] ?? '${j['artist']}-${j['dateStart']}').toString(),
      artist: (j['artist'] ?? '').toString(),
      title: (j['title'] ?? '').toString(),
      kind: (j['kind'] ?? 'inne').toString(),
      tier: (j['tier'] is num) ? (j['tier'] as num).toInt().clamp(1, 3) : 1,
      start: start,
      end: end.isBefore(start) ? start : end,
      note: (j['note'] ?? '').toString(),
      stops: stops,
      url: _nonEmpty(j['url']),
      tickets: _nonEmpty(j['tickets']),
      foundAt: _parseDate(j['foundAt']),
      origin: origin,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'artist': artist,
        'title': title,
        'kind': kind,
        'tier': tier,
        'dateStart': _fmt(start),
        'dateEnd': _fmt(end),
        'note': note,
        'stops': stops.map((s) => s.toJson()).toList(),
        if (url != null) 'url': url,
        if (tickets != null) 'tickets': tickets,
        if (foundAt != null) 'foundAt': _fmt(foundAt!),
      };

  String get displayTitle => title.trim().isEmpty ? artist : title;

  Set<String> get countries => stops.map((s) => s.cc).where((c) => c.isNotEmpty).toSet();

  bool get isOver {
    final today = todayDate();
    return end.isBefore(today);
  }

  /// Najbliższy przystanek, który jeszcze się nie odbył.
  EventStop? get nextStop {
    final today = todayDate();
    for (final s in stops) {
      if (!s.date.isBefore(today)) return s;
    }
    return null;
  }

  /// Data, do której liczymy odliczanie: najbliższy przystanek albo początek.
  DateTime get nextDate => nextStop?.date ?? start;

  /// Tekst, w którym szukamy nazw Twoich artystów.
  String get searchable => '$artist $title $note'.toLowerCase();
}

/// Dzisiejsza data bez godziny.
DateTime todayDate() {
  final n = DateTime.now();
  return DateTime(n.year, n.month, n.day);
}

DateTime? _parseDate(Object? v) {
  if (v == null) return null;
  final s = v.toString();
  if (s.isEmpty) return null;
  final d = DateTime.tryParse(s);
  if (d == null) return null;
  return DateTime(d.year, d.month, d.day);
}

String? _nonEmpty(Object? v) {
  final s = v?.toString().trim();
  return (s == null || s.isEmpty) ? null : s;
}

String _fmt(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
