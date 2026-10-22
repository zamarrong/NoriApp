import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/api/api_client.dart';
import '../../core/authorizations/authorization_flow.dart';
import '../../core/design/design.dart';
import '../../core/providers.dart';
import '../../core/sync/outbox.dart';
import '../../core/widgets/pickers.dart';
import '../../core/widgets/sync_indicator.dart';
import '../collections/collection_page.dart';
import '../collections/tender_sheet.dart';
import '../sales/cart_page.dart';
import 'route_repo.dart';
import 'route_today_page.dart';
import 'visit_actions.dart';

/// Posición actual con tiempo límite; null si no hay permiso o no responde.
Future<Map<String, dynamic>> currentGps() async {
  final at = DateTime.now().toIso8601String();
  try {
    var perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) perm = await Geolocator.requestPermission();
    if (perm == LocationPermission.denied || perm == LocationPermission.deniedForever) return {'at': at};
    final p = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.high, timeLimit: Duration(seconds: 12)),
    );
    return {'lat': p.latitude, 'lng': p.longitude, 'at': at};
  } catch (_) {
    return {'at': at};
  }
}

/// Catálogo de motivos del día: {visit, no_sale, skip, return}.
final routeReasonsProvider = FutureProvider.autoDispose<Map<String, List<Map<String, dynamic>>>>((ref) async {
  final db = ref.watch(localDbProvider);
  final today = asMap(await db.getJson(RouteRepo.todayKey));
  final fromDay = asMap(today['reasons']);
  if (fromDay.isNotEmpty) return {for (final e in fromDay.entries) e.key: asList(e.value)};
  final all = await db.all('visit_reasons');
  final out = <String, List<Map<String, dynamic>>>{};
  for (final r in all) {
    out.putIfAbsent('${r['type']}', () => []).add(r);
  }
  return out;
});

class VisitPage extends ConsumerStatefulWidget {
  const VisitPage({super.key, required this.visitId});

  final int visitId;

  @override
  ConsumerState<VisitPage> createState() => _VisitPageState();
}

class _VisitPageState extends ConsumerState<VisitPage> {
  bool busy = false;

  String get _base => '/route/visits/${widget.visitId}';

