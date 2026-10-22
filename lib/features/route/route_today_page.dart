import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';

import '../../core/api/api_client.dart';
import '../../core/authorizations/authorization_flow.dart';
import '../../core/design/design.dart';
import '../../core/providers.dart';
import '../../core/sync/outbox.dart';
import '../../core/widgets/sync_indicator.dart';
import '../printing/printer.dart';
import '../printing/templates.dart';
import '../sales/quick_capture.dart';
import 'route_repo.dart';

NrTone stopTone(String? status) => switch (status) {
      'completed' => NrTone.success,
      'in_progress' => NrTone.accent,
      'skipped' => NrTone.danger,
      _ => NrTone.neutral,
    };

/// "Hoy": la ruta del día con sus paradas en orden, en lista y en mapa.
class RouteTodayPage extends ConsumerWidget {
  const RouteTodayPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final today = ref.watch(routeTodayProvider);
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Mi ruta'),
          actions: const [SyncIndicator()],
          bottom: const TabBar(tabs: [Tab(text: 'Paradas'), Tab(text: 'Mapa')]),
        ),
        body: today.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => NrErrorView(e, onRetry: () => ref.invalidate(routeTodayProvider)),
          data: (c) {
            final plans = asList(c.value['plans']);
            if (plans.isEmpty) {
              return const _NoRouteToday();
            }
            final plan = plans.first;
            final stops = asList(plan['stops'])..sort((a, b) => ((a['sequence'] as num?) ?? 0).compareTo((b['sequence'] as num?) ?? 0));
            return TabBarView(children: [
              RefreshIndicator(
                onRefresh: () async => ref.invalidate(routeTodayProvider),
                child: ListView(padding: const EdgeInsets.all(NrSpace.gutter), children: [
                  if (c.offline)
                    Padding(
                      padding: const EdgeInsets.only(bottom: NrSpace.md),
                      child: NrPill('Sin señal: mostrando lo guardado', tone: NrTone.warning, icon: Icons.cloud_off),
                    ),
                  _PlanHeader(plan: plan),
                  NrSectionHeader('Paradas', count: stops.length),
                  NrGroup(children: [for (final s in stops) _StopRow(stop: s)]),
                ]),
              ),
              _StopsMap(plan: plan, stops: stops),
            ]);
          },
        ),
      ),
    );
  }
}

/// Sin ruta hoy: lo de la venta libre en lugar de una lista vacía.
class _NoRouteToday extends ConsumerWidget {
  const _NoRouteToday();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(sessionProvider);
    final canSell = s?.canFreeSell ?? false;
    final canCheck = s?.canCheckPrices ?? false;
    return RefreshIndicator(
      onRefresh: () async => ref.invalidate(routeTodayProvider),
      child: ListView(padding: const EdgeInsets.all(NrSpace.gutter), children: [
        NrCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text('Sin ruta hoy', style: NrText.title(context)),
            const SizedBox(height: NrSpace.xs),
            Text(canSell ? 'Puedes vender sin ruta: elige al cliente y el documento.' : 'No tienes una ruta planeada para hoy.', style: NrText.bodySm(context)),
            if (canSell) ...[
              const SizedBox(height: NrSpace.lg),
              FilledButton.icon(onPressed: () => context.go('/sell'), icon: const Icon(Icons.point_of_sale), label: const Text('Vender')),
            ],
            if (canCheck) ...[
              const SizedBox(height: NrSpace.sm),
              OutlinedButton.icon(onPressed: () => context.push('/checker'), icon: const Icon(Icons.qr_code_2), label: const Text('Checador de precios')),
            ],
            if (canSell) ...[
              const SizedBox(height: NrSpace.sm),
              OutlinedButton.icon(onPressed: () => context.push('/documents'), icon: const Icon(Icons.description_outlined), label: const Text('Mis documentos')),
            ],
          ]),
        ),
      ]),
    );
  }
}

class _PlanHeader extends ConsumerWidget {
  const _PlanHeader({required this.plan});

  final Map<String, dynamic> plan;

