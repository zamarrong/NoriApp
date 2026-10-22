import 'package:flutter/material.dart';

/// Tokens de diseño de Nori: color, espacio y radio. El lenguaje visual sigue
/// al de la app rediseñada de Recaudo (plano, borde de 1px, sombra mínima,
/// botón primario en tinta) pero el acento es el de la empresa (ajustes de
/// apariencia de nori-web, `company.accent_color`, #2563EB por omisión).
///
/// Regla: el acento marca lo activo (un botón, una cifra, un enlace); nunca es
/// fondo de pantalla ni de tarjeta. Las pantallas no escriben `Color(0x...)`.
@immutable
class NrColors extends ThemeExtension<NrColors> {
  const NrColors({
    required this.canvas,
    required this.surface,
    required this.raised,
    required this.border,
    required this.borderStrong,
    required this.headline,
    required this.body,
    required this.secondary,
    required this.muted,
    required this.accent,
    required this.accentSoft,
    required this.link,
    required this.ink,
    required this.onInk,
    required this.success,
    required this.successBg,
    required this.warning,
    required this.warningBg,
    required this.danger,
    required this.dangerBg,
    required this.shadow,
  });

  final Color canvas;
  final Color surface;
  final Color raised;
  final Color border;
  final Color borderStrong;
  final Color headline;
  final Color body;
  final Color secondary;
  final Color muted;
  final Color accent;
  final Color accentSoft;
  final Color link;
  final Color ink;
  final Color onInk;
  final Color success;
  final Color successBg;
  final Color warning;
  final Color warningBg;
  final Color danger;
  final Color dangerBg;
  final List<BoxShadow> shadow;

  static const defaultAccent = Color(0xFF2563EB);

  static NrColors light([Color accent = defaultAccent]) => NrColors(
        canvas: const Color(0xFFF8F9FA),
        surface: const Color(0xFFFFFFFF),
        raised: const Color(0xFFF3F4F6),
        border: const Color(0xFFE8E8EB),
        borderStrong: const Color(0xFFE5E7EB),
        headline: const Color(0xFF1A1A1A),
        body: const Color(0xFF1F2937),
        secondary: const Color(0xFF6B7280),
        muted: const Color(0xFF9CA3AF),
        accent: accent,
        accentSoft: Color.alphaBlend(accent.withValues(alpha: 0.08), Colors.white),
        link: accent,
        ink: const Color(0xFF242629),
        onInk: Colors.white,
        success: const Color(0xFF15803D),
        successBg: const Color(0xFFF0FDF4),
        warning: const Color(0xFFB45309),
        warningBg: const Color(0xFFFFFBEB),
        danger: const Color(0xFFB91C1C),
        dangerBg: const Color(0xFFFEF2F2),
        shadow: const [
          BoxShadow(color: Color(0x050F172A), offset: Offset(0, 1)),
          BoxShadow(color: Color(0x0A0F172A), offset: Offset(0, 2), blurRadius: 8),
        ],
      );

  static NrColors dark([Color accent = defaultAccent]) => NrColors(
        canvas: const Color(0xFF111315),
        surface: const Color(0xFF1A1D21),
        raised: const Color(0xFF232629),
        border: const Color(0xFF2D3138),
        borderStrong: const Color(0xFF3D4148),
        headline: const Color(0xFFF9FAFB),
        body: const Color(0xFFE5E7EB),
        secondary: const Color(0xFF9CA3AF),
        muted: const Color(0xFF6B7280),
        accent: accent,
        accentSoft: accent.withValues(alpha: 0.15),
        // El acento sobre la superficie oscura no siempre llega a 4.5:1: el texto de enlace va neutro.
        link: const Color(0xFFF9FAFB),
        ink: const Color(0xFFF9FAFB),
        onInk: const Color(0xFF111315),
        success: const Color(0xFF86EFAC),
        successBg: const Color(0x2622C55E),
        warning: const Color(0xFFFCD34D),
        warningBg: const Color(0x26F59E0B),
        danger: const Color(0xFFFCA5A5),
        dangerBg: const Color(0x26EF4444),
        shadow: const [],
      );

  @override
  NrColors copyWith({Color? accent}) => NrColors(
        canvas: canvas,
        surface: surface,
        raised: raised,
        border: border,
        borderStrong: borderStrong,
        headline: headline,
        body: body,
        secondary: secondary,
        muted: muted,
        accent: accent ?? this.accent,
        accentSoft: accentSoft,
        link: link,
        ink: ink,
        onInk: onInk,
        success: success,
        successBg: successBg,
        warning: warning,
        warningBg: warningBg,
        danger: danger,
        dangerBg: dangerBg,
        shadow: shadow,
      );

  @override
  NrColors lerp(ThemeExtension<NrColors>? other, double t) {
    if (other is! NrColors) return this;
    Color l(Color a, Color b) => Color.lerp(a, b, t)!;
    return NrColors(
      canvas: l(canvas, other.canvas),
      surface: l(surface, other.surface),
      raised: l(raised, other.raised),
      border: l(border, other.border),
      borderStrong: l(borderStrong, other.borderStrong),
      headline: l(headline, other.headline),
      body: l(body, other.body),
      secondary: l(secondary, other.secondary),
      muted: l(muted, other.muted),
      accent: l(accent, other.accent),
      accentSoft: l(accentSoft, other.accentSoft),
      link: l(link, other.link),
      ink: l(ink, other.ink),
      onInk: l(onInk, other.onInk),
      success: l(success, other.success),
      successBg: l(successBg, other.successBg),
      warning: l(warning, other.warning),
      warningBg: l(warningBg, other.warningBg),
      danger: l(danger, other.danger),
      dangerBg: l(dangerBg, other.dangerBg),
      shadow: t < 0.5 ? shadow : other.shadow,
    );
  }
}

/// Espaciado en múltiplos de 4.
abstract final class NrSpace {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 20;
  static const double xxl = 24;
  static const double xxxl = 32;
  static const double gutter = 16;
}

abstract final class NrRadius {
  static const double sm = 6;
  static const double md = 8;
  static const double lg = 10;
  static const double xl = 12;
  static const double xxl = 16;
  static const double pill = 999;
}

/// Convierte "#2563eb" en un [Color]; null si no es válido.
Color? parseHexColor(String? hex) {
  if (hex == null) return null;
  final h = hex.replaceFirst('#', '').trim();
  if (h.length != 6) return null;
  final v = int.tryParse(h, radix: 16);
  return v == null ? null : Color(0xFF000000 | v);
}

extension NrContext on BuildContext {
  NrColors get nr => Theme.of(this).extension<NrColors>() ?? NrColors.light();
  bool get isDark => Theme.of(this).brightness == Brightness.dark;
}
