import 'package:flutter/material.dart';

import '../data/defaults.dart';
import '../edition.dart';
import '../models/event.dart';
import 'app_scope.dart';
import 'background.dart';
import 'util.dart';
import 'widgets/glass.dart';

/// Formularz własnego eventu, np. Vocafestu wypatrzonego na ich stronie.
class ManualEventPage extends StatefulWidget {
  const ManualEventPage({super.key, this.existing});

  final RadarEvent? existing;

  static Route<void> route({RadarEvent? existing}) =>
      MaterialPageRoute(builder: (_) => ManualEventPage(existing: existing));

  @override
  State<ManualEventPage> createState() => _ManualEventPageState();
}

class _ManualEventPageState extends State<ManualEventPage> {
  final _form = GlobalKey<FormState>();
  late final _artist = TextEditingController(text: widget.existing?.artist ?? '');
  late final _title = TextEditingController(text: widget.existing?.title ?? '');
  late final _city = TextEditingController(text: widget.existing?.stops.firstOrNull?.city ?? '');
  late final _venue = TextEditingController(text: widget.existing?.stops.firstOrNull?.venue ?? '');
  late final _url = TextEditingController(text: widget.existing?.url ?? '');
  late final _tickets = TextEditingController(text: widget.existing?.tickets ?? '');
  late final _note = TextEditingController(text: widget.existing?.note ?? '');
  late String _kind = widget.existing?.kind ?? 'vocaloid';
  late String _cc = widget.existing?.stops.firstOrNull?.cc ?? 'UK';
  late DateTime _start = widget.existing?.start ?? todayDate().add(const Duration(days: 30));
  late DateTime _end = widget.existing?.end ?? _start;

  @override
  void dispose() {
    for (final c in [_artist, _title, _city, _venue, _url, _tickets, _note]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _pickDates() async {
    final r = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
      initialDateRange: DateTimeRange(start: _start, end: _end),
    );
    if (r != null) {
      setState(() {
        _start = DateTime(r.start.year, r.start.month, r.start.day);
        _end = DateTime(r.end.year, r.end.month, r.end.day);
      });
    }
  }

  void _save() {
    if (!_form.currentState!.validate()) return;
    final e = RadarEvent(
      id: widget.existing?.id ?? 'manual-${DateTime.now().millisecondsSinceEpoch}',
      artist: _artist.text.trim(),
      title: _title.text.trim(),
      kind: _kind,
      tier: 3,
      start: _start,
      end: _end,
      note: _note.text.trim(),
      stops: [EventStop(cc: _cc, city: _city.text.trim(), date: _start, venue: _venue.text.trim())],
      url: _url.text.trim().isEmpty ? null : _url.text.trim(),
      tickets: _tickets.text.trim().isEmpty ? null : _tickets.text.trim(),
      foundAt: widget.existing?.foundAt ?? todayDate(),
      origin: EventOrigin.manual,
    );
    AppScope.read(context).saveManualEvent(e);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    InputDecoration deco(String label, IconData icon) =>
        InputDecoration(labelText: label, prefixIcon: Icon(icon), border: const OutlineInputBorder());
    return AppBackground(
      child: Scaffold(
        appBar: AppBar(title: Text(widget.existing == null ? 'Nowy event' : 'Edytuj event')),
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
                    child: Column(children: [
                      TextFormField(
                        controller: _artist,
                        decoration: deco('Artysta / nazwa eventu', Icons.mic_rounded),
                        validator: (v) => (v == null || v.trim().isEmpty) ? byEdition('Wpisz chociaż nazwę, baka', 'Wpisz nazwę') : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(controller: _title, decoration: deco('Podtytuł (opcjonalnie)', Icons.title_rounded)),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        initialValue: _kind,
                        decoration: deco('Rodzaj', Icons.category_rounded),
                        items: [
                          for (final k in kindLabels.entries)
                            DropdownMenuItem(value: k.key, child: Text(k.value)),
                        ],
                        onChanged: (v) => setState(() => _kind = v ?? _kind),
                      ),
                      const SizedBox(height: 12),
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.date_range_rounded),
                        title: Text(_start == _end ? formatLong(_start) : '${formatDay(_start)} – ${formatDay(_end)}'),
                        subtitle: const Text('Kliknij, żeby zmienić daty'),
                        onTap: _pickDates,
                      ),
                    ]),
                  ),
                  const SizedBox(height: 12),
                  Glass(
                    child: Column(children: [
                      DropdownButtonFormField<String>(
                        initialValue: countryNames.containsKey(_cc) ? _cc : 'UK',
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
                      TextFormField(controller: _venue, decoration: deco('Klub / miejsce', Icons.place_rounded)),
                    ]),
                  ),
                  const SizedBox(height: 12),
                  Glass(
                    child: Column(children: [
                      TextFormField(controller: _url, decoration: deco('Link do strony', Icons.link_rounded)),
                      const SizedBox(height: 12),
                      TextFormField(controller: _tickets, decoration: deco('Link do biletów', Icons.confirmation_number_rounded)),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _note,
                        minLines: 2,
                        maxLines: 6,
                        decoration: deco('Notatka', Icons.notes_rounded),
                      ),
                    ]),
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
