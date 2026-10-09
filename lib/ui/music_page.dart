import 'package:flutter/material.dart';

import '../edition.dart';
import '../models/song.dart';
import 'app_scope.dart';
import 'refresh.dart';
import 'util.dart';
import 'widgets/glass.dart';
import 'widgets/unread.dart';

enum _Filter { mine, picks, all, starred }

/// Nowa muzyka: codzienny skan nowych kawałków Twoich artystów plus propozycje.
class MusicPage extends StatefulWidget {
  const MusicPage({super.key});

  @override
  State<MusicPage> createState() => _MusicPageState();
}

class _MusicPageState extends State<MusicPage> {
  _Filter _filter = _Filter.all;
  bool _onlyNew = false;

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final theme = Theme.of(context);
    final list = s.songs.where((x) {
      if (_onlyNew && !s.isSongUnread(x)) return false;
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
              byEdition(
                'Codziennie świeże kawałki Twoich artystów i trochę propozycji ✨ spoza listy. '
                    'Nie żebym wybierała je specjalnie dla Ciebie.',
                'Nowe kawałki z ostatnich tygodni. ✨ to propozycje spoza głównej listy.',
              ),
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
          InboxBar(
            count: s.unreadSongs,
            onlyNew: _onlyNew,
            onOnlyNew: (v) => setState(() => _onlyNew = v),
            onMarkAll: () => setState(() {
              s.markAllRead(const [], songs: s.songs);
              _onlyNew = false;
            }),
          ),
          const SizedBox(height: 8),
          if (list.isEmpty)
            Padding(
              padding: const EdgeInsets.all(28),
              child: Column(
                children: [
                  Text(byEdition('♪(´ε｀ )', '🎵'), style: const TextStyle(fontSize: 26)),
                  const SizedBox(height: 10),
                  Text(
                    s.songs.isEmpty
                        ? 'Jeszcze pusto. Skan wrzuca nowe kawałki raz dziennie rano, więc zajrzyj jutro.'
                        : _onlyNew
                        ? 'Nic nowego. Wszystko już przesłuchane (albo przynajmniej przejrzane).'
                        : byEdition('Nic tu nie pasuje. Zmień filtr, baka.', 'Nic tu nie pasuje. Zmień filtr.'),
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

/// Kawałek jako zwarty wiersz, jak mail w skrzynce: nowe z kropką i pogrubione.
/// Kliknięcie rozwija opis; rozwinięcie albo otwarcie linku oznacza jako przejrzany.
class _SongCard extends StatefulWidget {
  const _SongCard({required this.song});

  final Song song;

  @override
  State<_SongCard> createState() => _SongCardState();
}

class _SongCardState extends State<_SongCard> {
  bool _open = false;

  Song get song => widget.song;

  String get _spotifyUrl =>
      'https://open.spotify.com/search/${Uri.encodeComponent('${song.artist} ${song.title}')}';

  String get _youtubeUrl => song.url != null && song.url!.contains('youtu')
      ? song.url!
      : 'https://www.youtube.com/results?search_query=${Uri.encodeQueryComponent('${song.artist} ${song.title}')}';

  void _openLink(String url) {
    AppScope.read(context).markSongRead(song);
    openLink(context, url);
  }

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final theme = Theme.of(context);
    final rank = s.songRank(song);
    final mine = rank != null;
    final fav = s.isSongFav(song);
    final unread = s.isSongUnread(song);
    final muted = theme.colorScheme.onSurfaceVariant;
    final small = theme.textTheme.bodySmall?.copyWith(color: muted);
    final hasMore = song.songAbout != null || song.about != null;

    final tags = [
      song.kind,
      formatDay(song.date),
      if (mine) rank < 9999 ? 'Spotify #$rank' : 'Twój artysta',
      if (song.pick) '✨ propozycja',
    ];

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Glass(
        padding: const EdgeInsets.fromLTRB(14, 10, 4, 10),
        highlight: mine ? spotifyGreen : (song.pick ? const Color(0xFFB98CFF) : null),
        onTap: () {
          setState(() => _open = !_open);
          s.markSongRead(song);
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          if (unread) ...[const UnreadDot(), const SizedBox(width: 7)],
                          Expanded(
                            child: Text(
                              song.title,
                              maxLines: _open ? 3 : 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: unread ? FontWeight.w900 : FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                      Text(
                        song.artist,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: mine ? spotifyGreen : (unread ? null : muted),
                          fontWeight: unread ? FontWeight.w700 : null,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(tags.join(' · '), maxLines: 1, overflow: TextOverflow.ellipsis, style: small),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Spotify',
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(Icons.play_circle_fill_rounded, color: spotifyGreen),
                  onPressed: () => _openLink(_spotifyUrl),
                ),
                IconButton(
                  tooltip: 'YouTube',
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(Icons.smart_display_rounded),
                  onPressed: () => _openLink(_youtubeUrl),
                ),
                IconButton(
                  tooltip: fav ? 'Usuń gwiazdkę' : 'Daj gwiazdkę',
                  visualDensity: VisualDensity.compact,
                  icon: Icon(
                    fav ? Icons.star_rounded : Icons.star_outline_rounded,
                    color: fav ? const Color(0xFFFFD23F) : null,
                  ),
                  onPressed: () => s.toggleSongFav(song),
                ),
              ],
            ),
            if (_open) ...[
              if (song.songAbout != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(0, 8, 8, 0),
                  child: Text(song.songAbout!, style: theme.textTheme.bodyMedium),
                ),
              if (song.about != null)
                Padding(padding: const EdgeInsets.fromLTRB(0, 6, 8, 0), child: Text(song.about!, style: small)),
              if (song.url != null && !song.url!.contains('youtu'))
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: TextButton.icon(
                    icon: const Icon(Icons.open_in_new_rounded),
                    label: const Text('Źródło'),
                    onPressed: () => _openLink(song.url!),
                  ),
                ),
            ] else if (hasMore)
              Padding(
                padding: const EdgeInsets.fromLTRB(0, 4, 8, 0),
                child: Text(
                  song.songAbout ?? song.about!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: small,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
