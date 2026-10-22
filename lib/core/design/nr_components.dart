import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

import '../api/api_error.dart';
import '../util/decimal.dart';
import 'nr_illustration.dart';
import 'nr_motion.dart';
import 'nr_tokens.dart';
import 'nr_typography.dart';

/// Profundidad de una superficie.
enum NrDepth { flat, card, floating }

/// Tarjeta base: superficie con sombra en capas (claro), filo de 1px
/// (oscuro y alto contraste) y, si se toca, se hunde un poco. [accent] pinta
/// una franja a la izquierda (lo activo, lo urgente).
class NrCard extends StatelessWidget {
  const NrCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(NrSpace.lg),
    this.onTap,
    this.onLongPress,
    this.borderColor,
    this.accent,
    this.color,
    this.gradient,
    this.depth = NrDepth.card,
    this.radius = NrRadius.xxl,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final Color? borderColor;
  final Color? accent;
  final Color? color;
  final Gradient? gradient;
  final NrDepth depth;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final nr = context.nr;
    final r = BorderRadius.circular(radius);
    final bordered = nr.night || nr.highContrast || depth == NrDepth.flat;
    final border = borderColor ?? (bordered ? (nr.highContrast ? nr.borderStrong : nr.border) : null);
    Widget content = Padding(padding: padding, child: child);
    if (accent != null) {
      content = Stack(children: [
        content,
        Positioned(left: 0, top: 14, bottom: 14, child: Container(width: 3, decoration: BoxDecoration(color: accent, borderRadius: const BorderRadius.horizontal(right: Radius.circular(3))))),
      ]);
    }
    final box = DecoratedBox(
      decoration: BoxDecoration(
        color: gradient == null ? (color ?? nr.surface) : null,
        gradient: gradient,
        borderRadius: r,
        border: border == null ? null : Border.all(color: border, width: nr.highContrast ? 1.5 : 1),
        boxShadow: switch (depth) {
          NrDepth.flat => null,
          NrDepth.card => nr.shadow,
          NrDepth.floating => nr.shadowLg,
        },
      ),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: onTap,
          onLongPress: onLongPress,
          borderRadius: r,
          child: ClipRRect(borderRadius: r, child: content),
        ),
      ),
    );
    return onTap == null ? box : NrPressable(scale: 0.985, child: box);
  }
}

/// Filas agrupadas en una tarjeta con divisores sangrados.
class NrGroup extends StatelessWidget {
  const NrGroup({super.key, required this.children, this.inset = NrSpace.lg});

  final List<Widget> children;
  final double inset;

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[];
    for (var i = 0; i < children.length; i++) {
      rows.add(children[i]);
      if (i < children.length - 1) rows.add(Divider(height: 1, indent: inset, color: context.nr.border));
    }
    return NrCard(padding: EdgeInsets.zero, child: Column(mainAxisSize: MainAxisSize.min, children: rows));
  }
}

class NrSectionHeader extends StatelessWidget {
  const NrSectionHeader(this.title, {super.key, this.action, this.onAction, this.count, this.trailing});

  final String title;
  final String? action;
  final VoidCallback? onAction;
  final int? count;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final nr = context.nr;
    return Padding(
      padding: const EdgeInsets.fromLTRB(NrSpace.xs, NrSpace.xxl, NrSpace.xs, NrSpace.sm),
      child: Row(children: [
        Text(title.toUpperCase(), style: NrText.eyebrow(context)),
        if (count != null) ...[
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
            decoration: BoxDecoration(color: nr.night ? nr.raised : nr.sunken, borderRadius: BorderRadius.circular(NrRadius.pill)),
            child: Text('$count', style: NrText.eyebrow(context).copyWith(letterSpacing: 0)),
          ),
        ],
        const Spacer(),
        ?trailing,
        if (action != null)
          InkWell(
            borderRadius: BorderRadius.circular(NrRadius.md),
            onTap: onAction,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
              child: Text(action!, style: NrText.label(context).copyWith(color: nr.link, fontWeight: FontWeight.w600)),
            ),
          ),
      ]),
    );
  }
}

enum NrTone { neutral, accent, success, warning, danger }

extension NrToneColors on NrColors {
  (Color bg, Color fg) toneColors(NrTone tone) => switch (tone) {
        NrTone.neutral => (night ? raised : sunken, secondary),
        NrTone.accent => (accentSoft, night ? link : accent),
        NrTone.success => (successBg, success),
        NrTone.warning => (warningBg, warning),
        NrTone.danger => (dangerBg, danger),
      };

