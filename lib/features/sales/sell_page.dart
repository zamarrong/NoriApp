import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/api/api_client.dart';
import '../../core/api/api_error.dart';
import '../../core/authorizations/authorization_flow.dart';
import '../../core/auth/session.dart';
import '../../core/design/design.dart';
import '../../core/providers.dart';
import '../../core/sync/outbox.dart';
import '../../core/widgets/pickers.dart';
import '../../core/widgets/sync_indicator.dart';
import '../collections/tender_sheet.dart';
import '../printing/printer.dart';
import '../printing/templates.dart';
import '../route/visit_page.dart' show showDoneDialog;
import '../customers/customer_card.dart';
import 'cart.dart';
import 'cart_page.dart';
import 'quick_capture.dart';

/// Un tipo de documento de venta que se puede capturar sin ruta.
class SaleType {
  const SaleType(this.type, this.label, this.permission, this.icon, {this.collects = false});

  final String type;
  final String label;
  final String permission;
  final IconData icon;

  /// Entrega y factura: se pueden cobrar en el mismo paso.
  final bool collects;
}

const saleTypes = [
  SaleType('quotation', 'Cotización', 'quotations.create', Icons.request_quote_rounded),
  SaleType('sales_order', 'Pedido', 'sales_orders.create', Icons.receipt_long_rounded),
  SaleType('delivery', 'Entrega', 'deliveries.create', Icons.local_shipping_rounded, collects: true),
  SaleType('invoice', 'Factura', 'invoices.create', Icons.receipt_rounded, collects: true),
  SaleType('return', 'Devolución', 'returns.create', Icons.assignment_return_rounded),
];

const documentTypeLabels = {
  'quotation': 'Cotización',
  'sales_order': 'Pedido',
  'delivery': 'Entrega',
  'invoice': 'Factura',
  'return': 'Devolución',
  'credit_memo': 'Nota de crédito',
  'down_payment': 'Anticipo',
  'debit_memo': 'Nota de cargo',
};

List<SaleType> allowedSaleTypes(Session s) => saleTypes.where((t) => s.can(t.permission)).toList();

/// Artículos que el checador manda a la próxima venta.
final pendingSaleItemsProvider = StateProvider<List<Map<String, dynamic>>>((ref) => []);

const _recentKey = 'recent_customers';

final recentCustomersProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  return asList(await ref.watch(localDbProvider).getJson(_recentKey));
});

Future<void> rememberCustomer(WidgetRef ref, Map<String, dynamic> c) async {
  final db = ref.read(localDbProvider);
  final list = asList(await db.getJson(_recentKey)).where((r) => r['id'] != c['id']).toList();
  final slim = {for (final k in ['id', 'code', 'name', 'trade_name', 'price_list_id', 'phone']) k: c[k]};
  await db.putJson(_recentKey, [slim, ...list].take(8).toList());
  ref.invalidate(recentCustomersProvider);
}

/// "Vender": venta libre, sin ruta. Cliente (búsqueda, recientes, escaneo o
/// alta rápida), tipo de documento según permisos y carrito.
class SellPage extends ConsumerStatefulWidget {
  const SellPage({super.key});

  @override
  ConsumerState<SellPage> createState() => _SellPageState();
}

class _SellPageState extends ConsumerState<SellPage> {
  Map<String, dynamic>? customer;

  String get _customerName => '${customer?['trade_name'] ?? customer?['name'] ?? ''}';

  Future<void> _choose(Map<String, dynamic>? c) async {
    if (c == null) return;
    setState(() => customer = c);
    await rememberCustomer(ref, c);
  }

  Future<void> _scanCustomer() async {
    final code = await scanBarcode(context);
    if (code == null || !mounted) return;
    final rows = await ref.read(localDbProvider).search('customers', code, limit: 5);
    final exact = rows.where((r) => '${r['code']}'.toLowerCase() == code.trim().toLowerCase()).firstOrNull ?? (rows.length == 1 ? rows.first : null);
    if (!mounted) return;
    if (exact == null) {
      NrHaptics.warning();
      showSnack(context, 'No se encontró el cliente $code', tone: NrTone.danger);
    } else {
      await _choose(exact);
    }
  }

