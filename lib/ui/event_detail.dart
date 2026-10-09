import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/defaults.dart';
import '../data/sync_service.dart';
import '../edition.dart';
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
        position: Tween(
          begin: const Offset(0, 0.04),
          end: Offset.zero,
        ).animate(CurvedAnimation(parent: a, curve: Curves.easeOutCubic)),
        child: child,
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    // Bierzemy świeżą wersję eventu, żeby wybór miasta od razu było widać.
    final event = s.events.where((x) => x.id == this.event.id).firstOrNull ?? this.event;
    // Otwarcie eventu = przeczytany (po klatce, bo zmienia stan, który właśnie rysujemy).
    if (s.isUnread(event)) WidgetsBinding.instance.addPostFrameCallback((_) => s.markRead(event));
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
              icon: Icon(
                fav ? Icons.star_rounded : Icons.star_outline_rounded,
                color: fav ? const Color(0xFFFFD23F) : null,
              ),
              onPressed: () => s.toggleFavourite(event.id),
            ),
            PopupMenuButton<String>(
              onSelected: (v) {
                switch (v) {
                  case 'copy':
                    Clipboard.setData(ClipboardData(text: _shareText()));
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Skopiowano opis eventu')));
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
                  highlight: matched.isNotEmpty ? spotifyGreen : null,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          if (matched.isNotEmpty)
                            Pill(
                              spotifyLabel(s.spotifyRank(event)),
                              color: spotifyGreen,
                              icon: Icons.headphones_rounded,
                            ),
                          Pill(kindLabels[event.kind] ?? event.kind, color: kc, icon: kindIcon(event.kind)),
                          Pill(countdown(event.nextDate), icon: Icons.timer_outlined),
                          Pill('dopasowanie ${event.tier}/3', icon: Icons.tune_rounded),
                          if (s.isNew(event)) const Pill('NOWE', color: Color(0xFFFF5370)),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Text(event.artist, style: theme.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w900)),
                      if (event.title.isNotEmpty && event.title != event.artist)
                        Text(event.title, style: theme.textTheme.titleMedium),
                      const SizedBox(height: 8),
                      Text(
                        formatRange(event),
                        style: theme.textTheme.bodyLarge?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                      ),
                      if (event.chosen != null) ...[
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Icon(Icons.flight_takeoff_rounded, size: 20, color: kc),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Jedziesz: ${flagOf(event.chosen!.cc)} ${event.chosen!.city}, ${formatLong(event.chosen!.date)}',
                                style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                              ),
                            ),
                          ],
                        ),
                      ],
                      if (matched.isNotEmpty || keywords.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: [
                            for (final a in matched.take(6))
                              Pill(a, color: spotifyGreen, icon: Icons.headphones_rounded),
                            if (matched.length > 6) Pill('+${matched.length - 6}', color: spotifyGreen),
                            for (final k in keywords) Pill(k, icon: Icons.tag_rounded),
                          ],
                        ),
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
                            : byEdition(
                                'Synchronizację z telefonem/komputerem włączysz w zakładce Wygląd.',
                                'Zapisane tylko na tym urządzeniu.',
                              ),
                        style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
                if (event.changeNote != null) ...[
                  const SizedBox(height: 12),
                  Glass(
                    highlight: const Color(0xFFFFB13B),
                    child: Row(
                      children: [
                        const Icon(Icons.campaign_rounded, color: Color(0xFFFFB13B)),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Zmiana${event.updatedAt != null ? ' (${formatDay(event.updatedAt!)})' : ''}: ${event.changeNote}',
                            style: theme.textTheme.bodyMedium,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                if (event.about != null) ...[
                  const SectionTitle('Kto to?'),
                  Glass(child: SelectableText(event.about!, style: theme.textTheme.bodyLarge)),
                ],
                if (event.lineup.isNotEmpty) ...[
                  SectionTitle(
                    event.kind == 'konwent'
                        ? 'Goście muzyczni (${event.lineup.length})'
                        : 'Line-up (${event.lineup.length})',
                  ),
                  Glass(child: _Lineup(event: event)),
                ],
                if (event.facts.isNotEmpty) ...[
                  const SectionTitle('Najważniejsze info'),
                  Glass(
                    padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 16),
                    child: Column(
                      children: [
                        for (final (i, f) in event.facts.indexed) ...[
                          if (i > 0) const Divider(height: 1),
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                SizedBox(
                                  width: 120,
                                  child: Text(
                                    f.label,
                                    style: theme.textTheme.labelLarge?.copyWith(
                                      color: theme.colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                ),
                                Expanded(child: SelectableText(f.value, style: theme.textTheme.bodyLarge)),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
                if (event.note.isNotEmpty) ...[
                  const SectionTitle('Notatka'),
                  Glass(child: SelectableText(event.note, style: theme.textTheme.bodyLarge)),
                ],
                const SectionTitle('🎶 Mogą zagrać'),
                Glass(child: _MayPlay(event: event)),
                if (event.stops.isNotEmpty) ...[
                  SectionTitle(event.stops.length > 1 ? 'Przystanki (${event.stops.length})' : 'Gdzie'),
                  if (event.stops.length > 1)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
                      child: Text(
                        event.chosen == null
                            ? 'Kliknij miasto, do którego jedziesz: odliczanie, kalendarz i karta pokażą ten termin.'
                            : 'Jedziesz do: ${event.chosen!.city}. Kliknij jeszcze raz, żeby zdjąć wybór.',
                        style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                      ),
                    ),
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
                            home: s.homeCountry != 'EU' && s.isHome(st.cc),
                            color: kc,
                            chosen: event.chosen?.key == st.key,
                            onTap: event.stops.length > 1 && !st.date.isBefore(today)
                                ? () => s.chooseStop(event.id, st)
                                : null,
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
    this.chosen = false,
    this.onTap,
  });

  final EventStop stop;
  final bool first, last, past, home, chosen;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dim = past ? 0.4 : 1.0;
    return Opacity(
      opacity: dim,
      child: InkWell(
        onTap: onTap,
        child: Container(
          color: chosen ? color.withValues(alpha: 0.16) : null,
          child: IntrinsicHeight(
            child: Row(
              children: [
                const SizedBox(width: 18),
                SizedBox(
                  width: 20,
                  child: Column(
                    children: [
                      Expanded(
                        child: Container(width: 2, color: first ? Colors.transparent : color.withValues(alpha: 0.5)),
                      ),
                      Container(
                        width: home ? 14 : 10,
                        height: home ? 14 : 10,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: color,
                          boxShadow: home ? [BoxShadow(color: color, blurRadius: 10)] : null,
                        ),
                      ),
                      Expanded(
                        child: Container(width: 2, color: last ? Colors.transparent : color.withValues(alpha: 0.5)),
                      ),
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
                        Text(
                          '${flagOf(stop.cc)}  ${stop.city.isEmpty ? countryName(stop.cc) : stop.city}',
                          style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
                        ),
                        Text(
                          [formatLong(stop.date), if (stop.venue.isNotEmpty) stop.venue].join(' · '),
                          style: theme.textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                ),
                if (chosen)
                  const Padding(
                    padding: EdgeInsets.only(right: 8),
                    child: Pill('jadę tu', icon: Icons.flight_takeoff_rounded),
                  ),
                if (home)
                  const Padding(
                    padding: EdgeInsets.only(right: 14),
                    child: Pill('u Ciebie', icon: Icons.home_rounded),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Line-up: Twoi artyści ze Spotify na zielono i na początku, reszta zwyczajnie.
class _Lineup extends StatefulWidget {
  const _Lineup({required this.event});

  final RadarEvent event;

  @override
  State<_Lineup> createState() => _LineupState();
}

class _LineupState extends State<_Lineup> {
  static const _collapsed = 30;
  bool _all = false;

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final theme = Theme.of(context);
    final entries =
        [
          for (final (i, name) in widget.event.lineup.indexed)
            (name: name, mine: s.artistsIn(name).isNotEmpty, rank: s.rankOfEntry(name), order: i),
        ]..sort((a, b) {
          if (a.mine != b.mine) return a.mine ? -1 : 1;
          if (a.mine) return (a.rank ?? 9999).compareTo(b.rank ?? 9999);
          return a.order.compareTo(b.order);
        });
    final mine = entries.where((e) => e.mine).length;
    final shown = _all ? entries : entries.take(_collapsed).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (mine > 0)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Text(
              byEdition(
                mine == 1 ? '1 osoba z Twojego Spotify' : '$mine osób z Twojego Spotify',
                mine == 1 ? '1 osoba z Twojej listy artystów' : '$mine osób z Twojej listy artystów',
              ),
              style: theme.textTheme.labelLarge?.copyWith(color: spotifyGreen, fontWeight: FontWeight.w700),
            ),
          ),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final e in shown)
              e.mine
                  ? Pill(
                      e.rank != null ? '${e.name}  #${e.rank}' : e.name,
                      color: spotifyGreen,
                      icon: Icons.headphones_rounded,
                    )
                  : Pill(e.name, color: theme.colorScheme.onSurfaceVariant),
          ],
        ),
        if (entries.length > _collapsed)
          TextButton(
            onPressed: () => setState(() => _all = !_all),
            child: Text(_all ? 'Zwiń' : 'Pokaż wszystkich (${entries.length})'),
          ),
      ],
    );
  }
}

/// Przykładowe kawałki: setlista z ostatnich koncertów, a jak jej nie ma, największe hity.
class _MayPlay extends StatelessWidget {
  const _MayPlay({required this.event});

  final RadarEvent event;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final small = theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant);
    final fromSetlist = event.setlist.isNotEmpty;
    final songs = fromSetlist ? event.setlist : event.hits;
    final group = event.kind == 'festiwal' || event.kind == 'konwent' || event.kind == 'rave';
    final String caption;
    if (fromSetlist) {
      caption = event.setlistFrom == null
          ? 'Setlista z ostatnich koncertów, więc pewnie usłyszysz coś z tego.'
          : 'Setlista: ${event.setlistFrom}.';
    } else if (songs.isNotEmpty) {
      caption = group
          ? 'Największe hity gwiazd z line-upu. Setlist jeszcze nie ma.'
          : 'Największe hity. Setlisty z tej trasy jeszcze nie ma.';
    } else {
      caption = byEdition(
        'Skan jeszcze tego nie uzupełnił. Na razie posłuchaj sam, baka.',
        'Tu jeszcze nic nie ma. Poszukaj artysty w Spotify albo na setlist.fm.',
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(caption, style: small),
        if (songs.isNotEmpty) ...[
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final (i, h) in songs.indexed)
                ActionChip(
                  avatar: fromSetlist
                      ? CircleAvatar(
                          backgroundColor: Colors.transparent,
                          child: Text('${i + 1}', style: theme.textTheme.labelSmall),
                        )
                      : const Icon(Icons.play_circle_fill_rounded, color: spotifyGreen),
                  label: Text(h),
                  tooltip: 'Posłuchaj w Spotify',
                  onPressed: () => openLink(context, spotifySearchUrl(event, h)),
                ),
            ],
          ),
        ],
        if (!group) ...[
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                icon: const Icon(Icons.queue_music_rounded, color: spotifyGreen),
                label: const Text('Artysta w Spotify'),
                onPressed: () =>
                    openLink(context, 'https://open.spotify.com/search/${Uri.encodeComponent(event.artist)}/artists'),
              ),
              OutlinedButton.icon(
                icon: const Icon(Icons.format_list_numbered_rounded),
                label: const Text('Setlisty'),
                onPressed: () =>
                    openLink(context, 'https://www.setlist.fm/search?query=${Uri.encodeComponent(event.artist)}'),
              ),
            ],
          ),
        ],
      ],
    );
  }
}
