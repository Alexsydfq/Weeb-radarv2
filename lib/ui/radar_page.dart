import 'package:flutter/material.dart';

import '../data/defaults.dart';
import '../models/event.dart';
import 'app_scope.dart';
import 'refresh.dart';
import 'event_detail.dart';
import 'util.dart';
import 'widgets/event_card.dart';
import 'widgets/glass.dart';

enum _Sort { date, match }

/// Ekran główny: najbliższy hit, statystyki, wyszukiwarka, filtry i lista.
/// Spotify = tylko Twoi artyści, Dla mnie = cały Twój gust, Wszystko = bez filtra.
enum _Scope { spotify, forYou, all }

class RadarPage extends StatefulWidget {
  const RadarPage({super.key});

  @override
  State<RadarPage> createState() => _RadarPageState();
}

class _RadarPageState extends State<RadarPage> {
  final _search = TextEditingController();
  _Scope _scope = _Scope.forYou;
  bool get _forYou => _scope != _Scope.all;
  final Set<String> _kinds = {};
  String? _country;
  _Sort _sort = _Sort.date;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final theme = Theme.of(context);
    final upcoming = s.upcomingEurope;
    final q = _search.text.trim().toLowerCase();

    var list = upcoming.where((e) {
      if (_scope == _Scope.forYou && !s.isForYou(e)) return false;
      if (_scope == _Scope.spotify && !s.isSpotify(e)) return false;
      if (_kinds.isNotEmpty && !_kinds.contains(e.kind)) return false;
      if (_country != null && !e.countries.contains(_country)) return false;
      if (q.isNotEmpty) {
        final hay = '${e.searchable} ${e.stops.map((x) => '${x.city} ${x.venue} ${x.cc}').join(' ')}'.toLowerCase();
        if (!hay.contains(q)) return false;
      }
      return true;
    }).toList();
    if (_sort == _Sort.match) {
      list.sort((a, b) => s.score(b).compareTo(s.score(a)));
    }

    final countries = <String>{for (final e in upcoming) ...e.countries}.toList()
      ..sort((a, b) => countryName(a).compareTo(countryName(b)));
    final kinds = <String>{for (final e in upcoming) e.kind}.toList()..sort();

    // Na górze najpierw to, czego słuchasz na Spotify, potem reszta pod Twój gust.
    final best =
        ([...upcoming.where(s.isForYou)]..sort((a, b) {
              final bySpotify = (s.isSpotify(b) ? 1 : 0).compareTo(s.isSpotify(a) ? 1 : 0);
              if (bySpotify != 0) return bySpotify;
              final byScore = s.score(b).compareTo(s.score(a));
              return byScore != 0 ? byScore : a.nextDate.compareTo(b.nextDate);
            }))
            .take(5)
            .toList();