  Color toneColor(NrTone tone) => toneColors(tone).$2;
}

/// Chip de estado: tinte suave con un punto (o ícono) del mismo tono.
class NrPill extends StatelessWidget {
  const NrPill(this.label, {super.key, this.tone = NrTone.neutral, this.icon, this.dot = false, this.large = false});

  final String label;
  final NrTone tone;
  final IconData? icon;
  final bool dot;
  final bool large;

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = context.nr.toneColors(tone);
    return Container(
      padding: EdgeInsets.symmetric(horizontal: large ? 10 : 8, vertical: large ? 5 : 3),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(NrRadius.pill)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        if (icon != null) ...[Icon(icon, size: large ? 14 : 12, color: fg), const SizedBox(width: 4)],
        if (dot && icon == null) ...[Container(width: 6, height: 6, decoration: BoxDecoration(color: fg, shape: BoxShape.circle)), const SizedBox(width: 5)],
        Flexible(
          child: Text(label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: (large ? NrText.label(context) : NrText.caption(context)).copyWith(color: fg, fontWeight: FontWeight.w600)),
        ),
      ]),
    );
  }
}

/// Monto con jerarquía: pesos grandes y centavos pequeños ("$12,480" + ".50").
/// Con [animate] cuenta desde 0 al aparecer y viaja entre valores.
class NrAmount extends StatelessWidget {
  const NrAmount(this.value, {super.key, this.size = 28, this.color, this.animate = false, this.showCents = true, this.weight = FontWeight.w700, this.prefix = ''});

  final Object? value;
  final double size;
  final Color? color;
  final bool animate;
  final bool showCents;
  final FontWeight weight;
  final String prefix;

  @override
  Widget build(BuildContext context) {
    final v = Dec.parse(value).toDouble();
    if (!animate) return _text(context, v);
    return NrCountUp(value: v, builder: _text);
  }

  Widget _text(BuildContext context, double v) {
    final full = money(v.toStringAsFixed(2));
    final dot = full.lastIndexOf('.');
    final whole = dot > 0 ? full.substring(0, dot) : full;
    final cents = dot > 0 ? full.substring(dot) : '';
    final main = NrText.money(context, size: size, weight: weight).copyWith(color: color, height: 1.05);
    final small = main.copyWith(fontSize: size * 0.56, letterSpacing: 0, color: (color ?? context.nr.headline).withValues(alpha: 0.5));
    return FittedBox(
      fit: BoxFit.scaleDown,
      alignment: Alignment.centerLeft,
      child: Text.rich(
        TextSpan(children: [
          TextSpan(text: '$prefix$whole', style: main),
          if (showCents && cents.isNotEmpty) TextSpan(text: cents, style: small),
        ]),
        maxLines: 1,
      ),
    );
  }
}

class NrMoney extends StatelessWidget {
  const NrMoney(this.value, {super.key, this.size = 15, this.color, this.weight = FontWeight.w600});

  final Object? value;
  final double size;
  final Color? color;
  final FontWeight weight;

  @override
  Widget build(BuildContext context) => Text(money(value), style: NrText.money(context, size: size, weight: weight).copyWith(color: color));
}

/// Ficha de KPI: rótulo con punto, cifra que cuenta, variación y tendencia.
class NrMetric extends StatelessWidget {
  const NrMetric({super.key, required this.label, required this.value, this.change, this.caption, this.amount, this.dot, this.spark, this.onTap});

  final String label;

  /// Texto de la cifra (si no es un monto).
  final String value;

  /// Monto: se anima y separa centavos.
  final Object? amount;
  final num? change;
  final String? caption;
  final Color? dot;
  final Widget? spark;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final nr = context.nr;
    return NrCard(
      onTap: onTap,
      padding: const EdgeInsets.fromLTRB(NrSpace.lg, NrSpace.md, NrSpace.lg, NrSpace.md),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
        Row(children: [
          if (dot != null) ...[Container(width: 7, height: 7, decoration: BoxDecoration(color: dot, shape: BoxShape.circle)), const SizedBox(width: 6)],
          Expanded(child: Text(label.toUpperCase(), style: NrText.eyebrow(context), maxLines: 1, overflow: TextOverflow.ellipsis)),
        ]),
        const SizedBox(height: NrSpace.sm),
        if (amount != null)
          NrAmount(amount, size: 24, animate: true)
        else
          FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: Text(value, style: NrText.stat(context))),
        if (change != null || caption != null) ...[
          const SizedBox(height: 6),
          Row(children: [
            if (change != null) NrDelta(change!),
            if (caption != null) ...[const SizedBox(width: 6), Flexible(child: Text(caption!, style: NrText.caption(context), maxLines: 1, overflow: TextOverflow.ellipsis))],
          ]),
        ],
        if (spark != null) ...[const SizedBox(height: NrSpace.sm), spark!],
        if (spark == null && change == null && caption == null) SizedBox(height: nr.highContrast ? 2 : 0),
      ]),
    );
  }
}

