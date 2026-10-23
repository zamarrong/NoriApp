import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/design/design.dart';

/// Onboarding scenes, one per top feature. Flat vector art in solid colors
/// (no gradients, no transparency) taken from the theme, with one accent.
/// Each scene tells its idea in a short loop; only the visible page plays,
/// and with "reduce motion" it stays on its final frame.
enum OnboardingScene { sell, collect, invoice, day }

class OnboardingArt extends StatefulWidget {
  const OnboardingArt(this.scene, {super.key, this.playing = true});

  final OnboardingScene scene;
  final bool playing;

  /// The art is drawn on a 300 × 225 board and scaled to fit.
  static const aspectRatio = 300 / 225;

  @override
  State<OnboardingArt> createState() => _OnboardingArtState();
}

class _OnboardingArtState extends State<OnboardingArt> with SingleTickerProviderStateMixin {
  late final AnimationController _loop = AnimationController(vsync: this, duration: const Duration(milliseconds: 4200));

  /// Frame shown when motion is reduced: everything in place, the idea complete.
  static const _still = 0.88;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didUpdateWidget(OnboardingArt old) {
    super.didUpdateWidget(old);
    if (old.playing != widget.playing) _sync();
  }

  void _sync() {
    if (nrReduceMotion(context)) {
      _loop
        ..stop()
        ..value = _still;
    } else if (widget.playing) {
      if (!_loop.isAnimating) _loop.repeat();
    } else {
      _loop
        ..stop()
        ..value = 0;
    }
  }

  @override
  void dispose() {
    _loop.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = _Palette.of(context.nr);
    return AspectRatio(
      aspectRatio: OnboardingArt.aspectRatio,
      child: AnimatedBuilder(
        animation: _loop,
        builder: (context, _) => CustomPaint(painter: _ScenePainter(widget.scene, t: _loop.value, p: palette)),
      ),
    );
  }
}

/// Solid colors for the art, all derived from the theme tokens.
class _Palette {
  const _Palette({
    required this.stage,
    required this.surface,
    required this.raised,
    required this.line,
    required this.ink,
    required this.soft,
    required this.accent,
    required this.accentSoft,
    required this.onAccent,
    required this.device,
    required this.frame,
    required this.success,
    required this.warm,
  });

  /// Disc behind the scene.
  final Color stage;
  final Color surface;
  final Color raised;
  final Color line;

  /// Strong strokes and text-like bars.
  final Color ink;

  /// Quiet text-like bars.
  final Color soft;
  final Color accent;
  final Color accentSoft;
  final Color onAccent;

  /// Hardware bodies (printer, van).
  final Color device;

  /// Outline of the phones.
  final Color frame;
  final Color success;
  final Color warm;

  factory _Palette.of(NrColors nr) {
    final base = nr.canvas;
    return _Palette(
      stage: Color.lerp(base, nr.accent, nr.night ? 0.16 : 0.09)!,
      surface: nr.night ? nr.raised : nr.surface,
      raised: nr.night ? nr.borderStrong : nr.sunken,
      line: nr.night ? Color.lerp(nr.borderStrong, nr.muted, 0.35)! : nr.borderStrong,
      ink: nr.headline,
      soft: nr.night ? nr.muted : Color.lerp(nr.borderStrong, nr.muted, 0.45)!,
      accent: nr.accent,
      accentSoft: Color.lerp(nr.night ? nr.raised : nr.surface, nr.accent, nr.night ? 0.32 : 0.16)!,
      onAccent: nr.onAccent,
      device: nr.night ? nr.borderStrong : nr.ink,
      frame: nr.night ? nr.muted : nr.headline,
      success: nr.night ? Color.lerp(nr.success, nr.canvas, 0.25)! : nr.success,
      warm: Color.lerp(nr.night ? nr.raised : nr.surface, NrColors.hues[4], nr.night ? 0.45 : 0.3)!,
    );
  }

