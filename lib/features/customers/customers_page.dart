import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/api/api_client.dart';
import '../../core/api/api_error.dart';
import '../../core/design/design.dart';
import '../../core/providers.dart';
import '../../core/widgets/sync_indicator.dart';
import '../collections/collection_page.dart';
import '../crm/customer_deals.dart';
import '../sales/sell_page.dart';
import 'customer_card.dart';

enum CustomerFilter { all, withBalance, overLimit }

final _customerSearchProvider = StateProvider.autoDispose<String>((ref) => '');
final _customerFilterProvider = StateProvider.autoDispose<CustomerFilter>((ref) => CustomerFilter.all);

final _customersProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final q = ref.watch(_customerSearchProvider);
  final f = ref.watch(_customerFilterProvider);
  final rows = await ref.watch(localDbProvider).search('customers', q, limit: f == CustomerFilter.all ? 100 : 1000);
  bool keep(Map<String, dynamic> c) {
    final balance = Dec.parse(c['balance']);
    final limit = Dec.parse(c['credit_limit']);
    return switch (f) {
      CustomerFilter.all => true,
      CustomerFilter.withBalance => balance > Dec.zero,
      CustomerFilter.overLimit => limit > Dec.zero && balance > limit,
    };
  }

  final out = rows.where(keep).toList();
  if (f != CustomerFilter.all) out.sort((a, b) => Dec.parse(b['balance']).compareTo(Dec.parse(a['balance'])));
  return out.take(100).toList();
});

String? _phoneOf(Map<String, dynamic> c) {
  final p = '${c['mobile'] ?? c['phone'] ?? ''}'.trim();
  return p.isEmpty ? null : p;
}

Future<void> _whatsApp(String phone) =>
    launchUrl(Uri.parse('https://wa.me/52${phone.replaceAll(RegExp(r'\D'), '')}'), mode: LaunchMode.externalApplication);

/// Cartera: búsqueda sin señal, filtros por saldo y crédito, y deslizar para
/// llamar (derecha) o escribir por WhatsApp (izquierda).
class CustomersPage extends ConsumerWidget {
  const CustomersPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final list = ref.watch(_customersProvider);
    final filter = ref.watch(_customerFilterProvider);
    final nr = context.nr;
    return Scaffold(
      appBar: AppBar(title: const Text('Clientes'), actions: const [SyncIndicator()]),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(NrSpace.gutter, 0, NrSpace.gutter, NrSpace.sm),
          child: NrSearchField(hint: 'Nombre, código, RFC o teléfono', onChanged: (v) => ref.read(_customerSearchProvider.notifier).state = v),
        ),
        SizedBox(
          height: 44,
          child: ListView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: NrSpace.gutter), children: [
            for (final (f, label, icon) in [
              (CustomerFilter.all, 'Todos', Icons.people_alt_rounded),
              (CustomerFilter.withBalance, 'Con saldo', Icons.account_balance_wallet_rounded),
              (CustomerFilter.overLimit, 'Crédito excedido', Icons.warning_amber_rounded),
            ])
              Padding(
                padding: const EdgeInsets.only(right: NrSpace.sm),
                child: ChoiceChip(
                  avatar: Icon(icon, size: 16, color: filter == f ? nr.onInk : nr.secondary),
                  label: Text(label),
                  selected: filter == f,
                  onSelected: (_) {
                    NrHaptics.tap();
                    ref.read(_customerFilterProvider.notifier).state = f;
                  },
                ),
              ),
          ]),
        ),
        const SizedBox(height: NrSpace.sm),
        Expanded(
          child: list.when(
            skipLoadingOnReload: true,
            loading: () => const NrSkeletonList(count: 8),
            error: (e, _) => NrErrorView(e),
            data: (rows) => rows.isEmpty
                ? NrEmpty(
                    icon: filter == CustomerFilter.all ? Icons.people_alt_rounded : Icons.verified_rounded,
                    title: filter == CustomerFilter.all ? 'Sin clientes' : 'Nadie en este filtro',
                    message: filter == CustomerFilter.all ? 'Sincroniza para tener tu cartera a la mano sin señal.' : 'Ningún cliente cumple con este filtro.',
                    action: filter == CustomerFilter.all ? 'Sincronizar' : 'Ver todos',
                    onAction: () => filter == CustomerFilter.all
                        ? ref.read(syncEngineProvider)?.syncNow()
                        : ref.read(_customerFilterProvider.notifier).state = CustomerFilter.all,
                  )
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(NrSpace.gutter, NrSpace.xs, NrSpace.gutter, NrSpace.xxxl),
                    itemCount: rows.length,
                    itemBuilder: (_, i) => Padding(
                      padding: const EdgeInsets.only(bottom: NrSpace.sm),
                      child: i < 12 ? NrEntrance(index: i, child: _CustomerRow(c: rows[i])) : _CustomerRow(c: rows[i]),
                    ),
                  ),
          ),
        ),
      ]),
    );
  }
}

