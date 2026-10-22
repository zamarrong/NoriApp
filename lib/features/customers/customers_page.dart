import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/api/api_client.dart';
import '../../core/api/api_error.dart';
import '../../core/authorizations/authorization_flow.dart';
import '../../core/design/design.dart';
import '../../core/providers.dart';
import '../../core/sync/outbox.dart';
import '../../core/widgets/sync_indicator.dart';
import '../collections/collection_page.dart';
import '../route/visit_page.dart' show showDoneDialog;
import '../sales/cart_page.dart';

final _customerSearchProvider = StateProvider.autoDispose<String>((ref) => '');

final _customersProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) {
  final q = ref.watch(_customerSearchProvider);
  return ref.watch(localDbProvider).search('customers', q, limit: 100);
});

class CustomersPage extends ConsumerWidget {
  const CustomersPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final list = ref.watch(_customersProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Clientes'), actions: const [SyncIndicator()]),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(NrSpace.gutter, 0, NrSpace.gutter, NrSpace.sm),
          child: TextField(
            decoration: const InputDecoration(hintText: 'Nombre, código, RFC o teléfono', prefixIcon: Icon(Icons.search)),
            onChanged: (v) => ref.read(_customerSearchProvider.notifier).state = v,
          ),
        ),
        Expanded(
          child: list.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => NrErrorView(e),
            data: (rows) => rows.isEmpty
                ? const NrEmpty(icon: Icons.people_outline, title: 'Sin clientes', message: 'Sincroniza para ver tu cartera sin señal.')
                : ListView.separated(
                    itemCount: rows.length,
                    separatorBuilder: (_, _) => const Divider(height: 1),
                    itemBuilder: (_, i) {
                      final c = rows[i];
                      final name = '${c['trade_name'] ?? c['name']}';
                      final balance = Dec.parse(c['balance']);
                      return NrListRow(
                        leading: NrAvatar(name),
                        title: name,
                        subtitle: '${c['code']}${c['phone'] != null ? ' · ${c['phone']}' : ''}',
                        trailing: balance > Dec.zero ? NrMoney(balance) : null,
                        onTap: () => context.push('/customers/${c['id']}'),
                      );
                    },
                  ),
          ),
        ),
      ]),
    );
  }
}

/// Cliente 360: con señal pide la cuenta (saldo, crédito, antigüedad); sin señal
/// muestra lo sincronizado.
final customerDetailProvider = FutureProvider.autoDispose.family<(Map<String, dynamic>, bool), int>((ref, id) async {
  final db = ref.watch(localDbProvider);
  try {
    final c = asMap(unwrap(await ref.watch(apiProvider).get('/customers/$id')));
    await db.putJson('customer_$id', c);
    return (c, false);
  } on ApiException catch (e) {
    if (!e.isTransient) rethrow;
    final cached = await db.getJson('customer_$id') ?? await db.find('customers', id);
    if (cached == null) rethrow;
    return (asMap(cached), true);
  }
});

/// Abre el carrito para una cotización o pedido y lo guarda con el motor de documentos.
Future<void> newSalesDocument(BuildContext context, WidgetRef ref, Map<String, dynamic> customer, String type) async {
  final api = ref.read(apiProvider);
  final id = (customer['id'] as num).toInt();
  final label = type == 'quotation' ? 'Cotización' : 'Pedido';
  await Navigator.of(context).push(MaterialPageRoute(
    builder: (_) => CartPage(
      title: label,
      customerName: '${customer['trade_name'] ?? customer['name']}',
      submitLabel: 'Guardar ${label.toLowerCase()}',
      priceListId: (customer['price_list_id'] as num?)?.toInt(),
      quote: (lines) async =>
          asMap(unwrap(await api.post('/pricing/recalculate', body: {'document_type': type, 'partner_id': id, 'lines': lines}))),
      onSubmit: (ctx, cart) async {
        final op = OutboxOp.create('POST', '/documents',
            body: {'type': type, 'business_partner_id': id, 'lines': cart.lines.map((l) => l.toApi()).toList()},
            label: '$label ${customer['name']}');
        final r = await sendWithAuthorization(ctx, ref, op);
        if (r == null || !ctx.mounted) return false;
        if (r.queued) {
          showSnack(ctx, '$label guardada sin señal; se enviará sola.');
        } else {
          final doc = asMap(unwrap(r.response));
          await showDoneDialog(ctx, ref, '$label ${doc['folio'] ?? ''}', doc);
        }
        return true;
      },
    ),
  ));
}

class CustomerPage extends ConsumerWidget {
  const CustomerPage({super.key, required this.customerId});

