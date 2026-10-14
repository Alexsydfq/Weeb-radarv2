import 'event.dart';

/// Koncert, na którym byłeś: kopia najważniejszych danych, bo eventy z feedu
/// znikają po ~60 dniach, a historia ma zostać na zawsze.
class Attended {
  const Attended({
    required this.id,
    required this.artist,
    this.title = '',
    required this.date,
    this.city = '',
    this.cc = '',
    this.venue = '',
    this.kind = 'koncert',
    this.note = '',
    this.rating = 0,
    this.eventId,
    this.lineup = const [],
    this.seen = const [],
    required this.at,
    this.deleted = false,
  });

  final String id;
  final String artist;
  final String title;
  final DateTime date;
  final String city;
  final String cc;
  final String venue;
  final String kind;
  final String note;

  /// 0 = bez oceny, inaczej 1–5 gwiazdek.
  final int rating;

  /// Event z feedu, z którego powstał wpis (null dla dopisanych ręcznie).
  final String? eventId;

  /// Line-up festiwalu/konwentu skopiowany z eventu (do odhaczania, kogo widziałeś).
  final List<String> lineup;

  /// Kogo na nim widziałeś: z line-upu albo dopisani ręcznie.
  final List<String> seen;

  /// Czas ostatniej zmiany (ms od epoki): przy synchronizacji wygrywa nowsza.
  final int at;

  /// Usunięte wpisy zostają jako „nagrobek”, żeby usunięcie też się zsynchronizowało.
  final bool deleted;

  /// Wpis z eventu z feedu; przy trasie bierze wybrany albo ostatni miniony przystanek.
  factory Attended.fromEvent(RadarEvent e, {required int at, DateTime? today}) {
    final now = today ?? DateTime.now();
    final past = e.stops.where((s) => !s.date.isAfter(now)).toList();
    final stop = e.chosen ?? (past.isNotEmpty ? past.last : e.stops.firstOrNull);
    return Attended(
      id: 'ev-${e.id}',
      artist: e.artist,
      title: e.title,
      date: stop?.date ?? e.start,
      city: stop?.city ?? '',
      cc: stop?.cc ?? '',
      venue: stop?.venue ?? '',
      kind: e.kind,
      eventId: e.id,
      lineup: e.lineup,
      at: at,
    );
  }

  Attended copyWith({
    String? artist,
    String? title,
    DateTime? date,
    String? city,
    String? cc,
    String? venue,
    String? kind,
    String? note,
    int? rating,
    List<String>? lineup,
    List<String>? seen,
    bool? deleted,
    required int at,
  }) => Attended(
    id: id,
    artist: artist ?? this.artist,
    title: title ?? this.title,
    date: date ?? this.date,
    city: city ?? this.city,
    cc: cc ?? this.cc,
    venue: venue ?? this.venue,
    kind: kind ?? this.kind,
    note: note ?? this.note,
    rating: rating ?? this.rating,
    eventId: eventId,
    lineup: lineup ?? this.lineup,
    seen: seen ?? this.seen,
    at: at,
    deleted: deleted ?? this.deleted,
  );

  factory Attended.fromJson(Map<String, dynamic> j) => Attended(
    id: (j['id'] ?? '').toString(),
    artist: (j['artist'] ?? '').toString(),
    title: (j['title'] ?? '').toString(),
    date: DateTime.tryParse((j['date'] ?? '').toString()) ?? DateTime(2000),
    city: (j['city'] ?? '').toString(),
    cc: (j['cc'] ?? '').toString(),
    venue: (j['venue'] ?? '').toString(),
    kind: (j['kind'] ?? 'koncert').toString(),
    note: (j['note'] ?? '').toString(),
    rating: ((j['rating'] as num?)?.toInt() ?? 0).clamp(0, 5),
    eventId: j['eventId'] is String ? j['eventId'] as String : null,
    lineup: _strings(j['lineup']),
    seen: _strings(j['seen']),
    at: (j['at'] as num?)?.toInt() ?? 0,
    deleted: j['deleted'] == true,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'artist': artist,
    if (title.isNotEmpty) 'title': title,
    'date':
        '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')}',
    if (city.isNotEmpty) 'city': city,
    if (cc.isNotEmpty) 'cc': cc,
    if (venue.isNotEmpty) 'venue': venue,
    'kind': kind,
    if (note.isNotEmpty) 'note': note,
    if (rating > 0) 'rating': rating,
    if (eventId != null) 'eventId': eventId,
    if (lineup.isNotEmpty) 'lineup': lineup,
    if (seen.isNotEmpty) 'seen': seen,
    'at': at,
    if (deleted) 'deleted': true,
  };

  static List<String> _strings(Object? raw) => raw is List
      ? [
          for (final x in raw)
            if (x != null && x.toString().trim().isNotEmpty) x.toString().trim(),
        ]
      : const [];

  @override
  bool operator ==(Object other) => other is Attended && other.id == id && other.at == at && other.deleted == deleted;

  @override
  int get hashCode => Object.hash(id, at, deleted);
}

/// Łączy dwie historie: dla każdego wpisu wygrywa nowsza zmiana.
Map<String, Attended> mergeAttended(Map<String, Attended> a, Map<String, Attended> b) {
  final out = {...a};
  b.forEach((id, e) {
    final mine = out[id];
    if (mine == null || e.at > mine.at) out[id] = e;
  });
  return out;
}

Map<String, Attended> decodeAttendedList(Object? raw) {
  if (raw is! List) return {};
  final out = <String, Attended>{};
  for (final x in raw) {
    if (x is Map) {
      final a = Attended.fromJson(x.cast<String, dynamic>());
      if (a.id.isNotEmpty) out[a.id] = a;
    }
  }
  return out;
}

List<Map<String, dynamic>> encodeAttendedList(Map<String, Attended> all) =>
    (all.values.toList()..sort((a, b) => a.id.compareTo(b.id))).map((a) => a.toJson()).toList();
