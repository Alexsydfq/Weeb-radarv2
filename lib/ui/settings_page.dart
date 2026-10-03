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
