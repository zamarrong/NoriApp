import 'package:flutter/material.dart';

/// Tokens de diseño de Nori: color, profundidad, espacio y radio.
///
/// Lenguaje: superficies con profundidad suave (sombras en capas en claro,
/// filo de 1px y superficies escalonadas en oscuro), cifras grandes y
/// tabulares, rótulos callados. El acento es el de la empresa (ajustes de
/// apariencia de nori-web, `company.accent_color`, #2563EB por omisión) y marca
/// lo activo: el botón principal, el avance, un punto de estado, una franja.
///
/// Alto contraste (uso en la calle, a pleno sol): texto negro sobre blanco,
/// bordes visibles en lugar de sombras y estados con más saturación.
/// Las pantallas no escriben `Color(0x...)`: todo sale de aquí.
@immutable
class NrColors extends ThemeExtension<NrColors> {
  const NrColors({
    required this.canvas,
    required this.surface,
    required this.raised,
    required this.sunken,
    required this.border,
    required this.borderStrong,
    required this.headline,
    required this.body,
    required this.secondary,
    required this.muted,
    required this.accent,
    required this.accentSoft,
    required this.onAccent,
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
    required this.shadowLg,
    required this.highContrast,
    required this.night,
  });

  /// Fondo de la pantalla.
  final Color canvas;

  /// Tarjetas y hojas.
  final Color surface;

  /// Rellenos dentro de una tarjeta (chips, campos, pistas de barras).
  final Color raised;

  /// Más bajo que el lienzo: huecos y pistas vacías.
  final Color sunken;
  final Color border;
  final Color borderStrong;
  final Color headline;
  final Color body;
  final Color secondary;
  final Color muted;
  final Color accent;
  final Color accentSoft;

  /// Texto e íconos sobre el acento (blanco o negro según su luminancia).
  final Color onAccent;
  final Color link;
  final Color ink;
  final Color onInk;
  final Color success;
  final Color successBg;
  final Color warning;
  final Color warningBg;
  final Color danger;
  final Color dangerBg;

  /// Sombra de tarjeta y sombra de lo que flota (barra inferior, hojas).
  final List<BoxShadow> shadow;
  final List<BoxShadow> shadowLg;
  final bool highContrast;
  final bool night;

  static const defaultAccent = Color(0xFF2563EB);

  static Color _onAccent(Color accent) => accent.computeLuminance() > 0.55 ? const Color(0xFF0F1115) : Colors.white;

  /// Tonos estables para avatares y familias de acciones (sin significado de estado).
  static const hues = [
    Color(0xFF2563EB), // azul
    Color(0xFF0D9488), // verde azulado
    Color(0xFF7C3AED), // violeta
    Color(0xFFDB2777), // rosa
    Color(0xFFEA580C), // naranja
    Color(0xFF0891B2), // cian
    Color(0xFF65A30D), // lima
    Color(0xFFCA8A04), // ámbar
  ];