  Future<void> _newCustomer() async {
    final name = TextEditingController();
    final phone = TextEditingController();
    final rfc = TextEditingController();
    final ok = await showNrSheet<bool>(
      context,
      title: 'Cliente nuevo',
      subtitle: 'Se da de alta en nori-web al guardar (necesita señal).',
      builder: (ctx) => Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        TextField(controller: name, autofocus: true, textCapitalization: TextCapitalization.words, decoration: const InputDecoration(labelText: 'Nombre o razón social', prefixIcon: Icon(Icons.storefront_rounded))),
        const SizedBox(height: NrSpace.md),
        TextField(controller: phone, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'Teléfono', prefixIcon: Icon(Icons.call_rounded))),
        const SizedBox(height: NrSpace.md),
        TextField(controller: rfc, textCapitalization: TextCapitalization.characters, decoration: const InputDecoration(labelText: 'RFC (opcional)', prefixIcon: Icon(Icons.badge_outlined))),
        const SizedBox(height: NrSpace.xl),
        NrButton(label: 'Dar de alta', icon: Icons.person_add_alt_1_rounded, onPressed: () => Navigator.pop(ctx, true)),
      ]),
    );
    if (ok != true || name.text.trim().isEmpty || !mounted) return;
    final op = OutboxOp.create('POST', '/customers',
        body: {
          'name': name.text.trim(),
          if (phone.text.trim().isNotEmpty) 'phone': phone.text.trim(),
          if (rfc.text.trim().isNotEmpty) 'rfc': rfc.text.trim().toUpperCase(),
        },
        label: 'Cliente ${name.text.trim()}');
    // El alta necesita señal: el documento lleva el id que da el servidor.
    final r = await sendWithAuthorization(context, ref, op, offline: false);
    if (r == null) return;
    final c = asMap(unwrap(r.response));
    await ref.read(localDbProvider).applySyncPage('customers', rows: [c], deleted: const []);
    await _choose(c);
  }

  Future<void> _start(SaleType t) async {
    customer ??= await pickCustomer(context);
    if (customer == null || !mounted) return;
    setState(() {});
    await rememberCustomer(ref, customer!);
    if (!mounted) return;
    final done = await startSaleDocument(context, ref, customer!, t);
    if (done && mounted) setState(() => customer = null);
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(sessionProvider);
    if (session == null) return const SizedBox.shrink();
    final types = allowedSaleTypes(session);
    final recents = ref.watch(recentCustomersProvider).valueOrNull ?? [];
    final pending = ref.watch(pendingSaleItemsProvider);
    final nr = context.nr;

    return NrScrollPage(
      eyebrow: 'Venta libre',
      title: 'Vender',
      subtitle: Text(customer == null ? 'Elige al cliente y luego el documento.' : '¿Qué le vas a hacer a ${_customerName.split(' ').first}?'),
      actions: [
        if (session.canCheckPrices) IconButton(icon: const Icon(Icons.qr_code_scanner_rounded), tooltip: 'Checador de precios', onPressed: () => context.push('/checker')),
        const SyncIndicator(),
      ],
      children: [
        if (pending.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: NrSpace.md),
            child: NrCard(
              accent: nr.accent,
              padding: const EdgeInsets.fromLTRB(NrSpace.lg, NrSpace.sm, NrSpace.sm, NrSpace.sm),
              child: Row(children: [
                Icon(Icons.shopping_basket_rounded, color: nr.night ? nr.link : nr.accent),
                const SizedBox(width: NrSpace.md),
                Expanded(child: Text('${pending.length} ${pending.length == 1 ? 'artículo' : 'artículos'} del checador esperan en la venta', style: NrText.label(context))),
                TextButton(onPressed: () => ref.read(pendingSaleItemsProvider.notifier).state = [], child: const Text('Quitar')),
              ]),
            ),
          ),
        _StepLabel(number: 1, label: 'Cliente', done: customer != null),
        NrSwitcher(
          child: customer == null
              ? Column(key: const ValueKey('pick'), crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  NrCard(
                    depth: NrDepth.floating,
                    onTap: () async => _choose(await pickCustomer(context)),
                    padding: const EdgeInsets.symmetric(horizontal: NrSpace.lg, vertical: NrSpace.lg),
                    child: Row(children: [
                      Icon(Icons.search_rounded, color: nr.muted),
                      const SizedBox(width: NrSpace.md),
                      Expanded(child: Text('Nombre, código, RFC o teléfono', style: NrText.body(context).copyWith(color: nr.muted))),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(color: nr.accentSoft, borderRadius: BorderRadius.circular(NrRadius.md)),
                        child: Text('Buscar', style: NrText.label(context).copyWith(color: nr.night ? nr.link : nr.accent, fontWeight: FontWeight.w700)),
                      ),
                    ]),
                  ),
                  const SizedBox(height: NrSpace.md),
                  Row(children: [
                    Expanded(child: NrButton(label: 'Escanear', icon: Icons.qr_code_scanner_rounded, variant: NrButtonVariant.secondary, height: NrTouch.min, onPressed: _scanCustomer)),
                    const SizedBox(width: NrSpace.md),
                    Expanded(child: NrButton(label: 'Cliente nuevo', icon: Icons.person_add_alt_1_rounded, variant: NrButtonVariant.secondary, height: NrTouch.min, onPressed: _newCustomer)),
                  ]),
                  if (recents.isNotEmpty) ...[
                    const SizedBox(height: NrSpace.lg),
                    Text('RECIENTES', style: NrText.eyebrow(context)),
                    const SizedBox(height: NrSpace.sm),
                    SizedBox(
                      height: 104,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        clipBehavior: Clip.none,
                        itemCount: recents.length,
                        separatorBuilder: (_, _) => const SizedBox(width: NrSpace.sm),
                        itemBuilder: (_, i) {
                          final c = recents[i];
                          final name = '${c['trade_name'] ?? c['name']}';
                          return NrEntrance(
                            index: i,
                            child: SizedBox(
                              width: 112,
                              child: NrCard(
                                padding: const EdgeInsets.all(NrSpace.md),
                                onTap: () async {
                                  final full = await ref.read(localDbProvider).find('customers', (c['id'] as num).toInt());
                                  await _choose(full ?? c);
                                },
                                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                  NrAvatar(name, size: 36),
                                  const Spacer(),
                                  Text(name, style: NrText.label(context).copyWith(fontWeight: FontWeight.w600), maxLines: 2, overflow: TextOverflow.ellipsis),
                                ]),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ])
              : CustomerCard(
                  key: ValueKey(customer!['id']),
                  customer: customer!,
                  onChange: () => setState(() => customer = null),
                  onTap: () => context.push('/customers/${customer!['id']}'),
                ),
        ),
        const SizedBox(height: NrSpace.sm),
        _StepLabel(number: 2, label: 'Documento', done: false),
        if (types.isEmpty)
          const NrCard(child: NrEmpty(compact: true, icon: Icons.lock_outline_rounded, title: 'Sin permiso', message: 'Tu usuario no puede crear documentos de venta.'))
        else
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: NrSpace.md,
            crossAxisSpacing: NrSpace.md,
            childAspectRatio: 1.45,
            children: [
              for (final (i, t) in types.indexed)
                NrEntrance(
                  index: i,
                  child: NrTile(
                    icon: t.icon,
                    title: t.label,
                    subtitle: t.collects && session.canCollect ? 'Con cobro' : saleTypeHints[t.type],
                    color: saleTypeColor(t.type),
                    onTap: () => _start(t),
                  ),
                ),
            ],
          ),
        NrSectionHeader('Herramientas'),
        NrGroup(children: [
          if (session.canCheckPrices)
            NrListRow(
              leading: _toolIcon(context, Icons.qr_code_scanner_rounded, NrColors.hues[1]),
              title: 'Checador de precios',
              subtitle: 'Precio, imagen y existencias al escanear',
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => context.push('/checker'),
            ),
          NrListRow(
            leading: _toolIcon(context, Icons.receipt_long_rounded, NrColors.hues[2]),
            title: 'Mis documentos',
            subtitle: 'Estado y PDF para compartir',
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => context.push('/documents'),
          ),
        ]),
      ],
    );
  }
}

