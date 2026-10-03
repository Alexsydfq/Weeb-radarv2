import 'package:flutter/material.dart';

import '../data/defaults.dart';
import 'app_scope.dart';
import 'widgets/glass.dart';

/// Twój gust: artyści ze Spotify i słowa kluczowe, po których radar dopasowuje eventy.
class ArtistsPage extends StatefulWidget {
  const ArtistsPage({super.key});

  @override
  State<ArtistsPage> createState() => _ArtistsPageState();
}

class _ArtistsPageState extends State<ArtistsPage> {
  final _artist = TextEditingController();
  final _keyword = TextEditingController();

  @override
  void dispose() {
    _artist.dispose();
    _keyword.dispose();
    super.dispose();
  }

  void _addArtist() {
    final s = AppScope.read(context);
    final names = _artist.text.split(RegExp(r'[,\n]')).map((x) => x.trim()).where((x) => x.isNotEmpty);
    final next = [...s.artists];
    for (final n in names) {
      if (!next.any((a) => a.toLowerCase() == n.toLowerCase())) next.add(n);
    }
    s.setArtists(next);
    _artist.clear();
  }

  void _addKeyword() {
    final s = AppScope.read(context);
    final k = _keyword.text.trim().toLowerCase();
    if (k.isEmpty || s.keywords.contains(k)) return;
    s.setKeywords([...s.keywords, k]);
    _keyword.clear();
  }

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final theme = Theme.of(context);
    final counts = {
      for (final a in s.artists)
        a: s.upcoming.where((e) => s.mentions(e.searchable, a)).length,
    };
    final sorted = [...s.artists]..sort((a, b) => counts[b]!.compareTo(counts[a]!));

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4),
          child: Text('Twoi artyści',
              style: theme.textTheme.headlineLarge?.copyWith(fontWeight: FontWeight.w900)),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 4, 4, 12),
          child: Text(
            'Startowa lista pochodzi z Twojego Spotify. Radar podświetla eventy, w których pada któreś z tych imion.',
            style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
        ),
        Glass(
          padding: const EdgeInsets.fromLTRB(14, 4, 4, 4),
          radius: 30,
          child: Row(children: [
            Expanded(
              child: TextField(
                controller: _artist,
                onSubmitted: (_) => _addArtist(),
                decoration: const InputDecoration(
                  border: InputBorder.none,
                  hintText: 'Dodaj artystę (kilku: po przecinku)',
                ),
              ),
            ),
            IconButton.filled(onPressed: _addArtist, icon: const Icon(Icons.add_rounded)),
          ]),
        ),
        SectionTitle(
          '${s.artists.length} artystów',
          trailing: TextButton.icon(
            icon: const Icon(Icons.restore_rounded),
            label: const Text('Lista ze Spotify'),
            onPressed: () async {
              final ok = await showDialog<bool>(
                context: context,
                builder: (c) => AlertDialog(
                  title: const Text('Przywrócić listę ze Spotify?'),
                  content: const Text('Twoje ręczne zmiany na liście artystów znikną.'),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Anuluj')),
                    FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Przywróć')),
                  ],
                ),
              );
              if (ok == true) s.setArtists([...defaultArtists]);
            },
          ),
        ),
        Glass(
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final a in sorted)
                InputChip(
                  label: Text(a),
                  avatar: counts[a]! > 0
                      ? CircleAvatar(
                          backgroundColor: s.accent,
                          child: Text('${counts[a]}', style: const TextStyle(fontSize: 11, color: Colors.white)),
                        )
                      : null,
                  onDeleted: () => s.setArtists(s.artists.where((x) => x != a).toList()),
                ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Glass(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: SwitchListTile(
            secondary: const Icon(Icons.festival_rounded),
            title: const Text('Konwenty i festiwale zawsze dla mnie'),
            subtitle: const Text('Pokazuj je w „Dla mnie”, nawet bez znanych nazw w składzie'),
            value: s.conventionsAlwaysForYou,
            onChanged: s.setConventionsAlwaysForYou,
          ),
        ),
        const SectionTitle('Słowa kluczowe'),
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 0, 4, 10),
          child: Text(
            'Eventy z tymi słowami w opisie też trafiają do zakładki „Dla mnie”.',
            style: theme.textTheme.bodySmall,
          ),
        ),
        Glass(
          padding: const EdgeInsets.fromLTRB(14, 4, 4, 4),
          radius: 30,
          child: Row(children: [
            Expanded(
              child: TextField(
                controller: _keyword,
                onSubmitted: (_) => _addKeyword(),
                decoration: const InputDecoration(border: InputBorder.none, hintText: 'np. utaite, eurobeat'),
              ),
            ),
            IconButton.filled(onPressed: _addKeyword, icon: const Icon(Icons.add_rounded)),
          ]),
        ),
        const SizedBox(height: 10),
        Glass(
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final k in s.keywords)
                InputChip(
                  label: Text('#$k'),
                  onDeleted: () => s.setKeywords(s.keywords.where((x) => x != k).toList()),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
