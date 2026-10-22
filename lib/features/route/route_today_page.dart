import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/api/api_client.dart';
import '../../core/authorizations/authorization_flow.dart';
import '../../core/design/design.dart';
import '../../core/providers.dart';
import '../../core/sync/outbox.dart';
import '../../core/widgets/sync_indicator.dart';
import '../printing/printer.dart';
import '../printing/templates.dart';
import '../sales/quick_capture.dart';
import '../supervisor/kpis_page.dart';
import 'route_repo.dart';

NrTone stopTone(String? status) => switch (status) {
      'completed' => NrTone.success,
      'in_progress' => NrTone.accent,
      'skipped' => NrTone.danger,
      _ => NrTone.neutral,
    };

/// "Buenos días" según la hora.
String greeting([DateTime? now]) {
  final h = (now ?? DateTime.now()).hour;
  return h < 12 ? 'Buenos días' : (h < 19 ? 'Buenas tardes' : 'Buenas noches');
}

String _firstName(String name) => name.trim().split(RegExp(r'\s+')).firstOrNull ?? '';

String _today() => DateFormat("EEEE d 'de' MMMM", 'es_MX').format(DateTime.now());

/// Una parada se puede marcar como "en visita" o la siguiente por hacer.
Map<String, dynamic>? nextStop(List<Map<String, dynamic>> stops) =>
    stops.where((s) => s['status'] == 'in_progress').firstOrNull ?? stops.where((s) => s['status'] == 'pending').firstOrNull;

Future<void> _call(String? phone) async {
  if (phone == null || phone.isEmpty) return;
  await launchUrl(Uri.parse('tel:$phone'));
}

Future<void> _navigate(Map<String, dynamic> stop) async {
  final url = stop['navigate_url'] as String?;
  if (url != null) await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
}

/// "Hoy" (Mi día): el avance de la ruta, la venta contra la meta, lo cobrado,
/// lo que falta por enviar y la siguiente parada; abajo, la ruta en lista o en
/// mapa. Sin ruta, el resumen del día y los atajos de la venta libre.
class RouteTodayPage extends ConsumerStatefulWidget {
  const RouteTodayPage({super.key});

  @override
  ConsumerState<RouteTodayPage> createState() => _RouteTodayPageState();
}

class _RouteTodayPageState extends ConsumerState<RouteTodayPage> {
  bool map = false;