  static NrColors light([Color accent = defaultAccent, bool highContrast = false]) {
    if (highContrast) {
      return NrColors(
        canvas: const Color(0xFFFFFFFF),
        surface: const Color(0xFFFFFFFF),
        raised: const Color(0xFFF0F1F3),
        sunken: const Color(0xFFE4E6EA),
        border: const Color(0xFF8A919C),
        borderStrong: const Color(0xFF3F4650),
        headline: const Color(0xFF000000),
        body: const Color(0xFF000000),
        secondary: const Color(0xFF22262C),
        muted: const Color(0xFF4A515B),
        accent: _deepen(accent),
        accentSoft: Color.alphaBlend(accent.withValues(alpha: 0.14), Colors.white),
        onAccent: _onAccent(_deepen(accent)),
        link: _deepen(accent),
        ink: const Color(0xFF000000),
        onInk: Colors.white,
        success: const Color(0xFF0B6B30),
        successBg: const Color(0xFFDDF6E6),
        warning: const Color(0xFF8A3B00),
        warningBg: const Color(0xFFFFEBC7),
        danger: const Color(0xFF9F1111),
        dangerBg: const Color(0xFFFFE0E0),
        shadow: const [],
        shadowLg: const [BoxShadow(color: Color(0x33000000), offset: Offset(0, 6), blurRadius: 20, spreadRadius: -6)],
        highContrast: true,
        night: false,
      );
    }
    return NrColors(
      canvas: const Color(0xFFF4F5F7),
      surface: const Color(0xFFFFFFFF),
      raised: const Color(0xFFF1F3F5),
      sunken: const Color(0xFFE9ECEF),
      border: const Color(0xFFE7E9ED),
      borderStrong: const Color(0xFFD6DAE0),
      headline: const Color(0xFF0F1115),
      body: const Color(0xFF1F2329),
      secondary: const Color(0xFF5E6570),
      muted: const Color(0xFF969DA8),
      accent: accent,
      accentSoft: Color.alphaBlend(accent.withValues(alpha: 0.09), Colors.white),
      onAccent: _onAccent(accent),
      link: accent,
      ink: const Color(0xFF16181D),
      onInk: Colors.white,
      success: const Color(0xFF15803D),
      successBg: const Color(0xFFEAF8EF),
      warning: const Color(0xFFB45309),
      warningBg: const Color(0xFFFFF5E3),
      danger: const Color(0xFFC81E1E),
      dangerBg: const Color(0xFFFDEEEE),
      shadow: const [
        BoxShadow(color: Color(0x0A0F1115), offset: Offset(0, 1), blurRadius: 2),
        BoxShadow(color: Color(0x120F1115), offset: Offset(0, 8), blurRadius: 20, spreadRadius: -8),
      ],
      shadowLg: const [
        BoxShadow(color: Color(0x0F0F1115), offset: Offset(0, 2), blurRadius: 6),
        BoxShadow(color: Color(0x290F1115), offset: Offset(0, 18), blurRadius: 40, spreadRadius: -14),
      ],
      highContrast: false,
      night: false,
    );
  }

  static NrColors dark([Color accent = defaultAccent, bool highContrast = false]) {
    final bright = _brighten(accent);
    if (highContrast) {
      return NrColors(
        canvas: const Color(0xFF000000),
        surface: const Color(0xFF0B0C0E),
        raised: const Color(0xFF1A1C20),
        sunken: const Color(0xFF26292E),
        border: const Color(0xFF7B828D),
        borderStrong: const Color(0xFFC7CCD3),
        headline: const Color(0xFFFFFFFF),
        body: const Color(0xFFFFFFFF),
        secondary: const Color(0xFFE6E8EB),
        muted: const Color(0xFFB9BEC6),
        accent: bright,
        accentSoft: bright.withValues(alpha: 0.24),
        onAccent: _onAccent(bright),
        link: Color.lerp(bright, Colors.white, 0.35)!,
        ink: const Color(0xFFFFFFFF),
        onInk: const Color(0xFF000000),
        success: const Color(0xFF8BF0AE),
        successBg: const Color(0x3322C55E),
        warning: const Color(0xFFFFD66B),
        warningBg: const Color(0x33F59E0B),
        danger: const Color(0xFFFFADAD),
        dangerBg: const Color(0x33EF4444),
        shadow: const [],
        shadowLg: const [],
        highContrast: true,
        night: true,
      );
    }
    return NrColors(
      canvas: const Color(0xFF0C0E11),
      surface: const Color(0xFF16191E),
      raised: const Color(0xFF1F2329),
      sunken: const Color(0xFF0A0B0D),
      border: const Color(0xFF252A31),
      borderStrong: const Color(0xFF353B44),
      headline: const Color(0xFFF5F7FA),
      body: const Color(0xFFDCE0E6),
      secondary: const Color(0xFF9BA3AF),
      muted: const Color(0xFF6B737F),
      accent: bright,
      accentSoft: bright.withValues(alpha: 0.16),
      onAccent: _onAccent(bright),
      // El acento sobre la superficie oscura no siempre llega a 4.5:1: el texto de enlace va aclarado.
      link: Color.lerp(bright, Colors.white, 0.45)!,
      ink: const Color(0xFFF5F7FA),
      onInk: const Color(0xFF0C0E11),
      success: const Color(0xFF6EE7A0),
      successBg: const Color(0x2422C55E),
      warning: const Color(0xFFFCD34D),
      warningBg: const Color(0x24F59E0B),
      danger: const Color(0xFFFCA5A5),
      dangerBg: const Color(0x26EF4444),
      shadow: const [BoxShadow(color: Color(0x40000000), offset: Offset(0, 6), blurRadius: 18, spreadRadius: -8)],
      shadowLg: const [BoxShadow(color: Color(0x80000000), offset: Offset(0, 18), blurRadius: 40, spreadRadius: -12)],
      highContrast: false,
      night: true,
    );
  }