  @override
  bool operator ==(Object other) => other is _Palette && other.accent == accent && other.surface == surface && other.ink == ink;

  @override
  int get hashCode => Object.hash(accent, surface, ink);
}

class _ScenePainter extends CustomPainter {
  _ScenePainter(this.scene, {required this.t, required this.p});

  final OnboardingScene scene;
  final double t;
  final _Palette p;

  static const _w = 300.0;

  Paint _fill(Color c) => Paint()..color = c;

  Paint _stroke(Color c, [double width = 1.5]) => Paint()
    ..color = c
    ..style = PaintingStyle.stroke
    ..strokeWidth = width
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round;

  /// 0→1 inside [a, b] of the loop.
  double win(double a, double b, [Curve curve = Curves.easeInOutCubic]) => curve.transform(((t - a) / (b - a)).clamp(0.0, 1.0));

  /// Pops in over [a, b] and pops out at the end of the loop so it closes without a jump.
  double pop(double a, double b, {double out = 0.94}) =>
      Curves.easeOutBack.transform(((t - a) / (b - a)).clamp(0.0, 1.0)) * (1 - win(out, 1, Curves.easeIn));

  /// Draws [draw] scaled by [s] around [c]; nothing when it is not visible.
  void _scaled(Canvas canvas, Offset c, double s, VoidCallback draw) {
    if (s <= 0.001) return;
    canvas.save();
    canvas.translate(c.dx, c.dy);
    canvas.scale(s);
    canvas.translate(-c.dx, -c.dy);
    draw();
    canvas.restore();
  }