  @override
  Widget build(BuildContext context) {
    final today = ref.watch(routeTodayProvider);
    final session = ref.watch(sessionProvider);
    final name = _firstName(session?.userName ?? '');
    final plans = asList(today.valueOrNull?.value['plans']);
    final plan = plans.firstOrNull;
    final stops = plan == null ? <Map<String, dynamic>>[] : (asList(plan['stops'])..sort((a, b) => ((a['sequence'] as num?) ?? 0).compareTo((b['sequence'] as num?) ?? 0)));
    final pendingStops = stops.where((s) => s['status'] == 'pending' || s['status'] == 'in_progress').length;

    Widget subtitle;
    if (today.isLoading && !today.hasValue) {
      subtitle = const Text('Cargando tu día…');
    } else if (plan == null) {
      subtitle = const Text('Hoy no tienes ruta planeada. Puedes vender a cualquier cliente.');
    } else if (pendingStops == 0) {
      subtitle = const Text('Terminaste las paradas de hoy. Ya puedes regresar al almacén.');
    } else {
      subtitle = Text('Te ${pendingStops == 1 ? 'falta 1 parada' : 'faltan $pendingStops paradas'} en ${asMap(plan['route'])['name'] ?? 'tu ruta'}.');
    }

    return NrScrollPage(
      eyebrow: _today(),
      title: name.isEmpty ? greeting() : '${greeting()}, $name',
      subtitle: subtitle,
      actions: const [SyncIndicator()],
      onRefresh: () async {
        ref.invalidate(routeTodayProvider);
        ref.invalidate(kpisProvider);
        await ref.read(routeTodayProvider.future).catchError((_) => const Cached(<String, dynamic>{}));
      },
      children: [
        ...today.when(
          loading: () => [const _DaySkeleton()],
          error: (e, _) => [NrErrorView(e, onRetry: () => ref.invalidate(routeTodayProvider))],
          data: (c) {
            if (plan == null) return [const _NoRouteToday()];
            final next = nextStop(stops);
            return [
              if (c.offline) const Padding(padding: EdgeInsets.only(bottom: NrSpace.md), child: NrBanner(message: 'Sin señal: estás viendo lo guardado. Lo que hagas se envía solo.')),
              NrEntrance(child: _DayCard(plan: plan, stops: stops)),
              if (next != null) ...[
                NrSectionHeader(next['status'] == 'in_progress' ? 'En visita' : 'Siguiente parada'),
                NrEntrance(index: 1, child: _NextStopCard(stop: next)),
              ],
              NrSectionHeader('Tu ruta', count: stops.length),
              NrSegmented<bool>(
                values: const [false, true],
                labels: const ['Paradas', 'Mapa'],
                icons: const [Icons.format_list_bulleted_rounded, Icons.map_outlined],
                selected: map,
                onChanged: (v) => setState(() => map = v),
              ),
              const SizedBox(height: NrSpace.md),
              NrSwitcher(
                child: map
                    ? ClipRRect(
                        key: const ValueKey('map'),
                        borderRadius: BorderRadius.circular(NrRadius.xxl),
                        child: SizedBox(height: 440, child: _StopsMap(plan: plan, stops: stops)),
                      )
                    : _Timeline(key: const ValueKey('list'), stops: stops),
              ),
            ];
          },
        ),
      ],
    );
  }
}

class _DaySkeleton extends StatelessWidget {
  const _DaySkeleton();

  @override
  Widget build(BuildContext context) => NrShimmer(
        child: Column(children: [
          NrCard(
            child: Row(children: [
              const NrSkeleton(width: 104, height: 104, radius: 52),
              const SizedBox(width: NrSpace.lg),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: const [
                  NrSkeleton(width: 80, height: 10),
                  SizedBox(height: 10),
                  NrSkeleton(width: 150, height: 28),
                  SizedBox(height: 14),
                  NrSkeleton(height: 8),
                ]),
              ),
            ]),
          ),
          const SizedBox(height: NrSpace.lg),
          const NrCard(child: SizedBox(height: 120)),
        ]),
      );
}

/// Tarjeta del día: anillo de paradas, venta contra meta y cifras del día.
class _DayCard extends ConsumerWidget {
  const _DayCard({required this.plan, required this.stops});

  final Map<String, dynamic> plan;
  final List<Map<String, dynamic>> stops;