    return RefreshIndicator(
      onRefresh: () => refreshAll(context),
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(
            child: _Header(onRefresh: () => refreshAll(context), loading: s.loading),
          ),
          if (s.lastError != null)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Glass(
                  highlight: theme.colorScheme.error,
                  child: Row(
                    children: [
                      Icon(Icons.wifi_off_rounded, color: theme.colorScheme.error),
                      const SizedBox(width: 10),
                      Expanded(child: Text(s.lastError!)),
                    ],
                  ),
                ),
              ),
            ),
          if (best.isNotEmpty) SliverToBoxAdapter(child: _HeroCarousel(events: best)),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: _Stats(events: upcoming),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Glass(
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    radius: 30,
                    child: TextField(
                      controller: _search,
                      onChanged: (_) => setState(() {}),
                      decoration: InputDecoration(
                        border: InputBorder.none,
                        prefixIcon: const Icon(Icons.search_rounded),
                        hintText: 'Szukaj artysty, miasta, klubu...',
                        suffixIcon: q.isEmpty
                            ? null
                            : IconButton(
                                icon: const Icon(Icons.close_rounded),
                                onPressed: () => setState(_search.clear),
                              ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        SegmentedButton<_Scope>(
                          segments: const [
                            ButtonSegment(
                              value: _Scope.spotify,
                              label: Text('Spotify'),
                              icon: Icon(Icons.headphones_rounded),
                            ),
                            ButtonSegment(
                              value: _Scope.forYou,
                              label: Text('Dla mnie'),
                              icon: Icon(Icons.favorite_rounded),
                            ),
                            ButtonSegment(value: _Scope.all, label: Text('Wszystko'), icon: Icon(Icons.public_rounded)),
                          ],
                          selected: {_scope},
                          onSelectionChanged: (v) => setState(() => _scope = v.first),
                        ),
                        const SizedBox(width: 8),
                        for (final k in kinds) ...[
                          FilterChip(
                            avatar: Icon(kindIcon(k), size: 16),
                            label: Text(kindLabels[k] ?? k),
                            selected: _kinds.contains(k),
                            onSelected: (v) => setState(() => v ? _kinds.add(k) : _kinds.remove(k)),
                          ),
                          const SizedBox(width: 6),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String?>(
                            value: _country,
                            isExpanded: true,
                            hint: const Text('🌍  Wszystkie kraje'),
                            items: [
                              const DropdownMenuItem(value: null, child: Text('🌍  Wszystkie kraje')),
                              for (final c in countries)
                                DropdownMenuItem(value: c, child: Text('${flagOf(c)}  ${countryName(c)}')),
                            ],
                            onChanged: (v) => setState(() => _country = v),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      TextButton.icon(
                        icon: Icon(_sort == _Sort.date ? Icons.event_rounded : Icons.auto_awesome_rounded),
                        label: Text(_sort == _Sort.date ? 'Wg daty' : 'Wg dopasowania'),
                        onPressed: () => setState(() => _sort = _sort == _Sort.date ? _Sort.match : _Sort.date),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          if (list.isEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  children: [
                    const Text('(´・ω・`)', style: TextStyle(fontSize: 34)),
                    const SizedBox(height: 8),
                    Text(
                      _forYou
                          ? 'Nic pod Twój gust z tymi filtrami. Przełącz na „Wszystko” albo dopisz artystów.'
                          : 'Brak eventów dla tych filtrów.',
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
              sliver: SliverLayoutBuilder(
                builder: (context, c) {
                  final cols = (c.crossAxisExtent / 430).floor().clamp(1, 3);
                  if (cols == 1) {
                    return SliverList.builder(
                      itemCount: list.length,
                      itemBuilder: (_, i) => EventCard(event: list[i]),
                    );
                  }
                  return SliverGrid.builder(
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: cols,
                      mainAxisExtent: 196,
                      crossAxisSpacing: 10,
                    ),
                    itemCount: list.length,
                    itemBuilder: (_, i) => EventCard(event: list[i]),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.onRefresh, required this.loading});

  final Future<void> Function() onRefresh;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final theme = Theme.of(context);
    final h = DateTime.now().hour;
    final greet = h < 5
        ? 'Czemu nie śpisz, baka?'
        : h < 12
        ? 'Ohayō, Awex!'
        : h < 18
        ? 'Konnichiwa, Awex!'
        : 'Konbanwa, Awex!';
    final updated = s.feedUpdated ?? s.lastRefresh;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 12, 4),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(greet, style: theme.textTheme.labelLarge?.copyWith(color: s.accent)),
                Text(
                  'Weeb Radar',
                  style: theme.textTheme.headlineLarge?.copyWith(fontWeight: FontWeight.w900, letterSpacing: -0.5),
                ),
                if (updated != null)
                  Text(
                    'Dane z ${formatDay(updated.toLocal())}',
                    style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                  ),
              ],
            ),
          ),
          loading
              ? const Padding(
                  padding: EdgeInsets.all(12),
                  child: SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5)),
                )
              : IconButton.filledTonal(
                  tooltip: 'Odśwież',
                  icon: const Icon(Icons.refresh_rounded),
                  onPressed: onRefresh,
                ),
        ],
      ),
    );
  }
}

class _HeroCarousel extends StatefulWidget {
  const _HeroCarousel({required this.events});

  final List<RadarEvent> events;

  @override
  State<_HeroCarousel> createState() => _HeroCarouselState();
}

