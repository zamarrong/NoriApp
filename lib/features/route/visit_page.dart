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
import '../printing/printer.dart';
import '../printing/templates.dart';
import '../sales/cart.dart';
import '../sales/cart_page.dart';
import '../sales/quick_capture.dart';
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
      NrHaptics.success();
      final repo = ref.read(routeRepoProvider);
      if (r.queued) {
        if (optimistic != null) await repo.patchStop(widget.visitId, optimistic);
        if (mounted) showSnack(context, 'Guardado sin señal; se enviará solo.', tone: NrTone.warning);
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
    final r = await _write('check-out', gps, label: 'Salida', optimistic: {'status': 'completed', 'status_label': 'Visitada', 'check_out_at': gps['at']});
    if (r != null) await _afterCheckOut();
  }

  Future<void> _reason(String type, String action, String title) async {
    final reasons = (await ref.read(routeReasonsProvider.future))[type] ?? [];
    if (!mounted) return;
    final picked = await pickReason(context, reasons, title: title);
    if (picked == null) return;
    final result = await _write(action, {'reason_id': picked.$1, if (picked.$2.isNotEmpty) 'notes': picked.$2},
        label: title,
        optimistic: action == 'skip' ? {'status': 'skipped', 'status_label': 'No visitada'} : {'outcome': 'no_sale'});
    if (result == null || action != 'no-sale' || !mounted) return;
    final visit = (await ref.read(routeRepoProvider).visit(widget.visitId)).value;
    final reason = '${reasons.where((r) => r['id'] == picked.$1).firstOrNull?['name'] ?? ''}';
    if (mounted) await autoPrint(context, ref, 'visit', (b) => visitTicket(visit, b, reason: reason, notes: picked.$2));
  }

  Future<void> _printVisit(Map<String, dynamic> v) => printTicket(context, ref, (b) => visitTicket(v, b));

  Future<void> _afterCheckOut() async {
    final visit = (await ref.read(routeRepoProvider).visit(widget.visitId)).value;
    if (mounted) await autoPrint(context, ref, 'visit', (b) => visitTicket(visit, b));
  }

  Future<void> _cart(Map<String, dynamic> visit, String kind) async {
    final customer = asMap(visit['customer']);
    final titles = {'sale': 'Venta', 'order': 'Pedido', 'pickup': 'Recolección'};
    final api = ref.read(apiProvider);
    final db = ref.read(localDbProvider);
    final tenders = asList(asMap(await db.getJson(RouteRepo.todayKey))['tenders']);
    final customerId = (customer['id'] as num?)?.toInt();
    final planId = (visit['plan_id'] as num?)?.toInt();
    var suggested = kind == 'sale' ? asList(visit['suggested']) : const <Map<String, dynamic>>[];
    var initialLines = <CartLine>[];
    // Captura rápida: la libreta con lo cargado en el camión (sugerido de la visita ya tecleado).
    if (kind != 'pickup' && customerId != null && ref.read(quickCaptureProvider).enabled && mounted) {
      final quick = await showQuickCapture(context,
          customerId: customerId,
          customerName: '${customer['name'] ?? ''}',
          title: titles[kind]!,
          priceListId: (customer['price_list_id'] as num?)?.toInt(),
          planId: planId,
          suggested: suggested);
      if (quick == null) return;
      initialLines = quick;
      suggested = const [];
    }
    if (!mounted) return;
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => CartPage(
        title: titles[kind]!,
        customerName: '${customer['name'] ?? ''}',
        submitLabel: kind == 'sale' ? 'Cobrar o dejar a crédito' : 'Guardar ${titles[kind]!.toLowerCase()}',
        initial: suggested,
        initialLines: initialLines,
        quote: (lines, _) async => asMap(await api.post('$_base/quote', body: {'kind': kind, 'lines': lines})),
        onSubmit: (ctx, cart) async {
          final body = <String, dynamic>{'lines': cart.lines.map((l) => l.toApi()).toList()};
          TenderChoice? choice;
          if (kind == 'sale') {
            choice = await showTenderSheet(ctx, tenderTypes: tenders, total: cart.totals.total, allowCredit: true);
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
          if (customerId != null && kind != 'pickup') await rememberLastOrder(db, customerId, cart.lines);
          if (kind == 'sale' && planId != null) await consumeTruckStock(db, planId, cart.lines);
          final docs = asList(result['documents']);
          final first = docs.firstOrNull;
          final (paid, change) = await printTenders(ref, choice?.tenders ?? const [], cart.totals.total);
          final printable = printDocFromCart(cart,
              type: '${first?['type'] ?? kind}',
              customer: '${customer['name'] ?? ''}',
              folio: first?['folio'] as String?,
              tenders: paid,
              change: change,
              onCredit: kind == 'sale' && paid.isEmpty,
              balance: first?['balance'] == null ? null : Dec.parse(first!['balance']));
          if (!ctx.mounted) return true;
          final cfdi = cfdiLoader(ref, 'documents', (first?['id'] as num?)?.toInt(), enabled: mayBeCfdi(printable.type));
          await autoPrint(ctx, ref, printKindOf(kind), (b) async => documentTicket(printable, b, cfdi: await cfdi()));
          if (first != null && ctx.mounted) {
            await showDoneDialog(ctx, ref, '${result['message'] ?? 'Guardado'}', first, print: (b) async => documentTicket(printable, b, cfdi: await cfdi()));
          }
          return true;
        },
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(visitProvider(widget.visitId));
    final v = async.valueOrNull?.value;
    final status = v?['status'] as String?;
    return Scaffold(
      appBar: AppBar(title: const Text('Visita'), actions: [
        if (v != null) IconButton(icon: const Icon(Icons.print_outlined), tooltip: 'Imprimir comprobante', onPressed: () => _printVisit(v)),
        const SyncIndicator(),
      ]),
      body: async.when(
        loading: () => const NrSkeletonList(header: true, count: 4),
        error: (e, _) => NrErrorView(e, onRetry: () => ref.invalidate(visitProvider(widget.visitId))),
        data: (c) => _body(context, c.value, c.offline),
      ),
      bottomNavigationBar: switch (status) {
        'pending' => NrBottomAction(
            label: 'Llegué con el cliente',
            icon: Icons.where_to_vote_rounded,
            busy: busy,
            onPressed: _checkIn,
            secondary: NrButton(
              label: 'No visitaré a este cliente',
              variant: NrButtonVariant.ghost,
              height: NrTouch.min,
              onPressed: busy ? null : () => _reason('skip', 'skip', 'Motivo de no visita'),
            ),
          ),
        'in_progress' => NrBottomAction(label: 'Terminar visita', icon: Icons.logout_rounded, busy: busy, onPressed: _checkOut),
        _ => null,
      },
    );
  }

  Widget _body(BuildContext context, Map<String, dynamic> v, bool offline) {
    final customer = asMap(v['customer']);
    final status = v['status'] as String?;
    final actions = asList(v['reasons']).map((r) => r['action']).toSet();
    final orders = asList(v['orders']);
    final assets = asList(v['assets']);
    final owed = asList(v['owed']);
    final owedTotal = Dec.parse(v['owed_total']);
    final overdue = owed.where((d) => d['overdue'] == true).length;
    final customerId = (customer['id'] as num?)?.toInt();
    final session = ref.watch(sessionProvider);
    final nr = context.nr;
    final phone = customer['phone'] as String?;
    final window = v['window'] is List ? (v['window'] as List).join('–') : null;
    final working = status == 'in_progress' || status == 'completed';

    Future<void> collect() async {
      final tenders = asList(asMap(await ref.read(localDbProvider).getJson(RouteRepo.todayKey))['tenders']);
      if (!context.mounted) return;
      await Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => CollectionPage(
          customerId: customerId!,
          customerName: '${customer['name']}',
          visitId: widget.visitId,
          tenderTypes: tenders.isEmpty ? null : tenders,
        ),
      ));
      ref.invalidate(visitProvider(widget.visitId));
    }

    final tiles = <Widget>[
      NrTile(icon: Icons.shopping_bag_rounded, title: 'Venta', subtitle: 'Del camión, con cobro', color: NrColors.hues[0], highlight: actions.contains('sale'), onTap: busy ? null : () => _cart(v, 'sale')),
      NrTile(icon: Icons.receipt_long_rounded, title: 'Pedido', subtitle: 'Para entregar después', color: NrColors.hues[2], highlight: actions.contains('order'), onTap: busy ? null : () => _cart(v, 'order')),
      if (orders.isNotEmpty)
        NrTile(
          icon: Icons.local_shipping_rounded,
          title: 'Entrega',
          subtitle: '${orders.length} ${orders.length == 1 ? 'pedido' : 'pedidos'} por entregar',
          color: NrColors.hues[5],
          highlight: true,
          badge: '${orders.length}',
          badgeTone: NrTone.accent,
          onTap: busy
              ? null
              : () async {
                  await Navigator.of(context).push(MaterialPageRoute(builder: (_) => DeliveryPage(visit: v)));
                  ref.invalidate(visitProvider(widget.visitId));
                },
        ),
      if (customerId != null && (session?.canCollect ?? false))
        NrTile(
          icon: Icons.payments_rounded,
          title: 'Cobro',
          subtitle: owedTotal > Dec.zero ? 'Debe ${money(owedTotal)}' : 'Pago a cuenta',
          color: NrColors.hues[1],
          highlight: actions.contains('collection') || owedTotal > Dec.zero,
          badge: overdue > 0 ? 'Vencido' : null,
          badgeTone: NrTone.danger,
          onTap: busy ? null : collect,
        ),
      NrTile(icon: Icons.assignment_return_rounded, title: 'Recolección', subtitle: 'Producto de regreso', color: NrColors.hues[4], highlight: actions.contains('pickup'), onTap: busy ? null : () => _cart(v, 'pickup')),
      if (assets.isNotEmpty)
        NrTile(
          icon: Icons.kitchen_rounded,
          title: 'Mantenimiento',
          subtitle: '${assets.length} ${assets.length == 1 ? 'equipo' : 'equipos'}',
          color: NrColors.hues[3],
          highlight: actions.contains('asset_service'),
          badge: assets.any((a) => a['service_due'] == true) ? 'Toca' : null,
          onTap: busy
              ? null
              : () async {
                  await Navigator.of(context).push(MaterialPageRoute(builder: (_) => AssetServicePage(visit: v)));
                  ref.invalidate(visitProvider(widget.visitId));
                },
        ),
      NrTile(icon: Icons.do_not_disturb_on_rounded, title: 'No venta', subtitle: 'Registrar el motivo', color: nr.muted, onTap: busy ? null : () => _reason('no_sale', 'no-sale', 'Motivo de no venta')),
    ];

    return ListView(padding: const EdgeInsets.fromLTRB(NrSpace.gutter, NrSpace.xs, NrSpace.gutter, NrSpace.xxxl), children: [
      if (offline) const Padding(padding: EdgeInsets.only(bottom: NrSpace.md), child: NrBanner(message: 'Sin señal: datos guardados. Lo que registres se envía solo.')),
      NrCard(
        depth: NrDepth.floating,
        radius: NrRadius.hero,
        padding: const EdgeInsets.fromLTRB(NrSpace.lg, NrSpace.lg, NrSpace.lg, NrSpace.md),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Hero(
              tag: 'stop-${v['id']}',
              child: Container(
                width: 52,
                height: 52,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: switch (status) { 'completed' => nr.success, 'skipped' => nr.danger, 'in_progress' => nr.accent, _ => nr.ink },
                ),
                child: status == 'completed'
                    ? const Icon(Icons.check_rounded, color: Colors.white, size: 28)
                    : Text('${v['sequence'] ?? ''}', style: NrText.title(context).copyWith(color: status == 'in_progress' ? nr.onAccent : (status == 'skipped' ? Colors.white : nr.onInk))),
              ),
            ),
            const SizedBox(width: NrSpace.md),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('${customer['name'] ?? ''}', style: NrText.title(context)),
                const SizedBox(height: 2),
                Text([?customer['code'] as String?, ?customer['address'] as String?].join(' · '), style: NrText.bodySm(context), maxLines: 2, overflow: TextOverflow.ellipsis),
              ]),
            ),
          ]),
          const SizedBox(height: NrSpace.md),
          Wrap(spacing: 6, runSpacing: 6, children: [
            NrPill('${v['status_label'] ?? status}', tone: stopTone(status), dot: true),
            if (window != null) NrPill(window, icon: Icons.schedule_rounded),
            if (v['check_in_at'] != null) NrPill('Llegada ${'${v['check_in_at']}'.length >= 16 ? '${v['check_in_at']}'.substring(11, 16) : ''}', icon: Icons.login_rounded),
          ]),
          const SizedBox(height: NrSpace.md),
          Divider(color: nr.border, height: 1),
          const SizedBox(height: NrSpace.sm),
          Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
            NrIconAction(
              icon: Icons.near_me_rounded,
              label: 'Navegar',
              color: NrColors.hues[0],
              onTap: v['navigate_url'] == null ? null : () => launchUrl(Uri.parse('${v['navigate_url']}'), mode: LaunchMode.externalApplication),
            ),
            NrIconAction(icon: Icons.call_rounded, label: 'Llamar', color: NrColors.hues[1], onTap: phone == null ? null : () => launchUrl(Uri.parse('tel:$phone'))),
            NrIconAction(
              icon: Icons.chat_rounded,
              label: 'WhatsApp',
              color: NrColors.hues[6],
              onTap: phone == null ? null : () => launchUrl(Uri.parse('https://wa.me/52${phone.replaceAll(RegExp(r'\D'), '')}'), mode: LaunchMode.externalApplication),
            ),
            NrIconAction(icon: Icons.person_rounded, label: 'Cliente', color: NrColors.hues[2], onTap: customerId == null ? null : () => context.push('/customers/$customerId')),
          ]),
        ]),
      ),
      if (owedTotal > Dec.zero) ...[
        const SizedBox(height: NrSpace.md),
        NrCard(
          accent: overdue > 0 ? nr.danger : nr.warning,
          onTap: working && customerId != null && (session?.canCollect ?? false) ? collect : null,
          child: Row(children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('SALDO PENDIENTE', style: NrText.eyebrow(context)),
                const SizedBox(height: 4),
                NrAmount(owedTotal, size: 24, animate: true, color: overdue > 0 ? nr.danger : null),
                const SizedBox(height: 2),
                Text('${owed.length} ${owed.length == 1 ? 'documento' : 'documentos'}${overdue > 0 ? ' · $overdue vencido${overdue == 1 ? '' : 's'}' : ''}', style: NrText.caption(context)),
              ]),
            ),
            if (working && customerId != null && (session?.canCollect ?? false))
              NrButton(label: 'Cobrar', icon: Icons.payments_rounded, expand: false, height: NrTouch.min, onPressed: collect),
          ]),
        ),
      ],
      if (working) ...[
        NrSectionHeader('¿Qué hiciste?'),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: NrSpace.md,
          crossAxisSpacing: NrSpace.md,
          childAspectRatio: 1.45,
          children: [for (final (i, t) in tiles.indexed) NrEntrance(index: i, child: t)],
        ),
      ] else if (status == 'pending') ...[
        const SizedBox(height: NrSpace.lg),
        NrCard(
          depth: NrDepth.flat,
          color: nr.accentSoft,
          borderColor: Colors.transparent,
          child: Row(children: [
            Icon(Icons.info_outline_rounded, color: nr.night ? nr.link : nr.accent),
            const SizedBox(width: NrSpace.md),
            Expanded(child: Text('Registra tu llegada para vender, cobrar o levantar pedidos. Se guarda tu ubicación.', style: NrText.bodySm(context).copyWith(color: nr.body))),
          ]),
        ),
      ],
      if (asList(v['done']).isNotEmpty) ...[
        NrSectionHeader('Hecho en esta visita', count: asList(v['done']).length),
        NrGroup(children: [
          for (final d in asList(v['done']))
            NrListRow(
              leading: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(color: nr.successBg, borderRadius: BorderRadius.circular(NrRadius.lg)),
                child: Icon(Icons.check_rounded, color: nr.success, size: 20),
              ),
              title: '${d['role_label'] ?? d['role']} ${d['folio'] ?? ''}',
              subtitle: [?d['type'] as String?, ?d['reason'] as String?].join(' · '),
              trailing: d['total'] == null ? null : NrMoney(d['total'], weight: FontWeight.w700),
            ),
        ]),
      ],
      if (owed.isNotEmpty) ...[
        NrSectionHeader('Documentos con saldo', count: owed.length),
        NrGroup(children: [
          for (final d in owed)
            NrListRow(
              title: '${d['type'] ?? ''} ${d['folio']}',
              subtitle: d['due_date'] == null ? null : 'Vence ${d['due_date']}',
              trailing: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.end, children: [
                NrMoney(d['balance'], weight: FontWeight.w700, color: d['overdue'] == true ? nr.danger : null),
                const SizedBox(height: 4),
                NrPill(d['overdue'] == true ? 'Vencido' : 'Por vencer', tone: d['overdue'] == true ? NrTone.danger : NrTone.neutral),
              ]),
            ),
        ]),
      ],
    ]);
  }
}

