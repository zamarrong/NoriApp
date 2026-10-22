import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

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
import '../route/visit_page.dart' show showDoneDialog;
import 'cart.dart';
import 'cart_page.dart';

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
  SaleType('quotation', 'Cotización', 'quotations.create', Icons.request_quote_outlined),
  SaleType('sales_order', 'Pedido', 'sales_orders.create', Icons.receipt_long_outlined),
  SaleType('delivery', 'Entrega', 'deliveries.create', Icons.local_shipping_outlined, collects: true),
  SaleType('invoice', 'Factura', 'invoices.create', Icons.point_of_sale, collects: true),
  SaleType('return', 'Devolución', 'returns.create', Icons.assignment_return_outlined),
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
      showSnack(context, 'No se encontró el cliente $code');
    } else {
      await _choose(exact);
    }
  }

  Future<void> _newCustomer() async {
    final name = TextEditingController();
    final phone = TextEditingController();
    final rfc = TextEditingController();
    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(NrSpace.xl, 0, NrSpace.xl, MediaQuery.of(ctx).viewInsets.bottom + NrSpace.xl),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text('Cliente nuevo', style: NrText.title(ctx)),
          const SizedBox(height: NrSpace.lg),
          TextField(controller: name, autofocus: true, textCapitalization: TextCapitalization.words, decoration: const InputDecoration(labelText: 'Nombre o razón social')),
          const SizedBox(height: NrSpace.md),
          TextField(controller: phone, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'Teléfono')),
          const SizedBox(height: NrSpace.md),
          TextField(controller: rfc, textCapitalization: TextCapitalization.characters, decoration: const InputDecoration(labelText: 'RFC (opcional)')),
          const SizedBox(height: NrSpace.lg),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Dar de alta')),
        ]),
      ),
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

    return Scaffold(
      appBar: AppBar(
        title: const Text('Vender'),
        actions: [
          if (session.canCheckPrices) IconButton(icon: const Icon(Icons.qr_code_2), tooltip: 'Checador de precios', onPressed: () => context.push('/checker')),
          const SyncIndicator(),
        ],
      ),
      body: ListView(padding: const EdgeInsets.all(NrSpace.gutter), children: [
        if (pending.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: NrSpace.md),
            child: NrCard(
              borderColor: nr.accent,
              padding: const EdgeInsets.symmetric(horizontal: NrSpace.lg, vertical: NrSpace.sm),
              child: Row(children: [
                Icon(Icons.shopping_basket_outlined, color: nr.accent),
                const SizedBox(width: NrSpace.md),
                Expanded(child: Text('${pending.length} ${pending.length == 1 ? 'artículo' : 'artículos'} del checador para la venta', style: NrText.body(context))),
                TextButton(onPressed: () => ref.read(pendingSaleItemsProvider.notifier).state = [], child: const Text('Quitar')),
              ]),
            ),
          ),
        NrCard(
          child: customer == null
              ? Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  Text('CLIENTE', style: NrText.eyebrow(context)),
                  const SizedBox(height: NrSpace.sm),
                  FilledButton.icon(onPressed: () async => _choose(await pickCustomer(context)), icon: const Icon(Icons.search), label: const Text('Buscar cliente')),
                  const SizedBox(height: NrSpace.sm),
                  Row(children: [
                    Expanded(child: OutlinedButton.icon(onPressed: _scanCustomer, icon: const Icon(Icons.qr_code_scanner), label: const Text('Escanear'))),
                    const SizedBox(width: NrSpace.sm),
                    Expanded(child: OutlinedButton.icon(onPressed: _newCustomer, icon: const Icon(Icons.person_add_alt), label: const Text('Nuevo'))),
                  ]),
                ])
              : Row(children: [
                  NrAvatar(_customerName),
                  const SizedBox(width: NrSpace.md),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(_customerName, style: NrText.headline(context)),
                      Text('${customer!['code'] ?? ''}', style: NrText.caption(context)),
                    ]),
                  ),
                  TextButton(onPressed: () => setState(() => customer = null), child: const Text('Cambiar')),
                ]),
        ),
        if (customer == null && recents.isNotEmpty) ...[
          NrSectionHeader('Recientes'),
          Wrap(spacing: NrSpace.sm, runSpacing: NrSpace.sm, children: [
            for (final c in recents)
              ActionChip(
                avatar: NrAvatar('${c['trade_name'] ?? c['name']}', size: 24),
                label: Text('${c['trade_name'] ?? c['name']}', overflow: TextOverflow.ellipsis),
                onPressed: () => _choose(c),
              ),
          ]),
        ],
        NrSectionHeader('¿Qué vas a hacer?'),
        if (types.isEmpty)
          const NrCard(child: Text('Tu usuario no tiene permiso para crear documentos de venta.'))
        else
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: NrSpace.md,
            crossAxisSpacing: NrSpace.md,
            childAspectRatio: 1.7,
            children: [
              for (final t in types)
                NrCard(
                  padding: const EdgeInsets.all(NrSpace.md),
                  onTap: () => _start(t),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Icon(t.icon, color: nr.accent),
                    const Spacer(),
                    Text(t.label, style: NrText.headline(context)),
                    if (t.collects && session.canCollect) Text('Con cobro', style: NrText.caption(context)),
                  ]),
                ),
            ],
          ),
        NrSectionHeader('Herramientas'),
        NrGroup(children: [
          if (session.canCheckPrices)
            NrListRow(
              leading: const Icon(Icons.qr_code_2),
              title: 'Checador de precios',
              subtitle: 'Precio, imagen y existencias al escanear',
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push('/checker'),
            ),
          NrListRow(
            leading: const Icon(Icons.description_outlined),
            title: 'Mis documentos',
            subtitle: 'Estado y PDF para compartir',
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/documents'),
          ),
        ]),
      ]),
    );
  }
}

