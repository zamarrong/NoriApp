import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/api/api_client.dart';
import '../../core/design/design.dart';
import '../../core/providers.dart';
import '../../core/sync/outbox.dart';
import '../../core/widgets/sync_indicator.dart';
import '../sales/sell_page.dart' show saleTypes, startSaleDocument, documentTypeLabels;
import 'crm_repo.dart';
import 'crm_sheets.dart';
import 'crm_widgets.dart';

/// Una oportunidad: cliente, monto, avance por etapas, acciones rápidas
/// (llamar, WhatsApp, cómo llegar, visita, nota, programar), seguimientos,
/// cotización y pedido ligados, y el historial. Ganar o perder abajo.
class DealPage extends ConsumerWidget {
  const DealPage({super.key, required this.dealId});

  final int dealId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(crmDealProvider(dealId));
    final deal = async.valueOrNull?.value;
    final s = ref.watch(sessionProvider);
    final canEdit = (s?.canCrmUpdate ?? false) && dealId > 0;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Oportunidad'),
        actions: [
          const SyncIndicator(),
          if (deal != null && canEdit)
            PopupMenuButton<String>(
              tooltip: 'Más opciones',
              onSelected: (v) => switch (v) {
                'edit' => _edit(context, ref, deal),
                'move' => showMoveSheet(context, ref, deal),
                'reopen' => _reopen(context, ref, deal),
                _ => null,
              },
              itemBuilder: (_) => [
                const PopupMenuItem(value: 'edit', child: ListTile(leading: Icon(Icons.edit_rounded), title: Text('Editar datos'), contentPadding: EdgeInsets.zero)),
                if (deal['status'] == 'open') const PopupMenuItem(value: 'move', child: ListTile(leading: Icon(Icons.swap_horiz_rounded), title: Text('Mover de etapa'), contentPadding: EdgeInsets.zero)),
                if (deal['status'] != 'open') const PopupMenuItem(value: 'reopen', child: ListTile(leading: Icon(Icons.replay_rounded), title: Text('Reabrir'), contentPadding: EdgeInsets.zero)),
              ],
            ),
        ],
      ),
      body: async.when(
        skipLoadingOnReload: true,
        loading: () => const NrSkeletonList(header: true, count: 4),
        error: (e, _) => NrErrorView(e, onRetry: () => ref.invalidate(crmDealProvider(dealId))),
        data: (c) => _Body(deal: c.value, offline: c.offline, canEdit: canEdit),
      ),
      bottomNavigationBar: deal == null || !canEdit
          ? null
          : NrBottomBar(
              child: deal['status'] == 'open'
                  ? Row(children: [
                      Expanded(
                        child: NrButton(label: 'Perdida', icon: Icons.thumb_down_alt_outlined, variant: NrButtonVariant.secondary, onPressed: () => showLoseSheet(context, ref, deal)),
                      ),
                      const SizedBox(width: NrSpace.md),
                      Expanded(child: NrButton(label: 'Ganada', icon: Icons.emoji_events_rounded, onPressed: () => winDeal(context, ref, deal))),
                    ])
                  : NrButton(label: 'Reabrir oportunidad', icon: Icons.replay_rounded, variant: NrButtonVariant.secondary, onPressed: () => _reopen(context, ref, deal)),
            ),
    );
  }

  Future<void> _reopen(BuildContext context, WidgetRef ref, Map<String, dynamic> deal) async {
    final op = OutboxOp.create('POST', '/crm/deals/$dealId/reopen', label: 'Reabrir ${deal['title']}');
    final first = asList(asMap(deal['pipeline'])['stages']).where((s) => s['outcome'] == 'open').firstOrNull;
    await crmWrite(context, ref, op, dealId: dealId, optimistic: {'status': 'open', 'stage_id': ?first?['id'], 'stage': ?first, 'closed_at': null});
  }

  Future<void> _edit(BuildContext context, WidgetRef ref, Map<String, dynamic> deal) async {
    final title = TextEditingController(text: '${deal['title'] ?? ''}');
    final amount = TextEditingController(text: Dec.parse(deal['amount']).toFixed(2));
    var close = DateTime.tryParse('${deal['expected_close_date'] ?? ''}');
    final result = await showNrSheet<Map<String, dynamic>>(
      context,
      title: 'Editar oportunidad',
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            TextField(controller: title, textCapitalization: TextCapitalization.sentences, decoration: const InputDecoration(labelText: 'Título', prefixIcon: Icon(Icons.flag_rounded))),
            const SizedBox(height: NrSpace.md),
            TextField(
              controller: amount,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
              style: NrText.money(ctx, size: 20),
              decoration: const InputDecoration(labelText: 'Monto estimado', prefixText: r'$ ', prefixIcon: Icon(Icons.payments_rounded)),
            ),
            const SizedBox(height: NrSpace.md),
            NrListRow(
              leading: const Icon(Icons.event_rounded),
              title: close == null ? 'Sin fecha de cierre' : 'Cierre estimado: ${DateFormat("d 'de' MMMM yyyy", 'es_MX').format(close!)}',
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () async {
                final d = await showDatePicker(context: ctx, firstDate: DateTime(2020), lastDate: DateTime(DateTime.now().year + 3), initialDate: close ?? DateTime.now());
                if (d != null) setState(() => close = d);
              },
            ),
            const SizedBox(height: NrSpace.xl),
            NrButton(
              label: 'Guardar',
              onPressed: () => Navigator.pop(ctx, {
                'title': title.text.trim(),
                'amount': Dec.parse(amount.text).toJson(2),
                'expected_close_date': close == null ? null : DateFormat('yyyy-MM-dd').format(close!),
              }),
            ),
          ]),
        ),
      ),
    );
    if (result == null || !context.mounted) return;
    final op = OutboxOp.create('PATCH', '/crm/deals/$dealId', body: result, label: 'Editar ${deal['title']}');
    await crmWrite(context, ref, op, dealId: dealId, optimistic: {...result, 'amount': '${result['amount']}'});
  }
}

