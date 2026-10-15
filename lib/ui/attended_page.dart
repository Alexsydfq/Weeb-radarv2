import 'package:flutter/material.dart';

import '../data/app_state.dart';
import '../data/defaults.dart';
import '../edition.dart';
import '../models/attended.dart';
import '../models/event.dart';
import 'app_scope.dart';
import 'background.dart';
import 'util.dart';
import 'widgets/glass.dart';

/// Grupa w „Byłem”: festiwale i konwenty osobno, reszta (koncerty, trasy,
/// symfoniczne, rave'y) jako koncerty.
String attendedGroup(String kind) => kind == 'festiwal' || kind == 'konwent' ? kind : 'koncert';

const attendedGroups = {'koncert': 'Koncerty', 'festiwal': 'Festiwale', 'konwent': 'Konwenty'};

/// Filtr grup: „Wszystko” + koncerty / festiwale / konwenty z licznikami.
class _GroupChips extends StatelessWidget {
  const _GroupChips({required this.counts, required this.selected, required this.onChanged});

  final Map<String, int> counts;
  final String? selected;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    final total = counts.values.fold(0, (a, b) => a + b);
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        ChoiceChip(label: Text('Wszystko ($total)'), selected: selected == null, onSelected: (_) => onChanged(null)),
        for (final g in attendedGroups.entries)
          ChoiceChip(
            avatar: Icon(kindIcon(g.key), size: 18, color: kindColor(g.key)),
            label: Text('${g.value} (${counts[g.key] ?? 0})'),
            selected: selected == g.key,
            onSelected: (_) => onChanged(selected == g.key ? null : g.key),
          ),
      ],
    );
  }
}

/// Linijka „ze Spotify: …” dla festiwalu/konwentu: Twoi artyści z line-upu,
/// najwyżej w Twoim topie najpierw (null, gdy nikogo).
String? spotifyInLineup(AppState s, List<String> lineup) {
  final mine = [
    for (final n in lineup)
      if (s.artistsIn(n).isNotEmpty) (name: n, rank: s.rankOfEntry(n)),
  ]..sort((a, b) => (a.rank ?? 9999).compareTo(b.rank ?? 9999));
  if (mine.isEmpty) return null;
  final names = mine.take(6).map((m) => m.name).join(', ');
  return '🎧 ${mine.length} ${byEdition('z Twojego Spotify', 'z Twojej listy')}: $names${mine.length > 6 ? '…' : ''}';
}

/// Historia „Byłem”: koncerty, festiwale i konwenty, na których już byłeś, pogrupowane po latach.
class AttendedHistory extends StatefulWidget {
  const AttendedHistory({super.key});

  @override
  State<AttendedHistory> createState() => _AttendedHistoryState();
}

class _AttendedHistoryState extends State<AttendedHistory> {
  String? _group;

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final theme = Theme.of(context);
    final everything = s.attended;
    final counts = <String, int>{};
    for (final a in everything) {
      counts[attendedGroup(a.kind)] = (counts[attendedGroup(a.kind)] ?? 0) + 1;
    }
    final list = _group == null ? everything : everything.where((a) => attendedGroup(a.kind) == _group).toList();
    final thisYear = list.where((a) => a.date.year == todayDate().year).length;
    final byArtist = <String, int>{};
    for (final a in list) {
      byArtist[a.artist] = (byArtist[a.artist] ?? 0) + 1;
    }
    final top = byArtist.entries.where((e) => e.value > 1).toList()..sort((a, b) => b.value.compareTo(a.value));
    final countries = list.map((a) => a.cc).where((c) => c.isNotEmpty).toSet();

