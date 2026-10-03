import 'package:flutter/material.dart';

import 'artists_page.dart';
import 'background.dart';
import 'calendar_page.dart';
import 'favorites_page.dart';
import 'japan_page.dart';
import 'music_page.dart';
import 'radar_page.dart';
import 'settings_page.dart';
import 'sources_page.dart';

class _Dest {
  final String label;
  final IconData icon, selected;
  final Widget page;
  const _Dest(this.label, this.icon, this.selected, this.page);
}

/// Główny szkielet: dolny pasek na telefonie, boczny na Windowsie i tabletach.
class Shell extends StatefulWidget {
  const Shell({super.key});

  @override
  State<Shell> createState() => _ShellState();
}

class _ShellState extends State<Shell> {
  int _index = 0;

  static const _dests = [
    _Dest('Radar', Icons.radar_outlined, Icons.radar, RadarPage()),
    _Dest('Muzyka', Icons.library_music_outlined, Icons.library_music, MusicPage()),
    _Dest('Japonia', Icons.temple_buddhist_outlined, Icons.temple_buddhist, JapanPage()),
    _Dest('Plany', Icons.event_available_outlined, Icons.event_available_rounded, FavoritesPage()),
    _Dest('Kalendarz', Icons.calendar_month_outlined, Icons.calendar_month, CalendarPage()),
    _Dest('Artyści', Icons.headphones_outlined, Icons.headphones, ArtistsPage()),
    _Dest('Źródła', Icons.travel_explore_outlined, Icons.travel_explore, SourcesPage()),
    _Dest('Wygląd', Icons.palette_outlined, Icons.palette, SettingsPage()),
  ];

  /// Na telefonie mieści się tyle zakładek; reszta jest pod „Więcej”.
  static const _bar = 4;

  void _more(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (c) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = _bar; i < _dests.length; i++)
              ListTile(
                leading: Icon(i == _index ? _dests[i].selected : _dests[i].icon),
                title: Text(_dests[i].label),
                selected: i == _index,
                onTap: () {
                  Navigator.pop(c);
                  setState(() => _index = i);
                },
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 760;
    final body = AnimatedSwitcher(
      duration: const Duration(milliseconds: 260),
      switchInCurve: Curves.easeOutCubic,
      transitionBuilder: (child, a) => FadeTransition(
        opacity: a,
        child: ScaleTransition(scale: Tween(begin: 0.985, end: 1.0).animate(a), child: child),
      ),
      child: KeyedSubtree(key: ValueKey(_index), child: _dests[_index].page),
    );

    return AppBackground(
      child: Scaffold(
        body: wide
            ? Row(
                children: [
                  NavigationRail(
                    selectedIndex: _index,
                    onDestinationSelected: (i) => setState(() => _index = i),
                    labelType: NavigationRailLabelType.all,
                    leading: Padding(padding: const EdgeInsets.symmetric(vertical: 18), child: _Logo()),
                    destinations: [
                      for (final d in _dests)
                        NavigationRailDestination(
                          icon: Icon(d.icon),
                          selectedIcon: Icon(d.selected),
                          label: Text(d.label),
                        ),
                    ],
                  ),
                  Expanded(child: SafeArea(left: false, child: body)),
                ],
              )
            : SafeArea(bottom: false, child: body),
        bottomNavigationBar: wide
            ? null
            : NavigationBar(
                selectedIndex: _index < _bar ? _index : _bar,
                onDestinationSelected: (i) => i < _bar ? setState(() => _index = i) : _more(context),
                labelBehavior: NavigationDestinationLabelBehavior.onlyShowSelected,
                destinations: [
                  for (final d in _dests.take(_bar))
                    NavigationDestination(icon: Icon(d.icon), selectedIcon: Icon(d.selected), label: d.label),
                  NavigationDestination(
                    icon: const Icon(Icons.more_horiz_rounded),
                    selectedIcon: const Icon(Icons.more_horiz_rounded),
                    label: _index < _bar ? 'Więcej' : _dests[_index].label,
                  ),
                ],
              ),
      ),
    );
  }
}

class _Logo extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme.primary;
    return Column(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: SweepGradient(colors: [c, c.withValues(alpha: 0.2), c]),
            boxShadow: [BoxShadow(color: c.withValues(alpha: 0.5), blurRadius: 16)],
          ),
          child: const Icon(Icons.radar, color: Colors.white),
        ),
        const SizedBox(height: 6),
        Text(
          'Weeb\nRadar',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(fontWeight: FontWeight.w900),
        ),
      ],
    );
  }
}