  Future<void> _start(BuildContext context, WidgetRef ref) async {
    final fund = TextEditingController(text: '0');
    final ok = await showNrSheet<bool>(
      context,
      title: 'Iniciar el día',
      subtitle: 'Con cuánto efectivo sales para dar cambio.',
      builder: (ctx) => Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        TextField(
          controller: fund,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          style: NrText.money(ctx, size: 28),
          decoration: const InputDecoration(labelText: 'Fondo de caja', prefixText: r'$ '),
        ),
        const SizedBox(height: NrSpace.lg),
        NrButton(label: 'Iniciar ruta', icon: Icons.play_arrow_rounded, onPressed: () => Navigator.pop(ctx, true)),
      ]),
    );
    if (ok != true || !context.mounted) return;
    final op = OutboxOp.create('POST', '/route/plans/${plan['id']}/start', body: {'fund': Dec.parse(fund.text).toJson(2)}, label: 'Inicio de ruta');
    final r = await sendWithAuthorization(context, ref, op);
    if (r != null) {
      NrHaptics.success();
      ref.invalidate(routeTodayProvider);
    }
  }

  Future<void> _finish(BuildContext context, WidgetRef ref) async {
    final op = OutboxOp.create('POST', '/route/plans/${plan['id']}/finish', body: {}, label: 'Fin de ruta');
    final r = await sendWithAuthorization(context, ref, op);
    if (r != null) {
      NrHaptics.success();
      ref.invalidate(routeTodayProvider);
    }
    if (r != null && context.mounted) await autoPrint(context, ref, 'settlement', (b) => settlementTicket(plan, b));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final nr = context.nr;
    final counts = asMap(plan['counts']);
    final planned = ((counts['planned'] as num?) ?? stops.length).toInt();
    final completed = ((counts['completed'] as num?) ?? 0).toInt();
    final skipped = ((counts['skipped'] as num?) ?? 0).toInt();
    final done = completed + skipped;
    final route = asMap(plan['route']);
    final target = Dec.parse(plan['target']);
    final sales = Dec.parse(plan['sales']);
    final collected = stops.fold(Dec.zero, (s, v) => s + Dec.parse(v['collected_total']));
    final pendingSync = ref.watch(syncStatusProvider.select((s) => s.pending));
    final status = plan['status'] as String?;
    final progress = target.isZero ? null : sales.toDouble() / target.toDouble();

    return NrCard(
      depth: NrDepth.floating,
      radius: NrRadius.hero,
      padding: EdgeInsets.zero,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(NrSpace.lg, NrSpace.lg, NrSpace.lg, NrSpace.md),
          child: Row(children: [
            NrRing(
              value: planned == 0 ? 0 : completed / planned,
              secondary: planned == 0 ? 0 : skipped / planned,
              secondaryColor: nr.danger.withValues(alpha: 0.55),
              size: 108,
              stroke: 11,
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                NrCountUp(
                  value: done.toDouble(),
                  builder: (context, v) => Text('${v.round()}/$planned', style: NrText.stat(context).copyWith(fontSize: 24)),
                ),
                Text('paradas', style: NrText.caption(context)),
              ]),
            ),
            const SizedBox(width: NrSpace.lg),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Expanded(child: Text('VENTA DEL DÍA', style: NrText.eyebrow(context))),
                  NrPill('${plan['status_label'] ?? status}', tone: status == 'in_progress' ? NrTone.accent : NrTone.neutral, dot: true),
                ]),
                const SizedBox(height: 6),
                NrAmount(sales, size: 30, animate: true),
                const SizedBox(height: NrSpace.md),
                if (progress != null) ...[
                  NrMeter(value: progress, height: 7, color: progress >= 1 ? nr.success : nr.accent),
                  const SizedBox(height: 6),
                  Text(
                    progress >= 1 ? '¡Meta cumplida! ${money(target)}' : '${(progress * 100).round()} % de la meta de ${moneyCompact(target)}',
                    style: NrText.caption(context).copyWith(color: progress >= 1 ? nr.success : null, fontWeight: progress >= 1 ? FontWeight.w600 : null),
                  ),
                ] else
                  Text('${route['name'] ?? route['code'] ?? 'Ruta'}${plan['vehicle'] != null ? ' · ${plan['vehicle']}' : ''}', style: NrText.caption(context), maxLines: 2),
              ]),
            ),
          ]),
        ),
        Container(
          margin: const EdgeInsets.symmetric(horizontal: NrSpace.lg),
          padding: const EdgeInsets.symmetric(vertical: NrSpace.md),
          decoration: BoxDecoration(border: Border(top: BorderSide(color: nr.border))),
          child: IntrinsicHeight(
            child: Row(children: [
              _MiniStat(label: 'Cobrado', dot: nr.success, child: NrAmount(collected, size: 17, animate: true, showCents: false)),
              VerticalDivider(color: nr.border, width: NrSpace.xl),
              _MiniStat(
                label: 'Por visitar',
                dot: nr.accent,
                child: Text('${((counts['pending'] as num?) ?? 0)}', style: NrText.money(context, size: 17, weight: FontWeight.w700)),
              ),
              VerticalDivider(color: nr.border, width: NrSpace.xl),
              _MiniStat(
                label: 'Por enviar',
                dot: pendingSync > 0 ? nr.warning : nr.muted,
                onTap: () => context.push('/sync'),
                child: Text('$pendingSync', style: NrText.money(context, size: 17, weight: FontWeight.w700).copyWith(color: pendingSync > 0 ? nr.warning : null)),
              ),
            ]),
          ),
        ),
        if (status == 'draft' || status == 'loaded')
          Padding(
            padding: const EdgeInsets.fromLTRB(NrSpace.lg, 0, NrSpace.lg, NrSpace.lg),
            child: NrButton(label: 'Iniciar el día', icon: Icons.play_arrow_rounded, onPressed: () => _start(context, ref)),
          ),
        if (status == 'in_progress' && planned > 0 && done >= planned)
          Padding(
            padding: const EdgeInsets.fromLTRB(NrSpace.lg, 0, NrSpace.lg, NrSpace.lg),
            child: NrButton(label: 'Regresar al almacén', icon: Icons.flag_rounded, onPressed: () => _finish(context, ref)),
          ),
        Container(
          padding: const EdgeInsets.fromLTRB(NrSpace.md, NrSpace.xs, NrSpace.md, NrSpace.sm),
          color: nr.night ? nr.raised.withValues(alpha: 0.5) : nr.canvas.withValues(alpha: 0.6),
          child: Row(children: [
            Icon(Icons.local_shipping_outlined, size: 16, color: nr.muted),
            const SizedBox(width: 6),
            Expanded(
              child: Text('${route['name'] ?? route['code'] ?? 'Ruta'}${plan['vehicle'] != null ? ' · ${plan['vehicle']}' : ''}',
                  style: NrText.caption(context), maxLines: 1, overflow: TextOverflow.ellipsis),
            ),
            if (plan['truck_warehouse_id'] != null)
              TextButton(
                onPressed: () async {
                  final stock = await truckStock(ref.read(apiProvider), ref.read(localDbProvider), (plan['id'] as num).toInt());
                  if (context.mounted) await printTicket(context, ref, (b) => loadSheetTicket(plan, stock, b));
                },
                child: const Text('Carga'),
              ),
            TextButton(onPressed: () => printTicket(context, ref, (b) => settlementTicket(plan, b)), child: const Text('Liquidación')),
          ]),
        ),
      ]),
    );
  }
}