class _Body extends ConsumerWidget {
  const _Body({required this.deal, required this.offline, required this.canEdit});

  final Map<String, dynamic> deal;
  final bool offline;
  final bool canEdit;

  int get id => (deal['id'] as num).toInt();

  Future<void> _quote(BuildContext context, WidgetRef ref) async {
    final partnerId = (deal['business_partner_id'] as num?)?.toInt();
    if (partnerId == null) return;
    final cached = await ref.read(localDbProvider).find('customers', partnerId);
    if (!context.mounted) return;
    final customer = cached ?? {...asMap(deal['partner'])};
    final quotation = saleTypes.firstWhere((t) => t.type == 'quotation');
    final saved = await startSaleDocument(context, ref, customer, quotation, extraBody: {'crm_deal_id': id});
    if (saved) refreshCrm(ref, dealId: id);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final nr = context.nr;
    final s = ref.watch(sessionProvider);
    final status = deal['status'] as String?;
    final open = status == 'open';
    final stage = asMap(deal['stage']);
    final timeline = asMap(deal['timeline']);
    final pending = asList(timeline['pending']);
    final history = asList(timeline['history']);
    final documents = asList(deal['documents']);
    final partner = asMap(deal['partner']);
    final phone = partnerPhone(deal);
    final lat = (partner['latitude'] as num?)?.toDouble();
    final lng = (partner['longitude'] as num?)?.toDouble();
    final amount = Dec.parse(deal['amount']);
    final probability = Dec.parse(deal['effective_probability'] ?? stage['probability']).toDouble();
    final canQuote = (s?.can('quotations.create') ?? false) && canEdit && open;
    final local = deal['local'] == true;
    final partnerId = (partner['id'] as num?)?.toInt();

    return RefreshIndicator(
      onRefresh: () async => ref.invalidate(crmDealProvider(id)),
      child: ListView(padding: const EdgeInsets.fromLTRB(NrSpace.gutter, NrSpace.xs, NrSpace.gutter, NrSpace.xxxl), children: [
        if (offline) const Padding(padding: EdgeInsets.only(bottom: NrSpace.md), child: NrBanner(message: 'Sin señal: datos guardados. Lo que hagas se envía solo.')),
        if (local) const Padding(padding: EdgeInsets.only(bottom: NrSpace.md), child: NrBanner(message: 'Por enviar: podrás registrar actividades cuando llegue al servidor.', icon: Icons.cloud_upload_outlined)),
        // Título y cliente
        Wrap(spacing: 6, runSpacing: 6, children: [
          if (open && stage.isNotEmpty)
            NrPill('${stage['name']}', tone: NrTone.accent, dot: true)
          else if (status == 'won')
            const NrPill('Ganada', tone: NrTone.success, icon: Icons.emoji_events_rounded)
          else if (status == 'lost')
            NrPill('Perdida${asMap(deal['loss_reason'])['name'] != null ? ' · ${asMap(deal['loss_reason'])['name']}' : ''}', tone: NrTone.danger, icon: Icons.close_rounded),
          if (deal['idle'] == true && open) const NrPill('Inactiva', tone: NrTone.warning, icon: Icons.hourglass_bottom_rounded),
          for (final t in asList(deal['tags'])) NrPill('${t['name']}'),
        ]),
        const SizedBox(height: NrSpace.sm),
        Text('${deal['title']}', style: NrText.display(context).copyWith(fontSize: 26)),
        const SizedBox(height: NrSpace.md),
        NrCard(
          padding: const EdgeInsets.symmetric(horizontal: NrSpace.md, vertical: NrSpace.md),
          onTap: partnerId == null || partner['type'] == 'lead' ? null : () => context.push('/customers/$partnerId'),
          child: Row(children: [
            NrAvatar(partnerName(deal), size: 44),
            const SizedBox(width: NrSpace.md),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(partnerName(deal), style: NrText.headline(context), maxLines: 2, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 2),
                Text(
                  [partner['code'], if (asMap(deal['contact'])['name'] != null) asMap(deal['contact'])['name'], phone].whereType<Object>().join(' · '),
                  style: NrText.caption(context),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ]),
            ),
            if (partnerId != null && partner['type'] != 'lead') Icon(Icons.chevron_right_rounded, color: nr.muted),
          ]),
        ),
        const SizedBox(height: NrSpace.lg),
        // Monto
        NrCard(
          depth: NrDepth.floating,
          radius: NrRadius.hero,
          padding: const EdgeInsets.all(NrSpace.xl),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(children: [
              Expanded(child: Text('MONTO ESTIMADO', style: NrText.eyebrow(context))),
              if (asMap(deal['owner'])['name'] != null) ...[
                NrAvatar('${asMap(deal['owner'])['name']}', size: 22),
                const SizedBox(width: 6),
                Text('${asMap(deal['owner'])['name']}'.split(' ').first, style: NrText.caption(context)),
              ],
            ]),
            const SizedBox(height: 6),
            NrAmount(amount, size: 36, animate: true),
            const SizedBox(height: NrSpace.md),
            if (open) ...[
              NrMeter(value: probability / 100, height: 6, color: stageColor(context, stage)),
              const SizedBox(height: 6),
            ],
            Row(children: [
              Expanded(
                child: Text(
                  open ? '${probability.round()} % de probabilidad · ${money(deal['weighted_amount'])} ponderado' : (status == 'won' ? 'Cerrada como ganada' : 'Cerrada como perdida'),
                  style: NrText.caption(context),
                ),
              ),
            ]),
            const SizedBox(height: NrSpace.md),
            Row(children: [
              Icon(Icons.event_rounded, size: 16, color: deal['close_overdue'] == true ? nr.danger : nr.secondary),
              const SizedBox(width: 6),
              Expanded(child: Text(
                deal['expected_close_date'] == null
                    ? 'Sin fecha de cierre'
                    : 'Cierre estimado: ${DateFormat("d 'de' MMMM", 'es_MX').format(DateTime.parse('${deal['expected_close_date']}'))}${deal['close_overdue'] == true ? ' (vencido)' : ''}',
                style: NrText.label(context).copyWith(color: deal['close_overdue'] == true ? nr.danger : null),
              )),
            ]),
            if ('${deal['loss_notes'] ?? ''}'.isNotEmpty) ...[
              const SizedBox(height: NrSpace.sm),
              Text('${deal['loss_notes']}', style: NrText.bodySm(context)),
            ],
          ]),
        ),
        // Avance por etapas
        if (open) ...[
          NrSectionHeader('Avance', action: canEdit && !local ? 'Mover' : null, onAction: () => showMoveSheet(context, ref, deal)),
          _StageStepper(deal: deal, onTap: canEdit && !local ? (st) => moveDeal(context, ref, deal, st) : null),
        ],
        // Acciones rápidas
        const SizedBox(height: NrSpace.xl),
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(child: NrIconAction(icon: Icons.call_rounded, label: 'Llamar', color: NrColors.hues[1], onTap: phone == null ? null : () => _contact(context, ref, 'call', phone))),
          Expanded(child: NrIconAction(icon: Icons.chat_rounded, label: 'WhatsApp', color: NrColors.hues[6], onTap: phone == null ? null : () => _contact(context, ref, 'whatsapp', phone))),
          Expanded(child: NrIconAction(
            icon: Icons.near_me_rounded,
            label: 'Llegar',
            color: NrColors.hues[0],
            onTap: lat == null || lng == null || (lat == 0 && lng == 0) ? null : () => navigateTo(lat, lng),
          )),
          Expanded(child: NrIconAction(icon: Icons.storefront_rounded, label: 'Visita', color: NrColors.hues[4], onTap: canEdit && !local ? () => showActivitySheet(context, ref, deal, type: 'visit') : null)),
          Expanded(child: NrIconAction(icon: Icons.sticky_note_2_rounded, label: 'Nota', color: NrColors.hues[7], onTap: canEdit && !local ? () => showActivitySheet(context, ref, deal, type: 'note') : null)),
        ]),
        // Seguimientos
        NrSectionHeader('Seguimientos', count: pending.isEmpty ? null : pending.length, action: canEdit && !local ? 'Programar' : null, onAction: () => showActivitySheet(context, ref, deal, schedule: true)),
        if (pending.isEmpty)
          NrCard(
            depth: NrDepth.flat,
            onTap: canEdit && !local ? () => showActivitySheet(context, ref, deal, schedule: true) : null,
            child: Row(children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(color: open ? nr.warningBg : nr.raised, borderRadius: BorderRadius.circular(NrRadius.lg)),
                child: Icon(open ? Icons.event_busy_rounded : Icons.event_available_rounded, color: open ? nr.warning : nr.secondary),
              ),
              const SizedBox(width: NrSpace.md),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(open ? 'Sin siguiente paso' : 'Sin pendientes', style: NrText.headline(context).copyWith(fontSize: 15)),
                  if (open) Text('Programa una llamada o visita para no perderla.', style: NrText.caption(context)),
                ]),
              ),
            ]),
          )
        else
          NrGroup(inset: 64, children: [
            for (final a in pending) ActivityTile(activity: a, onToggle: canEdit ? () => toggleActivity(context, ref, a, dealId: id) : null),
          ]),
        // Documentos
        NrSectionHeader('Cotización y pedido', count: documents.isEmpty ? null : documents.length),
        if (documents.isNotEmpty)
          NrGroup(inset: 64, children: [
            for (final d in documents)
              NrListRow(
                leading: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(color: nr.tint(NrColors.hues[2], 0.13), borderRadius: BorderRadius.circular(NrRadius.lg)),
                  child: Icon(d['type'] == 'quotation' ? Icons.request_quote_rounded : Icons.receipt_long_rounded, color: nr.tone(NrColors.hues[2]), size: 19),
                ),
                title: '${documentTypeLabels[d['type']] ?? d['type']} ${d['folio']}',
                subtitle: [
                  if (d['document_date'] != null) DateFormat('d MMM yyyy', 'es_MX').format(DateTime.parse('${d['document_date']}')).replaceAll('.', ''),
                  _docStatus(d['status'] as String?),
                ].join(' · '),
                trailing: NrMoney(d['total'], weight: FontWeight.w700),
              ),
          ]),
        if (canQuote) ...[
          if (documents.isNotEmpty) const SizedBox(height: NrSpace.md),
          NrButton(
            label: local ? 'Podrás cotizar cuando se envíe' : (documents.any((d) => d['type'] == 'quotation') ? 'Hacer otra cotización' : 'Crear cotización'),
            icon: Icons.request_quote_rounded,
            variant: NrButtonVariant.secondary,
            onPressed: local ? null : () => _quote(context, ref),
          ),
        ] else if (documents.isEmpty)
          NrCard(depth: NrDepth.flat, child: Text('Sin documentos ligados.', style: NrText.bodySm(context))),
        // Historial
        NrSectionHeader('Historial', count: history.isEmpty ? null : history.length),
        if (history.isEmpty)
          NrCard(depth: NrDepth.flat, child: Text('Aún no hay actividad.', style: NrText.bodySm(context)))
        else
          NrGroup(inset: 64, children: [for (final a in history.take(40)) ActivityTile(activity: a)]),
      ]),
    );
  }

  /// Llamar o escribir y, al volver, ofrecer registrarlo.
  Future<void> _contact(BuildContext context, WidgetRef ref, String type, String phone) async {
    if (type == 'call') {
      await callPhone(phone);
    } else {
      await openWhatsApp(phone);
    }
    if (!context.mounted || !canEdit || deal['local'] == true) return;
    await Future<void>.delayed(const Duration(milliseconds: 600));
    if (!context.mounted) return;
    showSnack(context, type == 'call' ? '¿Registras la llamada?' : '¿Registras el mensaje?',
        action: 'Registrar', onAction: () => showActivitySheet(context, ref, deal, type: type));
  }

  static String _docStatus(String? s) => switch (s) {
        'draft' => 'Borrador',
        'open' => 'Abierto',
        'closed' => 'Cerrado',
        'cancelled' => 'Cancelado',
        _ => s ?? '',
      };
}

