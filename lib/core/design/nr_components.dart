import 'package:flutter/material.dart';

import '../util/decimal.dart';
import 'nr_tokens.dart';
import 'nr_typography.dart';

/// Tarjeta base: superficie, borde de 1px, sombra suave solo en claro.
class NrCard extends StatelessWidget {
  const NrCard({super.key, required this.child, this.padding = const EdgeInsets.all(NrSpace.lg), this.onTap, this.borderColor});

  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final Color? borderColor;

  @override
  Widget build(BuildContext context) {
    final nr = context.nr;
    final radius = BorderRadius.circular(NrRadius.xxl);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: nr.surface,
        borderRadius: radius,
        border: Border.all(color: borderColor ?? nr.border),
        boxShadow: nr.shadow,
      ),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(onTap: onTap, borderRadius: radius, child: Padding(padding: padding, child: child)),
      ),
    );
  }
}

/// Filas agrupadas en una tarjeta con divisores.
class NrGroup extends StatelessWidget {
  const NrGroup({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[];
    for (var i = 0; i < children.length; i++) {
      rows.add(children[i]);
      if (i < children.length - 1) rows.add(Divider(height: 1, color: context.nr.border));
    }
    return NrCard(
      padding: EdgeInsets.zero,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(NrRadius.xxl),
        child: Column(mainAxisSize: MainAxisSize.min, children: rows),
      ),
    );
  }
}

class NrSectionHeader extends StatelessWidget {
  const NrSectionHeader(this.title, {super.key, this.action, this.onAction, this.count});

  final String title;
  final String? action;
  final VoidCallback? onAction;
  final int? count;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(NrSpace.xs, NrSpace.xl, NrSpace.xs, NrSpace.sm),
      child: Row(children: [
        Text(title.toUpperCase(), style: NrText.eyebrow(context)),
        if (count != null) ...[const SizedBox(width: 6), Text('$count', style: NrText.eyebrow(context))],
        const Spacer(),
        if (action != null)
          GestureDetector(
            onTap: onAction,
            child: Text(action!, style: NrText.label(context).copyWith(color: context.nr.link, fontWeight: FontWeight.w600)),
          ),
      ]),
    );
  }
}

enum NrTone { neutral, accent, success, warning, danger }

class NrPill extends StatelessWidget {
  const NrPill(this.label, {super.key, this.tone = NrTone.neutral, this.icon});

  final String label;
  final NrTone tone;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final nr = context.nr;
    final (bg, fg) = switch (tone) {
      NrTone.neutral => (nr.raised, nr.secondary),
      NrTone.accent => (nr.accentSoft, nr.accent),
      NrTone.success => (nr.successBg, nr.success),
      NrTone.warning => (nr.warningBg, nr.warning),
      NrTone.danger => (nr.dangerBg, nr.danger),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(NrRadius.pill)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        if (icon != null) ...[Icon(icon, size: 12, color: fg), const SizedBox(width: 4)],
        Text(label, style: NrText.caption(context).copyWith(color: fg, fontWeight: FontWeight.w600)),
      ]),
    );
  }
}

/// Ficha de KPI: rótulo, cifra y variación contra el periodo anterior.
class NrMetric extends StatelessWidget {
  const NrMetric({super.key, required this.label, required this.value, this.change, this.caption});

  final String label;
  final String value;
  final num? change;
  final String? caption;

  @override
  Widget build(BuildContext context) {
    final nr = context.nr;
    return NrCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label.toUpperCase(), style: NrText.eyebrow(context)),
        const SizedBox(height: NrSpace.sm),
        FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: Text(value, style: NrText.stat(context))),
        if (change != null || caption != null) ...[
          const SizedBox(height: NrSpace.xs),
          Row(children: [
            if (change != null)
              Text(
                '${change! >= 0 ? '▲' : '▼'} ${change!.abs().toStringAsFixed(1)} %',
                style: NrText.caption(context).copyWith(color: change! >= 0 ? nr.success : nr.danger, fontWeight: FontWeight.w600),
              ),
            if (caption != null) ...[const SizedBox(width: 6), Flexible(child: Text(caption!, style: NrText.caption(context)))],
          ]),
        ],
      ]),
    );
  }
}