class _MiniStat extends StatelessWidget {
  const _MiniStat({required this.label, required this.child, required this.dot, this.onTap});

  final String label;
  final Widget child;
  final Color dot;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Expanded(
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(NrRadius.md),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Container(width: 6, height: 6, decoration: BoxDecoration(color: dot, shape: BoxShape.circle)),
              const SizedBox(width: 5),
              Flexible(child: Text(label.toUpperCase(), style: NrText.eyebrow(context).copyWith(fontSize: 10), maxLines: 1, overflow: TextOverflow.ellipsis)),
            ]),
            const SizedBox(height: 4),
            child,
          ]),
        ),
      );
}

/// La parada que sigue: grande, con navegar y llamar a la mano.
class _NextStopCard extends StatelessWidget {
  const _NextStopCard({required this.stop});

  final Map<String, dynamic> stop;

  @override
  Widget build(BuildContext context) {
    final nr = context.nr;
    final customer = asMap(stop['customer']);
    final window = stop['window'] is List ? (stop['window'] as List).join('–') : null;
    final inVisit = stop['status'] == 'in_progress';
    final reasons = asList(stop['reasons']);
    return NrCard(
      accent: nr.accent,
      onTap: () => context.push('/route/visit/${stop['id']}'),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _SeqBadge(stop: stop, size: 44),
          const SizedBox(width: NrSpace.md),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('${customer['name'] ?? 'Cliente'}', style: NrText.title(context).copyWith(fontSize: 18), maxLines: 2, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 2),
              Text('${customer['address'] ?? customer['code'] ?? ''}', style: NrText.bodySm(context), maxLines: 2, overflow: TextOverflow.ellipsis),
            ]),
          ),
        ]),
        const SizedBox(height: NrSpace.md),
        Wrap(spacing: 6, runSpacing: 6, children: [
          if (inVisit) const NrPill('En visita', tone: NrTone.accent, dot: true),
          if (window != null) NrPill(window, icon: Icons.schedule_rounded),
          for (final r in reasons) _ReasonChip(reason: r),
        ]),
        const SizedBox(height: NrSpace.lg),
        Row(children: [
          if (stop['navigate_url'] != null) ...[
            Expanded(child: NrButton(label: 'Navegar', icon: Icons.near_me_rounded, variant: NrButtonVariant.secondary, height: NrTouch.min, onPressed: () => _navigate(stop))),
            const SizedBox(width: NrSpace.sm),
          ],
          if (customer['phone'] != null) ...[
            NrSquareButton(icon: Icons.call_rounded, tooltip: 'Llamar', onPressed: () => _call('${customer['phone']}')),
            const SizedBox(width: NrSpace.sm),
          ],
          Expanded(
            child: NrButton(
              label: inVisit ? 'Continuar' : 'Abrir visita',
              icon: Icons.arrow_forward_rounded,
              height: NrTouch.min,
              onPressed: () => context.push('/route/visit/${stop['id']}'),
            ),
          ),
        ]),
      ]),
    );
  }
}

