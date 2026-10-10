/// Kraje zakładki „Japonia i Korea” (pole region albo wszystkie przystanki).
const asiaCodes = <String>{'JP', 'KR'};

/// Jeden przystanek trasy (albo jedyny termin koncertu).
class EventStop {
  final String cc;
  final String city;
  final DateTime date;
  final String venue;

  const EventStop({required this.cc, required this.city, required this.date, required this.venue});

  factory EventStop.fromJson(Map<String, dynamic> j) => EventStop(
    cc: (j['cc'] ?? '').toString(),
    city: (j['city'] ?? '').toString(),
    date: _parseDate(j['date']) ?? DateTime(1970),
    venue: (j['venue'] ?? '').toString(),
  );

  /// Klucz przystanku do zapamiętania wyboru („jadę tutaj”).
  String get key => '${_fmt(date)}|$city';

  Map<String, dynamic> toJson() => {'cc': cc, 'city': city, 'date': _fmt(date), 'venue': venue};
}

/// Jedna ważna informacja o evencie, np. „Bilety” → „od 59 €, sprzedaż od 1.11”.
class EventFact {
  final String label;
  final String value;
  const EventFact(this.label, this.value);

  Map<String, dynamic> toJson() => {'k': label, 'v': value};
}

/// Skąd przyszedł event: wspólny feed, VocaDB, dodatkowy feed, dodany ręcznie
/// albo wbudowany w aplikację (festiwale Awexa).
enum EventOrigin { feed, vocadb, custom, manual, curated }

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

  /// Line-up festiwalu, goście muzyczni konwentu, supporty koncertu.
  final List<String> lineup;

  /// Najważniejsze informacje: ceny, start sprzedaży, godziny, wiek, program.
  final List<EventFact> facts;

  /// Ostatnia istotna zmiana wykryta przez skan.
  final DateTime? updatedAt;
  final String? changeNote;

  /// Kto to i skąd możesz go znać (anime, gra, vocaloid…).
  final String? about;

  /// Najpopularniejsze kawałki artysty (albo gwiazd festiwalu).
  final List<String> hits;

  /// Kawałki grane na ostatnich koncertach (setlista z tej albo poprzedniej trasy).
  final List<String> setlist;

  /// Skąd jest setlista, np. „MIKU EXPO 2025 North America, Nowy Jork”.
  final String? setlistFrom;

  /// Przystanek trasy, który sam wybrałeś („jadę tutaj”).
  final EventStop? chosen;

  /// Region z feedu: "JP" (Japonia) albo "KR" (Korea Płd.) trafia do osobnej zakładki, inaczej Europa.
  final String? region;

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
    this.lineup = const [],
    this.facts = const [],
    this.updatedAt,
    this.changeNote,
    this.about,
    this.hits = const [],
    this.setlist = const [],
    this.setlistFrom,
    this.chosen,
    this.region,
  });

  /// Wydarzenie w Japonii albo Korei: do śledzenia, nie do Radaru Europy.
  bool get isJapan =>
      asiaCodes.contains(region?.toUpperCase()) ||
      (stops.isNotEmpty && stops.every((s) => asiaCodes.contains(s.cc.toUpperCase())));

  /// Ten sam event z wybranym przystankiem (albo bez wyboru).
  RadarEvent withChosen(EventStop? stop) => RadarEvent(
    id: id,
    artist: artist,
    title: title,
    kind: kind,
    tier: tier,
    start: start,
    end: end,
    note: note,
    stops: stops,
    url: url,
    tickets: tickets,
    foundAt: foundAt,
    origin: origin,
    lineup: lineup,
    facts: facts,
    updatedAt: updatedAt,
    changeNote: changeNote,
    about: about,
    hits: hits,
    setlist: setlist,
    setlistFrom: setlistFrom,
    chosen: stop,
    region: region,
  );

  factory RadarEvent.fromJson(Map<String, dynamic> j, {EventOrigin origin = EventOrigin.feed}) {
    final stops =
        ((j['stops'] as List?) ?? const [])
            .whereType<Map>()
            .map((s) => EventStop.fromJson(s.cast<String, dynamic>()))
            .toList()
          ..sort((a, b) => a.date.compareTo(b.date));
    final start = _parseDate(j['dateStart']) ?? (stops.isNotEmpty ? stops.first.date : DateTime(1970));
    final end = _parseDate(j['dateEnd']) ?? (stops.isNotEmpty ? stops.last.date : start);
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
      lineup: ((j['lineup'] as List?) ?? const []).map((x) => x.toString().trim()).where((x) => x.isNotEmpty).toList(),
      facts: [
        for (final f in (j['facts'] as List?) ?? const [])
          if (f is Map && _nonEmpty(f['k']) != null && _nonEmpty(f['v']) != null)
            EventFact(_nonEmpty(f['k'])!, _nonEmpty(f['v'])!),
      ],
      updatedAt: _parseDate(j['updatedAt']),
      changeNote: _nonEmpty(j['changeNote']),
      about: _nonEmpty(j['about']),
      hits: _strings(j['hits']),
      setlist: _strings(j['setlist']),
      setlistFrom: _nonEmpty(j['setlistFrom']),
      region: _nonEmpty(j['region']),
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
    if (lineup.isNotEmpty) 'lineup': lineup,
    if (facts.isNotEmpty) 'facts': facts.map((f) => f.toJson()).toList(),
    if (updatedAt != null) 'updatedAt': _fmt(updatedAt!),
    if (changeNote != null) 'changeNote': changeNote,
    if (about != null) 'about': about,
    if (hits.isNotEmpty) 'hits': hits,
    if (setlist.isNotEmpty) 'setlist': setlist,
    if (setlistFrom != null) 'setlistFrom': setlistFrom,
    if (region != null) 'region': region,
  };

  static List<String> _strings(Object? v) =>
      ((v is List) ? v : const []).map((x) => x.toString().trim()).where((x) => x.isNotEmpty).toList();

  String get displayTitle => title.trim().isEmpty ? artist : title;

  Set<String> get countries => stops.map((s) => s.cc).where((c) => c.isNotEmpty).toSet();

  bool get isOver {
    final today = todayDate();
    return end.isBefore(today);
  }

  /// Twój przystanek (jeśli wybrałeś i jeszcze się nie odbył),
  /// inaczej najbliższy, który jeszcze się nie odbył.
  EventStop? get nextStop {
    final today = todayDate();
    if (chosen != null && !chosen!.date.isBefore(today)) return chosen;
    for (final s in stops) {
      if (!s.date.isBefore(today)) return s;
    }
    return null;
  }

  /// Data, do której liczymy odliczanie: najbliższy przystanek albo początek.
  DateTime get nextDate => nextStop?.date ?? start;

  /// Tekst, w którym szukamy nazw Twoich artystów.
  String get searchable => '$artist $title $note ${lineup.join(' · ')} ${about ?? ''}'.toLowerCase();
}

/// Klucz zmiany w zbiorach „już powiadomione” i „przeczytane”.
String changeKey(RadarEvent e) => '${e.id}~${e.changeNote}';

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