  /// Un acento muy claro se oscurece para que el texto blanco encima se lea.
  static Color _deepen(Color c) {
    final hsl = HSLColor.fromColor(c);
    return hsl.lightness > 0.45 ? hsl.withLightness(0.38).toColor() : c;
  }

  /// En oscuro, un acento muy profundo se aclara un poco para que se vea.
  static Color _brighten(Color c) {
    final hsl = HSLColor.fromColor(c);
    return hsl.lightness < 0.5 ? hsl.withLightness((hsl.lightness + 0.08).clamp(0, 0.62)).toColor() : c;
  }

  /// Tono estable a partir de un texto (avatares).
  static Color hueFor(String key) {
    var h = 0;
    for (final c in key.codeUnits) {
      h = (h * 31 + c) & 0x7fffffff;
    }
    return hues[h % hues.length];
  }

  /// Fondo suave de un tono para chips e íconos.
  Color tint(Color c, [double amount = 0.12]) =>
      night ? c.withValues(alpha: amount + 0.06) : Color.alphaBlend(c.withValues(alpha: amount), surface);

  /// Un tono legible como texto sobre su propio tinte.
  Color tone(Color c) => night ? Color.lerp(c, Colors.white, 0.35)! : Color.lerp(c, Colors.black, 0.12)!;

  @override
  NrColors copyWith({Color? accent}) {
    final base = night ? NrColors.dark(accent ?? this.accent, highContrast) : NrColors.light(accent ?? this.accent, highContrast);
    return base;
  }

  @override
  NrColors lerp(ThemeExtension<NrColors>? other, double t) {
    if (other is! NrColors) return this;
    Color l(Color a, Color b) => Color.lerp(a, b, t)!;
    return NrColors(
      canvas: l(canvas, other.canvas),
      surface: l(surface, other.surface),
      raised: l(raised, other.raised),
      sunken: l(sunken, other.sunken),
      border: l(border, other.border),
      borderStrong: l(borderStrong, other.borderStrong),
      headline: l(headline, other.headline),
      body: l(body, other.body),
      secondary: l(secondary, other.secondary),
      muted: l(muted, other.muted),
      accent: l(accent, other.accent),
      accentSoft: l(accentSoft, other.accentSoft),
      onAccent: l(onAccent, other.onAccent),
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
      shadowLg: t < 0.5 ? shadowLg : other.shadowLg,
      highContrast: t < 0.5 ? highContrast : other.highContrast,
      night: t < 0.5 ? night : other.night,
    );
  }
}

/// Espaciado en múltiplos de 4.
abstract final class NrSpace {
  static const double xxs = 2;
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 20;
  static const double xxl = 24;
  static const double xxxl = 32;
  static const double huge = 48;
  static const double gutter = 16;

  /// Lo que deja libre al final de una lista con barra de acción inferior.
  static const double bottomBar = 120;
}

abstract final class NrRadius {
  static const double sm = 6;
  static const double md = 8;
  static const double lg = 12;
  static const double xl = 14;
  static const double xxl = 18;
  static const double hero = 24;
  static const double pill = 999;
}

/// Tamaños mínimos de toque (uso con una mano, en la calle).
abstract final class NrTouch {
  static const double min = 48;
  static const double comfy = 56;
  static const double big = 64;
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
