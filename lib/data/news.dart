import '../models/event.dart';
import 'app_state.dart';
import 'sync_service.dart';

/// Coś, o czym warto dać znać powiadomieniem.
class NewsItem {
  const NewsItem(this.event, {this.change, this.rank});

  final RadarEvent event;

  /// Treść zmiany (dla eventów, które już znasz), null dla nowych.
  final String? change;

  /// Miejsce artysty w Twoim Spotify, jeśli jest.
  final int? rank;

  bool get isChange => change != null;
}

/// Klucz zmiany w zbiorze „już powiadomione”.
String changeKey(RadarEvent e) => '${e.id}~${e.changeNote}';

/// Porównuje świeżo pobrane eventy z tym, co już było w powiadomieniach
/// (na tym albo na drugim urządzeniu, przez gista) i zwraca nowości.
/// Pierwsze sprawdzenie zgłasza wszystko, co pasuje, a potem każdy event
/// i każda zmiana trafia do powiadomień tylko raz.
Future<List<NewsItem>> collectNews(AppState s, List<RadarEvent> events) async {
  final seen = s.notified ?? const <String>{};

  final news = <NewsItem>[];
  for (final e in events) {
    if (e.isOver || s.hidden.contains(e.id)) continue;
    if (e.isJapan && !s.notifyJapan) continue;
    final plan = s.planOf(e.id);
    if (plan == Plan.notGoing) continue;
    final rank = s.spotifyRank(e);
    final relevant = s.notifySpotifyOnly ? s.isSpotify(e) : s.isForYou(e);
    if (!seen.contains(e.id)) {
      if (relevant) news.add(NewsItem(e, rank: rank));
    } else if (e.changeNote != null && !seen.contains(changeKey(e))) {
      // Zmiany tylko dla tego, co Cię obchodzi: plany, gwiazdki, Twoi artyści.
      if (plan != null || s.favourites.contains(e.id) || s.isSpotify(e)) {
        news.add(NewsItem(e, change: e.changeNote, rank: rank));
      }
    }
  }

  // Zapamiętujemy wszystko, co dziś widać (też to, czego nie zgłosiliśmy).
  await s.markNotified([
    for (final e in events) ...[e.id, if (e.changeNote != null) changeKey(e)],
  ]);

  // Najpierw Spotify (wg miejsca), potem reszta wg daty.
  news.sort((a, b) {
    final ra = a.rank ?? 99999, rb = b.rank ?? 99999;
    if (ra != rb) return ra.compareTo(rb);
    return a.event.nextDate.compareTo(b.event.nextDate);
  });
  return news;
}
