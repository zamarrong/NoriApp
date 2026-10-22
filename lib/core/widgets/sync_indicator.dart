import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../design/design.dart';
import '../providers.dart';

/// Estado de sincronización para la barra superior: un punto de color (late
/// mientras envía) y un rótulo corto. Sin señal, con pendientes, con errores o
/// al día. Abre la cola.
class SyncIndicator extends ConsumerWidget {
  const SyncIndicator({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(syncStatusProvider);
    final nr = context.nr;
    final (label, tone, pulse) = switch (s) {
      _ when s.syncing => ('Sincronizando', NrTone.accent, true),
      _ when s.failed > 0 => ('${s.failed} con error', NrTone.danger, false),
      _ when !s.online => (s.pending > 0 ? 'Sin señal · ${s.pending}' : 'Sin señal', NrTone.warning, false),
      _ when s.pending > 0 => ('${s.pending} por enviar', NrTone.warning, true),
      _ => ('Al día', NrTone.success, false),
    };
    final (bg, fg) = nr.toneColors(tone);
    return Padding(
      padding: const EdgeInsets.only(right: NrSpace.md),
      child: Semantics(
        button: true,
        label: 'Estado de sincronización: $label',
        child: InkWell(
          borderRadius: BorderRadius.circular(NrRadius.pill),
          onTap: () => context.push('/sync'),
          child: AnimatedContainer(
            duration: NrMotion.base,
            height: 32,
            padding: const EdgeInsets.only(left: 6, right: 12),
            decoration: BoxDecoration(color: tone == NrTone.success ? (nr.night ? nr.raised : nr.surface) : bg, borderRadius: BorderRadius.circular(NrRadius.pill), boxShadow: tone == NrTone.success ? nr.shadow : null),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              NrPulseDot(color: fg, size: 7, pulse: pulse),
              ExcludeSemantics(
                child: AnimatedSize(
                  duration: NrMotion.base,
                  curve: NrMotion.ease,
                  child: Text(label, style: NrText.caption(context).copyWith(color: tone == NrTone.success ? nr.body : fg, fontWeight: FontWeight.w600)),
                ),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}