class _CustomerRow extends StatelessWidget {
  const _CustomerRow({required this.c});

  final Map<String, dynamic> c;

  @override
  Widget build(BuildContext context) {
    final nr = context.nr;
    final id = (c['id'] as num).toInt();
    final name = '${c['trade_name'] ?? c['name']}';
    final balance = Dec.parse(c['balance']);
    final limit = Dec.parse(c['credit_limit']);
    final over = limit > Dec.zero && balance > limit;
    final phone = _phoneOf(c);
    final card = NrCard(
      padding: const EdgeInsets.symmetric(horizontal: NrSpace.md, vertical: NrSpace.md),
      onTap: () => context.push('/customers/$id'),
      accent: over ? nr.danger : null,
      child: Row(children: [
        NrAvatar(name, size: 44, heroTag: 'customer-$id', imageUrl: c['image_url'] as String?),
        const SizedBox(width: NrSpace.md),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(name, style: NrText.headline(context).copyWith(fontSize: 15), maxLines: 2, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 2),
            Text([?c['code'] as String?, ?phone].join(' · '), style: NrText.caption(context), maxLines: 1, overflow: TextOverflow.ellipsis),
          ]),
        ),
        const SizedBox(width: NrSpace.sm),
        SizedBox(
          width: 84,
          child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            if (balance > Dec.zero)
              Text(moneyCompact(balance), style: NrText.money(context, size: 15, weight: FontWeight.w700).copyWith(color: over ? nr.danger : null))
            else
              Text('Sin saldo', style: NrText.caption(context).copyWith(color: nr.muted)),
            if (limit > Dec.zero) ...[
              const SizedBox(height: 6),
              NrMeter(value: balance.toDouble() / limit.toDouble(), height: 4, color: over ? nr.danger : (balance.toDouble() / limit.toDouble() > 0.8 ? nr.warning : nr.success)),
            ],
          ]),
        ),
      ]),
    );
    if (phone == null) return card;
    Widget bg(IconData icon, String label, Color color, Alignment a) => Container(
          alignment: a,
          padding: const EdgeInsets.symmetric(horizontal: NrSpace.xl),
          decoration: BoxDecoration(color: nr.tint(color, 0.18), borderRadius: BorderRadius.circular(NrRadius.xxl)),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, color: nr.tone(color)),
            const SizedBox(width: 6),
            Text(label, style: NrText.label(context).copyWith(color: nr.tone(color), fontWeight: FontWeight.w700)),
          ]),
        );
    return Dismissible(
      key: ValueKey('customer-swipe-$id'),
      dismissThresholds: const {DismissDirection.startToEnd: 0.3, DismissDirection.endToStart: 0.3},
      background: bg(Icons.call_rounded, 'Llamar', nr.success, Alignment.centerLeft),
      secondaryBackground: bg(Icons.chat_rounded, 'WhatsApp', NrColors.hues[6], Alignment.centerRight),
      confirmDismiss: (d) async {
        NrHaptics.action();
        if (d == DismissDirection.startToEnd) {
          await launchUrl(Uri.parse('tel:$phone'));
        } else {
          await _whatsApp(phone);
        }
        return false;
      },
      child: card,
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

/// Lo último que se le hizo al cliente (cualquier vendedor), guardado para verlo sin señal.
final _recentDocsProvider = FutureProvider.autoDispose.family<List<Map<String, dynamic>>, int>((ref, id) async {
  final db = ref.watch(localDbProvider);
  try {
    final docs = asList(asMap(await ref.watch(apiProvider).get('/documents', query: {'partner_id': id, 'per_page': 5}))['data']);
    await db.putJson('recent_docs_$id', docs);
    return docs;
  } on ApiException catch (e) {
    if (!e.isTransient) rethrow;
    return asList(await db.getJson('recent_docs_$id'));
  }
});

class CustomerPage extends ConsumerWidget {
  const CustomerPage({super.key, required this.customerId});

  final int customerId;

  Future<void> _sell(BuildContext context, WidgetRef ref, Map<String, dynamic> c) async {
    final session = ref.read(sessionProvider);
    if (session == null) return;
    final types = allowedSaleTypes(session);
    if (types.isEmpty) return;
    final t = types.length == 1
        ? types.first
        : await showNrSheet<SaleType>(
            context,
            title: '¿Qué le vas a hacer?',
            builder: (ctx) => GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              mainAxisSpacing: NrSpace.md,
              crossAxisSpacing: NrSpace.md,
              childAspectRatio: 1.5,
              children: [
                for (final t in types)
                  NrTile(
                    icon: t.icon,
                    title: t.label,
                    subtitle: t.collects && session.canCollect ? 'Con cobro' : saleTypeHints[t.type],
                    color: saleTypeColor(t.type),
                    onTap: () => Navigator.pop(ctx, t),
                  ),
              ],
            ),
          );
    if (t == null || !context.mounted) return;
    await rememberCustomer(ref, c);
    if (!context.mounted) return;
    final done = await startSaleDocument(context, ref, c, t);
    if (done) ref.invalidate(customerDetailProvider(customerId));
  }

  Future<void> _collect(BuildContext context, WidgetRef ref, String name) async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => CollectionPage(customerId: customerId, customerName: name)));
    ref.invalidate(customerDetailProvider(customerId));
    ref.invalidate(_openDocsProvider(customerId));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(customerDetailProvider(customerId));
    final session = ref.watch(sessionProvider);
    final c = async.valueOrNull?.$1;
    final canSell = session != null && allowedSaleTypes(session).isNotEmpty;
    final canCollect = session?.canCollect ?? false;
    return Scaffold(
      appBar: AppBar(title: const Text('Cliente'), actions: const [SyncIndicator()]),
      body: async.when(
        loading: () => const NrSkeletonList(header: true, count: 3),
        error: (e, _) => NrErrorView(e, onRetry: () => ref.invalidate(customerDetailProvider(customerId))),
        data: (r) => _body(context, ref, r.$1, r.$2),
      ),
      bottomNavigationBar: c == null || (!canSell && !canCollect)
          ? null
          : NrBottomBar(
              child: Row(children: [
                if (canCollect)
                  Expanded(
                    child: NrButton(
                      label: 'Cobrar',
                      icon: Icons.payments_rounded,
                      variant: canSell ? NrButtonVariant.secondary : NrButtonVariant.primary,
                      onPressed: () => _collect(context, ref, '${c['trade_name'] ?? c['name']}'),
                    ),
                  ),
                if (canCollect && canSell) const SizedBox(width: NrSpace.md),
                if (canSell) Expanded(child: NrButton(label: 'Vender', icon: Icons.add_shopping_cart_rounded, onPressed: () => _sell(context, ref, c))),
              ]),
            ),
    );
  }

  Widget _body(BuildContext context, WidgetRef ref, Map<String, dynamic> c, bool offline) {
    final nr = context.nr;
    final name = '${c['trade_name'] ?? c['name']}';
    final account = asMap(c['account']);
    final aging = asMap(account['aging']);
    final phone = _phoneOf(c);
    final balance = Dec.parse(account['balance'] ?? c['balance']);
    final limit = Dec.parse(account['credit_limit'] ?? c['credit_limit']);
    final lat = (c['latitude'] as num?)?.toDouble() ?? 0;
    final lng = (c['longitude'] as num?)?.toDouble() ?? 0;
    final insights = ref.watch(customerInsightsProvider(customerId)).valueOrNull;
    final email = c['email'] as String?;
    final docs = ref.watch(_openDocsProvider(customerId)).valueOrNull ?? const [];
    final maxOverdue = docs.fold<int>(0, (m, d) => ((d['days_overdue'] as num?)?.toInt() ?? 0) > m ? (d['days_overdue'] as num).toInt() : m);

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(customerDetailProvider(customerId));
        ref.invalidate(_openDocsProvider(customerId));
        ref.invalidate(_recentDocsProvider(customerId));
      },
      child: ListView(padding: const EdgeInsets.fromLTRB(NrSpace.gutter, NrSpace.xs, NrSpace.gutter, NrSpace.xxxl), children: [
        if (offline) const Padding(padding: EdgeInsets.only(bottom: NrSpace.md), child: NrBanner(message: 'Sin señal: datos guardados.')),
        Row(children: [
          NrAvatar(name, size: 64, heroTag: 'customer-$customerId', imageUrl: c['image_url'] as String?),
          const SizedBox(width: NrSpace.lg),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(name, style: NrText.title(context)),
              const SizedBox(height: 2),
              Text([?c['code'] as String?, ?c['rfc'] as String?].join(' · '), style: NrText.bodySm(context)),
            ]),
          ),
        ]),
        if (insights != null && (insights.stopSequence != null || insights.lastAt != null || maxOverdue > 0)) ...[
          const SizedBox(height: NrSpace.md),
          Wrap(spacing: 6, runSpacing: 6, children: [
            if (maxOverdue > 0) NrPill('$maxOverdue días de atraso', tone: NrTone.danger, dot: true),
            if (insights.stopSequence != null)
              NrPill(insights.stopStatus == 'completed' ? 'Visitado hoy' : 'En tu ruta hoy · parada ${insights.stopSequence}', tone: NrTone.accent, icon: Icons.route_rounded),
            if (insights.lastAt != null) NrPill('Última venta ${relativeDay(insights.lastAt!)}', icon: Icons.history_rounded),
          ]),
        ],
        const SizedBox(height: NrSpace.lg),
        Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
          NrIconAction(icon: Icons.call_rounded, label: 'Llamar', color: NrColors.hues[1], onTap: phone == null ? null : () => launchUrl(Uri.parse('tel:$phone'))),
          NrIconAction(icon: Icons.chat_rounded, label: 'WhatsApp', color: NrColors.hues[6], onTap: phone == null ? null : () => _whatsApp(phone)),
          NrIconAction(icon: Icons.mail_rounded, label: 'Correo', color: NrColors.hues[2], onTap: email == null ? null : () => launchUrl(Uri.parse('mailto:$email'))),
          NrIconAction(
            icon: Icons.near_me_rounded,
            label: 'Cómo llegar',
            color: NrColors.hues[0],
            onTap: lat == 0 && lng == 0
                ? null
                : () => launchUrl(Uri.parse('https://www.google.com/maps/dir/?api=1&destination=$lat,$lng'), mode: LaunchMode.externalApplication),
          ),
        ]),
        const SizedBox(height: NrSpace.lg),
        NrCard(
          depth: NrDepth.floating,
          radius: NrRadius.hero,
          padding: const EdgeInsets.all(NrSpace.xl),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(children: [
              Expanded(child: Text('SALDO', style: NrText.eyebrow(context))),
              if (account['over_limit'] == true) const NrPill('Crédito excedido', tone: NrTone.danger, dot: true),
            ]),
            const SizedBox(height: 6),
            NrAmount(balance, size: 36, animate: true, color: account['over_limit'] == true ? nr.danger : null),
            const SizedBox(height: NrSpace.lg),
            CreditGauge(balance: balance, limit: limit),
            if (aging.isNotEmpty && balance > Dec.zero) ...[
              const SizedBox(height: NrSpace.xl),
              Text('ANTIGÜEDAD', style: NrText.eyebrow(context)),
              const SizedBox(height: NrSpace.sm),
              NrStackBar(
                format: (v) => money(v.toStringAsFixed(2)),
                segments: [
                  NrSegment('0 a 30 días', Dec.parse(aging['0_30']).toDouble(), nr.accent),
                  NrSegment('31 a 60 días', Dec.parse(aging['31_60']).toDouble(), nr.warning),
                  NrSegment('61 a 90 días', Dec.parse(aging['61_90']).toDouble(), NrColors.hues[4]),
                  NrSegment('Más de 90', Dec.parse(aging['90_plus']).toDouble(), nr.danger),
                ],
              ),
            ],
          ]),
        ),
        CustomerDeals(customer: c),
        NrSectionHeader('Documentos abiertos', count: docs.isEmpty ? null : docs.length),
        _OpenDocs(customerId: customerId),
        NrSectionHeader('Actividad reciente'),
        _RecentDocs(customerId: customerId),
      ]),
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
    final nr = context.nr;
    return ref.watch(_openDocsProvider(customerId)).when(
          loading: () => const NrShimmer(child: NrCard(child: Column(children: [NrSkeleton(height: 14), SizedBox(height: 10), NrSkeleton(width: 160, height: 10)]))),
          error: (e, _) => NrBanner(message: '$e', tone: NrTone.danger, icon: Icons.error_outline_rounded),
          data: (docs) => docs.isEmpty
              ? NrCard(
                  child: Row(children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(color: nr.successBg, borderRadius: BorderRadius.circular(NrRadius.lg)),
                      child: Icon(Icons.verified_rounded, color: nr.success),
                    ),
                    const SizedBox(width: NrSpace.md),
                    Expanded(child: Text('Al corriente: sin saldo pendiente.', style: NrText.headline(context).copyWith(fontSize: 15))),
                  ]),
                )
              : NrGroup(children: [
                  for (final d in docs)
                    NrListRow(
                      title: '${d['folio']}',
                      subtitle: [
                        '${d['document_date']}',
                        if (d['due_date'] != null) 'vence ${d['due_date']}',
                      ].join(' · '),
                      trailing: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.end, children: [
                        NrMoney(d['balance'], weight: FontWeight.w700, color: (d['days_overdue'] as num? ?? 0) > 0 ? nr.danger : null),
                        const SizedBox(height: 4),
                        if ((d['days_overdue'] as num? ?? 0) > 0)
                          NrPill('${d['days_overdue']} días vencido', tone: NrTone.danger)
                        else
                          const NrPill('Al corriente', tone: NrTone.success),
                      ]),
                    ),
                ]),
        );
  }
}

class _RecentDocs extends ConsumerWidget {
  const _RecentDocs({required this.customerId});

  final int customerId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ref.watch(_recentDocsProvider(customerId)).when(
          loading: () => const NrShimmer(child: NrCard(child: Column(children: [NrSkeleton(height: 14), SizedBox(height: 10), NrSkeleton(width: 160, height: 10)]))),
          error: (e, _) => const SizedBox.shrink(),
          data: (docs) => docs.isEmpty
              ? const NrCard(depth: NrDepth.flat, child: NrEmpty(compact: true, icon: Icons.receipt_long_rounded, title: 'Sin movimientos', message: 'Aún no hay documentos para este cliente.'))
              : NrGroup(children: [for (final d in docs) DocumentRow(doc: d)]),
        );
  }
}