    final years = <int, List<Attended>>{};
    for (final a in list) {
      (years[a.date.year] ??= []).add(a);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Glass(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                list.isEmpty && everything.isNotEmpty
                    ? 'Tu jeszcze nic.'
                    : list.isEmpty
                    ? byEdition('Jeszcze nic. Gdzieś przecież byłeś, baka!', 'Jeszcze nic nie zapisano.')
                    : '${byEdition('Byłeś na', 'Zaliczone:')} ${list.length} ${_plural(list.length, _group)}'
                          '${thisYear > 0 ? ', w tym roku: $thisYear' : ''}'
                          '${countries.length > 1 ? ' · ${countries.length} krajów' : ''}',
                style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
              ),
              if (top.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  'Najczęściej: ${top.take(3).map((e) => '${e.key} ×${e.value}').join(', ')}',
                  style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
              ],
              const SizedBox(height: 8),
              Text(
                'Wybierz koncert z listy minionych (archiwum od 2023, z wyszukiwarką), odhacz „${byEdition('Byłem', 'Byłem/am')}” w szczegółach eventu albo dopisz ręcznie.',
                style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  FilledButton.tonalIcon(
                    onPressed: () => Navigator.push(context, PastEventPicker.route()),
                    icon: const Icon(Icons.search_rounded),
                    label: const Text('Wybierz z listy koncertów'),
                  ),
                  FilledButton.tonalIcon(
                    onPressed: () => Navigator.push(context, PastEventPicker.route(group: 'festiwal')),
                    icon: Icon(kindIcon('festiwal')),
                    label: const Text('Wybierz festiwal'),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => Navigator.push(context, AttendedEditPage.route()),
                    icon: const Icon(Icons.edit_rounded),
                    label: const Text('Dopisz ręcznie'),
                  ),
                ],
              ),
              if (everything.isNotEmpty) ...[
                const SizedBox(height: 12),
                _GroupChips(counts: counts, selected: _group, onChanged: (g) => setState(() => _group = g)),
              ],
            ],
          ),
        ),
        for (final y in years.keys.toList()..sort((a, b) => b.compareTo(a))) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 16, 4, 8),
            child: Text('$y (${years[y]!.length})', style: theme.textTheme.titleMedium),
          ),
          for (final a in years[y]!) AttendedTile(entry: a),
        ],
      ],
    );
  }

  static String _plural(int n, String? group) => switch (group) {
    'festiwal' => byEdition(n == 1 ? 'festiwalu' : 'festiwalach', n == 1 ? 'festiwal' : 'festiwale/i'),
    'konwent' => byEdition(n == 1 ? 'konwencie' : 'konwentach', n == 1 ? 'konwent' : 'konwenty/ów'),
    _ => byEdition(n == 1 ? 'koncercie' : 'koncertach', n == 1 ? 'koncert' : 'koncerty/ów'),
  };
}

class AttendedTile extends StatelessWidget {
  const AttendedTile({super.key, required this.entry});

  final Attended entry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final a = entry;
    final place = [
      if (a.cc.isNotEmpty) flagOf(a.cc),
      if (a.city.isNotEmpty) a.city,
      if (a.venue.isNotEmpty) '· ${a.venue}',
    ].join(' ');
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Glass(
        padding: EdgeInsets.zero,
        child: ListTile(
          leading: CircleAvatar(
            backgroundColor: kindColor(a.kind).withValues(alpha: 0.25),
            child: Icon(kindIcon(a.kind), color: kindColor(a.kind)),
          ),
          title: Text(a.artist, style: const TextStyle(fontWeight: FontWeight.w800)),
          subtitle: Text(
            [
              formatLong(a.date),
              if (place.isNotEmpty) place,
              if (a.title.isNotEmpty && a.title != a.artist) a.title,
              if (a.seen.isNotEmpty)
                '${byEdition('Widziałeś', 'Widziane')}: ${a.seen.take(5).join(', ')}'
                    '${a.seen.length > 5 ? ' (+${a.seen.length - 5})' : ''}',
              if (a.note.isNotEmpty) '„${a.note}”',
            ].join('\n'),
          ),
          isThreeLine: true,
          trailing: a.rating > 0
              ? Text('★' * a.rating, style: theme.textTheme.titleSmall?.copyWith(color: const Color(0xFFFFD23F)))
              : null,
          onTap: () => Navigator.push(context, AttendedEditPage.route(existing: a)),
        ),
      ),
    );
  }
}

/// Formularz wpisu „Byłem”: nowy koncert spoza apki albo poprawka (ocena, notatka).
class AttendedEditPage extends StatefulWidget {
  const AttendedEditPage({super.key, this.existing});