class _HeroCarouselState extends State<_HeroCarousel> {
  final _controller = PageController(viewportFraction: 0.92);
  int _page = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 760;
    if (wide) {
      // Na dużym ekranie karty stoją obok siebie zamiast karuzeli.
      return SizedBox(
        height: 220,
        child: ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
          scrollDirection: Axis.horizontal,
          itemCount: widget.events.length,
          separatorBuilder: (_, _) => const SizedBox(width: 12),
          itemBuilder: (_, i) => SizedBox(width: 440, child: _HeroCard(event: widget.events[i])),
        ),
      );
    }
    return Column(
      children: [
        const SizedBox(height: 10),
        SizedBox(
          height: wide ? 210 : 190,
          child: PageView.builder(
            controller: _controller,
            itemCount: widget.events.length,
            onPageChanged: (i) => setState(() => _page = i),
            itemBuilder: (_, i) => Padding(
              padding: const EdgeInsets.symmetric(horizontal: 5),
              child: _HeroCard(event: widget.events[i]),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(
            widget.events.length,
            (i) => AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              width: i == _page ? 20 : 7,
              height: 7,
              margin: const EdgeInsets.symmetric(horizontal: 3),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary.withValues(alpha: i == _page ? 1 : 0.3),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _HeroCard extends StatelessWidget {
  const _HeroCard({required this.event});

  final RadarEvent event;

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final theme = Theme.of(context);
    final kc = kindColor(event.kind);
    final matched = s.matchedArtists(event);
    final spotify = matched.isNotEmpty;
    final next = event.nextStop;
    return ClipRRect(
      borderRadius: BorderRadius.circular(26),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => Navigator.of(context).push(EventDetailPage.route(event)),
          child: Ink(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                // Ze Spotify: mocna zieleń. Reszta (Twój gust ogólnie): spokojniej.
                colors: spotify
                    ? [
                        spotifyGreen.withValues(alpha: 0.9),
                        kc.withValues(alpha: 0.7),
                        Colors.black.withValues(alpha: 0.55),
                      ]
                    : [
                        kc.withValues(alpha: 0.45),
                        Colors.black.withValues(alpha: 0.55),
                        Colors.black.withValues(alpha: 0.7),
                      ],
              ),
            ),
            child: Stack(
              children: [
                Positioned(
                  right: -20,
                  bottom: -30,
                  child: Icon(kindIcon(event.kind), size: 170, color: Colors.white.withValues(alpha: 0.12)),
                ),
                Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          spotify
                              ? Pill(
                                  spotifyLabel(s.spotifyRank(event)).toUpperCase(),
                                  color: Colors.white,
                                  icon: Icons.headphones_rounded,
                                )
                              : const Pill('POLECAM', color: Colors.white, icon: Icons.auto_awesome),
                          const SizedBox(width: 6),
                          Pill(countdown(event.nextDate), color: Colors.white, icon: Icons.timer_outlined),
                        ],
                      ),
                      const Spacer(),
                      Text(
                        event.artist,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.headlineSmall?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      Text(
                        event.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyMedium?.copyWith(color: Colors.white70),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        next != null
                            ? '${flagOf(next.cc)} ${next.city} · ${formatDay(next.date)}${next.venue.isNotEmpty ? ' · ${next.venue}' : ''}'
                            : formatRange(event),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.labelLarge?.copyWith(color: Colors.white),
                      ),
                      if (matched.isNotEmpty)
                        Text(
                          '🎧 ${matched.join(', ')}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.labelMedium?.copyWith(color: Colors.white),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Stats extends StatelessWidget {
  const _Stats({required this.events});

  final List<RadarEvent> events;

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final mine = events.where(s.isSpotify).length;
    final home = events.where((e) => e.countries.any(s.isHome)).length;
    final soon = events.where((e) => e.nextDate.difference(todayDate()).inDays <= 30).length;
    Widget tile(String n, String label, IconData icon) => Expanded(
      child: Glass(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
        child: Column(
          children: [
            Icon(icon, size: 20, color: s.accent),
            const SizedBox(height: 4),
            Text(n, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
            Text(
              label,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelSmall,
            ),
          ],
        ),
      ),
    );
    return Row(
      children: [
        tile('${events.length}', 'nadchodzące', Icons.event_available_rounded),
        const SizedBox(width: 8),
        tile('$mine', 'ze Spotify', Icons.headphones_rounded),
        const SizedBox(width: 8),
        tile('$home', s.homeCountry == 'EU' ? 'w Europie' : '${flagOf(s.homeCountry)} u Ciebie', Icons.home_rounded),
        const SizedBox(width: 8),
        tile('$soon', 'w 30 dni', Icons.bolt_rounded),
      ],
    );
  }
}
