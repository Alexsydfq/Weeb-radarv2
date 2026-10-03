import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

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

/// Porównuje świeżo pobrane eventy z tym, co już widziałeś, i zwraca nowości.
/// Pierwsze wywołanie tylko zapamiętuje stan, żeby nie zasypać Cię starociami.
Future<List<NewsItem>> collectNews(AppState s, SharedPreferences prefs, List<RadarEvent> events) async {
  final seenRaw = prefs.getStringList('notify.seen');
  final firstRun = seenRaw == null;
  final seen = (seenRaw ?? const []).toSet();
  final changes = <String, String>{};
  try {
    changes.addAll((jsonDecode(prefs.getString('notify.changes') ?? '{}') as Map).cast<String, String>());
  } catch (_) {}

  final news = <NewsItem>[];
  for (final e in events) {
    if (e.isOver || s.hidden.contains(e.id)) continue;
    final plan = s.planOf(e.id);
    if (plan == Plan.notGoing) continue;
    final rank = s.spotifyRank(e);
    final relevant = s.notifySpotifyOnly ? s.isSpotify(e) : s.isForYou(e);
    if (!seen.contains(e.id)) {
      if (relevant) news.add(NewsItem(e, rank: rank));
    } else if (e.changeNote != null && changes[e.id] != e.changeNote) {
      // Zmiany tylko dla tego, co Cię obchodzi: plany, gwiazdki, Twoi artyści.
      if (plan != null || s.favourites.contains(e.id) || s.isSpotify(e)) {
        news.add(NewsItem(e, change: e.changeNote, rank: rank));
      }
    }
  }

  // Zapamiętujemy wszystko, co dziś widać (też to, czego nie zgłosiliśmy).
  await prefs.setStringList('notify.seen', {...seen, for (final e in events) e.id}.toList());
  await prefs.setString('notify.changes', jsonEncode({
    ...changes,
    for (final e in events)
      if (e.changeNote != null) e.id: e.changeNote!,
  }));
  if (firstRun) return const [];

  // Najpierw Spotify (wg miejsca), potem reszta wg daty.
  news.sort((a, b) {
    final ra = a.rank ?? 99999, rb = b.rank ?? 99999;
    if (ra != rb) return ra.compareTo(rb);
    return a.event.nextDate.compareTo(b.event.nextDate);
  });
  return news;
}
