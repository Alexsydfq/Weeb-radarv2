import 'package:flutter/material.dart';

import '../../data/defaults.dart';
import '../../models/event.dart';
import '../app_scope.dart';
import '../event_detail.dart';
import '../util.dart';
import 'glass.dart';

/// Karta eventu na liście: data, tytuł, flagi tras, dopasowanie do gustu.
class EventCard extends StatelessWidget {
  const EventCard({super.key, required this.event});

  final RadarEvent event;

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final theme = Theme.of(context);
    final matched = s.matchedArtists(event);
    final fav = s.favourites.contains(event.id);
    final next = event.nextStop;
    final kc = kindColor(event.kind);

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Glass(
        padding: const EdgeInsets.fromLTRB(12, 12, 6, 12),
        highlight: matched.isNotEmpty ? s.accent : null,
        onTap: () => Navigator.of(context).push(EventDetailPage.route(event)),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _DateBadge(date: event.nextDate, color: kc),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: [
                      Pill(kindLabels[event.kind] ?? event.kind, color: kc, icon: kindIcon(event.kind)),
                      if (s.isNew(event)) const Pill('NOWE', color: Color(0xFFFF5370), icon: Icons.auto_awesome),
                      if (event.origin == EventOrigin.vocadb)
                        const Pill('VocaDB', color: Color(0xFF39C5BB)),
                      if (event.origin == EventOrigin.manual)
                        const Pill('mój', color: Color(0xFFFFD23F)),
                      Pill(countdown(event.nextDate), color: theme.colorScheme.onSurfaceVariant),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    event.artist,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                  ),
                  if (event.title.isNotEmpty && event.title != event.artist)
                    Text(
                      event.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium,
                    ),
                  const SizedBox(height: 6),
                  Text(
                    _whereLine(event, next),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                  ),
                  if (matched.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(Icons.favorite_rounded, size: 14, color: s.accent),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            'Słuchasz: ${matched.join(', ')}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.labelMedium?.copyWith(color: s.accent),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            Column(
              children: [
                IconButton(
                  tooltip: fav ? 'Usuń z ulubionych' : 'Dodaj do ulubionych',
                  icon: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 250),
                    transitionBuilder: (c, a) => ScaleTransition(scale: a, child: c),
                    child: Icon(
                      fav ? Icons.star_rounded : Icons.star_outline_rounded,
                      key: ValueKey(fav),
                      color: fav ? const Color(0xFFFFD23F) : null,
                    ),
                  ),
                  onPressed: () => s.toggleFavourite(event.id),
                ),
                _TierDots(tier: event.tier),
              ],
            ),
          ],
        ),
      ),
    );
  }

  static String _whereLine(RadarEvent e, EventStop? next) {
    if (e.stops.isEmpty) return formatRange(e);
    if (e.stops.length == 1) {
      final st = e.stops.first;
      return '${flagOf(st.cc)} ${[st.city, st.venue].where((x) => x.isNotEmpty).join(' · ')}';
    }
    final flags = e.stops.map((st) => flagOf(st.cc)).toSet().join(' ');
    final n = next ?? e.stops.first;
    return '$flags\n${e.stops.length} przystanków · następny: ${n.city} ${formatDay(n.date)}';
  }
}

class _DateBadge extends StatelessWidget {
  const _DateBadge({required this.date, required this.color});

  final DateTime date;
  final Color color;

  static const _months = ['STY', 'LUT', 'MAR', 'KWI', 'MAJ', 'CZE', 'LIP', 'SIE', 'WRZ', 'PAŹ', 'LIS', 'GRU'];

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Container(
      width: 54,
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [color.withValues(alpha: 0.9), color.withValues(alpha: 0.55)],
        ),
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(color: color.withValues(alpha: 0.35), blurRadius: 12)],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(_months[date.month - 1],
              style: t.labelSmall?.copyWith(color: Colors.white, fontWeight: FontWeight.w800, letterSpacing: 1)),
          Text('${date.day}',
              style: t.headlineSmall?.copyWith(color: Colors.white, fontWeight: FontWeight.w900, height: 1.1)),
          if (date.year != DateTime.now().year)
            Text('${date.year}', style: t.labelSmall?.copyWith(color: Colors.white70)),
        ],
      ),
    );
  }
}

class _TierDots extends StatelessWidget {
  const _TierDots({required this.tier});

  final int tier;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme.primary;
    return Tooltip(
      message: 'Dopasowanie z feedu: $tier/3',
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(
          3,
          (i) => Container(
            width: 6,
            height: 6,
            margin: const EdgeInsets.symmetric(horizontal: 1.5),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: i < tier ? c : c.withValues(alpha: 0.2),
            ),
          ),
        ),
      ),
    );
  }
}
