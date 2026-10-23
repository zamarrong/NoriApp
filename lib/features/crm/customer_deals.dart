import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/design/design.dart';
import '../../core/providers.dart';
import 'crm_repo.dart';
import 'crm_sheets.dart';
import 'crm_widgets.dart';

/// En la ficha del cliente: sus oportunidades abiertas (de lo guardado) y el
/// botón para abrir una nueva.
class CustomerDeals extends ConsumerWidget {
  const CustomerDeals({super.key, required this.customer});

  final Map<String, dynamic> customer;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(sessionProvider);
    if (s == null || !s.canCrm) return const SizedBox.shrink();
    final id = customer['id'];
    final deals = (ref.watch(crmDealsProvider).valueOrNull?.value ?? const <Map<String, dynamic>>[])
        .where((d) => d['business_partner_id'] == id && d['status'] == 'open')
        .toList();
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      NrSectionHeader(
        'Oportunidades',
        count: deals.isEmpty ? null : deals.length,
        action: s.canCrmCreate ? 'Nueva' : null,
        onAction: () => showNewDealSheet(context, ref, customer: customer),
      ),
      if (deals.isEmpty)
        NrCard(
          depth: NrDepth.flat,
          onTap: s.canCrmCreate ? () => showNewDealSheet(context, ref, customer: customer) : null,
          child: Row(children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(color: context.nr.tint(NrColors.hues[4], 0.13), borderRadius: BorderRadius.circular(NrRadius.lg)),
              child: Icon(Icons.view_kanban_rounded, color: context.nr.tone(NrColors.hues[4])),
            ),
            const SizedBox(width: NrSpace.md),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Sin oportunidades abiertas', style: NrText.headline(context).copyWith(fontSize: 15)),
                if (s.canCrmCreate) Text('Toca para abrir una y darle seguimiento.', style: NrText.caption(context)),
              ]),
            ),
            if (s.canCrmCreate) Icon(Icons.add_rounded, color: context.nr.muted),
          ]),
        )
      else
        for (final d in deals)
          Padding(
            padding: const EdgeInsets.only(bottom: NrSpace.sm),
            child: DealCard(deal: d, showStage: true, onTap: () => context.push('/crm/deals/${d['id']}')),
          ),
    ]);
  }
}