/// Variación con flecha: verde si sube, roja si baja.
class NrDelta extends StatelessWidget {
  const NrDelta(this.change, {super.key, this.inverse = false});

  final num change;

  /// true = bajar es bueno (vencido).
  final bool inverse;

  @override
  Widget build(BuildContext context) {
    final nr = context.nr;
    final up = change >= 0;
    final good = inverse ? !up : up;
    final c = change == 0 ? nr.secondary : (good ? nr.success : nr.danger);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(color: change == 0 ? nr.raised : (good ? nr.successBg : nr.dangerBg), borderRadius: BorderRadius.circular(NrRadius.pill)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(up ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded, size: 12, color: c),
        const SizedBox(width: 2),
        Text('${change.abs().toStringAsFixed(change.abs() >= 100 ? 0 : 1)} %', style: NrText.caption(context).copyWith(color: c, fontWeight: FontWeight.w700)),
      ]),
    );
  }
}

class NrListRow extends StatelessWidget {
  const NrListRow({super.key, required this.title, this.subtitle, this.leading, this.trailing, this.onTap, this.titleStyle, this.dense = false});

  final String title;
  final String? subtitle;
  final Widget? leading;
  final Widget? trailing;
  final VoidCallback? onTap;
  final TextStyle? titleStyle;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: dense ? NrTouch.min : NrTouch.comfy),
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: NrSpace.lg, vertical: dense ? NrSpace.sm : NrSpace.md),
          child: Row(children: [
            if (leading != null) ...[
              IconTheme.merge(data: IconThemeData(color: context.nr.secondary, size: 22), child: leading!),
              const SizedBox(width: NrSpace.md),
            ],
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                Text(title, style: titleStyle ?? NrText.headline(context).copyWith(fontSize: 15), maxLines: 2, overflow: TextOverflow.ellipsis),
                if (subtitle != null && subtitle!.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(subtitle!, style: NrText.bodySm(context), maxLines: 2, overflow: TextOverflow.ellipsis),
                ],
              ]),
            ),
            if (trailing != null) ...[
              const SizedBox(width: NrSpace.sm),
              IconTheme.merge(data: IconThemeData(color: context.nr.muted, size: 20), child: trailing!),
            ],
          ]),
        ),
      ),
    );
  }
}

/// Avatar de iniciales con un tono estable por nombre (o la imagen del cliente).
class NrAvatar extends StatelessWidget {
  const NrAvatar(this.name, {super.key, this.size = 40, this.heroTag, this.imageUrl, this.color});

  final String name;
  final double size;
  final Object? heroTag;
  final String? imageUrl;
  final Color? color;

  static String initialsOf(String name) {
    final words = name.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty && RegExp(r'[A-Za-zÁÉÍÓÚÑáéíóúñ0-9]').hasMatch(w[0])).toList();
    return words.take(2).map((w) => w[0].toUpperCase()).join();
  }

  @override
  Widget build(BuildContext context) {
    final nr = context.nr;
    final hue = color ?? NrColors.hueFor(name);
    final initials = initialsOf(name);
    final r = BorderRadius.circular(size * 0.32);
    Widget avatar = Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: nr.tint(hue, 0.14), borderRadius: r),
      child: Text(initials.isEmpty ? '·' : initials,
          style: TextStyle(fontFamily: NrText.family, fontSize: size * 0.36, fontWeight: FontWeight.w700, color: nr.tone(hue), letterSpacing: -0.3)),
    );
    if (imageUrl != null && imageUrl!.isNotEmpty) {
      avatar = ClipRRect(
        borderRadius: r,
        child: Image.network(imageUrl!, width: size, height: size, fit: BoxFit.cover, errorBuilder: (_, _, _) => avatar),
      );
    }
    return heroTag == null ? avatar : Hero(tag: heroTag!, child: Material(type: MaterialType.transparency, child: avatar));
  }
}

/// Imagen de un artículo o, sin imagen, un monograma con su tono.
class NrThumb extends StatelessWidget {
  const NrThumb({super.key, required this.name, this.url, this.size = 48, this.heroTag});

