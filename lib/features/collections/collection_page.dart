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
      showSnack(context, 'Cobro guardado sin señal; se enviará solo.');
      Navigator.of(context).pop(true);
      return;
    }
    await showDialog<void>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        icon: Icon(Icons.check_circle, color: context.nr.success, size: 40),
        title: Text('Cobro de ${money(payment['total'] ?? paid)}'),
        content: Text(Dec.parse(payment['change'] ?? payment['change_total']) > Dec.zero
            ? 'Cambio: ${money(payment['change'] ?? payment['change_total'])}'
            : 'Registrado.'),
        actions: [
          if (ref.read(printerSettingsProvider).configured)
            TextButton(onPressed: () => printTicket(dialogCtx, ref, (b) => paymentTicket(receipt, b)), child: const Text('Imprimir')),
          if (id != null)
            TextButton(
              onPressed: () => shareDocument(dialogCtx, ref, kind: 'payment', id: id, title: 'Recibo de pago'),
              child: const Text('Enviar recibo'),
            ),
          FilledButton(onPressed: () => Navigator.pop(dialogCtx), child: const Text('Listo')),
        ],
      ),
    );
    if (mounted) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final paid = Dec.tryParse(amount.text) ?? Dec.zero;
    final (applied, leftover) = allocatePayment(paid, docs);
    return Scaffold(
      appBar: AppBar(title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Cobrar'),
        Text(widget.customerName, style: NrText.caption(context)),
      ])),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(padding: const EdgeInsets.all(NrSpace.gutter), children: [
              TextField(
                controller: amount,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                style: NrText.money(context, size: 28),
                decoration: const InputDecoration(labelText: 'Monto recibido', prefixText: r'$ '),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: NrSpace.md),
              Wrap(spacing: NrSpace.sm, runSpacing: NrSpace.sm, children: [
                for (final t in tenderTypes)
                  ChoiceChip(label: Text('${t['name']}'), selected: tender?['id'] == t['id'], onSelected: (_) => setState(() => tender = t)),
              ]),
              if (tender?['requires_reference'] == true) ...[
                const SizedBox(height: NrSpace.md),
                TextField(controller: reference, decoration: const InputDecoration(labelText: 'Referencia')),
              ],
              NrSectionHeader('Documentos abiertos', count: docs.length),
              if (offlineData) Padding(
                padding: const EdgeInsets.only(bottom: NrSpace.sm),
                child: Text('Saldos guardados; pueden no estar al día.', style: NrText.caption(context).copyWith(color: context.nr.warning)),
              ),
              if (docs.isEmpty)
                const NrCard(child: Text('Sin documentos abiertos: el cobro queda como pago a cuenta.'))
              else
                NrGroup(children: [
                  for (final d in docs)
                    NrListRow(
                      title: '${d['folio']}',
                      subtitle: [
                        'Saldo ${money(d['balance'])}',
                        if (d['due_date'] != null) 'vence ${d['due_date']}',
                        if ((d['days_overdue'] as num? ?? 0) > 0) '${d['days_overdue']} días vencido',
                      ].join(' · '),
                      trailing: applied[(d['id'] as num).toInt()] == null
                          ? null
                          : NrPill(money(applied[(d['id'] as num).toInt()]), tone: NrTone.success),
                    ),
                ]),
              if (leftover > Dec.zero) ...[
                const SizedBox(height: NrSpace.md),
                NrCard(child: Text('Sobran ${money(leftover)}: quedan como saldo a favor (pago a cuenta).')),
              ],
            ]),
      bottomNavigationBar: NrBottomAction(label: paid > Dec.zero ? 'Cobrar ${money(paid)}' : 'Cobrar', busy: busy, onPressed: paid > Dec.zero ? _submit : null),
    );
  }
}