/// Motivo de la visita con su color (configurado en nori-web).
class _ReasonChip extends StatelessWidget {
  const _ReasonChip({required this.reason});

  final Map<String, dynamic> reason;

  @override
  Widget build(BuildContext context) {
    final nr = context.nr;
    final c = parseHexColor(reason['color'] as String?) ?? nr.muted;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: nr.night ? nr.raised : nr.canvas, borderRadius: BorderRadius.circular(NrRadius.pill), border: Border.all(color: nr.border)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 6, height: 6, decoration: BoxDecoration(color: c, shape: BoxShape.circle)),
        const SizedBox(width: 5),
        Text('${reason['name']}', style: NrText.caption(context).copyWith(color: nr.body, fontWeight: FontWeight.w500)),
      ]),
    );
  }
}

/// Número de la parada con el color de su estado (y Hero hacia la visita).
class _SeqBadge extends StatelessWidget {
  const _SeqBadge({required this.stop, this.size = 32});

  final Map<String, dynamic> stop;
  final double size;

  @override
  Widget build(BuildContext context) {
    final nr = context.nr;
    final status = stop['status'] as String?;
    final (bg, fg) = switch (status) {
      'completed' => (nr.success, Colors.white),
      'skipped' => (nr.dangerBg, nr.danger),
      'in_progress' => (nr.accent, nr.onAccent),
      _ => (nr.surface, nr.headline),
    };
    return Hero(
      tag: 'stop-${stop['id']}',
      child: Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: bg,
          shape: BoxShape.circle,
          border: status == 'pending' || status == null ? Border.all(color: nr.borderStrong, width: 1.5) : null,
          boxShadow: status == 'in_progress' ? [BoxShadow(color: nr.accent.withValues(alpha: 0.35), blurRadius: 10, spreadRadius: 1)] : null,
        ),
        child: switch (status) {
          'completed' => Icon(Icons.check_rounded, size: size * 0.55, color: fg),
          'skipped' => Icon(Icons.close_rounded, size: size * 0.5, color: fg),
          _ => Text('${stop['sequence'] ?? ''}', style: NrText.label(context).copyWith(color: fg, fontWeight: FontWeight.w700, fontSize: size * 0.4)),
        },
      ),
    );
  }
}

/// Paradas como línea de tiempo: punto con el estado, venta de las hechas.
/// Deslizar a la derecha llama; a la izquierda abre la navegación.
class _Timeline extends StatelessWidget {
  const _Timeline({super.key, required this.stops});

  final List<Map<String, dynamic>> stops;