  final String name;
  final String? url;
  final double size;
  final Object? heroTag;

  @override
  Widget build(BuildContext context) {
    final nr = context.nr;
    final hue = NrColors.hueFor(name);
    final r = BorderRadius.circular(size * 0.26);
    final fallback = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: r,
        gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [nr.tint(hue, 0.10), nr.tint(hue, 0.22)]),
      ),
      child: Icon(Icons.inventory_2_outlined, size: size * 0.42, color: nr.tone(hue).withValues(alpha: 0.75)),
    );
    Widget thumb = url == null || url!.isEmpty
        ? fallback
        : ClipRRect(
            borderRadius: r,
            child: Container(
              width: size,
              height: size,
              color: nr.raised,
              child: Image.network(url!, fit: BoxFit.cover, errorBuilder: (_, _, _) => fallback),
            ),
          );
    return heroTag == null ? thumb : Hero(tag: heroTag!, child: thumb);
  }
}

/// Estado vacío con ilustración y una acción sugerida.
class NrEmpty extends StatelessWidget {
  const NrEmpty({super.key, required this.icon, required this.title, this.message, this.action, this.onAction, this.color, this.compact = false});

  final IconData icon;
  final String title;
  final String? message;
  final String? action;
  final VoidCallback? onAction;
  final Color? color;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: NrSpace.xxxl, vertical: compact ? NrSpace.xl : NrSpace.xxxl),
        child: NrEntrance(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            NrIllustration(icon: icon, color: color, size: compact ? 0.75 : 1),
            SizedBox(height: compact ? NrSpace.md : NrSpace.xl),
            Text(title, style: NrText.title(context).copyWith(fontSize: compact ? 17 : 20), textAlign: TextAlign.center),
            if (message != null) ...[
              const SizedBox(height: NrSpace.sm),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 300),
                child: Text(message!, style: NrText.bodySm(context).copyWith(fontSize: 14), textAlign: TextAlign.center),
              ),
            ],
            if (action != null) ...[
              const SizedBox(height: NrSpace.xl),
              NrButton(label: action!, onPressed: onAction, expand: false, variant: NrButtonVariant.secondary),
            ],
          ]),
        ),
      ),
    );
  }
}

class NrErrorView extends StatelessWidget {
  const NrErrorView(this.error, {super.key, this.onRetry});

  final Object error;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final e = error;
    final offline = e is ApiException && e.isNetwork;
    return NrEmpty(
      icon: offline ? Icons.cloud_off_rounded : Icons.error_outline_rounded,
      color: offline ? context.nr.warning : context.nr.danger,
      title: offline ? 'Sin conexión' : 'No se pudo cargar',
      message: offline ? 'Revisa tu señal. Lo que capturas se guarda y se envía solo.' : e.toString(),
      action: onRetry == null ? null : 'Reintentar',
      onAction: onRetry,
    );
  }
}

enum NrButtonVariant { primary, secondary, ghost, danger, ink }

/// Botón grande de la app: acento con brillo (principal), superficie con filo
/// (secundario), sin fondo (fantasma). Se hunde al tocar y muestra un
/// indicador mientras trabaja.
class NrButton extends StatelessWidget {
  const NrButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.busy = false,
    this.variant = NrButtonVariant.primary,
    this.expand = true,
    this.height = NrTouch.comfy,
    this.trailing,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool busy;
  final NrButtonVariant variant;
  final bool expand;
  final double height;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final nr = context.nr;
    final enabled = onPressed != null && !busy;
    final (bg, fg, border) = switch (variant) {
      NrButtonVariant.primary => (nr.accent, nr.onAccent, null),
      NrButtonVariant.ink => (nr.ink, nr.onInk, null),
      NrButtonVariant.secondary => (nr.surface, nr.headline, nr.highContrast ? nr.borderStrong : nr.borderStrong),
      NrButtonVariant.ghost => (Colors.transparent, nr.link, null),
      NrButtonVariant.danger => (nr.dangerBg, nr.danger, null),
    };
    final disabled = !enabled && !busy;
    final glow = variant == NrButtonVariant.primary && enabled && !nr.highContrast;
    final r = BorderRadius.circular(height >= NrTouch.comfy ? NrRadius.xl : NrRadius.lg);
    final child = AnimatedContainer(
      duration: NrMotion.fast,
      height: height,
      padding: const EdgeInsets.symmetric(horizontal: NrSpace.xl),
      decoration: BoxDecoration(
        color: disabled ? (variant == NrButtonVariant.ghost ? Colors.transparent : nr.raised) : bg,
        borderRadius: r,
        border: border == null || disabled ? null : Border.all(color: border, width: nr.highContrast ? 1.5 : 1),
        gradient: variant == NrButtonVariant.primary && !disabled ? LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color.lerp(bg, Colors.white, 0.08)!, bg]) : null,
        boxShadow: glow ? [BoxShadow(color: bg.withValues(alpha: 0.42), offset: const Offset(0, 10), blurRadius: 22, spreadRadius: -10)] : null,
      ),
      child: Row(mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min, mainAxisAlignment: MainAxisAlignment.center, children: [
        if (busy)
          SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.2, color: fg))
        else ...[
          if (icon != null) ...[Icon(icon, size: 20, color: disabled ? nr.muted : fg), const SizedBox(width: NrSpace.sm)],
          Flexible(
            child: Text(label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: NrText.headline(context).copyWith(color: disabled ? nr.muted : fg, fontSize: height >= NrTouch.comfy ? 16 : 15)),
          ),
          if (trailing != null) ...[const SizedBox(width: NrSpace.sm), trailing!],
        ],
      ]),
    );
    return Semantics(
      button: true,
      enabled: enabled,
      label: label,
      child: NrPressable(
        enabled: enabled,
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            borderRadius: r,
            onTap: enabled
                ? () {
                    NrHaptics.tap();
                    onPressed!();
                  }
                : null,
            child: child,
          ),
        ),
      ),
    );
  }
}

