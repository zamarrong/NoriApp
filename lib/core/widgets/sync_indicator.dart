import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../design/design.dart';
import '../providers.dart';

/// Píldora de estado de sincronización para la barra superior: sin conexión,
/// enviando, pendientes, con errores o al día. Abre la cola.
class SyncIndicator extends ConsumerWidget {
  const SyncIndicator({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(syncStatusProvider);
    final (label, tone, icon) = switch (s) {
      _ when s.syncing => ('Sincronizando', NrTone.accent, Icons.sync),
      _ when s.failed > 0 => ('${s.failed} con error', NrTone.danger, Icons.error_outline),
      _ when !s.online => (s.pending > 0 ? 'Sin señal · ${s.pending}' : 'Sin señal', NrTone.warning, Icons.cloud_off),
      _ when s.pending > 0 => ('${s.pending} por enviar', NrTone.warning, Icons.cloud_upload_outlined),
      _ => ('Al día', NrTone.success, Icons.cloud_done_outlined),
    };
    return Padding(
      padding: const EdgeInsets.only(right: NrSpace.sm),
      child: InkWell(
        borderRadius: BorderRadius.circular(NrRadius.pill),
        onTap: () => context.push('/sync'),
        child: Semantics(label: 'Estado de sincronización: $label', child: NrPill(label, tone: tone, icon: icon)),
      ),
    );
  }
}