Widget _toolIcon(BuildContext context, IconData icon, Color c) => Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(color: context.nr.tint(c, 0.13), borderRadius: BorderRadius.circular(NrRadius.lg)),
      child: Icon(icon, color: context.nr.tone(c), size: 20),
    );

/// Paso numerado del flujo de venta.
class _StepLabel extends StatelessWidget {
  const _StepLabel({required this.number, required this.label, required this.done});

  final int number;
  final String label;
  final bool done;

  @override
  Widget build(BuildContext context) {
    final nr = context.nr;
    return Padding(
      padding: const EdgeInsets.fromLTRB(NrSpace.xs, NrSpace.md, NrSpace.xs, NrSpace.sm),
      child: Row(children: [
        AnimatedContainer(
          duration: NrMotion.base,
          width: 22,
          height: 22,
          alignment: Alignment.center,
          decoration: BoxDecoration(color: done ? nr.success : nr.ink, shape: BoxShape.circle),
          child: done
              ? const Icon(Icons.check_rounded, size: 14, color: Colors.white)
              : Text('$number', style: NrText.caption(context).copyWith(color: nr.onInk, fontWeight: FontWeight.w700)),
        ),
        const SizedBox(width: NrSpace.sm),
        Text(label.toUpperCase(), style: NrText.eyebrow(context).copyWith(color: nr.headline)),
      ]),
    );
  }
}