/// Botón cuadrado de un solo ícono (llamar, escanear) con el mismo alto que [NrButton].
class NrSquareButton extends StatelessWidget {
  const NrSquareButton({super.key, required this.icon, required this.onPressed, required this.tooltip, this.size = NrTouch.min, this.primary = false});

  final IconData icon;
  final VoidCallback? onPressed;
  final String tooltip;
  final double size;
  final bool primary;

  @override
  Widget build(BuildContext context) {
    final nr = context.nr;
    final r = BorderRadius.circular(size >= NrTouch.comfy ? NrRadius.xl : NrRadius.lg);
    return Tooltip(
      message: tooltip,
      child: NrPressable(
        enabled: onPressed != null,
        child: Material(
          color: primary ? nr.accent : nr.surface,
          shape: RoundedRectangleBorder(borderRadius: r, side: primary ? BorderSide.none : BorderSide(color: nr.borderStrong, width: nr.highContrast ? 1.5 : 1)),
          child: InkWell(
            borderRadius: r,
            onTap: onPressed == null
                ? null
                : () {
                    NrHaptics.tap();
                    onPressed!();
                  },
            child: SizedBox.square(dimension: size, child: Icon(icon, size: 22, color: primary ? nr.onAccent : (onPressed == null ? nr.muted : nr.headline))),
          ),
        ),
      ),
    );
  }
}

/// Barra inferior flotante de una pantalla de captura: resumen a la izquierda
/// (opcional) y la acción principal al alcance del pulgar.
class NrBottomAction extends StatelessWidget {
  const NrBottomAction({super.key, required this.label, required this.onPressed, this.busy = false, this.leading, this.summary, this.icon, this.secondary});

  final String label;
  final VoidCallback? onPressed;
  final bool busy;

  /// Botón o widget a la izquierda del principal (mismo alto).
  final Widget? leading;

  /// Resumen arriba de los botones (total, artículos).
  final Widget? summary;
  final IconData? icon;

  /// Fila extra bajo el botón principal (acción secundaria).
  final Widget? secondary;

  @override
  Widget build(BuildContext context) {
    final nr = context.nr;
    return NrBottomBar(
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        if (summary != null) ...[summary!, const SizedBox(height: NrSpace.md)],
        Row(children: [
          if (leading != null) ...[
            if (leading is Icon)
              Container(
                width: NrTouch.comfy,
                height: NrTouch.comfy,
                decoration: BoxDecoration(color: nr.raised, borderRadius: BorderRadius.circular(NrRadius.xl)),
                child: IconTheme.merge(data: IconThemeData(color: nr.headline), child: leading!),
              )
            else
              Expanded(child: leading!),
            const SizedBox(width: NrSpace.md),
          ],
          Expanded(flex: leading is Icon ? 1 : 1, child: NrButton(label: label, onPressed: onPressed, busy: busy, icon: icon)),
        ]),
        if (secondary != null) ...[const SizedBox(height: NrSpace.sm), secondary!],
      ]),
    );
  }
}

