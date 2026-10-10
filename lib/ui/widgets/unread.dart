import 'package:flutter/material.dart';

import '../app_scope.dart';
import 'glass.dart';

/// Kolor „nowości”: ten sam róż co dawna pigułka NOWE.
const unreadColor = Color(0xFFFF5370);

/// Kropka przy nieprzeczytanym evencie albo kawałku, jak w skrzynce mailowej.
class UnreadDot extends StatelessWidget {
  const UnreadDot({super.key, this.size = 10});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: unreadColor,
        boxShadow: [BoxShadow(color: unreadColor.withValues(alpha: 0.6), blurRadius: 6)],
      ),
    );
  }
}

/// „1 nowość”, „5 nowości”.
String unreadLabel(int n) => n == 1 ? '1 nowość' : '$n nowości';

/// Pasek nad listą: ile jest nowych, filtr „tylko nowe” i „oznacz jako przeczytane”.
class InboxBar extends StatelessWidget {
  const InboxBar({
    super.key,
    required this.count,
    required this.onlyNew,
    required this.onOnlyNew,
    required this.onMarkAll,
  });

  final int count;
  final bool onlyNew;
  final ValueChanged<bool> onOnlyNew;
  final VoidCallback onMarkAll;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final s = AppScope.of(context);
    if (count == 0 && !onlyNew) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
        child: Row(
          children: [
            Icon(Icons.mark_email_read_outlined, size: 18, color: theme.colorScheme.onSurfaceVariant),
            const SizedBox(width: 8),
            Text(
              'Wszystko przejrzane',
              style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
          ],
        ),
      );
    }
    return Glass(
      padding: const EdgeInsets.fromLTRB(14, 6, 6, 6),
      highlight: count > 0 ? unreadColor.withValues(alpha: 0.7) : null,
      child: Row(
        children: [
          if (count > 0) ...[const UnreadDot(), const SizedBox(width: 10)],
          Expanded(
            child: Text(
              count > 0 ? unreadLabel(count) : 'Brak nowości',
              style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
            ),
          ),
          FilterChip(
            label: const Text('Tylko nowe'),
            selected: onlyNew,
            onSelected: onOnlyNew,
            visualDensity: VisualDensity.compact,
          ),
          IconButton(
            tooltip: 'Oznacz wszystko jako przejrzane',
            icon: Icon(Icons.done_all_rounded, color: count > 0 ? s.accent : null),
            onPressed: count > 0 ? onMarkAll : null,
          ),
        ],
      ),
    );
  }
}