/// Para qué sirve cada documento (debajo del nombre).
const saleTypeHints = {
  'quotation': 'Precio sin compromiso',
  'sales_order': 'Para surtir después',
  'delivery': 'Sale del almacén',
  'invoice': 'Con CFDI',
  'return': 'Producto de regreso',
};

Color saleTypeColor(String type) => switch (type) {
      'quotation' => NrColors.hues[7],
      'sales_order' => NrColors.hues[2],
      'delivery' => NrColors.hues[5],
      'invoice' => NrColors.hues[0],
      'return' => NrColors.hues[4],
      _ => NrColors.hues[1],
    };

/// Abre el carrito del tipo elegido para el cliente y lo guarda con el motor de
/// documentos (cola sin señal, llave de idempotencia). Entrega y factura se
/// pueden cobrar en el mismo paso. Regresa true si se guardó.
/// [extraBody] va tal cual en el documento (p. ej. `crm_deal_id`: la cotización
/// hecha desde una oportunidad del CRM queda ligada a ella).
Future<bool> startSaleDocument(BuildContext context, WidgetRef ref, Map<String, dynamic> customer, SaleType t, {Map<String, dynamic> extraBody = const {}}) async {
  final api = ref.read(apiProvider);
  final session = ref.read(sessionProvider)!;
  final id = (customer['id'] as num).toInt();
  final name = '${customer['trade_name'] ?? customer['name']}';

  var initialLines = <CartLine>[];
  var fromBase = false;
  if (t.type == 'return') {
    final base = await _pickDeliveryLines(context, ref, id);
    if (base == null) return false; // cancelado
    initialLines = base;
    fromBase = base.isNotEmpty;
  }
  final pending = ref.read(pendingSaleItemsProvider);
  final db = ref.read(localDbProvider);
  final priceListId = (customer['price_list_id'] as num?)?.toInt();
  // Captura rápida: la libreta con lo del camión (si hay ruta hoy), favoritos o lo más vendido.
  if (!fromBase && t.type != 'return' && ref.read(quickCaptureProvider).enabled) {
    final planId = await todayTruckPlanId(db);
    if (!context.mounted) return false;
    final quick = await showQuickCapture(context, customerId: id, customerName: name, title: t.label, priceListId: priceListId, planId: planId);
    if (quick == null) return false;
    initialLines = quick;
  }
  if (!fromBase) {
    initialLines = [...initialLines, for (final it in pending) CartLine(item: it, quantity: Dec.one)];
  }
  if (!context.mounted) return false;

  var saved = false;
  await Navigator.of(context).push(MaterialPageRoute(
    builder: (_) => CartPage(
      title: t.label,
      customerName: name,
      submitLabel: t.collects && session.canCollect ? 'Guardar y cobrar' : 'Guardar ${t.label.toLowerCase()}',
      priceListId: priceListId,
      initialLines: initialLines,
      allowHeader: true,
      allowAdd: !fromBase,
      quote: (lines, header) async => asMap(unwrap(await api.post('/pricing/recalculate', body: {
            'document_type': t.type,
            'partner_id': id,
            'warehouse_id': ?session.warehouseId,
            'lines': lines,
            ...header,
          }))),
      onSubmit: (ctx, cart) async {
        final body = <String, dynamic>{
          'type': t.type,
          'business_partner_id': id,
          'warehouse_id': ?session.warehouseId,
          'lines': cart.lines.map((l) => l.toApi()).toList(),
          ...cart.header,
          if (cart.notes.isNotEmpty) 'notes': cart.notes,
          ...extraBody,
        };
        TenderChoice? choice;
        if (t.collects && session.canCollect) {
          var tenders = session.tenderTypes;
          if (tenders.isEmpty) tenders = await ref.read(localDbProvider).all('tender_types');
          if (!ctx.mounted) return false;
          choice = await showTenderSheet(ctx, tenderTypes: tenders, total: cart.totals.total, allowCredit: true, title: t.label);
          if (choice == null) return false;
          if (choice.onCredit) {
            body['on_credit'] = true;
          } else {
            body['tenders'] = choice.tenders;
          }
        }
        if (!ctx.mounted) return false;
        final op = OutboxOp.create('POST', '/documents', body: body, label: '${t.label} $name');
        final r = await sendWithAuthorization(ctx, ref, op);
        if (r == null || !ctx.mounted) return false;
        ref.read(pendingSaleItemsProvider.notifier).state = [];
        saved = true;
        await rememberLastOrder(db, id, cart.lines);
        final (paid, change) = await printTenders(ref, choice?.tenders ?? const [], cart.totals.total);
        final onCredit = choice?.onCredit ?? false;
        PrintDoc printable;
        if (r.queued) {
          printable = printDocFromCart(cart, type: t.type, customer: name, tenders: paid, change: change, onCredit: onCredit);
        } else {
          final doc = asMap(unwrap(r.response));
          if (doc['id'] != null) await db.putJson('print_doc_${doc['id']}', doc);
          printable = asList(doc['lines']).isEmpty
              ? printDocFromCart(cart, type: t.type, customer: name, folio: doc['folio'] as String?, tenders: paid, change: change, onCredit: onCredit)
              : PrintDoc.fromApi(doc, tenders: paid, change: change, onCredit: onCredit);
        }
        if (!ctx.mounted) return true;
        final cfdi = cfdiLoader(ref, 'documents', r.queued ? null : (asMap(unwrap(r.response))['id'] as num?)?.toInt(), enabled: mayBeCfdi(t.type));
        await autoPrint(ctx, ref, printKindOf(t.type), (b) async => documentTicket(printable, b, cfdi: await cfdi()));
        if (!ctx.mounted) return true;
        if (r.queued) {
          showSnack(ctx, '${t.label} guardada sin señal; se enviará sola.');
        } else {
          final doc = asMap(unwrap(r.response));
          await showDoneDialog(ctx, ref, '${t.label} ${doc['folio'] ?? ''}', doc, print: (b) async => documentTicket(printable, b, cfdi: await cfdi()));
        }
        return true;
      },
    ),
  ));
  return saved;
}