/// Contenedor translúcido pegado abajo (desenfoca lo que pasa detrás).
class NrBottomBar extends StatelessWidget {
  const NrBottomBar({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final nr = context.nr;
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: nr.surface.withValues(alpha: nr.highContrast ? 1 : 0.86),
            border: Border(top: BorderSide(color: nr.highContrast ? nr.borderStrong : nr.border)),
          ),
          child: SafeArea(
            top: false,
            child: Padding(padding: const EdgeInsets.fromLTRB(NrSpace.lg, NrSpace.md, NrSpace.lg, NrSpace.md), child: child),
          ),
        ),
      ),
    );
  }
}

/// Aviso a lo ancho (sin señal, datos guardados).
class NrBanner extends StatelessWidget {
  const NrBanner({super.key, required this.message, this.tone = NrTone.warning, this.icon, this.action, this.onAction});

  final String message;
  final NrTone tone;
  final IconData? icon;
  final String? action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = context.nr.toneColors(tone);
    return NrEntrance(
      offset: -8,
      child: Container(
        padding: const EdgeInsets.fromLTRB(NrSpace.md, NrSpace.sm, NrSpace.sm, NrSpace.sm),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(NrRadius.lg)),
        child: Row(children: [
          Icon(icon ?? Icons.cloud_off_rounded, size: 18, color: fg),
          const SizedBox(width: NrSpace.sm),
          Expanded(child: Text(message, style: NrText.label(context).copyWith(color: fg))),
          if (action != null) TextButton(onPressed: onAction, child: Text(action!, style: TextStyle(color: fg))),
        ]),
      ),
    );
  }
}

/// Acción circular con rótulo (llamar, navegar, WhatsApp).
class NrIconAction extends StatelessWidget {
  const NrIconAction({super.key, required this.icon, required this.label, required this.onTap, this.color});

  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final nr = context.nr;
    final c = color ?? nr.accent;
    return Semantics(
      button: true,
      label: label,
      child: NrPressable(
        enabled: onTap != null,
        child: InkWell(
          borderRadius: BorderRadius.circular(NrRadius.lg),
          onTap: onTap == null
              ? null
              : () {
                  NrHaptics.tap();
                  onTap!();
                },
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: NrSpace.xs, horizontal: NrSpace.xs),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(color: nr.tint(c, 0.12), borderRadius: BorderRadius.circular(NrRadius.xl)),
                child: Icon(icon, color: nr.tone(c), size: 24),
              ),
              const SizedBox(height: 6),
              Text(label, style: NrText.caption(context).copyWith(color: nr.body, fontWeight: FontWeight.w500), maxLines: 1, overflow: TextOverflow.ellipsis),
            ]),
          ),
        ),
      ),
    );
  }
}

/// Ficha de acción: ícono en un cuadro teñido, título, detalle y una insignia.
class NrTile extends StatelessWidget {
  const NrTile({super.key, required this.icon, required this.title, this.subtitle, this.onTap, this.color, this.badge, this.badgeTone = NrTone.warning, this.highlight = false});

  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback? onTap;
  final Color? color;
  final String? badge;
  final NrTone badgeTone;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final nr = context.nr;
    final c = color ?? nr.accent;
    return NrCard(
      onTap: onTap,
      padding: const EdgeInsets.all(NrSpace.md),
      borderColor: highlight ? c.withValues(alpha: 0.55) : null,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(color: nr.tint(c, 0.13), borderRadius: BorderRadius.circular(NrRadius.lg)),
            child: Icon(icon, color: nr.tone(c), size: 22),
          ),
          const Spacer(),
          if (badge != null) NrPill(badge!, tone: badgeTone),
        ]),
        const Spacer(),
        Text(title, style: NrText.headline(context), maxLines: 1, overflow: TextOverflow.ellipsis),
        if (subtitle != null) ...[
          const SizedBox(height: 2),
          Text(subtitle!, style: NrText.caption(context), maxLines: 1, overflow: TextOverflow.ellipsis),
        ],
      ]),
    );
  }
}

/// Bloque gris de carga (dentro de [NrShimmer]).
class NrSkeleton extends StatelessWidget {
  const NrSkeleton({super.key, this.width, this.height = 14, this.radius = 6});

  final double? width;
  final double height;
  final double radius;

  @override
  Widget build(BuildContext context) => Container(
        width: width,
        height: height,
        decoration: BoxDecoration(color: context.nr.night ? context.nr.raised : context.nr.sunken, borderRadius: BorderRadius.circular(radius)),
      );
}