/// Elige un motivo (y nota). Regresa (id, nota).
Future<(int, String)?> pickReason(BuildContext context, List<Map<String, dynamic>> reasons, {required String title, bool notes = true}) {
  final note = TextEditingController();
  int? selected;
  return showNrSheet<(int, String)>(
    context,
    title: title,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setState) {
        final nr = ctx.nr;
        return Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          if (reasons.isEmpty) const NrEmpty(compact: true, icon: Icons.list_alt_rounded, title: 'Sin motivos', message: 'No hay motivos configurados en nori-web.'),
          Flexible(
            child: ListView(shrinkWrap: true, children: [
              for (final r in reasons)
                Padding(
                  padding: const EdgeInsets.only(bottom: NrSpace.sm),
                  child: NrCard(
                    depth: NrDepth.flat,
                    padding: const EdgeInsets.symmetric(horizontal: NrSpace.lg, vertical: NrSpace.md),
                    color: selected == r['id'] ? nr.accentSoft : null,
                    borderColor: selected == r['id'] ? nr.accent : null,
                    onTap: () {
                      NrHaptics.tap();
                      setState(() => selected = (r['id'] as num).toInt());
                    },
                    child: Row(children: [
                      Expanded(child: Text('${r['name']}', style: NrText.headline(ctx).copyWith(fontSize: 15))),
                      AnimatedSwitcher(
                        duration: NrMotion.fast,
                        child: selected == r['id']
                            ? Icon(Icons.check_circle_rounded, key: const ValueKey(1), color: nr.accent)
                            : Icon(Icons.circle_outlined, key: const ValueKey(0), color: nr.borderStrong),
                      ),
                    ]),
                  ),
                ),
            ]),
          ),
          if (notes) ...[
            const SizedBox(height: NrSpace.sm),
            TextField(controller: note, decoration: const InputDecoration(labelText: 'Notas (opcional)')),
          ],
          const SizedBox(height: NrSpace.lg),
          NrButton(label: 'Guardar', onPressed: selected == null ? null : () => Navigator.pop(ctx, (selected!, note.text.trim()))),
        ]);
      },
    ),
  );
}