/// Devolución: elegir una entrega del cliente para copiar sus líneas.
/// Regresa [] para capturar sin documento base y null si se cancela.
Future<List<CartLine>?> _pickDeliveryLines(BuildContext context, WidgetRef ref, int customerId) async {
  final api = ref.read(apiProvider);
  List<Map<String, dynamic>> deliveries;
  try {
    deliveries = asList(asMap(await api.get('/documents', query: {'type': 'delivery', 'partner_id': customerId, 'per_page': 20}))['data'])
        .where((d) => d['status'] == 'open' || d['status'] == 'closed')
        .toList();
  } on ApiException catch (e) {
    if (!e.isTransient) rethrow;
    deliveries = [];
  }
  if (!context.mounted) return null;
  final picked = await showModalBottomSheet<Map<String, dynamic>>(
    context: context,
    isScrollControlled: true,
    builder: (ctx) => FractionallySizedBox(
      heightFactor: 0.7,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(NrSpace.xl, 0, NrSpace.xl, NrSpace.sm),
          child: Text('¿De qué entrega es la devolución?', style: NrText.title(ctx)),
        ),
        Expanded(
          child: ListView(children: [
            if (deliveries.isEmpty)
              const Padding(padding: EdgeInsets.all(NrSpace.xl), child: Text('No hay entregas recientes de este cliente (o no hay señal).')),
            for (final d in deliveries)
              NrListRow(
                leading: const Icon(Icons.local_shipping_outlined),
                title: 'Entrega ${d['folio']}',
                subtitle: '${d['document_date'] ?? ''}',
                trailing: NrMoney(d['total']),
                onTap: () => Navigator.pop(ctx, d),
              ),
            NrListRow(
              leading: const Icon(Icons.edit_note),
              title: 'Sin documento base',
              subtitle: 'Capturar los artículos a mano',
              onTap: () => Navigator.pop(ctx, const <String, dynamic>{}),
            ),
          ]),
        ),
      ]),
    ),
  );
  if (picked == null) return null;
  if (picked.isEmpty) return [];
  final doc = asMap(unwrap(await api.get('/documents/${picked['id']}')));
  return [
    for (final l in asList(doc['lines']))
      if (l['item_id'] != null)
        CartLine(
          item: {'id': l['item_id'], 'name': l['description'], 'code': l['item_code']},
          quantity: Dec.parse(l['quantity']),
          maxQuantity: Dec.parse(l['quantity']),
          uomId: (l['uom_id'] as num?)?.toInt(),
          baseLineId: (l['id'] as num).toInt(),
        ),
  ];
}