/// Lista de carga con la forma de las filas reales.
class NrSkeletonList extends StatelessWidget {
  const NrSkeletonList({super.key, this.count = 6, this.header = false, this.padding = const EdgeInsets.all(NrSpace.gutter)});

  final int count;
  final bool header;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return NrShimmer(
      child: ListView(physics: const NeverScrollableScrollPhysics(), padding: padding, children: [
        if (header) ...[
          NrCard(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: const [
              NrSkeleton(width: 90, height: 10),
              SizedBox(height: 12),
              NrSkeleton(width: 180, height: 28),
              SizedBox(height: 16),
              NrSkeleton(height: 8),
            ]),
          ),
          const SizedBox(height: NrSpace.xl),
        ],
        NrCard(
          padding: EdgeInsets.zero,
          child: Column(children: [
            for (var i = 0; i < count; i++)
              Padding(
                padding: const EdgeInsets.all(NrSpace.lg),
                child: Row(children: [
                  const NrSkeleton(width: 40, height: 40, radius: 12),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      NrSkeleton(width: 120.0 + (i * 37) % 90, height: 13),
                      const SizedBox(height: 8),
                      NrSkeleton(width: 80.0 + (i * 53) % 70, height: 10),
                    ]),
                  ),
                  const NrSkeleton(width: 56, height: 14),
                ]),
              ),
          ]),
        ),
      ]),
    );
  }
}

/// Campo de búsqueda grande (dedo y escáner).
class NrSearchField extends StatelessWidget {
  const NrSearchField({super.key, this.controller, this.hint = 'Buscar', this.onChanged, this.onSubmitted, this.onScan, this.autofocus = false, this.focusNode});

  final TextEditingController? controller;
  final String hint;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final VoidCallback? onScan;
  final bool autofocus;
  final FocusNode? focusNode;

  @override
  Widget build(BuildContext context) {
    final nr = context.nr;
    return TextField(
      controller: controller,
      focusNode: focusNode,
      autofocus: autofocus,
      onChanged: onChanged,
      onSubmitted: onSubmitted,
      textInputAction: TextInputAction.search,
      style: NrText.body(context).copyWith(fontSize: 16),
      decoration: InputDecoration(
        hintText: hint,
        prefixIcon: Icon(Icons.search_rounded, color: nr.muted),
        suffixIcon: onScan == null
            ? null
            : Padding(
                padding: const EdgeInsets.all(6),
                child: Material(
                  color: nr.accentSoft,
                  borderRadius: BorderRadius.circular(NrRadius.md),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(NrRadius.md),
                    onTap: onScan,
                    child: Tooltip(message: 'Escanear', child: Icon(Icons.qr_code_scanner_rounded, color: nr.night ? nr.link : nr.accent, size: 20)),
                  ),
                ),
              ),
        contentPadding: const EdgeInsets.symmetric(vertical: 16),
      ),
    );
  }
}

/// Selector segmentado con una píldora que se desliza.
class NrSegmented<T> extends StatelessWidget {
  const NrSegmented({super.key, required this.values, required this.labels, required this.selected, required this.onChanged, this.icons});

  final List<T> values;
  final List<String> labels;
  final List<IconData>? icons;
  final T selected;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    final nr = context.nr;
    final index = values.indexOf(selected).clamp(0, values.length - 1);
    return Container(
      height: 44,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(color: nr.night ? nr.raised : nr.sunken, borderRadius: BorderRadius.circular(NrRadius.lg)),
      child: LayoutBuilder(builder: (context, box) {
        final w = box.maxWidth / values.length;
        return Stack(children: [
          AnimatedPositioned(
            duration: nrReduceMotion(context) ? Duration.zero : NrMotion.base,
            curve: NrMotion.emphasized,
            left: w * index,
            top: 0,
            bottom: 0,
            width: w,
            child: Container(
              decoration: BoxDecoration(
                color: nr.night ? nr.borderStrong : nr.surface,
                borderRadius: BorderRadius.circular(NrRadius.md),
                boxShadow: nr.night ? null : const [BoxShadow(color: Color(0x14000000), blurRadius: 4, offset: Offset(0, 1))],
              ),
            ),
          ),
          Row(children: [
            for (var i = 0; i < values.length; i++)
              Expanded(
                child: Semantics(
                  selected: i == index,
                  button: true,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(NrRadius.md),
                    onTap: () {
                      NrHaptics.tap();
                      onChanged(values[i]);
                    },
                    child: Center(
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        if (icons != null) ...[Icon(icons![i], size: 16, color: i == index ? nr.headline : nr.secondary), const SizedBox(width: 6)],
                        Text(labels[i], style: NrText.label(context).copyWith(color: i == index ? nr.headline : nr.secondary, fontWeight: FontWeight.w600)),
                      ]),
                    ),
                  ),
                ),
              ),
          ]),
        ]);
      }),
    );
  }
}