  /// Escritura de ruta: guarda la visita que responde el servidor o, sin señal,
  /// refleja el cambio en lo guardado mientras la cola espera.
  Future<Map<String, dynamic>?> _write(String action, Map<String, dynamic> body, {String label = '', Map<String, dynamic>? optimistic}) async {
    setState(() => busy = true);
    try {
      final r = await sendWithAuthorization(context, ref, OutboxOp.create('POST', '$_base/$action', body: body, label: label));
      if (r == null) return null;
      final repo = ref.read(routeRepoProvider);
      if (r.queued) {
        if (optimistic != null) await repo.patchStop(widget.visitId, optimistic);
        if (mounted) showSnack(context, 'Guardado sin señal; se enviará solo.');
      } else {
        final visit = asMap(asMap(r.response)['visit']);
        if (visit.isNotEmpty) await repo.saveVisit(visit);
      }
      ref.invalidate(visitProvider(widget.visitId));
      ref.invalidate(routeTodayProvider);
      return r.queued ? {} : asMap(r.response);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _checkIn() async {
    final gps = await currentGps();
    await _write('check-in', gps, label: 'Llegada', optimistic: {'status': 'in_progress', 'status_label': 'En visita', 'check_in_at': gps['at']});
  }

  Future<void> _checkOut() async {
    final gps = await currentGps();
    await _write('check-out', gps, label: 'Salida', optimistic: {'status': 'completed', 'status_label': 'Visitada', 'check_out_at': gps['at']});
  }

  Future<void> _reason(String type, String action, String title) async {
    final reasons = (await ref.read(routeReasonsProvider.future))[type] ?? [];
    if (!mounted) return;
    final picked = await pickReason(context, reasons, title: title);
    if (picked == null) return;
    await _write(action, {'reason_id': picked.$1, if (picked.$2.isNotEmpty) 'notes': picked.$2},
        label: title,
        optimistic: action == 'skip' ? {'status': 'skipped', 'status_label': 'No visitada'} : {'outcome': 'no_sale'});
  }

  Future<void> _cart(Map<String, dynamic> visit, String kind) async {
    final customer = asMap(visit['customer']);
    final titles = {'sale': 'Venta', 'order': 'Pedido', 'pickup': 'Recolección'};
    final api = ref.read(apiProvider);
    final tenders = asList(asMap(await ref.read(localDbProvider).getJson(RouteRepo.todayKey))['tenders']);
    if (!mounted) return;
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => CartPage(
        title: titles[kind]!,
        customerName: '${customer['name'] ?? ''}',
        submitLabel: kind == 'sale' ? 'Cobrar o dejar a crédito' : 'Guardar ${titles[kind]!.toLowerCase()}',
        initial: kind == 'sale' ? asList(visit['suggested']) : const [],
        quote: (lines) async => asMap(await api.post('$_base/quote', body: {'kind': kind, 'lines': lines})),
        onSubmit: (ctx, cart) async {
          final body = <String, dynamic>{'lines': cart.lines.map((l) => l.toApi()).toList()};
          if (kind == 'sale') {
            final choice = await showTenderSheet(ctx, tenderTypes: tenders, total: cart.totals.total, allowCredit: true);
            if (choice == null) return false;
            body['tenders'] = choice.tenders;
          }
          if (kind == 'pickup') {
            final reasons = (await ref.read(routeReasonsProvider.future))['return'] ?? [];
            if (!ctx.mounted) return false;
            final r = await pickReason(ctx, reasons, title: 'Motivo de la recolección', notes: false);
            if (r == null) return false;
            body['lines'] = [for (final l in body['lines'] as List) {...l as Map, 'reason_id': r.$1}];
          }
          if (!ctx.mounted) return false;
          final result = await _write(kind, body, label: titles[kind]!, optimistic: {'outcome': kind});
          if (result == null) return false;
          final docs = asList(result['documents']);
          if (docs.isNotEmpty && ctx.mounted) {
            await showDoneDialog(ctx, ref, '${result['message'] ?? 'Guardado'}', docs.first);
          }
          return true;
        },
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(visitProvider(widget.visitId));
    return Scaffold(
      appBar: AppBar(title: const Text('Visita'), actions: const [SyncIndicator()]),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => NrErrorView(e, onRetry: () => ref.invalidate(visitProvider(widget.visitId))),
        data: (c) => _body(context, c.value, c.offline),
      ),
    );
  }

  Widget _body(BuildContext context, Map<String, dynamic> v, bool offline) {
    final customer = asMap(v['customer']);
    final status = v['status'] as String?;
    final pending = status == 'pending';
    final inProgress = status == 'in_progress';
    final actions = asList(v['reasons']).map((r) => r['action']).toSet();
    final orders = asList(v['orders']);
    final assets = asList(v['assets']);
    final owedTotal = Dec.parse(v['owed_total']);
    final customerId = (customer['id'] as num?)?.toInt();
    final session = ref.watch(sessionProvider);
    final nr = context.nr;

    Widget tile(IconData icon, String label, VoidCallback? onTap, {bool highlight = false, String? badge}) => NrCard(
          padding: const EdgeInsets.all(NrSpace.md),
          borderColor: highlight ? nr.accent : null,
          onTap: busy ? null : onTap,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Icon(icon, color: highlight ? nr.accent : nr.secondary),
              const Spacer(),
              if (badge != null) NrPill(badge, tone: NrTone.warning),
            ]),
            const SizedBox(height: NrSpace.sm),
            Text(label, style: NrText.headline(context)),
          ]),
        );

    return ListView(padding: const EdgeInsets.all(NrSpace.gutter), children: [
      if (offline) const Padding(padding: EdgeInsets.only(bottom: NrSpace.md), child: NrPill('Sin señal: datos guardados', tone: NrTone.warning, icon: Icons.cloud_off)),
      NrCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            NrAvatar('${customer['name'] ?? ''}'),
            const SizedBox(width: NrSpace.md),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('${customer['name'] ?? ''}', style: NrText.headline(context)),
                Text('${customer['code'] ?? ''}', style: NrText.caption(context)),
              ]),
            ),
            NrPill('${v['status_label'] ?? status}', tone: stopTone(status)),
          ]),
          if (customer['address'] != null) ...[const SizedBox(height: NrSpace.sm), Text('${customer['address']}', style: NrText.bodySm(context))],
          const SizedBox(height: NrSpace.md),
          Wrap(spacing: NrSpace.sm, children: [
            if (v['navigate_url'] != null)
              ActionChip(avatar: const Icon(Icons.directions, size: 18), label: const Text('Cómo llegar'), onPressed: () => launchUrl(Uri.parse('${v['navigate_url']}'), mode: LaunchMode.externalApplication)),
            if (customer['phone'] != null) ...[
              ActionChip(avatar: const Icon(Icons.call, size: 18), label: const Text('Llamar'), onPressed: () => launchUrl(Uri.parse('tel:${customer['phone']}'))),
              ActionChip(
                avatar: const Icon(Icons.chat_outlined, size: 18),
                label: const Text('WhatsApp'),
                onPressed: () => launchUrl(Uri.parse('https://wa.me/52${'${customer['phone']}'.replaceAll(RegExp(r'\D'), '')}'), mode: LaunchMode.externalApplication),
              ),
            ],
            if (customerId != null)
              ActionChip(avatar: const Icon(Icons.person_outline, size: 18), label: const Text('Cliente 360'), onPressed: () => context.push('/customers/$customerId')),
          ]),
        ]),
      ),
      const SizedBox(height: NrSpace.lg),
      if (pending) ...[
        FilledButton.icon(onPressed: busy ? null : _checkIn, icon: const Icon(Icons.login), label: const Text('Llegué (registrar llegada)')),
        const SizedBox(height: NrSpace.sm),
        OutlinedButton(onPressed: busy ? null : () => _reason('skip', 'skip', 'Motivo de no visita'), child: const Text('No visitaré a este cliente')),
      ],
      if (inProgress || status == 'completed') ...[
        NrSectionHeader('¿Qué hiciste?'),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: NrSpace.md,
          crossAxisSpacing: NrSpace.md,
          childAspectRatio: 1.7,
          children: [
            tile(Icons.point_of_sale, 'Venta', () => _cart(v, 'sale'), highlight: actions.contains('sale')),
            tile(Icons.receipt_long_outlined, 'Pedido', () => _cart(v, 'order'), highlight: actions.contains('order')),
            if (orders.isNotEmpty)
              tile(Icons.local_shipping_outlined, 'Entrega', () async {
                await Navigator.of(context).push(MaterialPageRoute(builder: (_) => DeliveryPage(visit: v)));
                ref.invalidate(visitProvider(widget.visitId));
              }, highlight: true, badge: '${orders.length}'),
            tile(Icons.assignment_return_outlined, 'Recolección', () => _cart(v, 'pickup'), highlight: actions.contains('pickup')),
            if (assets.isNotEmpty)
              tile(Icons.kitchen_outlined, 'Mantenimiento', () async {
                await Navigator.of(context).push(MaterialPageRoute(builder: (_) => AssetServicePage(visit: v)));
                ref.invalidate(visitProvider(widget.visitId));
              }, highlight: actions.contains('asset_service'), badge: assets.any((a) => a['service_due'] == true) ? 'Toca' : null),
            if (customerId != null && (session?.canCollect ?? false))
              tile(Icons.payments_outlined, 'Cobro', () async {
                final tenders = asList(asMap(await ref.read(localDbProvider).getJson(RouteRepo.todayKey))['tenders']);
                if (!context.mounted) return;
                await Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => CollectionPage(
                    customerId: customerId,
                    customerName: '${customer['name']}',
                    visitId: widget.visitId,
                    tenderTypes: tenders.isEmpty ? null : tenders,
                  ),
                ));
                ref.invalidate(visitProvider(widget.visitId));
              }, highlight: actions.contains('collection') || owedTotal > Dec.zero, badge: owedTotal > Dec.zero ? money(owedTotal) : null),
            tile(Icons.do_not_disturb_on_outlined, 'No venta', () => _reason('no_sale', 'no-sale', 'Motivo de no venta')),
          ],
        ),
      ],
      if (inProgress) ...[
        const SizedBox(height: NrSpace.lg),
        FilledButton.icon(onPressed: busy ? null : _checkOut, icon: const Icon(Icons.logout), label: const Text('Terminar visita (salida)')),
      ],
      if (asList(v['done']).isNotEmpty) ...[
        NrSectionHeader('Hecho en esta visita'),
        NrGroup(children: [
          for (final d in asList(v['done']))
            NrListRow(
              title: '${d['role_label'] ?? d['role']} ${d['folio'] ?? ''}',
              subtitle: [?d['type'] as String?, ?d['reason'] as String?].join(' · '),
              trailing: NrMoney(d['total']),
            ),
        ]),
      ],
      if (owedTotal > Dec.zero) ...[
        NrSectionHeader('Saldo pendiente'),
        NrGroup(children: [
          for (final d in asList(v['owed']))
            NrListRow(
              title: '${d['type'] ?? ''} ${d['folio']}',
              subtitle: d['due_date'] == null ? null : 'Vence ${d['due_date']}',
              trailing: NrMoney(d['balance'], color: d['overdue'] == true ? nr.danger : null),
            ),
        ]),
      ],
    ]);
  }
}

