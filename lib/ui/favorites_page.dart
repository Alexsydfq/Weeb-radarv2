import 'package:flutter/material.dart';

import 'app_scope.dart';
import 'widgets/event_card.dart';

class FavoritesPage extends StatelessWidget {
  const FavoritesPage({super.key});

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final theme = Theme.of(context);
    final favs = s.events.where((e) => s.favourites.contains(e.id)).toList()
      ..sort((a, b) => a.nextDate.compareTo(b.nextDate));
    final upcoming = favs.where((e) => !e.isOver).toList();
    final past = favs.where((e) => e.isOver).toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 12),
          child: Text('Ulubione',
              style: theme.textTheme.headlineLarge?.copyWith(fontWeight: FontWeight.w900)),
        ),
        if (favs.isEmpty)
          Padding(
            padding: const EdgeInsets.all(32),
            child: Column(children: [
              const Text('☆ (ﾉ◕ヮ◕)ﾉ*:・ﾟ✧', style: TextStyle(fontSize: 26)),
              const SizedBox(height: 10),
              Text(
                'N-nie ma tu nic! Kliknij gwiazdkę przy evencie, to go tu zapiszę. Nie żeby mi zależało.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyLarge,
              ),
            ]),
          ),
        for (final e in upcoming) EventCard(event: e),
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