  void _bar(Canvas canvas, double x, double y, double width, Color c, [double height = 5]) {
    if (width <= 0) return;
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(x, y - height / 2, width, height), Radius.circular(height / 2)), _fill(c));
  }

  void _panel(Canvas canvas, RRect r, {Color? fill, Color? border}) {
    canvas.drawRRect(r, _fill(fill ?? p.surface));
    canvas.drawRRect(r, _stroke(border ?? p.line));
  }

  void _check(Canvas canvas, Offset c, double r, double progress, {Color? color, Color? mark}) {
    if (progress <= 0) return;
    canvas.drawCircle(c, r, _fill(color ?? p.success));
    final path = Path()
      ..moveTo(c.dx - r * 0.42, c.dy + r * 0.02)
      ..lineTo(c.dx - r * 0.1, c.dy + r * 0.32)
      ..lineTo(c.dx + r * 0.44, c.dy - r * 0.3);
    final m = path.computeMetrics().first;
    canvas.drawPath(m.extractPath(0, m.length * progress.clamp(0.0, 1.0)), _stroke(mark ?? p.onAccent, r * 0.22));
  }

  /// A dot riding a path (something on its way).
  void _travel(Canvas canvas, Path path, double progress, {double r = 6}) {
    if (progress <= 0 || progress >= 1) return;
    final m = path.computeMetrics().first;
    final at = m.getTangentForOffset(m.length * progress)!.position;
    canvas.drawCircle(at, r + 3, _fill(p.surface));
    canvas.drawCircle(at, r, _fill(p.accent));
  }

  void _dashed(Canvas canvas, Path path, Paint paint, {double dash = 6, double gap = 6, double upTo = 1}) {
    for (final m in path.computeMetrics()) {
      final end = m.length * upTo;
      var d = 0.0;
      while (d < end) {
        canvas.drawPath(m.extractPath(d, math.min(d + dash, end)), paint);
        d += dash + gap;
      }
    }
  }

  /// Nori's cloud (the isotype) inside a 128 box, scaled to [size].
  Path _cloud(Offset topLeft, double size) {
    final k = size / 128;
    Offset o(double x, double y) => topLeft + Offset(x * k, y * k);
    return Path()
      ..addRect(Rect.fromPoints(o(34.55, 73.3), o(90.35, 96.55)))
      ..addOval(Rect.fromCircle(center: o(34.55, 76.4), radius: 20.15 * k))
      ..addOval(Rect.fromCircle(center: o(62.45, 60.9), radius: 29.45 * k))
      ..addOval(Rect.fromCircle(center: o(90.35, 73.3), radius: 23.25 * k));
  }

  void _phone(Canvas canvas, Rect r) {
    final body = RRect.fromRectAndRadius(r, const Radius.circular(18));
    canvas.drawRRect(body, _fill(p.surface));
    canvas.drawRRect(body, _stroke(p.frame, 2));
    _bar(canvas, r.center.dx - 12, r.top + 10, 24, p.raised, 5);
  }

  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / _w);
    canvas.drawCircle(const Offset(150, 116), 104, _fill(p.stage));
    switch (scene) {
      case OnboardingScene.sell:
        _sell(canvas);
      case OnboardingScene.collect:
        _collect(canvas);
      case OnboardingScene.invoice:
        _invoice(canvas);
      case OnboardingScene.day:
        _day(canvas);
    }
  }

  // --- 1. Sell on the road or at the counter, even offline ---------------------

  void _sell(Canvas canvas) {
    // Road with a van on the left, a shop counter on the right.
    final roadShift = (t * 48) % 12;
    canvas.save();
    canvas.clipRect(const Rect.fromLTWH(0, 196, 300, 8));
    for (var x = -12.0; x < 300; x += 12) {
      _bar(canvas, x + roadShift, 200, 6, p.line, 3);
    }
    canvas.restore();

    final bob = math.sin(t * math.pi * 12) * 0.8;
    canvas.save();
    canvas.translate(0, bob);
    final van = RRect.fromRectAndCorners(const Rect.fromLTWH(14, 150, 66, 38),
        topLeft: const Radius.circular(8), topRight: const Radius.circular(16), bottomLeft: const Radius.circular(6), bottomRight: const Radius.circular(6));
    canvas.drawRRect(van, _fill(p.device));
    canvas.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(56, 157, 18, 13), const Radius.circular(4)), _fill(p.accentSoft));
    _bar(canvas, 20, 168, 28, p.accent, 6);
    canvas.restore();
    for (final x in [30.0, 66.0]) {
      canvas.drawCircle(Offset(x, 190), 8, _fill(p.frame));
      canvas.drawCircle(Offset(x, 190), 3.5, _fill(p.surface));
    }

    // Shop with a striped awning.
    const shop = Rect.fromLTWH(226, 150, 60, 46);
    canvas.drawRect(shop, _fill(p.surface));
    canvas.drawRect(shop, _stroke(p.line));
    canvas.drawRect(const Rect.fromLTWH(238, 168, 36, 28), _fill(p.raised));
    for (var i = 0; i < 5; i++) {
      final x = 222.0 + i * 13.6;
      final stripe = Path()
        ..moveTo(x, 138)
        ..lineTo(x + 13.6, 138)
        ..lineTo(x + 13.6, 150)
        ..arcToPoint(Offset(x, 150), radius: const Radius.circular(6.8))
        ..close();
      canvas.drawPath(stripe, _fill(i.isEven ? p.accent : p.surface));
    }
    canvas.drawRect(const Rect.fromLTWH(222, 138, 68, 12), _stroke(p.line));

    // Phone taking the sale.
    const phone = Rect.fromLTWH(96, 18, 108, 184);
    _phone(canvas, phone);
    _bar(canvas, 110, 38, 46, p.ink, 6);
    final thumbs = [p.accentSoft, p.warm, p.accentSoft];
    for (var i = 0; i < 3; i++) {
      final y = 62.0 + i * 30;
      final s = pop(0.04 + i * 0.09, 0.14 + i * 0.09);
      _scaled(canvas, Offset(110, y), s, () {
        canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(108, y - 10, 20, 20), const Radius.circular(6)), _fill(thumbs[i]));
        _bar(canvas, 134, y - 4, 42 - i * 6, p.ink, 4.5);
        _bar(canvas, 134, y + 5, 26, p.soft, 4);
        _bar(canvas, 180, y - 4, 12, p.soft, 4);
      });
    }
    final total = pop(0.34, 0.44);
    final totalBox = RRect.fromRectAndRadius(const Rect.fromLTWH(108, 160, 84, 28), const Radius.circular(10));
    _scaled(canvas, totalBox.center, total, () {
      canvas.drawRRect(totalBox, _fill(p.accent));
      _bar(canvas, 118, 174, 30, p.onAccent, 5);
      _bar(canvas, 170, 174, 12, p.onAccent, 5);
    });

    // No signal → signal is back → the sale goes up on its own.
    const cloudAt = Offset(210, 22);
    const cloudSize = 76.0;
    final online = win(0.5, 0.6);
    canvas.drawPath(_cloud(cloudAt, cloudSize), _fill(Color.lerp(p.raised, p.accent, online)!));
    final slash = 1 - win(0.46, 0.56);
    if (slash > 0) {
      const a = Offset(228, 40);
      const b = Offset(268, 92);
      final end = Offset.lerp(a, b, slash)!;
      canvas.drawLine(a, end, _stroke(p.stage, 9));
      canvas.drawLine(a, end, _stroke(p.soft, 4));
    }
    final send = Path()
      ..moveTo(192, 168)
      ..cubicTo(228, 160, 250, 130, 248, 96);
    if (win(0.6, 0.82) > 0 && win(0.6, 0.82) < 1) _dashed(canvas, send, _stroke(p.line, 2), dash: 4, gap: 5, upTo: win(0.6, 0.82));
    _travel(canvas, send, win(0.6, 0.82));
    _check(canvas, const Offset(250, 84), 11, win(0.8, 0.9) * (1 - win(0.94, 1)), color: p.surface, mark: p.accent);
  }

  // --- 2. Collect and print the ticket over Bluetooth --------------------------

  void _collect(Canvas canvas) {
    const phone = Rect.fromLTWH(30, 26, 100, 176);
    _phone(canvas, phone);
    _bar(canvas, 46, 50, 30, p.soft, 4.5);
    _bar(canvas, 46, 72, 64, p.ink, 12);
    // Two payment methods, the first one picked.
    final pick = win(0.02, 0.1);
    final a = RRect.fromRectAndRadius(const Rect.fromLTWH(44, 96, 34, 26), const Radius.circular(8));
    final b = RRect.fromRectAndRadius(const Rect.fromLTWH(84, 96, 34, 26), const Radius.circular(8));
    canvas.drawRRect(a, _fill(Color.lerp(p.raised, p.accentSoft, pick)!));
    canvas.drawRRect(a, _stroke(Color.lerp(p.line, p.accent, pick)!, 1.5));
    canvas.drawRRect(b, _fill(p.raised));
    _bar(canvas, 52, 109, 18, Color.lerp(p.soft, p.accent, pick)!, 4);
    _bar(canvas, 92, 109, 18, p.soft, 4);
    _bar(canvas, 46, 140, 52, p.soft, 4);

    // "Collect" button pressed, with its ripple.
    final press = win(0.12, 0.17) * (1 - win(0.17, 0.24));
    final btn = RRect.fromRectAndRadius(const Rect.fromLTWH(42, 160, 76, 28), const Radius.circular(10));
    _scaled(canvas, btn.center, 1 - press * 0.08, () {
      canvas.drawRRect(btn, _fill(p.accent));
      _bar(canvas, 64, 174, 32, p.onAccent, 5);
    });
    final ripple = win(0.14, 0.32, Curves.easeOut);
    if (ripple > 0 && ripple < 1) {
      canvas.drawCircle(btn.center, 10 + ripple * 34, _stroke(Color.lerp(p.accent, p.stage, ripple)!, 2));
    }

    // Bluetooth: the rune and its waves light up one by one.
    const bt = Offset(164, 96);
    final link = win(0.26, 0.4);
    final rune = Path()
      ..moveTo(bt.dx - 7, bt.dy - 7)
      ..lineTo(bt.dx + 7, bt.dy + 7)
      ..lineTo(bt.dx, bt.dy + 14)
      ..lineTo(bt.dx, bt.dy - 14)
      ..lineTo(bt.dx + 7, bt.dy - 7)
      ..lineTo(bt.dx - 7, bt.dy + 7);
    canvas.drawCircle(bt, 22, _fill(Color.lerp(p.surface, p.accentSoft, link)!));
    canvas.drawPath(rune, _stroke(Color.lerp(p.soft, p.accent, link)!, 2.6));
    for (var i = 0; i < 2; i++) {
      final on = win(0.3 + i * 0.06, 0.36 + i * 0.06) * (1 - win(0.94, 1));
      final c = Color.lerp(p.line, p.accent, on)!;
      final r = 27.0 + i * 7;
      canvas.drawArc(Rect.fromCircle(center: bt, radius: r), -0.6, 1.2, false, _stroke(c, 2.2));
      canvas.drawArc(Rect.fromCircle(center: bt, radius: r), math.pi - 0.6, 1.2, false, _stroke(c, 2.2));
    }

    // Thermal printer, with the ticket coming out of its slot.
    const printer = Rect.fromLTWH(196, 128, 88, 66);
    final paperOut = win(0.42, 0.74, Curves.easeOut) * (1 - win(0.92, 1, Curves.easeIn));
    final paperLen = 104 * paperOut;
    if (paperLen > 0) {
      final top = 136 - paperLen;
      final paper = Path()..moveTo(210, 136)..lineTo(210, top + 4);
      for (var x = 210.0; x < 270; x += 10) {
        paper
          ..lineTo(x + 5, top)
          ..lineTo(x + 10, top + 4);
      }
      paper
        ..lineTo(270, 136)
        ..close();
      canvas.drawPath(paper, _fill(p.surface));
      canvas.drawPath(paper, _stroke(p.line));
      // Lines ride with the paper: the first printed one is the highest.
      final rows = [(18.0, 28.0, p.ink), (32.0, 22.0, p.soft), (44.0, 26.0, p.soft), (56.0, 18.0, p.soft), (74.0, 40.0, p.accent)];
      canvas.save();
      canvas.clipRect(Rect.fromLTRB(206, top, 274, 128));
      for (final (dy, width, c) in rows) {
        _bar(canvas, 220, top + dy, width, c, c == p.accent ? 6 : 4);
      }
      canvas.restore();
      _check(canvas, Offset(258, top + 32), 9, win(0.76, 0.86) * (1 - win(0.92, 1)));
    }
    final body = RRect.fromRectAndRadius(printer, const Radius.circular(14));
    canvas.drawRRect(body, _fill(p.device));
    _bar(canvas, 206, 138, 68, p.soft, 4);
    canvas.drawCircle(const Offset(270, 180), 4, _fill(link > 0.5 ? p.success : p.line));
    _bar(canvas, 208, 180, 28, p.line, 4);
  }

  // --- 3. CFDI invoice ---------------------------------------------------------

  void _invoice(Canvas canvas) {
    const doc = Rect.fromLTWH(60, 20, 136, 186);
    _panel(canvas, RRect.fromRectAndRadius(doc, const Radius.circular(14)), border: p.line);
    canvas.drawRRect(
      RRect.fromRectAndCorners(const Rect.fromLTWH(60, 20, 136, 38), topLeft: const Radius.circular(14), topRight: const Radius.circular(14)),
      _fill(p.accent),
    );
    final label = TextPainter(
      text: TextSpan(text: 'CFDI', style: TextStyle(fontFamily: NrText.family, fontSize: 15, fontWeight: FontWeight.w700, color: p.onAccent, letterSpacing: 0.6)),
      textDirection: TextDirection.ltr,
    )..layout();
    label.paint(canvas, Offset(74, 39 - label.height / 2));
    _bar(canvas, 150, 39, 32, p.onAccent, 5);

    // Lines typed one after the other.
    final rows = [(76.0, 70.0, p.ink), (92.0, 96.0, p.soft), (106.0, 84.0, p.soft), (120.0, 90.0, p.soft), (142.0, 56.0, p.ink)];
    for (var i = 0; i < rows.length; i++) {
      final (y, width, c) = rows[i];
      final grow = win(0.03 + i * 0.05, 0.1 + i * 0.05) * (1 - win(0.94, 1));
      _bar(canvas, 74, y, width * grow, c, i == rows.length - 1 ? 7 : 4.5);
    }

    // Fiscal QR code.
    const qr = Offset(74, 160);
    const cell = 4.4;
    const bits = [0x7D, 0x45, 0x55, 0x45, 0x7D, 0x00, 0x6B];
    final qrOn = win(0.3, 0.36) * (1 - win(0.94, 1));
    if (qrOn > 0) {
      for (var row = 0; row < bits.length; row++) {
        for (var col = 0; col < 7; col++) {
          if ((bits[row] >> (6 - col)) & 1 == 1) {
            canvas.drawRect(Rect.fromLTWH(qr.dx + col * cell, qr.dy + row * cell, cell - 0.4, cell - 0.4), _fill(p.ink));
          }
        }
      }
    }

    // The seal: stamped, valid.
    final seal = pop(0.38, 0.5);
    _scaled(canvas, const Offset(166, 172), seal, () {
      canvas.save();
      canvas.translate(166, 172);
      canvas.rotate(-0.2);
      canvas.translate(-166, -172);
      canvas.drawCircle(const Offset(166, 172), 24, _fill(p.stage));
      _check(canvas, const Offset(166, 172), 19, 1);
      canvas.restore();
    });

    // Sent to the customer.
    const customer = Offset(256, 72);
    canvas.drawCircle(customer, 26, _fill(p.surface));
    canvas.drawCircle(customer, 26, _stroke(p.line));
    canvas.drawCircle(customer + const Offset(0, -7), 8, _fill(p.accent));
    canvas.save();
    canvas.clipPath(Path()..addOval(Rect.fromCircle(center: customer, radius: 25)));
    canvas.drawOval(Rect.fromCenter(center: customer + const Offset(0, 18), width: 32, height: 22), _fill(p.accent));
    canvas.restore();
    final route = Path()
      ..moveTo(196, 130)
      ..cubicTo(228, 128, 250, 120, 254, 104);
    final go = win(0.56, 0.78);
    if (go > 0 && go < 1) {
      _dashed(canvas, route, _stroke(p.line, 2), dash: 4, gap: 5, upTo: go);
      final m = route.computeMetrics().first;
      final tan = m.getTangentForOffset(m.length * go)!;
      canvas.save();
      canvas.translate(tan.position.dx, tan.position.dy);
      canvas.rotate(-tan.angle);
      final plane = Path()
        ..moveTo(10, 0)
        ..lineTo(-8, -7)
        ..lineTo(-4, 0)
        ..lineTo(-8, 7)
        ..close();
      canvas.drawPath(plane, _fill(p.accent));
      canvas.restore();
    }
    final got = pop(0.78, 0.86);
    _scaled(canvas, customer + const Offset(19, -19), got, () => _check(canvas, customer + const Offset(19, -19), 10, 1));
  }

  // --- 4. Your day, your customers and the price checker -----------------------

  void _day(Canvas canvas) {
    // Map with today's route.
    const map = Rect.fromLTWH(18, 26, 154, 168);
    final mapBox = RRect.fromRectAndRadius(map, const Radius.circular(16));
    _panel(canvas, mapBox);
    canvas.save();
    canvas.clipRRect(mapBox);
    final street = _stroke(p.raised, 8);
    canvas.drawLine(const Offset(18, 80), const Offset(172, 64), street);
    canvas.drawLine(const Offset(18, 150), const Offset(172, 162), street);
    canvas.drawLine(const Offset(70, 26), const Offset(84, 194), street);
    canvas.drawLine(const Offset(134, 26), const Offset(124, 194), street);
    canvas.restore();

    const stops = [Offset(42, 168), Offset(80, 110), Offset(128, 136), Offset(148, 58)];
    final path = Path()
      ..moveTo(stops[0].dx, stops[0].dy)
      ..cubicTo(52, 140, 64, 118, stops[1].dx, stops[1].dy)
      ..cubicTo(96, 104, 110, 150, stops[2].dx, stops[2].dy)
      ..cubicTo(146, 124, 156, 86, stops[3].dx, stops[3].dy);
    _dashed(canvas, path, _stroke(p.line, 2.4), dash: 5, gap: 5);
    final drive = win(0.04, 0.6, Curves.easeInOut);
    final m = path.computeMetrics().first;
    if (drive > 0) canvas.drawPath(m.extractPath(0, m.length * drive), _stroke(p.accent, 3));
    final reached = <double>[0, 0.36, 0.68, 1];
    var done = 0;
    for (var i = 0; i < stops.length; i++) {
      final on = drive >= reached[i] && drive > 0;
      if (on) done++;
      canvas.drawCircle(stops[i], 9, _fill(on ? p.accent : p.surface));
      canvas.drawCircle(stops[i], 9, _stroke(on ? p.accent : p.soft, 2));
      if (on) canvas.drawCircle(stops[i], 3.5, _fill(p.onAccent));
    }
    if (drive > 0 && drive < 1) _travel(canvas, path, drive, r: 5);

    // Progress of the day.
    final card = RRect.fromRectAndRadius(const Rect.fromLTWH(184, 26, 100, 64), const Radius.circular(14));
    _panel(canvas, card);
    const ring = Offset(210, 58);
    canvas.drawCircle(ring, 15, _stroke(p.raised, 6));
    final shown = done / stops.length;
    if (shown > 0) {
      canvas.drawArc(Rect.fromCircle(center: ring, radius: 15), -math.pi / 2, math.pi * 2 * shown, false, _stroke(p.accent, 6));
    }
    _bar(canvas, 234, 50, 38, p.ink, 6);
    _bar(canvas, 234, 66, 26, p.soft, 4.5);

    // Price tag under the scanner.
    canvas.save();
    canvas.translate(234, 148);
    canvas.rotate(-0.08);
    final tag = Path()
      ..addRRect(RRect.fromRectAndRadius(Rect.fromCenter(center: Offset.zero, width: 96, height: 76), const Radius.circular(12)));
    canvas.drawPath(tag, _fill(p.surface));
    canvas.drawPath(tag, _stroke(p.line));
    canvas.drawCircle(const Offset(-36, -26), 4, _fill(p.stage));
    canvas.drawCircle(const Offset(-36, -26), 4, _stroke(p.line));
    const widths = [2.0, 4.0, 2.0, 2.0, 5.0, 2.0, 3.0, 2.0, 4.0, 2.0, 2.0, 5.0, 2.0, 3.0];
    var x = -32.0;
    for (final bw in widths) {
      canvas.drawRect(Rect.fromLTWH(x, -12, bw, 26), _fill(p.ink));
      x += bw + 2.4;
    }
    final scan = win(0.6, 0.78);
    if (scan > 0 && scan < 1) {
      final y = -18 + 38 * (0.5 - 0.5 * math.cos(scan * math.pi * 2));
      canvas.drawLine(Offset(-42, y), Offset(42, y), _stroke(p.accent, 2.5));
    }
    final price = pop(0.78, 0.88);
    _scaled(canvas, const Offset(0, 28), price, () {
      canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromCenter(center: const Offset(0, 28), width: 64, height: 22), const Radius.circular(11)), _fill(p.accent));
      _bar(canvas, -20, 28, 40, p.onAccent, 5);
    });
    canvas.restore();
  }

  @override
  bool shouldRepaint(_ScenePainter old) => old.t != t || old.scene != scene || old.p != p;
}