class NrListRow extends StatelessWidget {
  const NrListRow({super.key, required this.title, this.subtitle, this.leading, this.trailing, this.onTap});

  final String title;
  final String? subtitle;
  final Widget? leading;
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: NrSpace.lg, vertical: NrSpace.md),
        child: Row(children: [
          if (leading != null) ...[leading!, const SizedBox(width: NrSpace.md)],
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: NrText.headline(context).copyWith(fontSize: 15), maxLines: 2, overflow: TextOverflow.ellipsis),
              if (subtitle != null && subtitle!.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(subtitle!, style: NrText.bodySm(context), maxLines: 2, overflow: TextOverflow.ellipsis),
              ],
            ]),
          ),
          if (trailing != null) ...[const SizedBox(width: NrSpace.sm), trailing!],
        ]),
      ),
    );
  }
}

/// Avatar de iniciales con un tono estable por nombre.
class NrAvatar extends StatelessWidget {
  const NrAvatar(this.name, {super.key, this.size = 40});

  final String name;
  final double size;

  @override
  Widget build(BuildContext context) {
    final words = name.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
    final initials = words.take(2).map((w) => w[0].toUpperCase()).join();
    final nr = context.nr;
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: nr.accentSoft, borderRadius: BorderRadius.circular(NrRadius.xl)),
      child: Text(initials.isEmpty ? '·' : initials, style: NrText.label(context).copyWith(color: nr.accent, fontWeight: FontWeight.w700)),
    );
  }
}

class NrMoney extends StatelessWidget {
  const NrMoney(this.value, {super.key, this.size = 15, this.color});

  final Object? value;
  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) =>
      Text(money(value), style: NrText.money(context, size: size).copyWith(color: color));
}

class NrEmpty extends StatelessWidget {
  const NrEmpty({super.key, required this.icon, required this.title, this.message, this.action, this.onAction});

  final IconData icon;
  final String title;
  final String? message;
  final String? action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(NrSpace.xxxl),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 40, color: context.nr.muted),
          const SizedBox(height: NrSpace.md),
          Text(title, style: NrText.headline(context), textAlign: TextAlign.center),
          if (message != null) ...[
            const SizedBox(height: NrSpace.xs),
            Text(message!, style: NrText.bodySm(context), textAlign: TextAlign.center),
          ],
          if (action != null) ...[
            const SizedBox(height: NrSpace.lg),
            OutlinedButton(onPressed: onAction, child: Text(action!)),
          ],
        ]),
      ),
    );
  }
}

class NrErrorView extends StatelessWidget {
  const NrErrorView(this.error, {super.key, this.onRetry});

  final Object error;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) => NrEmpty(
        icon: Icons.error_outline,
        title: 'No se pudo cargar',
        message: error.toString(),
        action: onRetry == null ? null : 'Reintentar',
        onAction: onRetry,
      );
}

/// Barra inferior con el botón principal de una pantalla de captura.
class NrBottomAction extends StatelessWidget {
  const NrBottomAction({super.key, required this.label, required this.onPressed, this.busy = false, this.leading});

  final String label;
  final VoidCallback? onPressed;
  final bool busy;
  final Widget? leading;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(NrSpace.lg, NrSpace.md, NrSpace.lg, NrSpace.md),
        decoration: BoxDecoration(color: context.nr.surface, border: Border(top: BorderSide(color: context.nr.border))),
        child: Row(children: [
          if (leading != null) ...[Expanded(child: leading!), const SizedBox(width: NrSpace.md)],
          Expanded(
            child: FilledButton(
              onPressed: busy ? null : onPressed,
              child: busy
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : Text(label),
            ),
          ),
        ]),
      ),
    );
  }
}

void showSnack(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}
