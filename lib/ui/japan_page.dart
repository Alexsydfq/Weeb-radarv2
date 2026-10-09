import 'package:flutter/material.dart';

import '../edition.dart';
import '../models/event.dart';
import 'app_scope.dart';
import 'refresh.dart';
import 'util.dart';
import 'widgets/event_card.dart';
import 'widgets/glass.dart';
import 'widgets/unread.dart';

enum _Scope { spotify, forYou, all }

/// Japonia osobno: koncerty, fesy i lajwy VTuberów, na które warto kiedyś polecieć.
/// Nie miesza się z Radarem Europy.
class JapanPage extends StatefulWidget {
  const JapanPage({super.key});

  @override
  State<JapanPage> createState() => _JapanPageState();
}

class _JapanPageState extends State<JapanPage> {
  _Scope _scope = _Scope.forYou;
  bool _onlyNew = false;
  final _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final theme = Theme.of(context);
    final all = s.upcomingJapan;
    final q = _search.text.trim().toLowerCase();
    final list = all.where((e) {
      if (_onlyNew && !s.isUnread(e)) return false;
      if (_scope == _Scope.forYou && !s.isForYou(e)) return false;
      if (_scope == _Scope.spotify && !s.isSpotify(e)) return false;
      if (q.isNotEmpty) {
        final hay = '${e.searchable} ${e.stops.map((x) => '${x.city} ${x.venue}').join(' ')}'.toLowerCase();
        if (!hay.contains(q)) return false;
      }
      return true;
    }).toList();

    // Grupujemy miesiącami, jak w kalendarzu.
    final months = <DateTime, List<RadarEvent>>{};
    for (final e in list) {
      final d = e.nextDate;
      months.putIfAbsent(DateTime(d.year, d.month), () => []).add(e);
    }

    return RefreshIndicator(
      onRefresh: () => refreshAll(context),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4),
            child: Row(
              children: [
                const Text('🇯🇵', style: TextStyle(fontSize: 30)),
                const SizedBox(width: 10),
                Expanded(
                  child: Text('Japonia', style: theme.textTheme.headlineLarge?.copyWith(fontWeight: FontWeight.w900)),
                ),
                RefreshButton(loading: s.loading),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 4, 4, 12),
            child: Text(
              'Lajwy, fesy i koncerty VTuberów oraz vocaloidu w Japonii. Do śledzenia i planowania wyjazdu, '
              'osobno od Europy.',
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
                hintText: 'Szukaj artysty, hali, miasta...',
              ),
            ),
          ),
          const SizedBox(height: 10),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SegmentedButton<_Scope>(
              segments: [
                ButtonSegment(
                  value: _Scope.spotify,
                  label: Text(byEdition('Spotify', 'Moi artyści')),
                  icon: const Icon(Icons.headphones_rounded),
                ),
                const ButtonSegment(value: _Scope.forYou, label: Text('Dla mnie'), icon: Icon(Icons.favorite_rounded)),
                const ButtonSegment(value: _Scope.all, label: Text('Wszystko'), icon: Icon(Icons.public_rounded)),
              ],
              selected: {_scope},
              onSelectionChanged: (v) => setState(() => _scope = v.first),
            ),
          ),
          const SizedBox(height: 10),
          InboxBar(
            count: s.unreadCount(all),
            onlyNew: _onlyNew,
            onOnlyNew: (v) => setState(() => _onlyNew = v),
            onMarkAll: () => setState(() {
              s.markAllRead(all);
              _onlyNew = false;
            }),
          ),
          const SizedBox(height: 4),
          if (list.isEmpty)
            Padding(
              padding: const EdgeInsets.all(28),
              child: Column(
                children: [
                  Text(byEdition('(￣ヘ￣;)', '🗾'), style: const TextStyle(fontSize: 26)),
                  const SizedBox(height: 10),
                  Text(
                    all.isEmpty
                        ? byEdition(
                            'Jeszcze nic z Japonii. Skan dorzuca je dwa razy w tygodniu, więc cierpliwości, baka.',
                            'Jeszcze nic z Japonii. Nowe wydarzenia pojawiają się tu kilka razy w tygodniu.',
                          )
                        : _onlyNew
                        ? 'Nic nowego z tym filtrem.'
                        : 'Nic nie pasuje do filtra. Spróbuj „Wszystko”.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyLarge,
                  ),
                ],
              ),
            ),
          for (final m in months.entries) ...[
            SectionTitle('${_cap(monthTitle.format(m.key))} (${m.value.length})'),
            for (final e in m.value) EventCard(event: e),
          ],
        ],
      ),
    );
  }
}

String _cap(String s) => s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);
