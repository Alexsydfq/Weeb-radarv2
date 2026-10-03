import 'dart:io';

import 'package:flutter/foundation.dart';

import 'package:flutter/material.dart';

import '../background/background.dart';
import '../background/notifications.dart';
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
          child: Text('Wygląd', style: theme.textTheme.headlineLarge?.copyWith(fontWeight: FontWeight.w900)),
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
              Text(
                'PNG, JPG, GIF (animowany!), WebP i BMP. Plik kopiuję do folderu aplikacji.',
                style: theme.textTheme.bodySmall,
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
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
                ],
              ),
              const SizedBox(height: 16),
              Text('Dopasowanie', style: theme.textTheme.labelLarge),
              const SizedBox(height: 6),
              SegmentedButton<BackgroundFit>(
                segments: const [
                  ButtonSegment(value: BackgroundFit.cover, label: Text('Wypełnij'), icon: Icon(Icons.crop_rounded)),
                  ButtonSegment(
                    value: BackgroundFit.contain,
                    label: Text('Zmieść'),
                    icon: Icon(Icons.fit_screen_rounded),
                  ),
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
                  ButtonSegment(
                    value: ThemeMode.system,
                    label: Text('System'),
                    icon: Icon(Icons.settings_suggest_rounded),
                  ),
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
        const SectionTitle('Powiadomienia'),
        const _NotifyCard(),
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

/// Powiadomienia o nowych eventach sprawdzanych w tle.
class _NotifyCard extends StatefulWidget {
  const _NotifyCard();

  @override
  State<_NotifyCard> createState() => _NotifyCardState();
}

class _NotifyCardState extends State<_NotifyCard> {
  bool _checking = false;

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final theme = Theme.of(context);
    final small = theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant);
    final windows = !kIsWeb && Platform.isWindows;
    final checks = s.backgroundChecks is BackgroundChecks ? s.backgroundChecks as BackgroundChecks : null;

    return Glass(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            secondary: const Icon(Icons.notifications_active_rounded),
            title: const Text('Powiadamiaj o nowościach'),
            subtitle: Text(
              windows ? 'Sprawdzam w tle, dopóki apka działa (też schowana w zasobniku obok zegara).' : 'Sprawdzam w tle, nawet gdy apka jest zamknięta. Android może to trochę przesunąć, żeby oszczędzać baterię.',
              style: small,
            ),
            value: s.notifyEnabled,
            onChanged: (v) => s.setNotify(enabled: v),
          ),
          if (s.notifyEnabled) ...[
            const SizedBox(height: 4),
            Text('O czym', style: theme.textTheme.labelLarge),
            const SizedBox(height: 6),
            SegmentedButton<bool>(
              segments: const [
                ButtonSegment(value: true, label: Text('Tylko Spotify'), icon: Icon(Icons.headphones_rounded)),
                ButtonSegment(value: false, label: Text('Cały „Dla mnie”'), icon: Icon(Icons.favorite_rounded)),
              ],
              selected: {s.notifySpotifyOnly},
              onSelectionChanged: (v) => s.setNotify(spotifyOnly: v.first),
            ),
            const SizedBox(height: 6),
            Text(
              'Plus zmiany (line-up, bilety, odwołania) w eventach z planem, gwiazdką albo Twoim artystą.',
              style: small,
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              secondary: const Text('🇯🇵', style: TextStyle(fontSize: 22)),
              title: const Text('Też Japonia'),
              subtitle: Text('Nowości z zakładki Japonia, według tych samych zasad.', style: small),
              value: s.notifyJapan,
              onChanged: (v) => s.setNotify(japan: v),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              secondary: const Icon(Icons.library_music_rounded),
              title: const Text('Nowa muzyka'),
              subtitle: Text('Ciche powiadomienie o nowych kawałkach Twoich artystów i propozycjach.', style: small),
              value: s.notifyMusic,
              onChanged: (v) => s.setNotify(music: v),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.schedule_rounded),
              title: const Text('Sprawdzaj co'),
              trailing: DropdownButton<int>(
                value: const [1, 3, 6, 12, 24].contains(s.notifyHours) ? s.notifyHours : 24,
                underline: const SizedBox(),
                items: [
                  for (final h in const [1, 3, 6, 12, 24])
                    DropdownMenuItem(
                      value: h,
                      child: Text(
                        h == 1
                            ? 'godzinę'
                            : h == 24
                            ? 'dzień'
                            : '$h godz.',
                      ),
                    ),
                ],
                onChanged: (v) => v == null ? null : s.setNotify(hours: v),
              ),
            ),
          ],
          if (s.notifyEnabled && !kIsWeb && Platform.isAndroid)
            FutureBuilder<bool>(
              future: Notifier.batteryUnrestricted(),
              builder: (context, snap) => snap.data != false
                  ? const SizedBox()
                  : ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.battery_alert_rounded, color: Color(0xFFFFB347)),
                      title: const Text('Oszczędzanie baterii może ubijać sprawdzanie'),
                      subtitle: Text('Zezwól apce działać w tle, żeby codzienny skan dochodził.', style: small),
                      trailing: TextButton(
                        onPressed: () async {
                          await Notifier.requestBatteryUnrestricted();
                          if (mounted) setState(() {});
                        },
                        child: const Text('Zezwól'),
                      ),
                    ),
            ),
          if (windows) ...[
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              secondary: const Icon(Icons.minimize_rounded),
              title: const Text('Zamykanie chowa do zasobnika'),
              subtitle: Text('Krzyżyk chowa okno obok zegara. Zakończysz z menu ikonki.', style: small),
              value: s.trayOnClose,
              onChanged: (v) => s.setNotify(tray: v),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              secondary: const Icon(Icons.power_settings_new_rounded),
              title: const Text('Uruchamiaj z Windowsem'),
              subtitle: Text('Startuje schowana w zasobniku i od razu sprawdza nowości.', style: small),
              value: s.autostart,
              onChanged: (v) => s.setNotify(startup: v),
            ),
          ],
          if (checks != null)
            Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton.icon(
                icon: _checking
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.radar_rounded),
                label: const Text('Sprawdź nowości teraz'),
                onPressed: _checking || !s.notifyEnabled
                    ? null
                    : () async {
                        setState(() => _checking = true);
                        final n = await checks.checkNow();
                        if (!context.mounted) return;
                        setState(() => _checking = false);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              n == 0 ? 'Nic nowego. Hmph, nie moja wina.' : 'Nowości: $n, patrz powiadomienie!',
                            ),
                          ),
                        );
                      },
              ),
            ),
        ],
      ),
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
            'koncie GitHub. Ten sam token wklejasz na telefonie i na komputerze, i tyle. '
            'Ten token pozwala też czytać feed eventów z prywatnego repo.',
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: 10),
          if (!s.syncEnabled) ...[
            Text(
              'Token: github.com → Settings → Developer settings → Personal access tokens → '
              'Fine-grained tokens → Generate. Uprawnienie: Account permissions → Gists → Read and write. '
              'Jeśli repo z feedem (weeb-radar) jest prywatne: Repository access → Only select repositories → '
              'weeb-radar, i Repository permissions → Contents → Read-only. '
              '(Klasyczny token też działa: zaznacz „gist”, a dla prywatnego feedu też „repo”.)',
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
                  : Icon(
                      s.syncError == null ? Icons.cloud_done_rounded : Icons.cloud_off_rounded,
                      color: s.syncError == null ? s.accent : theme.colorScheme.error,
                    ),
              title: Text(s.syncError ?? (s.syncing ? 'Synchronizuję…' : 'Synchronizacja włączona')),
              subtitle: Text(
                [
                  if (s.lastSync != null)
                    'Ostatnio: ${formatDay(s.lastSync!)} ${TimeOfDay.fromDateTime(s.lastSync!).format(context)}',
                  if (s.syncGistId != null) 'Gist: ${s.syncGistId}',
                  '${s.entries.values.where((e) => !e.isEmpty).length} eventów z decyzją',
                ].join(' · '),
              ),
            ),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
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
              ],
            ),
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
        Expanded(
          child: Slider(value: value.clamp(0, max), max: max, onChanged: onChanged),
        ),
        SizedBox(width: 44, child: Text(display, textAlign: TextAlign.end)),
      ],
    );
  }
}