  Future<void> _start(BuildContext context, WidgetRef ref) async {
    final fund = TextEditingController(text: '0');
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Iniciar el día'),
        content: TextField(
          controller: fund,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(labelText: 'Fondo de caja', prefixText: r'$ '),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Iniciar')),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    final op = OutboxOp.create('POST', '/route/plans/${plan['id']}/start', body: {'fund': Dec.parse(fund.text).toJson(2)}, label: 'Inicio de ruta');
    final r = await sendWithAuthorization(context, ref, op);
    if (r != null) ref.invalidate(routeTodayProvider);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final counts = asMap(plan['counts']);
    final planned = (counts['planned'] as num?) ?? 0;
    final done = ((counts['completed'] as num?) ?? 0) + ((counts['skipped'] as num?) ?? 0);
    final route = asMap(plan['route']);
    final target = Dec.parse(plan['target']);
    return NrCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text('${route['name'] ?? route['code'] ?? 'Ruta'}', style: NrText.title(context))),
          NrPill('${plan['status_label'] ?? plan['status']}', tone: NrTone.accent),
        ]),
        if (plan['vehicle'] != null) Text('${plan['vehicle']}', style: NrText.bodySm(context)),
        const SizedBox(height: NrSpace.lg),
        Row(children: [
          Expanded(child: _kv(context, 'Avance', '$done / $planned')),
          Expanded(child: _kv(context, 'Venta', money(plan['sales']))),
          if (!target.isZero) Expanded(child: _kv(context, 'Meta', money(target))),
        ]),
        const SizedBox(height: NrSpace.md),
        ClipRRect(
          borderRadius: BorderRadius.circular(NrRadius.pill),
          child: LinearProgressIndicator(value: planned == 0 ? 0 : done / planned, minHeight: 6),
        ),
        if (plan['status'] == 'draft' || plan['status'] == 'loaded') ...[
          const SizedBox(height: NrSpace.lg),
          SizedBox(width: double.infinity, child: FilledButton.icon(onPressed: () => _start(context, ref), icon: const Icon(Icons.play_arrow), label: const Text('Iniciar el día'))),
        ],
        if (plan['status'] == 'in_progress' && planned > 0 && done >= planned) ...[
          const SizedBox(height: NrSpace.lg),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              icon: const Icon(Icons.flag_outlined),
              label: const Text('Regresar al almacén'),
              onPressed: () async {
                final op = OutboxOp.create('POST', '/route/plans/${plan['id']}/finish', body: {}, label: 'Fin de ruta');
                final r = await sendWithAuthorization(context, ref, op);
                if (r != null) ref.invalidate(routeTodayProvider);
                if (r != null && context.mounted) await autoPrint(context, ref, 'settlement', (b) => settlementTicket(plan, b));
              },
            ),
          ),
        ],
        const SizedBox(height: NrSpace.md),
        Wrap(spacing: NrSpace.sm, children: [
          if (plan['truck_warehouse_id'] != null)
            ActionChip(
              avatar: const Icon(Icons.local_shipping_outlined, size: 18),
              label: const Text('Hoja de carga'),
              onPressed: () async {
                final stock = await truckStock(ref.read(apiProvider), ref.read(localDbProvider), (plan['id'] as num).toInt());
                if (context.mounted) await printTicket(context, ref, (b) => loadSheetTicket(plan, stock, b));
              },
            ),
          ActionChip(
            avatar: const Icon(Icons.summarize_outlined, size: 18),
            label: const Text('Liquidación'),
            onPressed: () => printTicket(context, ref, (b) => settlementTicket(plan, b)),
          ),
        ]),
      ]),
    );
  }

  Widget _kv(BuildContext context, String k, String v) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(k.toUpperCase(), style: NrText.eyebrow(context)),
        const SizedBox(height: 2),
        Text(v, style: NrText.money(context, size: 17)),
      ]);
}

class _StopRow extends StatelessWidget {
  const _StopRow({required this.stop});

  final Map<String, dynamic> stop;

  @override
  Widget build(BuildContext context) {
    final customer = asMap(stop['customer']);
    final window = stop['window'] is List ? (stop['window'] as List).join('–') : null;
    final reasons = asList(stop['reasons']).map((r) => '${r['name']}').join(', ');
    final nr = context.nr;
    return NrListRow(
      leading: Container(
        width: 32,
        height: 32,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: stop['status'] == 'completed' ? nr.successBg : nr.raised,
          borderRadius: BorderRadius.circular(NrRadius.pill),
        ),
        child: Text('${stop['sequence'] ?? ''}', style: NrText.label(context).copyWith(fontWeight: FontWeight.w700)),
      ),
      title: '${customer['name'] ?? 'Cliente'}',
      subtitle: [?customer['address'] as String?, ?window, if (reasons.isNotEmpty) reasons].join(' · '),
      trailing: NrPill('${stop['status_label'] ?? stop['status']}', tone: stopTone(stop['status'] as String?)),
      onTap: () => context.push('/route/visit/${stop['id']}'),
    );
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
    if (points.isEmpty) {
      return const NrEmpty(icon: Icons.map_outlined, title: 'Sin ubicaciones', message: 'Los clientes de la ruta no tienen coordenadas.');
    }
    final nr = context.nr;
    return FlutterMap(
      options: MapOptions(
        initialCameraFit: points.length == 1
            ? null
            : CameraFit.coordinates(coordinates: points, padding: const EdgeInsets.all(48)),
        initialCenter: points.first,
        initialZoom: 14,
      ),
      children: [
        TileLayer(urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png', userAgentPackageName: 'mx.nori.nori_mobile'),
        PolylineLayer(polylines: [Polyline(points: points, strokeWidth: 3, color: nr.accent.withValues(alpha: 0.6))]),
        MarkerLayer(markers: [
          if (depot['lat'] != null)
            Marker(
              point: LatLng((depot['lat'] as num).toDouble(), (depot['lng'] as num).toDouble()),
              child: Icon(Icons.warehouse, color: nr.ink),
            ),
          for (var i = 0; i < located.length; i++)
            Marker(
              point: points[i],
              width: 34,
              height: 34,
              child: GestureDetector(
                onTap: () => context.push('/route/visit/${located[i]['id']}'),
                child: Container(
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: located[i]['status'] == 'completed' ? nr.success : nr.accent,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                  child: Text('${located[i]['sequence'] ?? i + 1}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                ),
              ),
            ),
        ]),
        const SimpleAttributionWidget(source: Text('OpenStreetMap')),
      ],
    );
  }
}
