import 'package:flutter/material.dart';

import '../data/sync_service.dart';
import '../models/event.dart';
import 'app_scope.dart';
import 'util.dart';
import 'widgets/event_card.dart';

/// Twoje plany: Idę / Może / Zainteresowany / ulubione, a na końcu to, na co nie idziesz.
class FavoritesPage extends StatelessWidget {
  const FavoritesPage({super.key});

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final theme = Theme.of(context);
    final mine = s.events
        .where((e) => s.planOf(e.id) != null || s.favourites.contains(e.id))
        .toList()
      ..sort((a, b) => a.nextDate.compareTo(b.nextDate));
    final upcoming = mine.where((e) => !e.isOver).toList();
    final past = mine.where((e) => e.isOver && s.planOf(e.id) != Plan.notGoing).toList();
    List<RadarEvent> withPlan(Plan? p) => upcoming
        .where((e) => s.planOf(e.id) == p)
        .toList();

    final sections = <(String, IconData, Color?, List<RadarEvent>)>[
      for (final p in [Plan.going, Plan.maybe, Plan.interested]) (planLabels[p]!, planIcon(p), planColor(p), withPlan(p)),
      ('Ulubione, bez decyzji', Icons.star_rounded, const Color(0xFFFFD23F), withPlan(null)),
      (planLabels[Plan.notGoing]!, planIcon(Plan.notGoing), planColor(Plan.notGoing), withPlan(Plan.notGoing)),
    ];

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4),
          child: Text('Moje plany',
              style: theme.textTheme.headlineLarge?.copyWith(fontWeight: FontWeight.w900)),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 4, 4, 12),
          child: Row(children: [
            Icon(
              s.syncEnabled ? (s.syncError == null ? Icons.cloud_done_rounded : Icons.cloud_off_rounded) : Icons.cloud_outlined,
              size: 16,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                !s.syncEnabled
                    ? 'Tylko na tym urządzeniu. Synchronizację włączysz w Wyglądzie.'
                    : s.syncError ?? (s.syncing ? 'Synchronizuję…' : 'Zsynchronizowane z drugim urządzeniem'),
                style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
            ),
            if (s.syncEnabled)
              IconButton(
                tooltip: 'Synchronizuj teraz',
                icon: const Icon(Icons.sync_rounded, size: 20),
                onPressed: s.syncing ? null : s.syncNow,
              ),
          ]),
        ),
        if (mine.isEmpty)
          Padding(
            padding: const EdgeInsets.all(32),
            child: Column(children: [
              const Text('☆ (ﾉ◕ヮ◕)ﾉ*:・ﾟ✧', style: TextStyle(fontSize: 26)),
              const SizedBox(height: 10),
              Text(
                'N-nie ma tu nic! Otwórz event i kliknij „Idę”, „Może”, „Zainteresowany” albo gwiazdkę. Nie żeby mi zależało.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyLarge,
              ),
            ]),
          ),
        for (final (title, icon, color, list) in sections)
          if (list.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 8, 4, 8),
              child: Row(children: [
                Icon(icon, color: color, size: 20),
                const SizedBox(width: 8),
                Text('$title (${list.length})', style: theme.textTheme.titleMedium),
              ]),
            ),
            for (final e in list) EventCard(event: e),
          ],
        if (past.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 16, 4, 8),
            child: Text('Już były', style: theme.textTheme.titleMedium),
          ),
          for (final e in past) Opacity(opacity: 0.55, child: EventCard(event: e)),
        ],
      ],
    );
  }
}
