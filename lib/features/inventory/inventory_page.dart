import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/design/design.dart';
import '../../core/providers.dart';
import '../../core/widgets/sync_indicator.dart';

/// Terminal de inventario: traslados, ajustes y conteos según permisos, con
/// el almacén de trabajo a la vista.
class InventoryPage extends ConsumerWidget {
  const InventoryPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(sessionProvider);
    if (s == null) return const SizedBox.shrink();
    final nr = context.nr;
    final tiles = <(IconData, String, String, String, Color)>[
      if (s.can('transfer_requests.create')) (Icons.move_down_rounded, 'Solicitar', 'Pedir a otro almacén', '/inventory/movement/transfer-requests', NrColors.hues[0]),
      if (s.can('inventory_transfers.create') && s.can('transfer_requests.view'))
        (Icons.playlist_add_check_rounded, 'Surtir', 'Una solicitud, escaneando', '/inventory/requests', NrColors.hues[2]),
      if (s.can('inventory_transfers.create')) (Icons.swap_horiz_rounded, 'Traslado', 'Entre almacenes', '/inventory/movement/transfers', NrColors.hues[5]),
      if (s.can('goods_receipts.create')) (Icons.add_box_rounded, 'Entrada', 'Ajuste con causalidad', '/inventory/movement/goods-receipts', NrColors.hues[1]),
      if (s.can('goods_issues.create')) (Icons.indeterminate_check_box_rounded, 'Salida', 'Ajuste con causalidad', '/inventory/movement/goods-issues', NrColors.hues[4]),
      if (s.canAny(['inventory_counts.update', 'inventory_counts.view'])) (Icons.fact_check_rounded, 'Conteo físico', 'Unirse y escanear', '/inventory/counts', NrColors.hues[3]),
      if (s.canCheckPrices) (Icons.qr_code_scanner_rounded, 'Checador', 'Precio y existencia', '/checker', NrColors.hues[7]),
    ];
    return NrScrollPage(
      eyebrow: 'Terminal de mano',
      title: 'Inventario',
      actions: const [SyncIndicator()],
      children: [
        NrCard(
          depth: NrDepth.floating,
          radius: NrRadius.hero,
          onTap: () => context.push('/warehouse'),
          child: Row(children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(color: nr.accentSoft, borderRadius: BorderRadius.circular(NrRadius.xl)),
              child: Icon(Icons.warehouse_rounded, color: nr.night ? nr.link : nr.accent),
            ),
            const SizedBox(width: NrSpace.md),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('ALMACÉN DE TRABAJO', style: NrText.eyebrow(context)),
                const SizedBox(height: 2),
                Text(s.warehouseName ?? 'Sin elegir', style: NrText.title(context).copyWith(fontSize: 18)),
              ]),
            ),
            Text('Cambiar', style: NrText.label(context).copyWith(color: nr.link, fontWeight: FontWeight.w600)),
          ]),
        ),
        NrSectionHeader('Movimientos'),
        if (tiles.isEmpty)
          const NrEmpty(icon: Icons.lock_outline_rounded, title: 'Sin permisos de inventario')
        else
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: NrSpace.md,
            crossAxisSpacing: NrSpace.md,
            childAspectRatio: 1.45,
            children: [
              for (final (i, t) in tiles.indexed)
                NrEntrance(index: i, child: NrTile(icon: t.$1, title: t.$2, subtitle: t.$3, color: t.$5, onTap: () => context.push(t.$4))),
            ],
          ),
      ],
    );
  }
}