/// Confirmación con la opción de compartir el PDF del documento o imprimirlo.
Future<void> showDoneDialog(BuildContext context, WidgetRef ref, String message, Map<String, dynamic> doc, {TicketBuilder? print, String? detail}) {
  NrHaptics.success();
  final canPrint = print != null && ref.read(printerSettingsProvider).configured;
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: false,
    builder: (ctx) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(NrSpace.xl, NrSpace.xl, NrSpace.xl, NrSpace.lg),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const Center(child: NrSuccessMark(size: 76)),
          const SizedBox(height: NrSpace.sm),
          Text(message, textAlign: TextAlign.center, style: NrText.title(ctx)),
          if (doc['total'] != null) ...[
            const SizedBox(height: NrSpace.md),
            Center(child: NrAmount(doc['total'], size: 40, animate: true)),
          ],
          if (detail != null) ...[
            const SizedBox(height: NrSpace.xs),
            Text(detail, textAlign: TextAlign.center, style: NrText.bodySm(ctx)),
          ],
          const SizedBox(height: NrSpace.xxl),
          if (canPrint || doc['id'] != null)
            Row(children: [
              if (canPrint)
                Expanded(child: NrButton(label: 'Imprimir', icon: Icons.print_rounded, variant: NrButtonVariant.secondary, onPressed: () => printTicket(ctx, ref, print))),
              if (canPrint && doc['id'] != null) const SizedBox(width: NrSpace.md),
              if (doc['id'] != null)
                Expanded(
                  child: NrButton(
                    label: 'Enviar PDF',
                    icon: Icons.ios_share_rounded,
                    variant: NrButtonVariant.secondary,
                    onPressed: () => shareDocument(ctx, ref, kind: 'document', id: (doc['id'] as num).toInt(), title: '${doc['folio'] ?? ''}'),
                  ),
                ),
            ]),
          if (canPrint || doc['id'] != null) const SizedBox(height: NrSpace.md),
          NrButton(label: 'Listo', onPressed: () => Navigator.pop(ctx)),
        ]),
      ),
    ),
  );
}