/// Paso de cantidad: − cantidad +, con objetivos grandes.
class NrStepper extends StatelessWidget {
  const NrStepper({super.key, required this.value, required this.onChanged, this.max, this.onTapValue, this.compact = false});

  final Dec value;
  final ValueChanged<Dec> onChanged;
  final Dec? max;
  final VoidCallback? onTapValue;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final nr = context.nr;
    final s = compact ? 36.0 : 44.0;
    final active = value > Dec.zero;
    Widget btn(IconData icon, VoidCallback? onTap, {bool primary = false}) => Material(
          color: primary && onTap != null ? nr.accent : (nr.night ? nr.borderStrong : nr.surface),
          borderRadius: BorderRadius.circular(NrRadius.lg),
          child: InkWell(
            borderRadius: BorderRadius.circular(NrRadius.lg),
            onTap: onTap == null
                ? null
                : () {
                    NrHaptics.tap();
                    onTap();
                  },
            child: SizedBox.square(dimension: s, child: Icon(icon, size: 20, color: primary && onTap != null ? nr.onAccent : (onTap == null ? nr.muted : nr.headline))),
          ),
        );
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(color: active ? nr.accentSoft : (nr.night ? nr.raised : nr.sunken), borderRadius: BorderRadius.circular(NrRadius.lg + 3)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        btn(value <= Dec.one ? Icons.delete_outline_rounded : Icons.remove_rounded, value.isZero ? null : () => onChanged(value - Dec.one)),
        GestureDetector(
          onTap: onTapValue,
          behavior: HitTestBehavior.opaque,
          child: SizedBox(
            width: compact ? 40 : 48,
            child: AnimatedSwitcher(
              duration: nrReduceMotion(context) ? Duration.zero : NrMotion.fast,
              transitionBuilder: (c, a) => ScaleTransition(scale: a, child: FadeTransition(opacity: a, child: c)),
              child: Text(value.toQty(),
                  key: ValueKey(value.toQty()),
                  textAlign: TextAlign.center,
                  style: NrText.money(context, size: compact ? 16 : 19, weight: FontWeight.w700).copyWith(color: active ? (nr.night ? nr.link : nr.accent) : nr.muted)),
            ),
          ),
        ),
        btn(Icons.add_rounded, max != null && value >= max! ? null : () => onChanged(value + Dec.one), primary: true),
      ]),
    );
  }
}

/// Hoja inferior con título y el mismo margen en toda la app.
Future<T?> showNrSheet<T>(BuildContext context, {required WidgetBuilder builder, String? title, String? subtitle, bool scrollable = true}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: scrollable,
    useSafeArea: true,
    builder: (ctx) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(NrSpace.xl, 0, NrSpace.xl, NrSpace.xl),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            if (title != null) Text(title, style: NrText.title(ctx)),
            if (subtitle != null) ...[const SizedBox(height: 2), Text(subtitle, style: NrText.bodySm(ctx))],
            if (title != null) const SizedBox(height: NrSpace.lg),
            Flexible(child: builder(ctx)),
          ]),
        ),
      ),
    ),
  );
}

/// Aviso breve abajo, con ícono según el tono.
void showSnack(BuildContext context, String message, {NrTone tone = NrTone.neutral, String? action, VoidCallback? onAction}) {
  final nr = context.nr;
  final icon = switch (tone) {
    NrTone.success => Icons.check_circle_rounded,
    NrTone.warning => Icons.cloud_queue_rounded,
    NrTone.danger => Icons.error_rounded,
    _ => null,
  };
  final iconColor = switch (tone) {
    NrTone.success => nr.night ? nr.success : const Color(0xFF4ADE80),
    NrTone.warning => const Color(0xFFFCD34D),
    NrTone.danger => const Color(0xFFFCA5A5),
    _ => nr.onInk,
  };
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      content: Row(children: [
        if (icon != null) ...[Icon(icon, size: 20, color: nr.night ? (tone == NrTone.success ? nr.success : iconColor) : iconColor), const SizedBox(width: NrSpace.sm)],
        Expanded(child: Text(message)),
      ]),
      action: action == null ? null : SnackBarAction(label: action, onPressed: onAction ?? () {}),
    ));
}