  final Attended? existing;

  static Route<void> route({Attended? existing}) =>
      MaterialPageRoute(builder: (_) => AttendedEditPage(existing: existing));

  @override
  State<AttendedEditPage> createState() => _AttendedEditPageState();
}

class _AttendedEditPageState extends State<AttendedEditPage> {
  final _form = GlobalKey<FormState>();
  late final _artist = TextEditingController(text: widget.existing?.artist ?? '');
  late final _title = TextEditingController(text: widget.existing?.title ?? '');
  late final _city = TextEditingController(text: widget.existing?.city ?? '');
  late final _venue = TextEditingController(text: widget.existing?.venue ?? '');
  late final _note = TextEditingController(text: widget.existing?.note ?? '');
  late String _kind = widget.existing?.kind ?? 'koncert';
  late String _cc = widget.existing?.cc ?? 'PL';
  late DateTime _date = widget.existing?.date ?? todayDate().subtract(const Duration(days: 1));
  late int _rating = widget.existing?.rating ?? 0;
  late final List<String> _lineup = widget.existing?.lineup ?? const [];
  late final Set<String> _seen = {...?widget.existing?.seen};
  final _addSeen = TextEditingController();
  final _lineupFilter = TextEditingController();
  bool _allLineup = false;

  @override
  void dispose() {
    for (final c in [_artist, _title, _city, _venue, _note, _addSeen, _lineupFilter]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _pickDate() async {
    final d = await showDatePicker(
      context: context,
      firstDate: DateTime(1990),
      lastDate: todayDate().add(const Duration(days: 1)),
      initialDate: _date,
    );
    if (d != null) setState(() => _date = DateTime(d.year, d.month, d.day));
  }

  void _save() {
    if (!_form.currentState!.validate()) return;
    final old = widget.existing;
    final a = Attended(
      id: old?.id ?? 'own-${DateTime.now().millisecondsSinceEpoch}',
      artist: _artist.text.trim(),
      title: _title.text.trim(),
      date: _date,
      city: _city.text.trim(),
      cc: _cc,
      venue: _venue.text.trim(),
      kind: _kind,
      note: _note.text.trim(),
      rating: _rating,
      eventId: old?.eventId,
      lineup: _lineup,
      seen: [..._lineup.where(_seen.contains), ..._seen.where((n) => !_lineup.contains(n))],
      at: old?.at ?? 0,
    );
    AppScope.read(context).saveAttended(a);
    Navigator.pop(context);
  }

  Future<void> _delete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Usunąć z historii?'),
        content: Text(widget.existing!.artist),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Anuluj')),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Usuń')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    AppScope.read(context).removeAttended(widget.existing!.id);
    Navigator.pop(context);
  }

  void _addManualSeen() {
    final n = _addSeen.text.trim();
    if (n.isEmpty) return;
    setState(() {
      _seen.add(n);
      _addSeen.clear();
    });
  }

