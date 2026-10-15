import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../data/app_state.dart';
import '../models/asia_past.dart';
import 'app_scope.dart';
import 'background.dart';
import 'util.dart';
import 'widgets/glass.dart';

final _dayYear = DateFormat('d MMM y', 'pl');

const bilibiliBlue = Color(0xFF00A1D6);

/// Tagi posortowane od najczęstszych (Miku, Teto, VocaP…), z liczbą koncertów.
List<MapEntry<String, int>> asiaTagCounts(List<AsiaPast> list) {
  final counts = <String, int>{};
  for (final e in list) {
    for (final t in e.tags) {
      counts[t] = (counts[t] ?? 0) + 1;
    }
  }
  return counts.entries.toList()..sort(
    (a, b) => b.value != a.value ? b.value.compareTo(a.value) : a.key.toLowerCase().compareTo(b.key.toLowerCase()),
  );
}

/// Filtr historii: wszystkie wybrane tagi naraz + tekst.
List<AsiaPast> filterAsia(List<AsiaPast> list, {Set<String> tags = const {}, String query = ''}) {
  final q = query.trim().toLowerCase();
  return [
    for (final e in list)
      if (tags.every(e.tags.contains) && (q.isEmpty || e.searchable.contains(q))) e,
  ];
}

/// Historia koncertów z Japonii/Azji z gotowymi frazami do szukania nagrań (głównie Bilibili).
/// Tylko w mojej wersji.
class AsiaHistoryPage extends StatefulWidget {
  const AsiaHistoryPage({super.key});

  static Route<void> route() => MaterialPageRoute(builder: (_) => const AsiaHistoryPage());

  @override
  State<AsiaHistoryPage> createState() => _AsiaHistoryPageState();
}

class _AsiaHistoryPageState extends State<AsiaHistoryPage> {
  final _search = TextEditingController();
  final _tags = <String>{};
  bool _allTags = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final s = AppScope.of(context);
      if (s.asiaArchive.isEmpty && !s.asiaLoading) s.loadAsiaArchive();
    });
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final theme = Theme.of(context);
    final all = s.asiaArchive;
    final tags = asiaTagCounts(all);
    final shownTags = _allTags ? tags : tags.take(24).toList();
    final list = filterAsia(all, tags: _tags, query: _search.text);

    final years = <int, List<AsiaPast>>{};
    for (final e in list) {
      years.putIfAbsent(e.start.year, () => []).add(e);
    }

    return AppBackground(
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Historia Azji – nagrania'),
          actions: [
            IconButton(
              tooltip: 'Odśwież',
              icon: s.asiaLoading
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.refresh_rounded),
              onPressed: s.asiaLoading ? null : s.loadAsiaArchive,
            ),
          ],
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 0, 4, 10),
              child: Text(
                'Minione lajwy z Japonii, Korei i Chin. Stuknij frazę, żeby ją skopiować, albo od razu szukaj na Bilibili. '
                'Hmpf, nie musisz dziękować.',
                style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
            ),
            Glass(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              radius: 30,
              child: TextField(
                controller: _search,
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(
                  border: InputBorder.none,
                  prefixIcon: Icon(Icons.search_rounded),
                  hintText: 'Szukaj: マジカルミライ, Teto, 2024…',
                ),
              ),
            ),
            if (tags.isNotEmpty) ...[
              const SizedBox(height: 10),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final t in shownTags) _tagChip(s, t.key, t.value),
                  if (tags.length > 24)
                    ActionChip(
                      label: Text(_allTags ? 'Mniej tagów' : 'Wszystkie tagi (${tags.length})'),
                      onPressed: () => setState(() => _allTags = !_allTags),
                    ),
                  if (_tags.isNotEmpty)
                    ActionChip(
                      avatar: const Icon(Icons.clear_rounded, size: 18),
                      label: const Text('Wyczyść'),
                      onPressed: () => setState(_tags.clear),
                    ),
                ],
              ),
            ],
            const SizedBox(height: 8),
            if (s.asiaError != null && all.isEmpty)
              _empty(theme, '(╯°□°)╯ ${s.asiaError}')
            else if (all.isEmpty)
              _empty(theme, s.asiaLoading ? 'Ładuję historię…' : 'Historia jeszcze pusta. Odśwież za chwilę, baka.')
            else if (list.isEmpty)
              _empty(theme, 'Nic pod tym filtrem.')
            else ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 4, 4, 0),
                child: Text(
                  '${list.length} z ${all.length} koncertów',
                  style: theme.textTheme.labelMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
              ),
              for (final y in years.entries) ...[
                Padding(
                  padding: const EdgeInsets.fromLTRB(4, 16, 4, 8),
                  child: Text('${y.key}', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
                ),
                for (final e in y.value)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: AsiaPastTile(event: e),
                  ),
              ],
            ],
          ],
        ),
      ),
    );
  }

  Widget _tagChip(AppState s, String tag, int count) {
    final mine = s.artistsIn(tag).isNotEmpty;
    return FilterChip(
      label: Text('$tag · $count'),
      selected: _tags.contains(tag),
      side: mine ? const BorderSide(color: spotifyGreen) : null,
      onSelected: (v) => setState(() => v ? _tags.add(tag) : _tags.remove(tag)),
    );
  }

  Widget _empty(ThemeData theme, String text) => Padding(
    padding: const EdgeInsets.all(28),
    child: Text(text, textAlign: TextAlign.center, style: theme.textTheme.bodyMedium),
  );
}

