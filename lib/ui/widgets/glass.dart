import 'dart:ui';

import 'package:flutter/material.dart';

import '../app_scope.dart';

/// Półprzezroczysta „szklana” karta, przez którą prześwituje tło.
class Glass extends StatelessWidget {
  const Glass({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.radius = 20,
    this.onTap,
    this.highlight,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  final VoidCallback? onTap;

  /// Kolor obramowania, np. dla eventów z Twoimi artystami.
  final Color? highlight;

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final scheme = Theme.of(context).colorScheme;
    final br = BorderRadius.circular(radius);
    return ClipRRect(
      borderRadius: br,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: Material(
          color: scheme.surface.withValues(alpha: s.cardOpacity),
          shape: RoundedRectangleBorder(
            borderRadius: br,
            side: BorderSide(
              color: highlight ?? scheme.onSurface.withValues(alpha: 0.08),
              width: highlight != null ? 2.2 : 1,
            ),
          ),
          child: InkWell(
            onTap: onTap,
            borderRadius: br,
            child: Padding(padding: padding, child: child),
          ),
        ),
      ),
    );
  }
}

/// Mała pigułka z tekstem (rodzaj eventu, kraj, „NOWE”).
class Pill extends StatelessWidget {
  const Pill(this.text, {super.key, this.color, this.icon});

  final String text;
  final Color? color;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final c = color ?? Theme.of(context).colorScheme.primary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: c.withValues(alpha: 0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[Icon(icon, size: 13, color: c), const SizedBox(width: 4)],
          Text(
            text,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: c,
                  fontWeight: FontWeight.w700,
                ),
          ),
        ],
      ),
    );
  }
}

class SectionTitle extends StatelessWidget {
  const SectionTitle(this.text, {super.key, this.trailing});

  final String text;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 18, 4, 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              text,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}
