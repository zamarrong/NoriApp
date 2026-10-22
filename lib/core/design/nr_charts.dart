import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'nr_motion.dart';
import 'nr_tokens.dart';
import 'nr_typography.dart';

/// Anillo de avance (la ruta del día). Se llena al aparecer y entre valores.
class NrRing extends StatelessWidget {
  const NrRing({super.key, required this.value, this.size = 96, this.stroke = 10, this.color, this.secondary, this.secondaryColor, this.child});

  /// 0..1
  final double value;

  /// Segundo tramo apilado detrás del primero (p. ej. omitidas), 0..1.
  final double? secondary;
  final double size;
  final double stroke;
  final Color? color;
  final Color? secondaryColor;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final nr = context.nr;
    final reduce = nrReduceMotion(context);
    return SizedBox.square(
      dimension: size,
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: reduce ? value : 0, end: value.clamp(0, 1)),
        duration: reduce ? Duration.zero : const Duration(milliseconds: 900),
        curve: NrMotion.emphasized,
        builder: (context, v, _) => CustomPaint(
          painter: _RingPainter(
            value: v,
            secondary: secondary == null ? 0 : (secondary! * (value == 0 ? 1 : v / value)).clamp(0, 1),
            track: nr.night ? nr.raised : nr.sunken,
            color: color ?? nr.accent,
            secondaryColor: secondaryColor ?? nr.muted.withValues(alpha: 0.5),
            stroke: stroke,
          ),
          child: Center(child: child),
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter({required this.value, required this.secondary, required this.track, required this.color, required this.secondaryColor, required this.stroke});

  final double value;
  final double secondary;
  final Color track;
  final Color color;
  final Color secondaryColor;
  final double stroke;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final r = rect.deflate(stroke / 2);
    final base = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(r, 0, math.pi * 2, false, base..color = track);
    const start = -math.pi / 2;
    if (secondary > 0) {
      canvas.drawArc(r, start + value * math.pi * 2, secondary * math.pi * 2, false, base..color = secondaryColor);
    }
    if (value > 0) {
      final sweep = value * math.pi * 2;
      base.shader = SweepGradient(
        startAngle: 0,
        endAngle: math.pi * 2,
        transform: const GradientRotation(-math.pi / 2),
        colors: [Color.lerp(color, Colors.white, 0.25)!, color],
        stops: [0, value.clamp(0.01, 1)],
      ).createShader(rect);
      canvas.drawArc(r, start, sweep, false, base);
    }
  }

  @override
  bool shouldRepaint(covariant _RingPainter old) =>
      old.value != value || old.secondary != secondary || old.color != color || old.track != track;
}

/// Línea de tendencia con área degradada; se dibuja de izquierda a derecha.
class NrSparkline extends StatelessWidget {
  const NrSparkline({super.key, required this.values, this.height = 40, this.color, this.fill = true, this.dot = true});

  final List<double> values;
  final double height;
  final Color? color;
  final bool fill;
  final bool dot;

  @override
  Widget build(BuildContext context) {
    if (values.length < 2) return SizedBox(height: height);
    final c = color ?? context.nr.accent;
    final reduce = nrReduceMotion(context);
    return SizedBox(
      height: height,
      width: double.infinity,
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: reduce ? 1 : 0, end: 1),
        duration: reduce ? Duration.zero : const Duration(milliseconds: 900),
        curve: NrMotion.ease,
        builder: (context, t, _) => CustomPaint(painter: _SparkPainter(values, c, t, fill, dot, context.nr.surface)),
      ),
    );
  }
}

class _SparkPainter extends CustomPainter {
  _SparkPainter(this.values, this.color, this.t, this.fill, this.dot, this.surface);

  final List<double> values;
  final Color color;
  final double t;
  final bool fill;
  final bool dot;
  final Color surface;

  @override
  void paint(Canvas canvas, Size size) {
    final lo = values.reduce(math.min);
    final hi = values.reduce(math.max);
    final span = (hi - lo).abs() < 1e-9 ? 1.0 : hi - lo;
    const pad = 4.0;
    final pts = <Offset>[
      for (var i = 0; i < values.length; i++)
        Offset(i / (values.length - 1) * (size.width - pad * 2) + pad, pad + (1 - (values[i] - lo) / span) * (size.height - pad * 2)),
    ];
    final path = Path()..moveTo(pts.first.dx, pts.first.dy);
    for (var i = 1; i < pts.length; i++) {
      final p0 = pts[i - 1];
      final p1 = pts[i];
      final mx = (p0.dx + p1.dx) / 2;
      path.cubicTo(mx, p0.dy, mx, p1.dy, p1.dx, p1.dy);
    }
    canvas.save();
    canvas.clipRect(Rect.fromLTWH(0, 0, size.width * t + 6, size.height));
    if (fill) {
      final area = Path.from(path)
        ..lineTo(pts.last.dx, size.height)
        ..lineTo(pts.first.dx, size.height)
        ..close();
      canvas.drawPath(
        area,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [color.withValues(alpha: 0.22), color.withValues(alpha: 0)],
          ).createShader(Offset.zero & size),
      );
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
    canvas.restore();
    if (dot && t > 0.98) {
      canvas.drawCircle(pts.last, 4.5, Paint()..color = surface);
      canvas.drawCircle(pts.last, 3, Paint()..color = color);
    }
  }