  @override
  Widget build(BuildContext context) {
    final nr = context.nr;
    return NrCard(
      padding: const EdgeInsets.symmetric(vertical: NrSpace.sm),
      child: Column(children: [
        for (var i = 0; i < stops.length; i++)
          NrEntrance(
            index: i,
            child: _swipe(
              context,
              stops[i],
              InkWell(
                onTap: () => context.push('/route/visit/${stops[i]['id']}'),
                child: IntrinsicHeight(
                  child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    SizedBox(
                      width: 56,
                      child: Stack(alignment: Alignment.center, children: [
                        Positioned(
                          top: i == 0 ? 32 : 0,
                          bottom: i == stops.length - 1 ? null : 0,
                          height: i == stops.length - 1 ? 32 : null,
                          child: Container(width: 2, color: stops[i]['status'] == 'completed' ? nr.success.withValues(alpha: 0.35) : nr.border),
                        ),
                        Positioned(top: 16, child: _SeqBadge(stop: stops[i])),
                      ]),
                    ),
                    Expanded(child: _StopBody(stop: stops[i])),
                  ]),
                ),
              ),
            ),
          ),
      ]),
    );
  }

  Widget _swipe(BuildContext context, Map<String, dynamic> stop, Widget child) {
    final nr = context.nr;
    final customer = asMap(stop['customer']);
    final canCall = customer['phone'] != null;
    final canNav = stop['navigate_url'] != null;
    if (!canCall && !canNav) return child;
    Widget bg(IconData icon, String label, Color c, Alignment a) => Container(
          color: nr.tint(c, 0.16),
          alignment: a,
          padding: const EdgeInsets.symmetric(horizontal: NrSpace.xl),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, color: nr.tone(c)),
            const SizedBox(width: 6),
            Text(label, style: NrText.label(context).copyWith(color: nr.tone(c), fontWeight: FontWeight.w700)),
          ]),
        );
    return Dismissible(
      key: ValueKey('stop-swipe-${stop['id']}'),
      direction: canCall && canNav ? DismissDirection.horizontal : (canCall ? DismissDirection.startToEnd : DismissDirection.endToStart),
      dismissThresholds: const {DismissDirection.startToEnd: 0.3, DismissDirection.endToStart: 0.3},
      background: bg(Icons.call_rounded, 'Llamar', nr.success, Alignment.centerLeft),
      secondaryBackground: bg(Icons.near_me_rounded, 'Navegar', nr.accent, Alignment.centerRight),
      confirmDismiss: (d) async {
        NrHaptics.action();
        if (d == DismissDirection.startToEnd) {
          await _call('${customer['phone']}');
        } else {
          await _navigate(stop);
        }
        return false;
      },
      child: child,
    );
  }
}

class _StopBody extends StatelessWidget {
  const _StopBody({required this.stop});

  final Map<String, dynamic> stop;

  @override
  Widget build(BuildContext context) {
    final nr = context.nr;
    final customer = asMap(stop['customer']);
    final window = stop['window'] is List ? (stop['window'] as List).join('–') : null;
    final status = stop['status'] as String?;
    final sale = Dec.parse(stop['sale_total']);
    final reasons = asList(stop['reasons']);
    final faded = status == 'completed' || status == 'skipped';
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, NrSpace.md, NrSpace.lg, NrSpace.md),
      child: Row(children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('${customer['name'] ?? 'Cliente'}',
                style: NrText.headline(context).copyWith(fontSize: 15, color: faded ? nr.secondary : null), maxLines: 1, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 2),
            Text([?customer['address'] as String?, ?window].join(' · '), style: NrText.caption(context), maxLines: 1, overflow: TextOverflow.ellipsis),
            if (reasons.isNotEmpty) ...[
              const SizedBox(height: 6),
              Row(children: [
                for (final r in reasons.take(4))
                  Container(
                    margin: const EdgeInsets.only(right: 4),
                    width: 16,
                    height: 4,
                    decoration: BoxDecoration(color: parseHexColor(r['color'] as String?) ?? nr.muted, borderRadius: BorderRadius.circular(2)),
                  ),
                const SizedBox(width: 2),
                Flexible(child: Text(reasons.map((r) => '${r['name']}').join(', '), style: NrText.caption(context).copyWith(fontSize: 11), maxLines: 1, overflow: TextOverflow.ellipsis)),
              ]),
            ],
          ]),
        ),
        const SizedBox(width: NrSpace.sm),
        if (status == 'completed' && sale > Dec.zero)
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            NrMoney(sale, size: 15, weight: FontWeight.w700),
            Text('vendido', style: NrText.caption(context).copyWith(fontSize: 11)),
          ])
        else
          NrPill('${stop['status_label'] ?? status}', tone: stopTone(status)),
      ]),
    );
  }
}