/// Documentos del vendedor: los que esperan señal y los del servidor, con
/// estado y PDF para compartir.
final _myDocumentsProvider = FutureProvider.autoDispose.family<(List<Map<String, dynamic>>, bool), String?>((ref, type) async {
  final db = ref.watch(localDbProvider);
  final key = 'my_documents_${type ?? 'all'}';
  try {
    final rows = asList(asMap(await ref.watch(apiProvider).get('/documents', query: {'mine': 1, 'per_page': 50, 'type': ?type}))['data']);
    await db.putJson(key, rows);
    return (rows, false);
  } on ApiException catch (e) {
    if (!e.isTransient) rethrow;
    return (asList(await db.getJson(key)), true);
  }
});

final _queuedDocumentsProvider = FutureProvider.autoDispose<List<OutboxOp>>((ref) async {
  ref.watch(syncStatusProvider);
  final ops = await ref.watch(outboxProvider).list();
  return ops.where((o) => o.method == 'POST' && o.path.endsWith('/documents')).toList();
});

NrTone documentTone(String? status) => switch (status) {
      'open' => NrTone.accent,
      'closed' => NrTone.success,
      'cancelled' => NrTone.danger,
      _ => NrTone.neutral,
    };

const documentStatusLabels = {'draft': 'Borrador', 'open': 'Abierto', 'closed': 'Cerrado', 'cancelled': 'Cancelado'};

