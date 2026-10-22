import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_client.dart';
import '../../core/api/api_error.dart';
import '../../core/authorizations/authorization_flow.dart';
import '../../core/design/design.dart';
import '../../core/providers.dart';
import '../../core/sync/outbox.dart';
import '../../core/widgets/pickers.dart';
import '../printing/printer.dart';
import '../printing/templates.dart';
import 'allocation.dart';
import 'tender_sheet.dart' show tenderIcon;

/// Cobranza: contra facturas abiertas (las más vencidas primero) o pago a cuenta.
/// Con [visitId] se registra como cobro de la visita de ruta.
class CollectionPage extends ConsumerStatefulWidget {
  const CollectionPage({super.key, required this.customerId, required this.customerName, this.visitId, this.tenderTypes});

  final int customerId;
  final String customerName;
  final int? visitId;
  final List<Map<String, dynamic>>? tenderTypes;

  @override
  ConsumerState<CollectionPage> createState() => _CollectionPageState();
}

class _CollectionPageState extends ConsumerState<CollectionPage> {
  List<Map<String, dynamic>> docs = [];
  List<Map<String, dynamic>> tenderTypes = [];
  Map<String, dynamic>? tender;
  bool loading = true;
  bool offlineData = false;
  bool busy = false;
  final amount = TextEditingController();
  final reference = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final db = ref.read(localDbProvider);
    final key = 'open_docs_${widget.customerId}';
    try {
      final r = await ref.read(apiProvider).get('/customers/${widget.customerId}/open-documents');
      docs = asList(asMap(r)['data']);
      await db.putJson(key, docs);
    } on ApiException catch (_) {
      docs = asList(await db.getJson(key));
      offlineData = true;
    }
    tenderTypes = widget.tenderTypes ?? await db.all('tender_types');
    if (tenderTypes.isEmpty) tenderTypes = ref.read(sessionProvider)?.tenderTypes ?? [];
    tenderTypes = tenderTypes.where((t) => t['is_credit_document'] != true).toList();
    tender = tenderTypes.firstOrNull;
    final owed = docs.fold(Dec.zero, (s, d) => s + Dec.parse(d['balance']).max(Dec.zero));
    amount.text = owed.isZero ? '' : owed.toFixed(2);
    if (mounted) setState(() => loading = false);
  }

  Future<void> _submit() async {
    final paid = Dec.tryParse(amount.text) ?? Dec.zero;
    if (paid <= Dec.zero || tender == null) return;
    final (applied, leftover) = allocatePayment(paid, docs);
    final tenders = [
      {'tender_type_id': tender!['id'], 'amount': paid.toJson(2), if (reference.text.trim().isNotEmpty) 'reference': reference.text.trim()}
    ];
    final op = widget.visitId != null
        ? OutboxOp.create('POST', '/route/visits/${widget.visitId}/collection',
            body: {'tenders': tenders, if (applied.isNotEmpty) 'document_ids': applied.keys.toList()}, label: 'Cobro ${widget.customerName}')
        : OutboxOp.create('POST', '/payments',
            body: {
              'business_partner_id': widget.customerId,
              'applications': [for (final e in applied.entries) {'document_id': e.key, 'amount': e.value.toJson(2)}],
              'tenders': tenders,
              if (applied.isEmpty || !leftover.isZero) 'on_account': true,
            },
            label: 'Cobro ${widget.customerName}');
    setState(() => busy = true);
    final r = await sendWithAuthorization(context, ref, op);
    if (!mounted) return;
    setState(() => busy = false);
    if (r == null) return;
    final owed = docs.fold(Dec.zero, (s, d) => s + Dec.parse(d['balance']).max(Dec.zero));
    final appliedTotal = applied.values.fold(Dec.zero, (s, v) => s + v);
    final folios = {for (final d in docs) (d['id'] as num).toInt(): '${d['folio']}'};
    var payment = r.queued ? <String, dynamic>{} : asMap(widget.visitId != null ? asMap(r.response)['payment'] : unwrap(asMap(r.response)));
    final id = (payment['id'] as num?)?.toInt();
    // El cobro de ruta solo regresa id y total: el folio viene del detalle.
    if (id != null && payment['folio'] == null) {
      try {
        payment = {...payment, ...asMap(unwrap(await ref.read(apiProvider).get('/payments/$id')))};
      } on ApiException catch (_) {}
    }
    final (paidTenders, localChange) = await printTenders(ref, tenders, paid);
    final serverChange = payment['change'] ?? payment['change_total'];
    final receipt = PrintPayment(
      folio: payment['folio'] as String?,
      date: DateTime.now(),
      customer: widget.customerName,
      total: payment['total'] == null ? paid : Dec.parse(payment['total']),
      tenders: paidTenders,
      applications: [for (final e in applied.entries) (folios[e.key] ?? '${e.key}', e.value)],
      change: serverChange == null ? localChange : Dec.parse(serverChange),
      unapplied: leftover,
      balanceAfter: offlineData ? null : (owed - appliedTotal).max(Dec.zero),
    );
    if (!mounted) return;
    await autoPrint(context, ref, 'payment', (b) => paymentTicket(receipt, b));
    if (!mounted) return;
    if (r.queued) {
      NrHaptics.success();
      showSnack(context, 'Cobro guardado sin señal; se enviará solo.', tone: NrTone.warning);
      Navigator.of(context).pop(true);
      return;
    }
    NrHaptics.success();
    final change = Dec.parse(payment['change'] ?? payment['change_total']);
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: false,
      builder: (dialogCtx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(NrSpace.xl, NrSpace.xl, NrSpace.xl, NrSpace.lg),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            const Center(child: NrSuccessMark(size: 76)),
            const SizedBox(height: NrSpace.sm),
            Text('Cobro registrado', textAlign: TextAlign.center, style: NrText.title(dialogCtx)),
            const SizedBox(height: NrSpace.md),
            Center(child: NrAmount(payment['total'] ?? paid.toFixed(2), size: 40, animate: true)),
            if (change > Dec.zero) ...[
              const SizedBox(height: NrSpace.sm),
              Center(child: NrPill('Cambio ${money(change)}', tone: NrTone.success, large: true, icon: Icons.savings_rounded)),
            ],
            const SizedBox(height: NrSpace.xxl),
            Row(children: [
              if (ref.read(printerSettingsProvider).configured)
                Expanded(child: NrButton(label: 'Imprimir', icon: Icons.print_rounded, variant: NrButtonVariant.secondary, onPressed: () => printTicket(dialogCtx, ref, (b) => paymentTicket(receipt, b)))),
              if (ref.read(printerSettingsProvider).configured && id != null) const SizedBox(width: NrSpace.md),
              if (id != null)
                Expanded(
                  child: NrButton(
                    label: 'Enviar recibo',
                    icon: Icons.ios_share_rounded,
                    variant: NrButtonVariant.secondary,
                    onPressed: () => shareDocument(dialogCtx, ref, kind: 'payment', id: id, title: 'Recibo de pago'),
                  ),
                ),
            ]),
            const SizedBox(height: NrSpace.md),
            NrButton(label: 'Listo', onPressed: () => Navigator.pop(dialogCtx)),
          ]),
        ),
      ),
    );
    if (mounted) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final nr = context.nr;
    final paid = Dec.tryParse(amount.text) ?? Dec.zero;
    final (applied, leftover) = allocatePayment(paid, docs);
    final owed = docs.fold(Dec.zero, (s, d) => s + Dec.parse(d['balance']).max(Dec.zero));
    final overdue = docs.where((d) => (d['days_overdue'] as num? ?? 0) > 0).length;
    return Scaffold(
      appBar: AppBar(title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Cobrar'),
        Text(widget.customerName, style: NrText.caption(context), maxLines: 1, overflow: TextOverflow.ellipsis),
      ])),
      body: loading
          ? const NrSkeletonList(header: true, count: 3)
          : ListView(padding: const EdgeInsets.fromLTRB(NrSpace.gutter, NrSpace.xs, NrSpace.gutter, NrSpace.xxxl), children: [
              NrCard(
                depth: NrDepth.floating,
                radius: NrRadius.hero,
                padding: const EdgeInsets.all(NrSpace.xl),
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  Row(children: [
                    Expanded(child: Text('DEBE', style: NrText.eyebrow(context))),
                    if (overdue > 0) NrPill('$overdue vencido${overdue == 1 ? '' : 's'}', tone: NrTone.danger, dot: true),
                  ]),
                  const SizedBox(height: 4),
                  NrAmount(owed, size: 22, animate: true, color: overdue > 0 ? nr.danger : null),
                  const SizedBox(height: NrSpace.lg),
                  TextField(
                    controller: amount,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    style: NrText.money(context, size: 34, weight: FontWeight.w700),
                    decoration: const InputDecoration(labelText: 'Monto recibido', prefixText: r'$ '),
                    onChanged: (_) => setState(() {}),
                  ),
                  if (!owed.isZero) ...[
                    const SizedBox(height: NrSpace.sm),
                    Wrap(spacing: NrSpace.sm, children: [
                      ChoiceChip(label: const Text('Todo'), selected: paid == owed, onSelected: (_) => setState(() => amount.text = owed.toFixed(2))),
                      if (docs.isNotEmpty && Dec.parse(docs.first['balance']) < owed)
                        ChoiceChip(
                          label: Text('Solo ${docs.first['folio']}'),
                          selected: paid == Dec.parse(docs.first['balance']),
                          onSelected: (_) => setState(() => amount.text = Dec.parse(docs.first['balance']).toFixed(2)),
                        ),
                    ]),
                  ],
                ]),
              ),
              NrSectionHeader('Forma de pago'),
              SizedBox(
                height: 76,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: tenderTypes.length,
                  separatorBuilder: (_, _) => const SizedBox(width: NrSpace.sm),
                  itemBuilder: (_, i) {
                    final t = tenderTypes[i];
                    final on = tender?['id'] == t['id'];
                    return SizedBox(
                      width: 112,
                      child: NrCard(
                        padding: const EdgeInsets.all(NrSpace.md),
                        color: on ? nr.accentSoft : null,
                        borderColor: on ? nr.accent : null,
                        onTap: () {
                          NrHaptics.tap();
                          setState(() => tender = t);
                        },
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Icon(tenderIcon(t), size: 22, color: on ? (nr.night ? nr.link : nr.accent) : nr.secondary),
                          const Spacer(),
                          Text('${t['name']}', maxLines: 1, overflow: TextOverflow.ellipsis, style: NrText.label(context).copyWith(fontWeight: FontWeight.w600)),
                        ]),
                      ),
                    );
                  },
                ),
              ),
              if (tender?['requires_reference'] == true) ...[
                const SizedBox(height: NrSpace.md),
                TextField(controller: reference, decoration: const InputDecoration(labelText: 'Referencia', prefixIcon: Icon(Icons.tag_rounded))),
              ],
              NrSectionHeader('Se aplica a', count: docs.length),
              if (offlineData) const Padding(padding: EdgeInsets.only(bottom: NrSpace.sm), child: NrBanner(message: 'Saldos guardados; pueden no estar al día.')),
              if (docs.isEmpty)
                const NrCard(depth: NrDepth.flat, child: NrEmpty(compact: true, icon: Icons.account_balance_wallet_rounded, title: 'Sin documentos abiertos', message: 'El cobro queda como pago a cuenta.'))
              else
                NrGroup(children: [
                  for (final d in docs)
                    Builder(builder: (context) {
                      final a = applied[(d['id'] as num).toInt()];
                      final balance = Dec.parse(d['balance']);
                      final full = a != null && a >= balance;
                      return NrListRow(
                        leading: AnimatedContainer(
                          duration: NrMotion.base,
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: a == null ? Colors.transparent : (full ? nr.success : nr.warning),
                            border: a == null ? Border.all(color: nr.borderStrong, width: 1.5) : null,
                          ),
                          child: a == null ? null : Icon(full ? Icons.check_rounded : Icons.more_horiz_rounded, size: 16, color: Colors.white),
                        ),
                        title: '${d['folio']}',
                        subtitle: [
                          'Saldo ${money(d['balance'])}',
                          if ((d['days_overdue'] as num? ?? 0) > 0) '${d['days_overdue']} días vencido' else if (d['due_date'] != null) 'vence ${d['due_date']}',
                        ].join(' · '),
                        trailing: a == null ? null : NrMoney(a, weight: FontWeight.w700, color: full ? nr.success : nr.warning),
                      );
                    }),
                ]),
              if (leftover > Dec.zero) ...[
                const SizedBox(height: NrSpace.md),
                NrBanner(message: 'Sobran ${money(leftover)}: quedan como saldo a favor (pago a cuenta).', tone: NrTone.accent, icon: Icons.info_outline_rounded),
              ],
            ]),
      bottomNavigationBar: NrBottomAction(label: paid > Dec.zero ? 'Cobrar ${money(paid)}' : 'Cobrar', icon: Icons.check_rounded, busy: busy, onPressed: paid > Dec.zero ? _submit : null),
    );
  }
}