/// Sin ruta hoy: el resumen del día y los atajos de la venta libre.
class _NoRouteToday extends ConsumerWidget {
  const _NoRouteToday();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(sessionProvider);
    final nr = context.nr;
    final canSell = s?.canFreeSell ?? false;
    final canCheck = s?.canCheckPrices ?? false;
    final kpis = (s?.canKpis ?? false) ? ref.watch(kpisProvider).valueOrNull : null;
    final sync = ref.watch(syncStatusProvider);
    Widget kpi(String key, String label, Color dot) {
      final m = asMap(kpis?[key]);
      return Expanded(
        child: NrMetric(
          label: label,
          value: '—',
          amount: m.isEmpty ? null : m['value'],
          change: m['change_percent'] as num?,
          dot: dot,
        ),
      );
    }

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      if (canSell)
        NrEntrance(
          child: NrCard(
            depth: NrDepth.floating,
            radius: NrRadius.hero,
            onTap: () => context.go('/sell'),
            gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color.lerp(nr.accent, Colors.white, 0.12)!, nr.accent, Color.lerp(nr.accent, Colors.black, 0.18)!]),
            padding: const EdgeInsets.all(NrSpace.xl),
            child: Row(children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('VENTA LIBRE', style: NrText.eyebrow(context).copyWith(color: nr.onAccent.withValues(alpha: 0.75))),
                  const SizedBox(height: 6),
                  Text('Vender a un cliente', style: NrText.title(context).copyWith(color: nr.onAccent)),
                  const SizedBox(height: 4),
                  Text('Cotización, pedido, entrega o factura, con cobro.', style: NrText.bodySm(context).copyWith(color: nr.onAccent.withValues(alpha: 0.8))),
                ]),
              ),
              const SizedBox(width: NrSpace.md),
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(color: nr.onAccent.withValues(alpha: 0.16), borderRadius: BorderRadius.circular(NrRadius.xl)),
                child: Icon(Icons.arrow_forward_rounded, color: nr.onAccent),
              ),
            ]),
          ),
        ),
      if (kpis != null) ...[
        NrSectionHeader('Tu día'),
        NrEntrance(
          index: 1,
          child: IntrinsicHeight(
            child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              kpi('sales_today', 'Venta hoy', nr.accent),
              const SizedBox(width: NrSpace.md),
              kpi('collections_today', 'Cobrado hoy', nr.success),
            ]),
          ),
        ),
      ],
      if (sync.pending > 0 || sync.failed > 0) ...[
        const SizedBox(height: NrSpace.md),
        NrCard(
          onTap: () => context.push('/sync'),
          accent: sync.failed > 0 ? nr.danger : nr.warning,
          child: Row(children: [
            Icon(sync.failed > 0 ? Icons.error_outline_rounded : Icons.cloud_upload_outlined, color: sync.failed > 0 ? nr.danger : nr.warning),
            const SizedBox(width: NrSpace.md),
            Expanded(
              child: Text(sync.failed > 0 ? '${sync.failed} operaciones con error' : '${sync.pending} operaciones por enviar',
                  style: NrText.headline(context).copyWith(fontSize: 15)),
            ),
            Icon(Icons.chevron_right_rounded, color: nr.muted),
          ]),
        ),
      ],
      NrSectionHeader('Atajos'),
      NrEntrance(
        index: 2,
        child: Row(children: [
          if (canCheck)
            Expanded(
              child: SizedBox(
                height: 116,
                child: NrTile(icon: Icons.qr_code_scanner_rounded, title: 'Checador', subtitle: 'Precio y existencia', color: NrColors.hues[1], onTap: () => context.push('/checker')),
              ),
            ),
          if (canCheck && canSell) const SizedBox(width: NrSpace.md),
          if (canSell)
            Expanded(
              child: SizedBox(
                height: 116,
                child: NrTile(icon: Icons.receipt_long_rounded, title: 'Mis documentos', subtitle: 'Estado y PDF', color: NrColors.hues[2], onTap: () => context.push('/documents')),
              ),
            ),
        ]),
      ),
      const SizedBox(height: NrSpace.md),
      const NrCard(
        depth: NrDepth.flat,
        child: NrEmpty(
          compact: true,
          icon: Icons.route_rounded,
          title: 'Sin ruta hoy',
          message: 'Cuando tengas una ruta planeada, aquí verás tus paradas, el avance y la meta del día.',
        ),
      ),
    ]);
  }
}