/// Abre el carrito del tipo elegido para el cliente y lo guarda con el motor de
/// documentos (cola sin señal, llave de idempotencia). Entrega y factura se
/// pueden cobrar en el mismo paso. Regresa true si se guardó.
Future<bool> startSaleDocument(BuildContext context, WidgetRef ref, Map<String, dynamic> customer, SaleType t) async {
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
      priceListId: (customer['price_list_id'] as num?)?.toInt(),
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
        };
        if (t.collects && session.canCollect) {
          var tenders = session.tenderTypes;
          if (tenders.isEmpty) tenders = await ref.read(localDbProvider).all('tender_types');
          if (!ctx.mounted) return false;
          final choice = await showTenderSheet(ctx, tenderTypes: tenders, total: cart.totals.total, allowCredit: true, title: t.label);
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
        if (r.queued) {
          showSnack(ctx, '${t.label} guardada sin señal; se enviará sola.');
        } else {
          final doc = asMap(unwrap(r.response));
          await showDoneDialog(ctx, ref, '${t.label} ${doc['folio'] ?? ''}', doc);
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
    return Scaffold(
      appBar: AppBar(title: const Text('Mis documentos'), actions: const [SyncIndicator()]),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(_myDocumentsProvider(type)),
        child: ListView(padding: const EdgeInsets.all(NrSpace.gutter), children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(children: [
              for (final e in {null: 'Todos', for (final t in saleTypes) t.type: t.label}.entries)
                Padding(
                  padding: const EdgeInsets.only(right: NrSpace.sm),
                  child: ChoiceChip(label: Text(e.value), selected: type == e.key, onSelected: (_) => setState(() => type = e.key)),
                ),
            ]),
          ),
          if (queued.isNotEmpty) ...[
            NrSectionHeader('Por enviar', count: queued.length),
            NrGroup(children: [
              for (final op in queued)
                NrListRow(
                  leading: const Icon(Icons.cloud_upload_outlined),
                  title: op.label,
                  subtitle: op.error ?? 'Se enviará al recuperar señal',
                  trailing: NrPill(op.error == null ? 'En cola' : 'Error', tone: op.error == null ? NrTone.warning : NrTone.danger),
                  onTap: () => context.push('/sync'),
                ),
            ]),
          ],
          ...docs.when(
            loading: () => [const Padding(padding: EdgeInsets.all(NrSpace.xl), child: Center(child: CircularProgressIndicator()))],
            error: (e, _) => [NrErrorView(e, onRetry: () => ref.invalidate(_myDocumentsProvider(type)))],
            data: (r) {
              final (rows, offline) = r;
              return [
                if (offline)
                  const Padding(padding: EdgeInsets.only(top: NrSpace.md), child: NrPill('Sin señal: lista guardada', tone: NrTone.warning, icon: Icons.cloud_off)),
                NrSectionHeader('Recientes', count: rows.length),
                if (rows.isEmpty)
                  const NrEmpty(icon: Icons.description_outlined, title: 'Sin documentos')
                else
                  NrGroup(children: [
                    for (final d in rows)
                      NrListRow(
                        title: '${documentTypeLabels[d['type']] ?? d['type']} ${d['folio'] ?? ''}',
                        subtitle: '${d['partner_name'] ?? asMap(d['partner'])['name'] ?? ''} · ${d['document_date'] ?? ''}',
                        trailing: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.end, children: [
                          NrMoney(d['total']),
                          const SizedBox(height: 2),
                          NrPill(documentStatusLabels[d['status']] ?? '${d['status']}', tone: documentTone(d['status'] as String?)),
                        ]),
                        onTap: () => shareDocument(context, ref, kind: 'document', id: (d['id'] as num).toInt(), title: '${d['folio']}'),
                      ),
                  ]),
              ];
            },
          ),
        ]),
      ),
    );
  }
}
