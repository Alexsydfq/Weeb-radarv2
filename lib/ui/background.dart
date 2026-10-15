import 'dart:io';
import 'dart:ui';

import 'package:flutter/material.dart';

import '../data/app_state.dart';
import '../edition.dart';
import 'app_scope.dart';

/// Tło całej aplikacji: Twój obrazek albo GIF, z rozmyciem i przyciemnieniem.
/// Bez własnego tła rysuje animowany gradient w kolorze akcentu.
class AppBackground extends StatelessWidget {
  const AppBackground({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final dark = Theme.of(context).brightness == Brightness.dark;
    final path = s.backgroundPath;

    Widget layer;
    if (path != null) {
      final file = File(path);
      layer = s.backgroundFit == BackgroundFit.tile
          ? DecoratedBox(
              decoration: BoxDecoration(
                image: DecorationImage(
                  image: FileImage(file),
                  repeat: ImageRepeat.repeat,
                  scale: 1.5,
                ),
              ),
            )
          : Image.file(
              file,
              key: ValueKey(path),
              fit: s.backgroundFit == BackgroundFit.contain ? BoxFit.contain : BoxFit.cover,
              width: double.infinity,
              height: double.infinity,
              gaplessPlayback: true,
              filterQuality: FilterQuality.medium,
              errorBuilder: (_, _, _) => _GradientBackground(accent: s.accent, dark: dark),
            );
    } else {
      layer = _GradientBackground(accent: s.accent, dark: dark);
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        ColoredBox(color: dark ? const Color(0xFF0B0B14) : const Color(0xFFF4F2FA)),
        if (s.backgroundBlur > 0 && path != null)
          ImageFiltered(
            imageFilter: ImageFilter.blur(sigmaX: s.backgroundBlur, sigmaY: s.backgroundBlur),
            child: layer,
          )
        else
          layer,
        if (path != null)
          ColoredBox(
            color: (dark ? Colors.black : Colors.white).withValues(alpha: s.backgroundDim),
          ),
        child,
      ],
    );
  }
}

class _GradientBackground extends StatefulWidget {
  const _GradientBackground({required this.accent, required this.dark});

  final Color accent;
  final bool dark;

  @override
  State<_GradientBackground> createState() => _GradientBackgroundState();
}

class _GradientBackgroundState extends State<_GradientBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(seconds: 18))..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hsl = HSLColor.fromColor(widget.accent);
    final second = hsl.withHue((hsl.hue + 70) % 360).toColor();
    final third = hsl.withHue((hsl.hue + 200) % 360).toColor();
    final base = widget.dark ? const Color(0xFF0B0B14) : const Color(0xFFF4F2FA);
    // U znajomych spokojniej: słabsze kolory.
    final a = (widget.dark ? 0.55 : 0.35) * (friendsEdition ? 0.5 : 1);
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        final t = Curves.easeInOut.transform(_c.value);
        return DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment(-1 + t, -1),
              end: Alignment(1, 1 - t),
              colors: [
                Color.lerp(base, widget.accent, a)!,
                base,
                Color.lerp(base, second, a * 0.8)!,
                Color.lerp(base, third, a * 0.6)!,
              ],
              stops: const [0, 0.4, 0.75, 1],
            ),
          ),
          child: const SizedBox.expand(),
        );
      },
    );
  }
}