  final int customerId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(customerDetailProvider(customerId));
    final session = ref.watch(sessionProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Cliente'), actions: const [SyncIndicator()]),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => NrErrorView(e, onRetry: () => ref.invalidate(customerDetailProvider(customerId))),
        data: (r) {
          final (c, offline) = r;
          final name = '${c['trade_name'] ?? c['name']}';
          final account = asMap(c['account']);
          final aging = asMap(account['aging']);
          final phone = c['mobile'] ?? c['phone'];
          final nr = context.nr;
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(customerDetailProvider(customerId)),
            child: ListView(padding: const EdgeInsets.all(NrSpace.gutter), children: [
              if (offline) const Padding(padding: EdgeInsets.only(bottom: NrSpace.md), child: NrPill('Sin señal: datos guardados', tone: NrTone.warning, icon: Icons.cloud_off)),
              Row(children: [
                NrAvatar(name, size: 52),
                const SizedBox(width: NrSpace.md),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(name, style: NrText.title(context)),
                    Text('${c['code']}${c['rfc'] != null ? ' · ${c['rfc']}' : ''}', style: NrText.bodySm(context)),
                  ]),
                ),
              ]),
              const SizedBox(height: NrSpace.lg),
              Row(children: [
                Expanded(child: NrMetric(label: 'Saldo', value: money(account['balance'] ?? c['balance']))),
                const SizedBox(width: NrSpace.md),
                Expanded(
                  child: NrMetric(
                    label: 'Crédito disponible',
                    value: account['available_credit'] == null ? 'Sin límite' : money(account['available_credit']),
                    caption: account['over_limit'] == true ? 'Excedido' : 'Límite ${money(account['credit_limit'] ?? c['credit_limit'])}',
                  ),
                ),
              ]),
              if (aging.isNotEmpty) ...[
                NrSectionHeader('Antigüedad de saldo'),
                NrCard(
                  child: Column(children: [
                    for (final e in {'0_30': '0–30 días', '31_60': '31–60 días', '61_90': '61–90 días', '90_plus': 'Más de 90'}.entries)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(children: [
                          Expanded(child: Text(e.value, style: NrText.body(context))),
                          NrMoney(aging[e.key], color: e.key != '0_30' && Dec.parse(aging[e.key]) > Dec.zero ? nr.danger : null),
                        ]),
                      ),
                  ]),
                ),
              ],
              NrSectionHeader('Acciones'),
              Wrap(spacing: NrSpace.sm, runSpacing: NrSpace.sm, children: [
                if (session?.can('sales_orders.create') ?? false)
                  FilledButton.icon(onPressed: () => newSalesDocument(context, ref, c, 'sales_order'), icon: const Icon(Icons.receipt_long), label: const Text('Pedido')),
                if (session?.can('quotations.create') ?? false)
                  OutlinedButton.icon(onPressed: () => newSalesDocument(context, ref, c, 'quotation'), icon: const Icon(Icons.request_quote_outlined), label: const Text('Cotización')),
                if (session?.canCollect ?? false)
                  OutlinedButton.icon(
                    onPressed: () async {
                      await Navigator.of(context).push(MaterialPageRoute(builder: (_) => CollectionPage(customerId: customerId, customerName: name)));
                      ref.invalidate(customerDetailProvider(customerId));
                    },
                    icon: const Icon(Icons.payments_outlined),
                    label: const Text('Cobrar'),
                  ),
                if (phone != null)
                  OutlinedButton.icon(
                    onPressed: () => launchUrl(Uri.parse('https://wa.me/52${'$phone'.replaceAll(RegExp(r'\D'), '')}'), mode: LaunchMode.externalApplication),
                    icon: const Icon(Icons.chat_outlined),
                    label: const Text('WhatsApp'),
                  ),
              ]),
              NrSectionHeader('Documentos abiertos'),
              _OpenDocs(customerId: customerId),
            ]),
          );
        },
      ),
    );
  }
}

final _openDocsProvider = FutureProvider.autoDispose.family<List<Map<String, dynamic>>, int>((ref, id) async {
  final db = ref.watch(localDbProvider);
  try {
    final docs = asList(asMap(await ref.watch(apiProvider).get('/customers/$id/open-documents'))['data']);
    await db.putJson('open_docs_$id', docs);
    return docs;
  } on ApiException catch (e) {
    if (!e.isTransient) rethrow;
    return asList(await db.getJson('open_docs_$id'));
  }
});

class _OpenDocs extends ConsumerWidget {
  const _OpenDocs({required this.customerId});

  final int customerId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ref.watch(_openDocsProvider(customerId)).when(
          loading: () => const LinearProgressIndicator(),
          error: (e, _) => Text('$e'),
          data: (docs) => docs.isEmpty
              ? const NrCard(child: Text('Sin saldo pendiente.'))
              : NrGroup(children: [
                  for (final d in docs)
                    NrListRow(
                      title: '${d['folio']}',
                      subtitle: [
                        '${d['document_date']}',
                        if ((d['days_overdue'] as num? ?? 0) > 0) '${d['days_overdue']} días vencido',
                      ].join(' · '),
                      trailing: NrMoney(d['balance'], color: (d['days_overdue'] as num? ?? 0) > 0 ? context.nr.danger : null),
                    ),
                ]),
        );
  }
}
