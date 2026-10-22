import 'package:flutter/material.dart';

import 'nr_tokens.dart';

/// Escala tipográfica: Inter en todo; el contraste sale del peso y del tracking.
abstract final class NrText {
  static const String family = 'Inter';
  static const _tabular = [FontFeature.tabularFigures()];

  static TextStyle _s(BuildContext c, double size, FontWeight w, Color color, {double ls = 0, double h = 1.3, bool tab = false}) =>
      TextStyle(fontFamily: family, fontSize: size, fontWeight: w, color: color, letterSpacing: ls, height: h, fontFeatures: tab ? _tabular : null);

  /// Cifra grande de KPI.
  static TextStyle stat(BuildContext c) => _s(c, 28, FontWeight.w600, c.nr.headline, ls: -0.7, h: 1.1, tab: true);

  /// Cifra enorme del conteo físico (se lee con el brazo extendido).
  static TextStyle huge(BuildContext c) => _s(c, 64, FontWeight.w700, c.nr.headline, ls: -2, h: 1, tab: true);

  static TextStyle display(BuildContext c) => _s(c, 28, FontWeight.w700, c.nr.headline, ls: -0.9, h: 1.15);
  static TextStyle title(BuildContext c) => _s(c, 20, FontWeight.w700, c.nr.headline, ls: -0.4, h: 1.25);
  static TextStyle headline(BuildContext c) => _s(c, 16, FontWeight.w600, c.nr.headline, ls: -0.2);
  static TextStyle body(BuildContext c) => _s(c, 15, FontWeight.w400, c.nr.body, h: 1.4);
  static TextStyle bodySm(BuildContext c) => _s(c, 13, FontWeight.w400, c.nr.secondary, h: 1.35);
  static TextStyle label(BuildContext c) => _s(c, 13, FontWeight.w500, c.nr.body, h: 1.2);
  static TextStyle caption(BuildContext c) => _s(c, 12, FontWeight.w400, c.nr.secondary);
  static TextStyle eyebrow(BuildContext c) => _s(c, 11, FontWeight.w500, c.nr.secondary, ls: 0.55, h: 1.2);
  static TextStyle money(BuildContext c, {double size = 15, FontWeight weight = FontWeight.w600}) =>
      _s(c, size, weight, c.nr.headline, ls: -0.2, h: 1.2, tab: true);
}
