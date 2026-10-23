import 'package:flutter/material.dart';

import 'nr_motion.dart';
import 'nr_tokens.dart';
import 'nr_typography.dart';

/// Pantalla de pestaña con título grande (al estilo iOS): el título grande
/// vive en el contenido y, al desplazarse, aparece el compacto en la barra.
class NrScrollPage extends StatefulWidget {
  const NrScrollPage({
    super.key,
    required this.title,
    required this.children,
    this.eyebrow,
    this.subtitle,
    this.actions = const [],
    this.onRefresh,
    this.bottom,
    this.floating,
    this.padding = const EdgeInsets.fromLTRB(NrSpace.gutter, 0, NrSpace.gutter, NrSpace.xxxl),
    this.leading,
    this.leadingWidth,
    this.headerTrailing,
  });

  final String title;
  final String? eyebrow;
  final Widget? subtitle;
  final List<Widget> actions;
  final List<Widget> children;
  final Future<void> Function()? onRefresh;
  final Widget? bottom;
  final Widget? floating;
  final EdgeInsetsGeometry padding;
  final Widget? leading;
  final double? leadingWidth;
  final Widget? headerTrailing;

  @override
  State<NrScrollPage> createState() => _NrScrollPageState();
}

class _NrScrollPageState extends State<NrScrollPage> {
  bool _scrolled = false;

  bool _onScroll(ScrollNotification n) {
    if (n.depth != 0) return false;
    final s = n.metrics.pixels > 44;
    if (s != _scrolled) setState(() => _scrolled = s);
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final nr = context.nr;
    Widget list = ListView(
      physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
      padding: widget.padding,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(NrSpace.xs, NrSpace.xs, NrSpace.xs, NrSpace.lg),
          child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                if (widget.eyebrow != null) ...[Text(widget.eyebrow!.toUpperCase(), style: NrText.eyebrow(context)), const SizedBox(height: 6)],
                Text(widget.title, style: NrText.display(context)),
                if (widget.subtitle != null) ...[
                  const SizedBox(height: 6),
                  DefaultTextStyle(style: NrText.body(context).copyWith(color: nr.secondary, fontSize: 15), child: widget.subtitle!),
                ],
              ]),
            ),
            ?widget.headerTrailing,
          ]),
        ),
        ...widget.children,
      ],
    );
    if (widget.onRefresh != null) {
      list = RefreshIndicator(
        color: nr.accent,
        onRefresh: () {
          NrHaptics.action();
          return widget.onRefresh!();
        },
        child: list,
      );
    }
    return Scaffold(
      appBar: AppBar(
        leading: widget.leading,
        leadingWidth: widget.leadingWidth,
        backgroundColor: _scrolled ? nr.surface.withValues(alpha: 0.96) : nr.canvas,
        shape: Border(bottom: BorderSide(color: _scrolled ? nr.border : Colors.transparent)),
        title: AnimatedOpacity(
          duration: NrMotion.fast,
          opacity: _scrolled ? 1 : 0,
          child: Text(widget.title),
        ),
        actions: widget.actions,
      ),
      body: NotificationListener<ScrollNotification>(onNotification: _onScroll, child: list),
      bottomNavigationBar: widget.bottom,
      floatingActionButton: widget.floating,
    );
  }
}
