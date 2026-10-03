import 'dart:io';

import 'package:flutter/material.dart';

import '../data/app_state.dart';
import '../data/defaults.dart';
import 'app_scope.dart';
import 'theme.dart';
import 'util.dart';
import 'widgets/glass.dart';

/// Wygląd: własne tło (też GIF), rozmycie, przyciemnienie, kolory, motyw.
class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final theme = Theme.of(context);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4),
          child: Text('Wygląd',
              style: theme.textTheme.headlineLarge?.copyWith(fontWeight: FontWeight.w900)),
        ),
        const SectionTitle('Tło'),
        Glass(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: AspectRatio(
                  aspectRatio: 16 / 7,
                  child: s.backgroundPath == null
                      ? Container(
                          color: s.accent.withValues(alpha: 0.15),
                          alignment: Alignment.center,
                          child: const Text('Animowany gradient (brak własnego tła)'),
                        )
                      : Image.file(File(s.backgroundPath!), fit: BoxFit.cover, gaplessPlayback: true),
                ),
              ),
              const SizedBox(height: 12),
              Text('PNG, JPG, GIF (animowany!), WebP i BMP. Plik kopiuję do folderu aplikacji.',
                  style: theme.textTheme.bodySmall),
              const SizedBox(height: 10),
              Wrap(spacing: 10, runSpacing: 10, children: [
                FilledButton.icon(
                  icon: const Icon(Icons.wallpaper_rounded),
                  label: const Text('Wybierz tło'),
                  onPressed: () async {
                    try {
                      final err = await s.pickBackground();
                      if (err != null && context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err)));
                      }
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context)
                            .showSnackBar(SnackBar(content: Text('Nie udało się wczytać pliku: $e')));
                      }
                    }
                  },
                ),
                if (s.backgroundPath != null)
                  OutlinedButton.icon(
                    icon: const Icon(Icons.delete_outline_rounded),
                    label: const Text('Usuń tło'),
                    onPressed: s.clearBackground,
                  ),
              ]),
              const SizedBox(height: 16),
              Text('Dopasowanie', style: theme.textTheme.labelLarge),
              const SizedBox(height: 6),
              SegmentedButton<BackgroundFit>(
                segments: const [
                  ButtonSegment(value: BackgroundFit.cover, label: Text('Wypełnij'), icon: Icon(Icons.crop_rounded)),
                  ButtonSegment(value: BackgroundFit.contain, label: Text('Zmieść'), icon: Icon(Icons.fit_screen_rounded)),
                  ButtonSegment(value: BackgroundFit.tile, label: Text('Kafelki'), icon: Icon(Icons.grid_view_rounded)),
                ],
                selected: {s.backgroundFit},
                onSelectionChanged: (v) => s.setBackgroundFit(v.first),
              ),
              _Slider(
                label: 'Rozmycie',
                value: s.backgroundBlur,
                max: 20,
                display: s.backgroundBlur.toStringAsFixed(0),
                onChanged: s.setBackgroundBlur,
              ),
              _Slider(
                label: 'Przyciemnienie',
                value: s.backgroundDim,
                max: 0.9,
                display: '${(s.backgroundDim * 100).round()}%',
                onChanged: s.setBackgroundDim,
              ),
              _Slider(
                label: 'Przezroczystość kart',
                value: 1 - s.cardOpacity,
                max: 0.9,
                display: '${((1 - s.cardOpacity) * 100).round()}%',
                onChanged: (v) => s.setCardOpacity(1 - v),
              ),
            ],
          ),
        ),
        const SectionTitle('Kolor akcentu'),
        Glass(
          child: Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              for (final p in accentPresets.entries)
                Tooltip(
                  message: p.key,
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: () => s.setAccent(p.value),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: p.value,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: s.accent.toARGB32() == p.value.toARGB32()
                              ? theme.colorScheme.onSurface
                              : Colors.transparent,
                          width: 3,
                        ),
                        boxShadow: [BoxShadow(color: p.value.withValues(alpha: 0.5), blurRadius: 10)],
                      ),
                      child: s.accent.toARGB32() == p.value.toARGB32()
                          ? const Icon(Icons.check_rounded, color: Colors.white)
                          : null,
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SectionTitle('Motyw i region'),
        Glass(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SegmentedButton<ThemeMode>(
                segments: const [
                  ButtonSegment(value: ThemeMode.dark, label: Text('Ciemny'), icon: Icon(Icons.dark_mode_rounded)),
                  ButtonSegment(value: ThemeMode.light, label: Text('Jasny'), icon: Icon(Icons.light_mode_rounded)),
                  ButtonSegment(value: ThemeMode.system, label: Text('System'), icon: Icon(Icons.settings_suggest_rounded)),
                ],
                selected: {s.themeMode},
                onSelectionChanged: (v) => s.setThemeMode(v.first),
              ),
              const SizedBox(height: 8),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Text(flagOf(s.homeCountry), style: const TextStyle(fontSize: 26)),
                title: const Text('Mój region'),
                subtitle: const Text('Eventy w tym regionie dostają bonus i oznaczenie „u Ciebie”'),
                trailing: DropdownButton<String>(
                  value: s.homeCountry,
                  underline: const SizedBox(),
                  items: [
                    for (final c in countryNames.keys.where((k) => k != 'GB'))
                      DropdownMenuItem(value: c, child: Text(countryName(c))),
                  ],
                  onChanged: (v) => v == null ? null : s.setHomeCountry(v),
                ),
              ),
            ],
          ),
        ),
        const SectionTitle('Synchronizacja telefon ↔ komputer'),
        const _SyncCard(),
        const SizedBox(height: 18),
        Center(
          child: Text(
            'Weeb Radar · zrobione z (｀・ω・´) dla Awexa',
            style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
        ),
      ],
    );
  }
}