/// Elige un motivo (y nota). Regresa (id, nota).
Future<(int, String)?> pickReason(BuildContext context, List<Map<String, dynamic>> reasons, {required String title, bool notes = true}) {
  return showModalBottomSheet<(int, String)>(
    context: context,
    isScrollControlled: true,
    builder: (ctx) {
      final note = TextEditingController();
      int? selected;
      return StatefulBuilder(
        builder: (ctx, setState) => Padding(
          padding: EdgeInsets.fromLTRB(NrSpace.xl, 0, NrSpace.xl, MediaQuery.of(ctx).viewInsets.bottom + NrSpace.xl),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text(title, style: NrText.title(ctx)),
            const SizedBox(height: NrSpace.md),
            if (reasons.isEmpty) const Text('No hay motivos configurados.'),
            Wrap(spacing: NrSpace.sm, runSpacing: NrSpace.sm, children: [
              for (final r in reasons)
                ChoiceChip(label: Text('${r['name']}'), selected: selected == r['id'], onSelected: (_) => setState(() => selected = (r['id'] as num).toInt())),
            ]),
            if (notes) ...[
              const SizedBox(height: NrSpace.md),
              TextField(controller: note, decoration: const InputDecoration(labelText: 'Notas')),
            ],
            const SizedBox(height: NrSpace.lg),
            FilledButton(onPressed: selected == null ? null : () => Navigator.pop(ctx, (selected!, note.text.trim())), child: const Text('Guardar')),
          ]),
        ),
      );
    },
  );
}

/// Confirmación con la opción de compartir el PDF del documento.
Future<void> showDoneDialog(BuildContext context, WidgetRef ref, String message, Map<String, dynamic> doc) => showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: Icon(Icons.check_circle, color: ctx.nr.success, size: 40),
        title: Text(message),
        content: doc['total'] == null ? null : Text('Total ${money(doc['total'])}'),
        actions: [
          if (doc['id'] != null)
            TextButton(
              onPressed: () => shareDocument(ctx, ref, kind: 'document', id: (doc['id'] as num).toInt(), title: '${doc['folio'] ?? ''}'),
              child: const Text('Enviar PDF'),
            ),
          FilledButton(onPressed: () => Navigator.pop(ctx), child: const Text('Listo')),
        ],
      ),
    );