IconData documentIcon(String? type) => saleTypes.where((t) => t.type == type).firstOrNull?.icon ?? switch (type) {
      'credit_memo' => Icons.receipt_rounded,
      'down_payment' => Icons.savings_rounded,
      _ => Icons.description_rounded,
    };

/// Renglón de documento: tipo con su color, folio, cliente y fecha, monto y estado.
class DocumentRow extends StatelessWidget {
  const DocumentRow({super.key, required this.doc, this.onTap, this.showPartner = true});

  final Map<String, dynamic> doc;
  final VoidCallback? onTap;
  final bool showPartner;

  @override
  Widget build(BuildContext context) {
    final nr = context.nr;
    final type = doc['type'] as String?;
    final c = saleTypeColor(type ?? '');
    final partner = '${doc['partner_name'] ?? asMap(doc['partner'])['name'] ?? ''}';
    return NrListRow(
      onTap: onTap,
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(color: nr.tint(c, 0.13), borderRadius: BorderRadius.circular(NrRadius.lg)),
        child: Icon(documentIcon(type), color: nr.tone(c), size: 20),
      ),
      title: '${documentTypeLabels[type] ?? type ?? ''} ${doc['folio'] ?? ''}',
      subtitle: [if (showPartner && partner.isNotEmpty) partner, '${doc['document_date'] ?? ''}'].where((e) => e.isNotEmpty).join(' · '),
      trailing: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.end, children: [
        NrMoney(doc['total'], weight: FontWeight.w700),
        const SizedBox(height: 4),
        NrPill(documentStatusLabels[doc['status']] ?? '${doc['status'] ?? ''}', tone: documentTone(doc['status'] as String?), dot: true),
      ]),
    );
  }
}

String _dayLabel(String? date) {
  final d = DateTime.tryParse(date ?? '');
  if (d == null) return 'Sin fecha';
  final today = DateUtils.dateOnly(DateTime.now());
  final days = today.difference(DateUtils.dateOnly(d)).inDays;
  if (days == 0) return 'Hoy';
  if (days == 1) return 'Ayer';
  return DateFormat("EEEE d 'de' MMMM", 'es_MX').format(d);
}

class MyDocumentsPage extends ConsumerStatefulWidget {
  const MyDocumentsPage({super.key});

  @override
  ConsumerState<MyDocumentsPage> createState() => _MyDocumentsPageState();
}

class _MyDocumentsPageState extends ConsumerState<MyDocumentsPage> {
  String? type;