class _StopsMap extends StatelessWidget {
  const _StopsMap({required this.plan, required this.stops});

  final Map<String, dynamic> plan;
  final List<Map<String, dynamic>> stops;

  @override
  Widget build(BuildContext context) {
    final located = stops.where((s) => asMap(s['customer'])['lat'] != null).toList();
    final points = located.map((s) {
      final c = asMap(s['customer']);
      return LatLng((c['lat'] as num).toDouble(), (c['lng'] as num).toDouble());
    }).toList();
    final depot = asMap(asMap(plan['route'])['depot']);
    final nr = context.nr;
    if (points.isEmpty) {
      return ColoredBox(
        color: nr.surface,
        child: const NrEmpty(icon: Icons.map_outlined, title: 'Sin ubicaciones', message: 'Los clientes de la ruta no tienen coordenadas.'),
      );
    }
    return FlutterMap(
      options: MapOptions(
        initialCameraFit: points.length == 1 ? null : CameraFit.coordinates(coordinates: points, padding: const EdgeInsets.all(48)),
        initialCenter: points.first,
        initialZoom: 14,
      ),
      children: [
        TileLayer(urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png', userAgentPackageName: 'mx.nori.nori_mobile'),
        PolylineLayer(polylines: [Polyline(points: points, strokeWidth: 4, color: nr.accent.withValues(alpha: 0.7))]),
        MarkerLayer(markers: [
          if (depot['lat'] != null)
            Marker(
              point: LatLng((depot['lat'] as num).toDouble(), (depot['lng'] as num).toDouble()),
              width: 36,
              height: 36,
              child: Container(
                decoration: BoxDecoration(color: nr.ink, borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.white, width: 2)),
                child: Icon(Icons.warehouse_rounded, color: nr.onInk, size: 18),
              ),
            ),
          for (var i = 0; i < located.length; i++)
            Marker(
              point: points[i],
              width: 36,
              height: 36,
              child: GestureDetector(
                onTap: () => context.push('/route/visit/${located[i]['id']}'),
                child: Container(
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: switch (located[i]['status']) {
                      'completed' => nr.success,
                      'skipped' => nr.danger,
                      'in_progress' => nr.accent,
                      _ => nr.ink,
                    },
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2.5),
                    boxShadow: const [BoxShadow(color: Color(0x40000000), blurRadius: 6, offset: Offset(0, 2))],
                  ),
                  child: Text('${located[i]['sequence'] ?? i + 1}',
                      style: TextStyle(color: located[i]['status'] == 'pending' ? nr.onInk : Colors.white, fontWeight: FontWeight.w700, fontSize: 13)),
                ),
              ),
            ),
        ]),
        const SimpleAttributionWidget(source: Text('OpenStreetMap')),
      ],
    );
  }
}
