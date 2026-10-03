import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../data/defaults.dart';
import '../models/event.dart';

final _day = DateFormat('d MMM', 'pl');
final _dayYear = DateFormat('d MMM y', 'pl');
final _weekday = DateFormat('EEEE, d MMMM y', 'pl');
final monthTitle = DateFormat('LLLL y', 'pl');

String formatDay(DateTime d) =>
    d.year == DateTime.now().year ? _day.format(d) : _dayYear.format(d);

String formatLong(DateTime d) => _weekday.format(d);

String formatRange(RadarEvent e) {
  if (e.start == e.end) return formatDay(e.start);
  return '${formatDay(e.start)} – ${formatDay(e.end)}';
}

/// „dziś”, „jutro”, „za 5 dni”, „za 3 tyg.”
String countdown(DateTime d) {
  final days = d.difference(todayDate()).inDays;
  if (days < 0) return 'trwa';
  if (days == 0) return 'dziś!';
  if (days == 1) return 'jutro';
  if (days < 14) return 'za $days dni';
  if (days < 60) return 'za ${(days / 7).round()} tyg.';
  return 'za ${(days / 30).round()} mies.';
}

String countryName(String cc) => countryNames[cc.toUpperCase()] ?? cc;

IconData kindIcon(String kind) => switch (kind) {
      'trasa' => Icons.route_rounded,
      'koncert' => Icons.mic_external_on_rounded,
      'konwent' => Icons.festival_rounded,
      'rave' => Icons.nightlife_rounded,
      'vocaloid' => Icons.graphic_eq_rounded,
      'festiwal' => Icons.celebration_rounded,
      _ => Icons.star_rounded,
    };

Color kindColor(String kind) => switch (kind) {
      'trasa' => const Color(0xFF7C9CFF),
      'koncert' => const Color(0xFFFF7EB6),
      'konwent' => const Color(0xFFFFB86B),
      'rave' => const Color(0xFFB98BFF),
      'vocaloid' => const Color(0xFF39C5BB),
      'festiwal' => const Color(0xFF5BD178),
      _ => const Color(0xFF9E9E9E),
    };

Future<void> openLink(BuildContext context, String url) async {
  final uri = Uri.tryParse(url);
  final ok = uri != null && await launchUrl(uri, mode: LaunchMode.externalApplication);
  if (!ok && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Nie umiem otworzyć: $url')),
    );
  }
}