/// Avance por etapas: puntos unidos, lo recorrido en el color de la etapa actual.
class _StageStepper extends StatelessWidget {
  const _StageStepper({required this.deal, this.onTap});

  final Map<String, dynamic> deal;
  final ValueChanged<Map<String, dynamic>>? onTap;

  @override
  Widget build(BuildContext context) {
    final nr = context.nr;
    final stages = asList(asMap(deal['pipeline'])['stages']).where((s) => s['outcome'] == 'open').toList();
    final current = stages.indexWhere((s) => s['id'] == deal['stage_id']);
    final color = stageColor(context, asMap(deal['stage']));
    return NrCard(
      padding: const EdgeInsets.fromLTRB(NrSpace.sm, NrSpace.lg, NrSpace.sm, NrSpace.md),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        for (var i = 0; i < stages.length; i++)
          Expanded(
            child: Semantics(
              button: onTap != null,
              selected: i == current,
              label: '${stages[i]['name']}',
              child: InkWell(
                borderRadius: BorderRadius.circular(NrRadius.md),
                onTap: onTap == null || i == current
                    ? null
                    : () {
                        NrHaptics.action();
                        onTap!(stages[i]);
                      },
                child: Column(children: [
                  Row(children: [
                    Expanded(child: Container(height: 3, color: i == 0 ? Colors.transparent : (i <= current ? color : nr.border))),
                    AnimatedContainer(
                      duration: NrMotion.base,
                      width: i == current ? 22 : 14,
                      height: i == current ? 22 : 14,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: i <= current ? color : nr.surface,
                        border: Border.all(color: i <= current ? color : nr.borderStrong, width: 2),
                        boxShadow: i == current && !nr.highContrast ? [BoxShadow(color: color.withValues(alpha: 0.35), blurRadius: 10, spreadRadius: 1)] : null,
                      ),
                      child: i < current ? Icon(Icons.check_rounded, size: 10, color: nr.night ? nr.canvas : Colors.white) : null,
                    ),
                    Expanded(child: Container(height: 3, color: i == stages.length - 1 ? Colors.transparent : (i < current ? color : nr.border))),
                  ]),
                  const SizedBox(height: 6),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                    child: Text(
                      '${stages[i]['name']}',
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: NrText.caption(context).copyWith(
                        fontSize: 11,
                        color: i == current ? nr.headline : nr.secondary,
                        fontWeight: i == current ? FontWeight.w700 : FontWeight.w500,
                      ),
                    ),
                  ),
                ]),
              ),
            ),
          ),
      ]),
    );
  }
}
