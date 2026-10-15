import 'package:flutter/material.dart';

import '../data/defaults.dart';
import 'app_scope.dart';
import 'event_detail.dart';
import 'manual_event_page.dart';
import 'util.dart';
import 'widgets/glass.dart';

/// Skąd radar bierze eventy + skróty do małych eventów bez API (Vocafest itp.).
class SourcesPage extends StatelessWidget {
  const SourcesPage({super.key});

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final theme = Theme.of(context);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4),
          child: Text('Źródła',
              style: theme.textTheme.headlineLarge?.copyWith(fontWeight: FontWeight.w900)),
        ),
        const SectionTitle('Małe eventy do podglądania'),
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 0, 4, 10),
          child: Text(
            'Te strony nie mają API, więc otwierasz je jednym kliknięciem. '
            'Coś ciekawego? Dodaj to jako swój event poniżej.',
            style: theme.textTheme.bodySmall,
          ),
        ),
        LayoutBuilder(builder: (context, c) {
          final cols = (c.maxWidth / 300).floor().clamp(1, 3);
          final w = (c.maxWidth - (cols - 1) * 10) / cols;
          return Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (final w8 in s.watchSources)
                SizedBox(
                  width: w,
                  child: Glass(
                    onTap: () => openLink(context, w8.url),
                    child: Row(children: [
                      CircleAvatar(
                        backgroundColor: s.accent.withValues(alpha: 0.25),
                        child: Text(w8.name.characters.first, style: TextStyle(color: s.accent, fontWeight: FontWeight.w900)),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(w8.name, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
                          Text(w8.description, maxLines: 2, overflow: TextOverflow.ellipsis, style: theme.textTheme.bodySmall),
                        ]),
                      ),
                      PopupMenuButton<String>(
                        onSelected: (_) => s.setWatchSources(s.watchSources.where((x) => x != w8).toList()),
                        itemBuilder: (_) => const [PopupMenuItem(value: 'del', child: Text('Usuń skrót'))],
                      ),
                    ]),
                  ),
                ),
              SizedBox(
                width: w,
                child: Glass(
                  onTap: () => _addWatch(context),
                  child: const Row(children: [
                    CircleAvatar(child: Icon(Icons.add_link_rounded)),
                    SizedBox(width: 12),
                    Text('Dodaj stronę'),
                  ]),
                ),
              ),
            ],
          );
        }),
        SectionTitle(
          'Moje eventy',
          trailing: FilledButton.tonalIcon(
            icon: const Icon(Icons.add_rounded),
            label: const Text('Dodaj'),
            onPressed: () => Navigator.push(context, ManualEventPage.route()),
          ),
        ),
        if (s.manualEvents.isEmpty)
          Glass(
            child: Text(
              'Np. Vocafest w Londynie, który wypatrzyłeś na ich stronie. Taki event trafia do radaru i kalendarza.',
              style: theme.textTheme.bodyMedium,
            ),
          )
        else
          Glass(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Column(children: [
              for (final e in [...s.manualEvents]..sort((a, b) => a.start.compareTo(b.start)))
                ListTile(
                  leading: Icon(kindIcon(e.kind), color: kindColor(e.kind)),
                  title: Text(e.artist),
                  subtitle: Text('${formatRange(e)} · ${e.stops.map((x) => x.city).join(', ')}'),
                  onTap: () => Navigator.push(context, EventDetailPage.route(e)),
                  trailing: IconButton(
                    icon: const Icon(Icons.edit_rounded),
                    onPressed: () => Navigator.push(context, ManualEventPage.route(existing: e)),
                  ),
                ),
            ]),
          ),
        const SectionTitle('Automatyczne źródła'),
        Glass(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Column(children: [
            ListTile(
              leading: const Icon(Icons.dataset_rounded),
              title: const Text('Feed Weeb Radar'),
              subtitle: Text('${s.feedUrl}\n${s.sourceStatus['Weeb Radar feed'] ?? 'jeszcze nie pobrano'}'),
              isThreeLine: true,
              trailing: const Icon(Icons.edit_rounded),
              onTap: () async {
                final v = await _ask(context, 'Adres feedu (JSON)', s.feedUrl);
                if (v != null) {
                  s.setFeedUrl(v);
                  s.refresh();
                }
              },
            ),
            SwitchListTile(
              secondary: const Icon(Icons.graphic_eq_rounded),
              title: const Text('VocaDB: eventy vocaloidowe'),
              subtitle: Text(s.sourceStatus['VocaDB'] ?? 'koncerty fanowskie, M3, Vocafest i inne'),
              value: s.useVocaDb,
              onChanged: (v) {
                s.setUseVocaDb(v);
                s.refresh();
              },
            ),
            SwitchListTile(
              secondary: const Icon(Icons.euro_rounded),
              title: const Text('VocaDB tylko z Europy'),
              value: s.vocaDbEuropeOnly,
              onChanged: s.useVocaDb
                  ? (v) {
                      s.setVocaDbEuropeOnly(v);
                      s.refresh();
                    }
                  : null,
            ),
            for (final (i, url) in s.extraFeeds.indexed)
              ListTile(
                leading: const Icon(Icons.rss_feed_rounded),
                title: Text('Dodatkowy feed ${i + 1}'),
                subtitle: Text('$url\n${s.sourceStatus['Dodatkowy feed ${i + 1}'] ?? ''}'),
                isThreeLine: true,
                trailing: IconButton(
                  icon: const Icon(Icons.delete_outline_rounded),
                  onPressed: () => s.setExtraFeeds([...s.extraFeeds]..removeAt(i)),
                ),
              ),
            ListTile(
              leading: const Icon(Icons.add_rounded),
              title: const Text('Dodaj feed JSON'),
              subtitle: const Text('W tym samym formacie co events.json'),
              onTap: () async {
                final v = await _ask(context, 'Adres feedu (JSON)', 'https://');
                if (v != null && v.startsWith('http')) {
                  s.setExtraFeeds([...s.extraFeeds, v]);
                  s.refresh();
                }
              },
            ),
          ]),
        ),
        if (s.hidden.isNotEmpty) ...[
          const SizedBox(height: 12),
          TextButton.icon(
            icon: const Icon(Icons.visibility_rounded),
            label: Text('Przywróć ukryte eventy (${s.hidden.length})'),
            onPressed: s.unhideAll,
          ),
        ],
      ],
    );
  }

  Future<void> _addWatch(BuildContext context) async {
    final s = AppScope.read(context);
    final name = TextEditingController();
    final url = TextEditingController(text: 'https://');
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Nowa strona do podglądania'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: name, decoration: const InputDecoration(labelText: 'Nazwa')),
          TextField(controller: url, decoration: const InputDecoration(labelText: 'Adres')),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Anuluj')),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Dodaj')),
        ],
      ),
    );
    if (ok == true && name.text.trim().isNotEmpty && url.text.startsWith('http')) {
      s.setWatchSources([...s.watchSources, WatchSource(name.text.trim(), url.text.trim(), '')]);
    }
  }

  static Future<String?> _ask(BuildContext context, String title, String initial) {
    final c = TextEditingController(text: initial);
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: TextField(controller: c, autofocus: true),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Anuluj')),
          FilledButton(onPressed: () => Navigator.pop(ctx, c.text.trim()), child: const Text('Zapisz')),
        ],
      ),
    );
  }
}