  @override
  bool shouldRepaint(covariant _SparkPainter old) => old.t != t || old.values != values || old.color != color;
}

/// Medidor horizontal (crédito usado contra el límite, venta contra la meta).
/// Pasado el límite la barra se pinta de peligro.
class NrMeter extends StatelessWidget {
  const NrMeter({super.key, required this.value, this.height = 8, this.color, this.danger = false, this.marker});

  /// 0..1 (puede pasar de 1: se pinta lleno).
  final double value;
  final double height;
  final Color? color;
  final bool danger;

  /// Marca vertical en 0..1 (p. ej. dónde debería ir según la hora).
  final double? marker;

  @override
  Widget build(BuildContext context) {
    final nr = context.nr;
    final c = danger || value > 1 ? nr.danger : (color ?? nr.accent);
    final reduce = nrReduceMotion(context);
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: reduce ? value : 0, end: value.clamp(0, 1)),
      duration: reduce ? Duration.zero : const Duration(milliseconds: 800),
      curve: NrMotion.emphasized,
      builder: (context, v, _) => LayoutBuilder(
        builder: (context, box) => Stack(clipBehavior: Clip.none, children: [
          Container(
            height: height,
            decoration: BoxDecoration(color: nr.night ? nr.raised : nr.sunken, borderRadius: BorderRadius.circular(height)),
          ),
          Container(
            height: height,
            width: math.max(v > 0 ? height : 0, box.maxWidth * v),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(height),
              gradient: LinearGradient(colors: [c.withValues(alpha: 0.8), c]),
            ),
          ),
          if (marker != null)
            Positioned(
              left: (box.maxWidth * marker!.clamp(0, 1)) - 1,
              top: -3,
              child: Container(width: 2, height: height + 6, decoration: BoxDecoration(color: nr.headline.withValues(alpha: 0.55), borderRadius: BorderRadius.circular(1))),
            ),
        ]),
      ),
    );
  }
}

/// Un tramo de [NrStackBar].
class NrSegment {
  const NrSegment(this.label, this.value, this.color);
  final String label;
  final double value;
  final Color color;
}

/// Barra apilada con leyenda (antigüedad de saldo).
class NrStackBar extends StatelessWidget {
  const NrStackBar({super.key, required this.segments, this.height = 12, this.format});

  final List<NrSegment> segments;
  final double height;
  final String Function(double)? format;

  @override
  Widget build(BuildContext context) {
    final nr = context.nr;
    final total = segments.fold<double>(0, (s, e) => s + e.value);
    final reduce = nrReduceMotion(context);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      ClipRRect(
        borderRadius: BorderRadius.circular(height),
        child: SizedBox(
          height: height,
          child: total <= 0
              ? ColoredBox(color: nr.sunken)
              : TweenAnimationBuilder<double>(
                  tween: Tween(begin: reduce ? 1 : 0, end: 1),
                  duration: reduce ? Duration.zero : const Duration(milliseconds: 900),
                  curve: NrMotion.emphasized,
                  builder: (context, t, _) => Row(children: [
                    for (final s in segments)
                      if (s.value > 0)
                        Expanded(
                          flex: math.max(1, (s.value / total * 1000 * t).round()),
                          child: Container(color: s.color, margin: const EdgeInsets.only(right: 2)),
                        ),
                    Expanded(flex: math.max(0, ((1 - t) * 1000).round()), child: ColoredBox(color: nr.sunken)),
                  ]),
                ),
        ),
      ),
      const SizedBox(height: NrSpace.md),
      for (final s in segments)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 5),
          child: Row(children: [
            Container(width: 8, height: 8, decoration: BoxDecoration(color: s.color, borderRadius: BorderRadius.circular(2))),
            const SizedBox(width: NrSpace.sm),
            Expanded(child: Text(s.label, style: NrText.label(context))),
            if (total > 0) Text('${(s.value / total * 100).round()} %', style: NrText.caption(context)),
            const SizedBox(width: NrSpace.md),
            SizedBox(
              width: 104,
              child: Text(format?.call(s.value) ?? s.value.toStringAsFixed(0),
                  textAlign: TextAlign.right, style: NrText.money(context, size: 14).copyWith(color: s.value > 0 ? null : nr.muted)),
            ),
          ]),
        ),
    ]);
  }
}