/// Ustawienia synchronizacji planów przez prywatny GitHub Gist.
class _SyncCard extends StatefulWidget {
  const _SyncCard();

  @override
  State<_SyncCard> createState() => _SyncCardState();
}

class _SyncCardState extends State<_SyncCard> {
  final _token = TextEditingController();
  bool _obscure = true;

  @override
  void dispose() {
    _token.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final theme = Theme.of(context);
    final small = theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant);

    return Glass(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Twoje „Idę / Może / Zainteresowany / Nie idę”, gwiazdki i ukryte eventy lądują w prywatnym Giście na Twoim '
            'koncie GitHub. Ten sam token wklejasz na telefonie i na komputerze, i tyle.',
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: 10),
          if (!s.syncEnabled) ...[
            Text(
              'Token: github.com → Settings → Developer settings → Personal access tokens → '
              'Fine-grained tokens → Generate. Uprawnienie: Account permissions → Gists → Read and write. '
              '(Klasyczny token też działa, wtedy zaznacz tylko „gist”.)',
              style: small,
            ),
            const SizedBox(height: 6),
            TextButton.icon(
              icon: const Icon(Icons.open_in_new_rounded, size: 18),
              label: const Text('Otwórz stronę tokenów'),
              onPressed: () => openLink(context, 'https://github.com/settings/personal-access-tokens/new'),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: _token,
              obscureText: _obscure,
              autocorrect: false,
              enableSuggestions: false,
              decoration: InputDecoration(
                labelText: 'Token GitHub',
                hintText: 'github_pat_… albo ghp_…',
                prefixIcon: const Icon(Icons.key_rounded),
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  icon: Icon(_obscure ? Icons.visibility_rounded : Icons.visibility_off_rounded),
                  onPressed: () => setState(() => _obscure = !_obscure),
                ),
              ),
              onSubmitted: (v) => s.setSyncToken(v),
            ),
            const SizedBox(height: 10),
            FilledButton.icon(
              icon: const Icon(Icons.cloud_sync_rounded),
              label: const Text('Włącz synchronizację'),
              onPressed: () {
                s.setSyncToken(_token.text);
                _token.clear();
              },
            ),
          ] else ...[
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: s.syncing
                  ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2.5))
                  : Icon(s.syncError == null ? Icons.cloud_done_rounded : Icons.cloud_off_rounded,
                      color: s.syncError == null ? s.accent : theme.colorScheme.error),
              title: Text(s.syncError ?? (s.syncing ? 'Synchronizuję…' : 'Synchronizacja włączona')),
              subtitle: Text(
                [
                  if (s.lastSync != null) 'Ostatnio: ${formatDay(s.lastSync!)} ${TimeOfDay.fromDateTime(s.lastSync!).format(context)}',
                  if (s.syncGistId != null) 'Gist: ${s.syncGistId}',
                  '${s.entries.values.where((e) => !e.isEmpty).length} eventów z decyzją',
                ].join(' · '),
              ),
            ),
            Wrap(spacing: 10, runSpacing: 10, children: [
              FilledButton.icon(
                icon: const Icon(Icons.sync_rounded),
                label: const Text('Synchronizuj teraz'),
                onPressed: s.syncing ? null : s.syncNow,
              ),
              OutlinedButton.icon(
                icon: const Icon(Icons.link_off_rounded),
                label: const Text('Wyłącz'),
                onPressed: () => s.setSyncToken(null),
              ),
            ]),
          ],
          const Divider(height: 28),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            secondary: const Icon(Icons.cancel_outlined),
            title: const Text('Chowaj „Nie idę” z zakładki „Dla mnie”'),
            subtitle: Text('Wyłączone: zostają, ale przygaszone i niżej', style: small),
            value: s.hideNotGoing,
            onChanged: s.setHideNotGoing,
          ),
        ],
      ),
    );
  }
}

class _Slider extends StatelessWidget {
  const _Slider({
    required this.label,
    required this.value,
    required this.max,
    required this.display,
    required this.onChanged,
  });

  final String label;
  final double value, max;
  final String display;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(width: 150, child: Text(label)),
        Expanded(child: Slider(value: value.clamp(0, max), max: max, onChanged: onChanged)),
        SizedBox(width: 44, child: Text(display, textAlign: TextAlign.end)),
      ],
    );
  }
}