  @override
  Widget build(BuildContext context) {
    final docs = ref.watch(_myDocumentsProvider(type));
    final queued = ref.watch(_queuedDocumentsProvider).valueOrNull ?? [];
    final nr = context.nr;
    return Scaffold(
      appBar: AppBar(title: const Text('Mis documentos'), actions: const [SyncIndicator()]),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(_myDocumentsProvider(type)),
        child: ListView(padding: const EdgeInsets.fromLTRB(NrSpace.gutter, 0, NrSpace.gutter, NrSpace.xxxl), children: [
          SizedBox(
            height: 44,
            child: ListView(scrollDirection: Axis.horizontal, children: [
              for (final e in {null: 'Todos', for (final t in saleTypes) t.type: t.label}.entries)
                Padding(
                  padding: const EdgeInsets.only(right: NrSpace.sm),
                  child: ChoiceChip(
                    label: Text(e.value),
                    selected: type == e.key,
                    onSelected: (_) {
                      NrHaptics.tap();
                      setState(() => type = e.key);
                    },
                  ),
                ),
            ]),
          ),
          if (queued.isNotEmpty) ...[
            NrSectionHeader('Por enviar', count: queued.length),
            NrGroup(children: [
              for (final op in queued)
                NrListRow(
                  leading: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(color: op.error == null ? nr.warningBg : nr.dangerBg, borderRadius: BorderRadius.circular(NrRadius.lg)),
                    child: Icon(op.error == null ? Icons.cloud_upload_rounded : Icons.error_outline_rounded, color: op.error == null ? nr.warning : nr.danger, size: 20),
                  ),
                  title: op.label,
                  subtitle: op.error ?? 'Se enviará al recuperar señal',
                  trailing: NrPill(op.error == null ? 'En cola' : 'Error', tone: op.error == null ? NrTone.warning : NrTone.danger, dot: true),
                  onTap: () => context.push('/sync'),
                ),
            ]),
          ],
          ...docs.when(
            skipLoadingOnReload: true,
            loading: () => [const SizedBox(height: NrSpace.lg), const SizedBox(height: 420, child: NrSkeletonList(count: 6, padding: EdgeInsets.zero))],
            error: (e, _) => [NrErrorView(e, onRetry: () => ref.invalidate(_myDocumentsProvider(type)))],
            data: (r) {
              final (rows, offline) = r;
              final groups = <String, List<Map<String, dynamic>>>{};
              for (final d in rows) {
                groups.putIfAbsent(_dayLabel(d['document_date'] as String?), () => []).add(d);
              }
              final dayTotal = {for (final e in groups.entries) e.key: e.value.fold(Dec.zero, (s, d) => d['status'] == 'cancelled' ? s : s + Dec.parse(d['total']))};
              return [
                if (offline) const Padding(padding: EdgeInsets.only(top: NrSpace.md), child: NrBanner(message: 'Sin señal: lista guardada.')),
                if (rows.isEmpty)
                  NrEmpty(
                    icon: Icons.receipt_long_rounded,
                    title: 'Sin documentos',
                    message: type == null ? 'Lo que vendas o cotices aparecerá aquí con su estado y su PDF.' : 'No hay documentos de este tipo.',
                    action: 'Vender',
                    onAction: () => context.go('/sell'),
                  )
                else
                  for (final (gi, e) in groups.entries.indexed) ...[
                    NrSectionHeader(e.key, count: e.value.length, trailing: Text(money(dayTotal[e.key]), style: NrText.money(context, size: 13).copyWith(color: nr.secondary))),
                    NrEntrance(
                      index: gi,
                      child: NrGroup(inset: 68, children: [for (final d in e.value) DocumentRow(doc: d, onTap: () => _documentActions(context, ref, d))]),
                    ),
                  ],
              ];
            },
          ),
        ]),
      ),
    );
  }
}

/// Enviar el PDF o reimprimir en la impresora térmica.
Future<void> _documentActions(BuildContext context, WidgetRef ref, Map<String, dynamic> d) => showNrSheet<void>(
      context,
      title: '${documentTypeLabels[d['type']] ?? d['type']} ${d['folio'] ?? ''}',
      subtitle: '${d['partner_name'] ?? asMap(d['partner'])['name'] ?? ''} · ${money(d['total'])}',
      builder: (ctx) => Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        NrButton(
          label: 'Enviar PDF',
          icon: Icons.ios_share_rounded,
          onPressed: () {
            Navigator.pop(ctx);
            shareDocument(context, ref, kind: 'document', id: (d['id'] as num).toInt(), title: '${d['folio']}');
          },
        ),
        const SizedBox(height: NrSpace.sm),
        NrButton(
          label: 'Reimprimir',
          icon: Icons.print_rounded,
          variant: NrButtonVariant.secondary,
          onPressed: () {
            Navigator.pop(ctx);
            reprintDocument(context, ref, (d['id'] as num).toInt());
          },
        ),
      ]),
    );
