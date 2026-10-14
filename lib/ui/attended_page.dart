import 'package:flutter/material.dart';

import '../data/defaults.dart';
import '../edition.dart';
import '../models/attended.dart';
import '../models/event.dart';
import 'app_scope.dart';
import 'background.dart';
import 'util.dart';
import 'widgets/glass.dart';

/// Historia „Byłem”: koncerty, na których już byłeś, pogrupowane po latach.
class AttendedHistory extends StatelessWidget {
  const AttendedHistory({super.key});

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final theme = Theme.of(context);
    final list = s.attended;
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
                list.isEmpty
                    ? byEdition('Jeszcze nic. Gdzieś przecież byłeś, baka!', 'Jeszcze nic nie zapisano.')
                    : '${byEdition('Byłeś na', 'Zaliczone:')} ${list.length} ${_plural(list.length)}'
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
                  OutlinedButton.icon(
                    onPressed: () => Navigator.push(context, AttendedEditPage.route()),
                    icon: const Icon(Icons.edit_rounded),
                    label: const Text('Dopisz ręcznie'),
                  ),
                ],
              ),
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

  static String _plural(int n) => byEdition(n == 1 ? 'koncercie' : 'koncertach', n == 1 ? 'koncert' : 'koncerty/ów');
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

  @override
  void dispose() {
    for (final c in [_artist, _title, _city, _venue, _note]) {
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
  const PastEventPicker({super.key});

  static Route<void> route() => MaterialPageRoute(builder: (_) => const PastEventPicker());

  @override
  State<PastEventPicker> createState() => _PastEventPickerState();
}

class _PastEventPickerState extends State<PastEventPicker> {
  String _q = '';

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
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Zapisane w historii: ${e.artist}')));
  }

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final theme = Theme.of(context);
    final list = s.pastEvents.where(_matches).toList();
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
                              subtitle: Text(
                                [
                                  formatRange(e),
                                  e.stops.map((x) => '${flagOf(x.cc)} ${x.city}').toSet().take(4).join(', '),
                                  if (e.title.isNotEmpty && e.title != e.artist) e.title,
                                ].where((x) => x.trim().isNotEmpty).join('\n'),
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