class AsiaPastTile extends StatelessWidget {
  const AsiaPastTile({super.key, required this.event});

  final AsiaPast event;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final e = event;
    final flag = switch (e.region) {
      'KR' => '🇰🇷',
      'CN' => '🇨🇳',
      'TW' => '🇹🇼',
      'HK' => '🇭🇰',
      'SG' => '🇸🇬',
      _ => '🇯🇵',
    };
    final date = e.end.difference(e.start).inDays > 0
        ? '${_dayYear.format(e.start)} – ${_dayYear.format(e.end)}'
        : _dayYear.format(e.start);
    final where = {
      for (final st in e.stops) [st.city, st.venue].where((x) => x.isNotEmpty).join(', '),
    }.where((x) => x.isNotEmpty).toList();
    return Glass(
      padding: EdgeInsets.zero,
      child: Theme(
        data: theme.copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
          childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
          expandedCrossAxisAlignment: CrossAxisAlignment.start,
          leading: Text(flag, style: const TextStyle(fontSize: 22)),
          title: Text(e.title.isNotEmpty ? e.title : e.name, style: const TextStyle(fontWeight: FontWeight.w700)),
          subtitle: Text(
            [if (e.nameOrig.isNotEmpty) e.nameOrig, date].join('\n'),
            style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
          children: [
            if (e.title.isNotEmpty && e.title != e.name) Text(e.name, style: theme.textTheme.bodyMedium),
            for (final w in where.take(6))
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text('📍 $w', style: theme.textTheme.bodySmall),
              ),
            if (where.length > 6) Text('… i ${where.length - 6} więcej', style: theme.textTheme.bodySmall),
            if (e.tags.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [for (final t in e.tags) Pill(t, color: kindColor('vocaloid'))],
              ),
            ],
            const SizedBox(height: 10),
            Text('Frazy do szukania', style: theme.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w800)),
            for (final q in e.search) PhraseRow(phrase: q),
            if (e.url != null)
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  icon: const Icon(Icons.open_in_new_rounded, size: 18),
                  label: const Text('Oficjalna strona'),
                  onPressed: () => openLink(context, e.url!),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Fraza: stuknięcie kopiuje, przyciski szukają na Bilibili / YouTube.
class PhraseRow extends StatelessWidget {
  const PhraseRow({super.key, required this.phrase});

  final String phrase;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: () async {
              await Clipboard.setData(ClipboardData(text: phrase));
              if (!context.mounted) return;
              ScaffoldMessenger.of(context)
                ..hideCurrentSnackBar()
                ..showSnackBar(SnackBar(content: Text('Skopiowane: $phrase'), duration: const Duration(seconds: 2)));
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 2),
              child: Row(
                children: [
                  const Icon(Icons.content_copy_rounded, size: 16),
                  const SizedBox(width: 8),
                  Expanded(child: Text(phrase, maxLines: 2, overflow: TextOverflow.ellipsis)),
                ],
              ),
            ),
          ),
        ),
        IconButton(
          tooltip: 'Szukaj na Bilibili',
          visualDensity: VisualDensity.compact,
          icon: const Icon(Icons.smart_display_rounded, color: bilibiliBlue),
          onPressed: () => openLink(context, bilibiliSearch(phrase)),
        ),
        IconButton(
          tooltip: 'Szukaj na YouTube',
          visualDensity: VisualDensity.compact,
          icon: const Icon(Icons.play_circle_outline_rounded, color: Color(0xFFFF4E45)),
          onPressed: () => openLink(context, youtubeSearch(phrase)),
        ),
      ],
    );
  }
}
