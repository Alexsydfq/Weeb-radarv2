import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/defaults.dart';
import '../data/sync_service.dart';
import '../models/event.dart';
import 'app_scope.dart';
import 'background.dart';
import 'manual_event_page.dart';
import 'util.dart';
import 'widgets/glass.dart';

class EventDetailPage extends StatelessWidget {
  const EventDetailPage({super.key, required this.event});

  final RadarEvent event;

  static Route<void> route(RadarEvent e) => PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 320),
        pageBuilder: (_, _, _) => EventDetailPage(event: e),
        transitionsBuilder: (_, a, _, child) => FadeTransition(
          opacity: a,
          child: SlideTransition(
            position: Tween(begin: const Offset(0, 0.04), end: Offset.zero)
                .animate(CurvedAnimation(parent: a, curve: Curves.easeOutCubic)),
            child: child,
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final theme = Theme.of(context);
    final fav = s.favourites.contains(event.id);
    final matched = s.matchedArtists(event);
    final keywords = s.matchedKeywords(event);
    final kc = kindColor(event.kind);
    final today = todayDate();

    return AppBackground(
      child: Scaffold(
        appBar: AppBar(
          actions: [
            IconButton(
              tooltip: fav ? 'Usuń z ulubionych' : 'Dodaj do ulubionych',
              icon: Icon(fav ? Icons.star_rounded : Icons.star_outline_rounded,
                  color: fav ? const Color(0xFFFFD23F) : null),
              onPressed: () => s.toggleFavourite(event.id),
            ),
            PopupMenuButton<String>(
              onSelected: (v) {
                switch (v) {
                  case 'copy':
                    Clipboard.setData(ClipboardData(text: _shareText()));
                    ScaffoldMessenger.of(context)
                        .showSnackBar(const SnackBar(content: Text('Skopiowano opis eventu')));
                  case 'hide':
                    s.hide(event.id);
                    Navigator.pop(context);
                  case 'edit':
                    Navigator.push(context, ManualEventPage.route(existing: event));
                  case 'delete':
                    s.deleteManualEvent(event.id);
                    Navigator.pop(context);
                }
              },
              itemBuilder: (_) => [
                const PopupMenuItem(value: 'copy', child: Text('Kopiuj opis')),
                if (event.origin == EventOrigin.manual) ...[
                  const PopupMenuItem(value: 'edit', child: Text('Edytuj')),
                  const PopupMenuItem(value: 'delete', child: Text('Usuń')),
                ] else
                  const PopupMenuItem(value: 'hide', child: Text('Ukryj ten event')),
              ],
            ),
          ],
        ),
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 820),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
              children: [
                Glass(
                  padding: const EdgeInsets.all(20),
                  highlight: matched.isNotEmpty ? s.accent : null,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(spacing: 6, runSpacing: 6, children: [
                        Pill(kindLabels[event.kind] ?? event.kind, color: kc, icon: kindIcon(event.kind)),
                        Pill(countdown(event.nextDate), icon: Icons.timer_outlined),
                        Pill('dopasowanie ${event.tier}/3', icon: Icons.tune_rounded),
                        if (s.isNew(event)) const Pill('NOWE', color: Color(0xFFFF5370)),
                      ]),
                      const SizedBox(height: 14),
                      Text(event.artist,
                          style: theme.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w900)),
                      if (event.title.isNotEmpty && event.title != event.artist)
                        Text(event.title, style: theme.textTheme.titleMedium),
                      const SizedBox(height: 8),
                      Text(formatRange(event),
                          style: theme.textTheme.bodyLarge?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                      if (matched.isNotEmpty || keywords.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Wrap(spacing: 6, runSpacing: 6, children: [
                          for (final a in matched) Pill(a, color: s.accent, icon: Icons.favorite_rounded),
                          for (final k in keywords) Pill(k, icon: Icons.tag_rounded),
                        ]),
                      ],
                    ],
                  ),
                ),
                const SectionTitle('Idziesz?'),
                Glass(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Cztery opcje się nie mieszczą w jednym rzędzie na telefonie, więc się zawijają.
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final p in Plan.values)
                            ChoiceChip(
                              avatar: Icon(planIcon(p), color: planColor(p), size: 18),
                              label: Text(planLabels[p]!),
                              showCheckmark: false,
                              selected: s.planOf(event.id) == p,
                              selectedColor: planColor(p).withValues(alpha: 0.35),
                              onSelected: (_) => s.setPlan(event.id, p),
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        s.syncEnabled
                            ? 'Synchronizuje się z drugim urządzeniem przez Twój prywatny Gist.'
                            : 'Synchronizację z telefonem/komputerem włączysz w zakładce Wygląd.',
                        style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
                if (event.note.isNotEmpty) ...[
                  const SectionTitle('Notatka'),
                  Glass(child: SelectableText(event.note, style: theme.textTheme.bodyLarge)),
                ],
                if (event.stops.isNotEmpty) ...[
                  SectionTitle(event.stops.length > 1 ? 'Przystanki (${event.stops.length})' : 'Gdzie'),
                  Glass(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Column(
                      children: [
                        for (final (i, st) in event.stops.indexed)
                          _StopTile(
                            stop: st,
                            first: i == 0,
                            last: i == event.stops.length - 1,
                            past: st.date.isBefore(today),
                            home: s.isHome(st.cc),
                            color: kc,
                          ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 18),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    if (event.tickets != null)
                      FilledButton.icon(
                        icon: const Icon(Icons.confirmation_number_rounded),
                        label: const Text('Bilety'),
                        onPressed: () => openLink(context, event.tickets!),
                      ),
                    if (event.url != null)
                      FilledButton.tonalIcon(
                        icon: const Icon(Icons.open_in_new_rounded),
                        label: const Text('Źródło'),
                        onPressed: () => openLink(context, event.url!),
                      ),
                    OutlinedButton.icon(
                      icon: const Icon(Icons.search_rounded),
                      label: const Text('Szukaj w sieci'),
                      onPressed: () => openLink(
                        context,
                        'https://www.google.com/search?q=${Uri.encodeQueryComponent('${event.artist} ${event.title} tickets')}',
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _shareText() {
    final b = StringBuffer(event.artist);
    if (event.title.isNotEmpty) b.write(' — ${event.title}');
    b.writeln();
    for (final st in event.stops) {
      b.writeln('${formatDay(st.date)} · ${st.city} · ${st.venue}');
    }
    if (event.tickets != null) b.writeln('Bilety: ${event.tickets}');
    if (event.url != null) b.writeln(event.url);
    return b.toString();
  }
}

class _StopTile extends StatelessWidget {
  const _StopTile({
    required this.stop,
    required this.first,
    required this.last,
    required this.past,
    required this.home,
    required this.color,
  });

  final EventStop stop;
  final bool first, last, past, home;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dim = past ? 0.4 : 1.0;
    return Opacity(
      opacity: dim,
      child: IntrinsicHeight(
        child: Row(
          children: [
            const SizedBox(width: 18),
            SizedBox(
              width: 20,
              child: Column(
                children: [
                  Expanded(child: Container(width: 2, color: first ? Colors.transparent : color.withValues(alpha: 0.5))),
                  Container(
                    width: home ? 14 : 10,
                    height: home ? 14 : 10,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: color,
                      boxShadow: home ? [BoxShadow(color: color, blurRadius: 10)] : null,
                    ),
                  ),
                  Expanded(child: Container(width: 2, color: last ? Colors.transparent : color.withValues(alpha: 0.5))),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${flagOf(stop.cc)}  ${stop.city.isEmpty ? countryName(stop.cc) : stop.city}',
                        style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
                    Text(
                      [formatLong(stop.date), if (stop.venue.isNotEmpty) stop.venue].join(' · '),
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ),
            if (home)
              const Padding(
                padding: EdgeInsets.only(right: 14),
                child: Pill('u Ciebie', icon: Icons.home_rounded),
              ),
          ],
        ),
      ),
    );
  }
}
