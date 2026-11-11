import 'dart:math' as math;

import 'package:flutter/material.dart';

/// A one-shot fall of paper, drawn rather than imported.
///
/// Hand-rolled because nothing else in this app reaches outside the phone and
/// a hundred lines of painter is a poor reason to start. It also means the
/// colours can come from the theme instead of clashing with it.
///
/// Paints nothing at all when the platform asks for reduced motion: a
/// celebration that ignores that setting is just an animation someone cannot
/// turn off.
class ConfettiBurst extends StatefulWidget {
  const ConfettiBurst({
    super.key,
    this.pieces = 70,
    this.duration = const Duration(milliseconds: 2800),
  });

  /// How much paper. Scaled by the caller to match the size of the occasion.
  final int pieces;
  final Duration duration;

  @override
  State<ConfettiBurst> createState() => _ConfettiBurstState();
}

class _ConfettiBurstState extends State<ConfettiBurst>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: widget.duration,
  );

  late final List<_Piece> _paper = _make(widget.pieces);

  @override
  void initState() {
    super.initState();
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  static List<_Piece> _make(int count) {
    final rng = math.Random();
    return [
      for (var i = 0; i < count; i++)
        _Piece(
          // Spread across the width, starting just above the top edge so the
          // first frame is empty rather than a row of paper sitting there.
          startX: rng.nextDouble(),
          startY: -0.15 - rng.nextDouble() * 0.5,
          driftX: (rng.nextDouble() - 0.5) * 0.34,
          fallSpeed: 0.16 + rng.nextDouble() * 0.28,
          width: 7 + rng.nextDouble() * 6,
          height: 11 + rng.nextDouble() * 8,
          spin: (rng.nextDouble() * 5 + 2) * (rng.nextBool() ? 1 : -1),
          phase: rng.nextDouble() * math.pi * 2,
          tint: rng.nextInt(5),
        ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.of(context).disableAnimations) {
      return const SizedBox.shrink();
    }

    final scheme = Theme.of(context).colorScheme;
    final palette = <Color>[
      scheme.primary,
      scheme.tertiary,
      scheme.secondary,
      scheme.primaryContainer,
      scheme.onPrimaryContainer,
    ];

    return IgnorePointer(
      child: RepaintBoundary(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) => CustomPaint(
            painter: _ConfettiPainter(
              paper: _paper,
              palette: palette,
              seconds:
                  _controller.value * widget.duration.inMilliseconds / 1000.0,
              progress: _controller.value,
            ),
            size: Size.infinite,
          ),
        ),
      ),
    );
  }
}

class _Piece {
  const _Piece({
    required this.startX,
    required this.startY,
    required this.driftX,
    required this.fallSpeed,
    required this.width,
    required this.height,
    required this.spin,
    required this.phase,
    required this.tint,
  });

  /// Fractions of the box: 0 is the left edge, 1 the right.
  final double startX;
  final double startY;

  /// Per second, also in fractions of the box.
  final double driftX;
  final double fallSpeed;

  final double width;
  final double height;

  /// Radians per second, either direction.
  final double spin;

  /// Where in its tumble the piece starts, so they do not flash in unison.
  final double phase;

  final int tint;
}

class _ConfettiPainter extends CustomPainter {
  _ConfettiPainter({
    required this.paper,
    required this.palette,
    required this.seconds,
    required this.progress,
  });

  final List<_Piece> paper;
  final List<Color> palette;
  final double seconds;
  final double progress;

  /// Fractions of the box per second squared. Tuned so the slowest pieces are
  /// only just off the bottom as the animation ends.
  static const _gravity = 0.26;

  /// Paper thins out towards the end instead of vanishing mid-air.
  static const _fadeFrom = 0.75;

  @override
  void paint(Canvas canvas, Size size) {
    final fade = progress <= _fadeFrom
        ? 1.0
        : 1.0 - (progress - _fadeFrom) / (1 - _fadeFrom);

    for (final piece in paper) {
      final y =
          piece.startY +
          piece.fallSpeed * seconds +
          0.5 * _gravity * seconds * seconds;
      if (y > 1.2) continue;

      final x = piece.startX + piece.driftX * seconds;
      final tumble = piece.phase + piece.spin * seconds;

      canvas.save();
      canvas.translate(x * size.width, y * size.height);
      canvas.rotate(tumble);
      // Squashing the width as it turns reads as a flat piece of paper
      // catching the light, without drawing anything in three dimensions.
      canvas.scale(math.cos(tumble).abs().clamp(0.25, 1.0), 1);
      canvas.drawRect(
        Rect.fromCenter(
          center: Offset.zero,
          width: piece.width,
          height: piece.height,
        ),
        Paint()
          ..color = palette[piece.tint % palette.length].withValues(
            alpha: 0.9 * fade,
          ),
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_ConfettiPainter old) =>
      old.seconds != seconds || old.palette != palette;
}
