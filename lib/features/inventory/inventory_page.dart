import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/design/design.dart';
import '../../core/providers.dart';
import '../../core/widgets/sync_indicator.dart';

/// Terminal de inventario: traslados, ajustes y conteos según permisos.
class InventoryPage extends ConsumerWidget {
  const InventoryPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(sessionProvider);
    if (s == null) return const SizedBox.shrink();
    final tiles = <(IconData, String, String, String)>[
      if (s.can('transfer_requests.create')) (Icons.move_down, 'Solicitud de traslado', 'Pedir mercancía a otro almacén', '/inventory/movement/transfer-requests'),
      if (s.can('inventory_transfers.create') && s.can('transfer_requests.view'))
        (Icons.playlist_add_check, 'Surtir solicitud', 'Traslado desde una solicitud, escaneando', '/inventory/requests'),
      if (s.can('inventory_transfers.create')) (Icons.swap_horiz, 'Traslado', 'Mover mercancía entre almacenes', '/inventory/movement/transfers'),
      if (s.can('goods_receipts.create')) (Icons.add_box_outlined, 'Entrada', 'Ajuste de entrada con causalidad', '/inventory/movement/goods-receipts'),
      if (s.can('goods_issues.create')) (Icons.indeterminate_check_box_outlined, 'Salida', 'Ajuste de salida con causalidad', '/inventory/movement/goods-issues'),
      if (s.canAny(['inventory_counts.update', 'inventory_counts.view'])) (Icons.fact_check_outlined, 'Conteo físico', 'Unirse a un conteo y escanear', '/inventory/counts'),
    ];
    return Scaffold(
      appBar: AppBar(title: const Text('Inventario'), actions: const [SyncIndicator()]),
      body: ListView(padding: const EdgeInsets.all(NrSpace.gutter), children: [
        NrCard(
          onTap: () => context.push('/warehouse'),
          child: Row(children: [
            Icon(Icons.warehouse_outlined, color: context.nr.accent),
            const SizedBox(width: NrSpace.md),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('ALMACÉN DE TRABAJO', style: NrText.eyebrow(context)),
                Text(s.warehouseName ?? 'Sin elegir', style: NrText.headline(context)),
              ]),
            ),
            const Icon(Icons.chevron_right),
          ]),
        ),
        const SizedBox(height: NrSpace.lg),
        NrGroup(children: [
          for (final t in tiles)
            NrListRow(
              leading: Icon(t.$1, color: context.nr.secondary),
              title: t.$2,
              subtitle: t.$3,
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push(t.$4),
            ),
        ]),
      ]),
    );
  }
}
