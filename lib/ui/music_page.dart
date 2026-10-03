import 'package:flutter/material.dart';

import '../models/song.dart';
import 'app_scope.dart';
import 'refresh.dart';
import 'util.dart';
import 'widgets/glass.dart';

enum _Filter { mine, picks, all, starred }

/// Nowa muzyka: codzienny skan nowych kawałków Twoich artystów plus propozycje.
class MusicPage extends StatefulWidget {
  const MusicPage({super.key});

  @override
  State<MusicPage> createState() => _MusicPageState();
}

class _MusicPageState extends State<MusicPage> {
  _Filter _filter = _Filter.all;

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final theme = Theme.of(context);
    final list = s.songs.where((x) {
      return switch (_filter) {
        _Filter.mine => s.isMySong(x),
        _Filter.picks => x.pick,
        _Filter.starred => s.isSongFav(x),
        _Filter.all => true,
      };
    }).toList();

    return RefreshIndicator(
      onRefresh: () => refreshAll(context),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Nowa muzyka',
                    style: theme.textTheme.headlineLarge?.copyWith(fontWeight: FontWeight.w900),
                  ),
                ),
                RefreshButton(loading: s.loading),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 4, 4, 12),
            child: Text(
              'Codziennie świeże kawałki Twoich artystów i trochę propozycji ✨ spoza listy. '
              'Nie żebym wybierała je specjalnie dla Ciebie.',
              style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SegmentedButton<_Filter>(
              segments: const [
                ButtonSegment(value: _Filter.all, label: Text('Wszystko'), icon: Icon(Icons.library_music_rounded)),
                ButtonSegment(value: _Filter.mine, label: Text('Moi artyści'), icon: Icon(Icons.headphones_rounded)),
                ButtonSegment(value: _Filter.picks, label: Text('Propozycje'), icon: Icon(Icons.auto_awesome_rounded)),
                ButtonSegment(value: _Filter.starred, label: Text('Gwiazdki'), icon: Icon(Icons.star_rounded)),
              ],
              selected: {_filter},
              onSelectionChanged: (v) => setState(() => _filter = v.first),
            ),
          ),
          const SizedBox(height: 10),
          if (list.isEmpty)
            Padding(
              padding: const EdgeInsets.all(28),
              child: Column(
                children: [
                  const Text('♪(´ε｀ )', style: TextStyle(fontSize: 26)),
                  const SizedBox(height: 10),
                  Text(
                    s.songs.isEmpty
                        ? 'Jeszcze pusto. Skan wrzuca nowe kawałki raz dziennie rano, więc zajrzyj jutro.'
                        : 'Nic tu nie pasuje. Zmień filtr, baka.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyLarge,
                  ),
                ],
              ),
            ),
          for (final x in list) _SongCard(song: x),
        ],
      ),
    );
  }
}

class _SongCard extends StatelessWidget {
  const _SongCard({required this.song});

  final Song song;

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final theme = Theme.of(context);
    final rank = s.songRank(song);
    final mine = rank != null;
    final fav = s.isSongFav(song);
    final small = theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant);

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Glass(
        highlight: mine ? spotifyGreen : (song.pick ? const Color(0xFFB98CFF) : null),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      Pill(song.kind, icon: Icons.album_rounded),
                      if (mine)
                        Pill(
                          rank < 9999 ? 'Spotify #$rank' : 'Twój artysta',
                          icon: Icons.headphones_rounded,
                          color: spotifyGreen,
                        ),
                      if (song.pick)
                        const Pill('propozycja', icon: Icons.auto_awesome_rounded, color: Color(0xFFB98CFF)),
                      Pill(formatDay(song.date), icon: Icons.today_rounded),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: fav ? 'Usuń gwiazdkę' : 'Daj gwiazdkę',
                  icon: Icon(
                    fav ? Icons.star_rounded : Icons.star_outline_rounded,
                    color: fav ? const Color(0xFFFFD23F) : null,
                  ),
                  onPressed: () => s.toggleSongFav(song),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(song.title, style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
            Text(song.artist, style: theme.textTheme.titleSmall?.copyWith(color: mine ? spotifyGreen : null)),
            if (song.songAbout != null) ...[
              const SizedBox(height: 8),
              Text(song.songAbout!, style: theme.textTheme.bodyMedium),
            ],
            if (song.about != null) ...[const SizedBox(height: 6), Text(song.about!, style: small)],
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton.tonalIcon(
                  icon: const Icon(Icons.play_circle_fill_rounded, color: spotifyGreen),
                  label: const Text('Spotify'),
                  onPressed: () => openLink(
                    context,
                    'https://open.spotify.com/search/${Uri.encodeComponent('${song.artist} ${song.title}')}',
                  ),
                ),
                OutlinedButton.icon(
                  icon: const Icon(Icons.smart_display_rounded),
                  label: const Text('YouTube'),
                  onPressed: () => openLink(
                    context,
                    song.url != null && song.url!.contains('youtu')
                        ? song.url!
                        : 'https://www.youtube.com/results?search_query=${Uri.encodeQueryComponent('${song.artist} ${song.title}')}',
                  ),
                ),
                if (song.url != null && !song.url!.contains('youtu'))
                  TextButton.icon(
                    icon: const Icon(Icons.open_in_new_rounded),
                    label: const Text('Źródło'),
                    onPressed: () => openLink(context, song.url!),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