  /// „Kogo widziałeś”: line-up do odhaczenia (Twoi ze Spotify na górze) + dopisywanie ręczne.
  Widget _seenSection(BuildContext context) {
    final s = AppScope.of(context);
    final theme = Theme.of(context);
    const collapsed = 40;
    final q = _lineupFilter.text.trim().toLowerCase();
    final entries =
        [
          for (final (i, name) in _lineup.indexed)
            (name: name, mine: s.artistsIn(name).isNotEmpty, rank: s.rankOfEntry(name), order: i),
        ]..sort((a, b) {
          if (a.mine != b.mine) return a.mine ? -1 : 1;
          if (a.mine) return (a.rank ?? 9999).compareTo(b.rank ?? 9999);
          return a.order.compareTo(b.order);
        });
    final filtered = q.isEmpty ? entries : entries.where((e) => e.name.toLowerCase().contains(q)).toList();
    final shown = _allLineup || q.isNotEmpty ? filtered : filtered.take(collapsed).toList();
    final mine = entries.where((e) => e.mine).length;
    final manual = _seen.where((n) => !_lineup.contains(n)).toList();
    return Glass(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${byEdition('Kogo widziałeś', 'Kogo widziane')} (${_seen.length})',
            style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          Text(
            _lineup.isEmpty
                ? 'Brak line-upu w archiwum. Dopisz artystów ręcznie.'
                : mine > 0
                ? '${byEdition('Na zielono ci z Twojego Spotify', 'Na zielono ci z Twojej listy artystów')} ($mine). Kliknij, kogo ${byEdition('widziałeś', 'widziano')}.'
                : 'Kliknij, kogo ${byEdition('widziałeś', 'widziano')}.',
            style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
          if (_lineup.length > collapsed) ...[
            const SizedBox(height: 8),
            TextField(
              controller: _lineupFilter,
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search_rounded),
                hintText: 'Szukaj w line-upie',
                isDense: true,
                border: OutlineInputBorder(),
              ),
              onChanged: (_) => setState(() {}),
            ),
          ],
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final e in shown)
                FilterChip(
                  avatar: e.mine && !_seen.contains(e.name)
                      ? const Icon(Icons.headphones_rounded, size: 16, color: spotifyGreen)
                      : null,
                  label: Text(e.rank != null ? '${e.name}  #${e.rank}' : e.name),
                  labelStyle: e.mine ? const TextStyle(color: spotifyGreen, fontWeight: FontWeight.w700) : null,
                  side: e.mine ? const BorderSide(color: spotifyGreen) : null,
                  selected: _seen.contains(e.name),
                  selectedColor: attendedColor.withValues(alpha: 0.3),
                  onSelected: (on) => setState(() => on ? _seen.add(e.name) : _seen.remove(e.name)),
                ),
              for (final n in manual)
                InputChip(
                  label: Text(n),
                  selected: true,
                  selectedColor: attendedColor.withValues(alpha: 0.3),
                  onDeleted: () => setState(() => _seen.remove(n)),
                ),
            ],
          ),
          if (filtered.length > collapsed && q.isEmpty)
            TextButton(
              onPressed: () => setState(() => _allLineup = !_allLineup),
              child: Text(_allLineup ? 'Zwiń' : 'Pokaż cały line-up (${entries.length})'),
            ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _addSeen,
                  decoration: const InputDecoration(
                    hintText: 'Dopisz artystę spoza listy',
                    isDense: true,
                    border: OutlineInputBorder(),
                  ),
                  onSubmitted: (_) => _addManualSeen(),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filledTonal(tooltip: 'Dodaj', onPressed: _addManualSeen, icon: const Icon(Icons.add_rounded)),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    InputDecoration deco(String label, IconData icon) =>
        InputDecoration(labelText: label, prefixIcon: Icon(icon), border: const OutlineInputBorder());
    return AppBackground(
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.existing == null ? byEdition('Byłem na…', 'Nowy wpis') : 'Edytuj wpis'),
          actions: [
            if (widget.existing != null)
              IconButton(
                tooltip: 'Usuń z historii',
                icon: const Icon(Icons.delete_outline_rounded),
                onPressed: _delete,
              ),
          ],
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: _save,
          icon: const Icon(Icons.check_rounded),
          label: const Text('Zapisz'),
        ),
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: Form(
              key: _form,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 96),
                children: [
                  Glass(
                    child: Column(
                      children: [
                        TextFormField(
                          controller: _artist,
                          decoration: deco('Artysta / nazwa koncertu', Icons.mic_rounded),
                          validator: (v) => (v == null || v.trim().isEmpty)
                              ? byEdition('Wpisz chociaż nazwę, baka', 'Wpisz nazwę')
                              : null,
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _title,
                          decoration: deco('Trasa / podtytuł (opcjonalnie)', Icons.title_rounded),
                        ),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<String>(
                          initialValue: kindLabels.containsKey(_kind) ? _kind : 'inne',
                          decoration: deco('Rodzaj', Icons.category_rounded),
                          items: [
                            for (final k in kindLabels.entries) DropdownMenuItem(value: k.key, child: Text(k.value)),
                          ],
                          onChanged: (v) => setState(() => _kind = v ?? _kind),
                        ),
                        const SizedBox(height: 12),
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(Icons.event_rounded),
                          title: Text(formatLong(_date)),
                          subtitle: const Text('Kliknij, żeby zmienić datę'),
                          onTap: _pickDate,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Glass(
                    child: Column(
                      children: [
                        DropdownButtonFormField<String>(
                          initialValue: countryNames.containsKey(_cc) ? _cc : 'PL',
                          decoration: deco('Kraj', Icons.flag_rounded),
                          items: [
                            for (final c in countryNames.keys.where((k) => k != 'GB' && k != 'EU'))
                              DropdownMenuItem(value: c, child: Text('${flagOf(c)}  ${countryName(c)}')),
                          ],
                          onChanged: (v) => setState(() => _cc = v ?? _cc),
                        ),
                        const SizedBox(height: 12),
                        TextFormField(controller: _city, decoration: deco('Miasto', Icons.location_city_rounded)),
                        const SizedBox(height: 12),
                        TextFormField(controller: _venue, decoration: deco('Klub / hala', Icons.place_rounded)),
                      ],
                    ),
                  ),
                  if (_lineup.isNotEmpty || _seen.isNotEmpty || _kind == 'festiwal' || _kind == 'konwent') ...[
                    const SizedBox(height: 12),
                    _seenSection(context),
                  ],
                  const SizedBox(height: 12),
                  Glass(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Ocena'),
                        Row(
                          children: [
                            for (var i = 1; i <= 5; i++)
                              IconButton(
                                tooltip: '$i/5',
                                icon: Icon(
                                  i <= _rating ? Icons.star_rounded : Icons.star_border_rounded,
                                  color: const Color(0xFFFFD23F),
                                ),
                                // Kliknięcie w aktualną ocenę ją zdejmuje.
                                onPressed: () => setState(() => _rating = _rating == i ? 0 : i),
                              ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _note,
                          minLines: 2,
                          maxLines: 6,
                          decoration: deco('Wrażenia, setlista, z kim…', Icons.notes_rounded),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Wybór „Byłem” z listy minionych eventów (feed + archiwum), z wyszukiwarką.
class PastEventPicker extends StatefulWidget {
  const PastEventPicker({super.key, this.group});

  /// Startowy filtr: 'festiwal', 'konwent', 'koncert' albo null (wszystko).
  final String? group;

  static Route<void> route({String? group}) => MaterialPageRoute(builder: (_) => PastEventPicker(group: group));

  @override
  State<PastEventPicker> createState() => _PastEventPickerState();
}

class _PastEventPickerState extends State<PastEventPicker> {
  String _q = '';
  late String? _group = widget.group;

  @override
  void initState() {
    super.initState();
    final s = AppScope.read(context);
    if (s.archive.isEmpty) s.loadArchive();
  }

  static String _fold(String s) => s
      .toLowerCase()
      .replaceAll(RegExp('[ąà]'), 'a')
      .replaceAll(RegExp('[ćç]'), 'c')
      .replaceAll(RegExp('[ęéè]'), 'e')
      .replaceAll('ł', 'l')
      .replaceAll('ń', 'n')
      .replaceAll('ó', 'o')
      .replaceAll('ś', 's')
      .replaceAll(RegExp('[źż]'), 'z');

  bool _matches(RadarEvent e) {
    if (_q.isEmpty) return true;
    final hay = _fold(
      '${e.artist} ${e.title} ${e.lineup.join(' ')} ${e.stops.map((s) => '${s.city} ${s.venue} ${countryName(s.cc)}').join(' ')} ${e.start.year}',
    );
    return _fold(_q).split(RegExp(r'\s+')).where((w) => w.isNotEmpty).every(hay.contains);
  }

  Future<void> _pick(RadarEvent e) async {
    final s = AppScope.read(context);
    final today = todayDate();
    final stops = e.stops.where((x) => !x.date.isAfter(today)).toList();
    var chosen = e;
    if (stops.length > 1) {
      final st = await showModalBottomSheet<EventStop>(
        context: context,
        showDragHandle: true,
        builder: (c) => SafeArea(
          child: ListView(
            shrinkWrap: true,
            children: [
              const Padding(padding: EdgeInsets.fromLTRB(16, 0, 16, 8), child: Text('Na którym koncercie trasy?')),
              for (final x in stops.reversed)
                ListTile(
                  leading: Text(flagOf(x.cc), style: const TextStyle(fontSize: 22)),
                  title: Text(x.city.isEmpty ? countryName(x.cc) : x.city),
                  subtitle: Text([formatLong(x.date), if (x.venue.isNotEmpty) x.venue].join(' · ')),
                  onTap: () => Navigator.pop(c, x),
                ),
            ],
          ),
        ),
      );
      if (st == null) return;
      chosen = e.withChosen(st);
    }
    if (!s.wasAt(e.id)) s.toggleAttended(chosen);
    if (!mounted) return;
    final saved = s.attendedAll['ev-${e.id}'];
    if (e.lineup.isNotEmpty && saved != null) {
      // Festiwal/konwent: od razu do odhaczania, kogo widziałeś.
      Navigator.pushReplacement(context, AttendedEditPage.route(existing: saved));
      return;
    }
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Zapisane w historii: ${e.artist}')));
  }

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final theme = Theme.of(context);
    final matching = s.pastEvents.where(_matches).toList();
    final counts = <String, int>{};
    for (final e in matching) {
      counts[attendedGroup(e.kind)] = (counts[attendedGroup(e.kind)] ?? 0) + 1;
    }
    final list = _group == null ? matching : matching.where((e) => attendedGroup(e.kind) == _group).toList();
    return AppBackground(
      child: Scaffold(
        appBar: AppBar(title: Text(byEdition('Na czym byłem?', 'Wybierz koncert'))),
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  child: TextField(
                    autofocus: true,
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.search_rounded),
                      hintText: 'Artysta, miasto, rok… np. „nier warszawa”',
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (v) => setState(() => _q = v.trim()),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: _GroupChips(counts: counts, selected: _group, onChanged: (g) => setState(() => _group = g)),
                  ),
                ),
                if (s.archiveLoading) const LinearProgressIndicator(),
                if (s.archiveError != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text(s.archiveError!, style: TextStyle(color: theme.colorScheme.error)),
                  ),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                    children: [
                      if (list.isEmpty && !s.archiveLoading)
                        Padding(
                          padding: const EdgeInsets.all(24),
                          child: Text(
                            'Nic nie pasuje. Nie ma go w archiwum? Dopisz go ręcznie.',
                            textAlign: TextAlign.center,
                            style: theme.textTheme.bodyLarge,
                          ),
                        ),
                      for (final e in list.take(200))
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Glass(
                            padding: EdgeInsets.zero,
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: kindColor(e.kind).withValues(alpha: 0.25),
                                child: Icon(kindIcon(e.kind), color: kindColor(e.kind)),
                              ),
                              title: Text(e.artist, style: const TextStyle(fontWeight: FontWeight.w800)),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    [
                                      formatRange(e),
                                      e.stops.map((x) => '${flagOf(x.cc)} ${x.city}').toSet().take(4).join(', '),
                                      if (e.title.isNotEmpty && e.title != e.artist) e.title,
                                    ].where((x) => x.trim().isNotEmpty).join('\n'),
                                  ),
                                  if (spotifyInLineup(s, e.lineup) case final mine?)
                                    Text(
                                      mine,
                                      style: const TextStyle(color: spotifyGreen, fontWeight: FontWeight.w700),
                                    ),
                                ],
                              ),
                              trailing: s.wasAt(e.id) ? const Icon(Icons.verified_rounded, color: attendedColor) : null,
                              onTap: s.wasAt(e.id) ? null : () => _pick(e),
                            ),
                          ),
                        ),
                      const SizedBox(height: 8),
                      OutlinedButton.icon(
                        onPressed: () => Navigator.pushReplacement(context, AttendedEditPage.route()),
                        icon: const Icon(Icons.edit_rounded),
                        label: const Text('Nie ma na liście? Dopisz ręcznie'),
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
