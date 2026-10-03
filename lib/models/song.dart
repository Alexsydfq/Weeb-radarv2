import 'dart:convert';

/// Nowa piosenka / klip / album z codziennego skanu „Nowa muzyka”.
class Song {
  final String id;
  final String title;
  final String artist;
  final DateTime? released;

  /// singiel, album, EP, MV, cover…
  final String kind;

  /// Krótko o twórcy.
  final String? about;

  /// Krótko o samym kawałku.
  final String? songAbout;
  final String? url;

  /// Propozycja od skanu spoza Twojej listy („może Ci się spodobać”).
  final bool pick;
  final DateTime? foundAt;

  const Song({
    required this.id,
    required this.title,
    required this.artist,
    this.released,
    this.kind = 'singiel',
    this.about,
    this.songAbout,
    this.url,
    this.pick = false,
    this.foundAt,
  });

  factory Song.fromJson(Map<String, dynamic> j) => Song(
        id: (j['id'] ?? '${j['artist']}-${j['title']}').toString(),
        title: (j['title'] ?? '').toString(),
        artist: (j['artist'] ?? '').toString(),
        released: _date(j['released']),
        kind: _str(j['kind']) ?? 'singiel',
        about: _str(j['about']),
        songAbout: _str(j['songAbout']),
        url: _str(j['url']),
        pick: j['pick'] == true,
        foundAt: _date(j['foundAt']),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'artist': artist,
        if (released != null) 'released': released!.toIso8601String().substring(0, 10),
        'kind': kind,
        if (about != null) 'about': about,
        if (songAbout != null) 'songAbout': songAbout,
        if (url != null) 'url': url,
        if (pick) 'pick': true,
        if (foundAt != null) 'foundAt': foundAt!.toIso8601String().substring(0, 10),
      };

  /// Data do sortowania: wydanie, a jak brak, to kiedy skan go znalazł.
  DateTime get date => released ?? foundAt ?? DateTime(1970);

  /// Klucz w zbiorze „już powiadomione” i w planach (gwiazdka).
  String get key => 'song:$id';

  String get searchable => '$artist $title ${about ?? ''} ${songAbout ?? ''}'.toLowerCase();

  /// Plik music.json leży obok events.json w tym samym repo.
  static String feedUrlFor(String eventsUrl) {
    final i = eventsUrl.lastIndexOf('/');
    return i < 0 ? eventsUrl : '${eventsUrl.substring(0, i)}/music.json';
  }

  static List<Song> parseFeed(String raw) {
    final j = _decode(raw);
    final list = j is Map ? (j['songs'] as List? ?? const []) : (j is List ? j : const []);
    final out = <Song>[];
    for (final s in list) {
      if (s is! Map) continue;
      final song = Song.fromJson(s.cast<String, dynamic>());
      if (song.title.isNotEmpty && song.artist.isNotEmpty) out.add(song);
    }
    out.sort((a, b) => b.date.compareTo(a.date));
    return out;
  }
}

Object? _decode(String raw) {
  try {
    return const JsonDecoder().convert(raw);
  } catch (_) {
    return null;
  }
}

String? _str(Object? v) {
  final s = v?.toString().trim();
  return (s == null || s.isEmpty) ? null : s;
}

DateTime? _date(Object? v) {
  final d = DateTime.tryParse(v?.toString() ?? '');
  return d == null ? null : DateTime(d.year, d.month, d.day);
}
