import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'nr_motion.dart';
import 'nr_tokens.dart';

/// Ilustración de estado (vacío, sin señal, error) hecha con capas: un halo
/// del acento, dos hojas inclinadas detrás y una ficha al frente con el
/// ícono. Flota despacio; quieta si se pidió reducir movimiento.
class NrIllustration extends StatefulWidget {
  const NrIllustration({super.key, required this.icon, this.color, this.size = 1});

  final IconData icon;

  /// Tono de la ficha (por omisión el acento).
  final Color? color;
  final double size;

  @override
  State<NrIllustration> createState() => _NrIllustrationState();
}

class _NrIllustrationState extends State<NrIllustration> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 3600));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (nrReduceMotion(context)) {
      _c.stop();
    } else if (!_c.isAnimating) {
      _c.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final nr = context.nr;
    final c = widget.color ?? nr.accent;
    final s = widget.size;
    Widget sheet(double angle, Offset at, Color fill) => Positioned(
          left: at.dx * s,
          top: at.dy * s,
          child: Transform.rotate(
            angle: angle,
            child: Container(
              width: 62 * s,
              height: 76 * s,
              decoration: BoxDecoration(
                color: fill,
                borderRadius: BorderRadius.circular(14 * s),
                border: nr.night || nr.highContrast ? Border.all(color: nr.border) : null,
                boxShadow: nr.shadow,
              ),
              child: Padding(
                padding: EdgeInsets.all(10 * s),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  for (final w in [0.8, 0.55, 0.7])
                    Container(
                      margin: EdgeInsets.only(bottom: 7 * s),
                      height: 5 * s,
                      width: 42 * s * w,
                      decoration: BoxDecoration(color: nr.sunken, borderRadius: BorderRadius.circular(3)),
                    ),
                ]),
              ),
            ),
          ),
        );
    return SizedBox(
      width: 168 * s,
      height: 128 * s,
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, _) {
          final t = Curves.easeInOut.transform(_c.value);
          return Stack(clipBehavior: Clip.none, children: [
            Positioned(
              left: 30 * s,
              top: 6 * s,
              child: Container(
                width: 112 * s,
                height: 112 * s,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(colors: [c.withValues(alpha: nr.night ? 0.22 : 0.16), c.withValues(alpha: 0)]),
                ),
              ),
            ),
            sheet(-0.16, Offset(26, 26 + t * 2), nr.surface),
            sheet(0.12, Offset(82, 22 - t * 2), nr.surface),
            Positioned(
              left: 52 * s,
              top: (30 - t * 5) * s,
              child: Container(
                width: 64 * s,
                height: 64 * s,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(18 * s),
                  gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color.lerp(c, Colors.white, 0.18)!, c]),
                  boxShadow: [BoxShadow(color: c.withValues(alpha: 0.35), offset: Offset(0, 10 * s), blurRadius: 22 * s, spreadRadius: -6 * s)],
                ),
                child: Icon(widget.icon, color: Colors.white, size: 30 * s),
              ),
            ),
            for (final (i, p) in const [(0, Offset(18, 18)), (1, Offset(146, 30)), (2, Offset(138, 104)), (3, Offset(28, 100))].indexed)
              Positioned(
                left: p.$2.dx * s,
                top: (p.$2.dy + math.sin((t + i * 0.25) * math.pi) * 3) * s,
                child: Container(
                  width: (i.isEven ? 7 : 5) * s,
                  height: (i.isEven ? 7 : 5) * s,
                  decoration: BoxDecoration(shape: BoxShape.circle, color: c.withValues(alpha: i.isEven ? 0.45 : 0.25)),
                ),
              ),
          ]);
        },
      ),
    );
  }
}

/// Palomita que se dibuja (confirmación de venta o cobro).
class NrSuccessMark extends StatelessWidget {
  const NrSuccessMark({super.key, this.size = 88, this.color});

  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final c = color ?? context.nr.success;
    final reduce = nrReduceMotion(context);
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: reduce ? 1 : 0, end: 1),
      duration: reduce ? Duration.zero : const Duration(milliseconds: 900),
      builder: (context, t, _) {
        final pop = Curves.elasticOut.transform((t * 1.6).clamp(0, 1));
        final draw = Curves.easeOutCubic.transform(((t - 0.3) / 0.7).clamp(0, 1));
        return SizedBox.square(
          dimension: size * 1.5,
          child: Stack(alignment: Alignment.center, children: [
            Container(
              width: size * 1.5 * (0.6 + 0.4 * draw),
              height: size * 1.5 * (0.6 + 0.4 * draw),
              decoration: BoxDecoration(shape: BoxShape.circle, color: c.withValues(alpha: 0.12 * draw)),
            ),
            Transform.scale(
              scale: 0.4 + 0.6 * pop,
              child: Container(
                width: size,
                height: size,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: c,
                  boxShadow: [BoxShadow(color: c.withValues(alpha: 0.4), blurRadius: 24, offset: const Offset(0, 10), spreadRadius: -6)],
                ),
                child: CustomPaint(painter: _CheckPainter(draw, Colors.white)),
              ),
            ),
          ]),
        );
      },
    );
  }
}

class _CheckPainter extends CustomPainter {
  _CheckPainter(this.t, this.color);
  final double t;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final path = Path()
      ..moveTo(w * 0.29, w * 0.52)
      ..lineTo(w * 0.44, w * 0.66)
      ..lineTo(w * 0.72, w * 0.37);
    final metric = path.computeMetrics().first;
    canvas.drawPath(
      metric.extractPath(0, metric.length * t),
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = w * 0.085
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(covariant _CheckPainter old) => old.t != t;
}
