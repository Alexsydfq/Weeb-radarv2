import 'package:flutter/material.dart';

import '../data/defaults.dart';
import '../data/sync_service.dart';
import '../models/event.dart';
import 'app_scope.dart';
import 'event_detail.dart';
import 'util.dart';
import 'widgets/glass.dart';

/// Wszystkie terminy (każdy przystanek trasy osobno), pogrupowane miesiącami.
class CalendarPage extends StatefulWidget {
  const CalendarPage({super.key});

  @override
  State<CalendarPage> createState() => _CalendarPageState();
}

class _CalendarPageState extends State<CalendarPage> {
  bool _onlyMine = false;
  bool _onlyHome = false;

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final theme = Theme.of(context);
    final today = todayDate();

    final entries = <(DateTime, RadarEvent, EventStop?)>[];
    for (final e in s.upcoming) {
      if (_onlyMine && !s.isForYou(e)) continue;
      if (e.stops.isEmpty) {
        entries.add((e.start, e, null));
        continue;
      }
      for (final st in e.stops) {
        if (st.date.isBefore(today)) continue;
        if (_onlyHome && !s.isHome(st.cc)) continue;
        entries.add((st.date, e, st));
      }
    }
    entries.sort((a, b) => a.$1.compareTo(b.$1));

    final byMonth = <DateTime, List<(DateTime, RadarEvent, EventStop?)>>{};
    for (final en in entries) {
      byMonth.putIfAbsent(DateTime(en.$1.year, en.$1.month), () => []).add(en);
    }

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 16, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Kalendarz',
                    style: theme.textTheme.headlineLarge?.copyWith(fontWeight: FontWeight.w900)),
                const SizedBox(height: 8),
                Wrap(spacing: 8, children: [
                  FilterChip(
                    label: const Text('Tylko dla mnie'),
                    avatar: const Icon(Icons.favorite_rounded, size: 16),
                    selected: _onlyMine,
                    onSelected: (v) => setState(() => _onlyMine = v),
                  ),
                  FilterChip(
                    label: Text(s.homeCountry == 'EU' ? 'Tylko Europa' : 'Tylko ${countryName(s.homeCountry)}'),
                    avatar: Text(flagOf(s.homeCountry)),
                    selected: _onlyHome,
                    onSelected: (v) => setState(() => _onlyHome = v),
                  ),
                ]),
              ],
            ),
          ),
        ),
        if (byMonth.isEmpty)
          const SliverFillRemaining(
            hasScrollBody: false,
            child: Center(child: Text('Pusto... na razie. (・_・;)')),
          ),
        for (final m in byMonth.entries) ...[
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 8),
              child: Row(children: [
                Container(width: 4, height: 22, decoration: BoxDecoration(color: s.accent, borderRadius: BorderRadius.circular(2))),
                const SizedBox(width: 10),
                Text(_cap(monthTitle.format(m.key)),
                    style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
                const SizedBox(width: 8),
                Pill('${m.value.length}'),
              ]),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            sliver: SliverList.builder(
              itemCount: m.value.length,
              itemBuilder: (_, i) {
                final (date, e, st) = m.value[i];
                final mine = s.matchedArtists(e).isNotEmpty;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Glass(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    highlight: mine ? s.accent : null,
                    onTap: () => Navigator.push(context, EventDetailPage.route(e)),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 46,
                          child: Column(children: [
                            Text('${date.day}',
                                style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
                            Text(_weekdays[date.weekday - 1], style: theme.textTheme.labelSmall),
                          ]),
                        ),
                        Container(width: 3, height: 38, color: kindColor(e.kind), margin: const EdgeInsets.only(right: 12)),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(e.artist,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
                              Text(
                                st == null
                                    ? e.title
                                    : '${flagOf(st.cc)} ${st.city}${st.venue.isNotEmpty ? ' · ${st.venue}' : ''}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.bodySmall,
                              ),
                            ],
                          ),
                        ),
                        if (s.planOf(e.id) case final p? when p != Plan.notGoing)
                          Padding(
                            padding: const EdgeInsets.only(right: 4),
                            child: Icon(planIcon(p), color: planColor(p), size: 20),
                          ),
                        if (s.favourites.contains(e.id))
                          const Icon(Icons.star_rounded, color: Color(0xFFFFD23F), size: 20),
                        Icon(kindIcon(e.kind), size: 18, color: kindColor(e.kind)),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
        const SliverToBoxAdapter(child: SizedBox(height: 24)),
      ],
    );
  }

  static const _weekdays = ['pn', 'wt', 'śr', 'cz', 'pt', 'sb', 'nd'];

  static String _cap(String s) => s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);
}
