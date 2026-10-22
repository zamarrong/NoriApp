import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/api/api_client.dart';
import '../../core/design/design.dart';
import '../../core/providers.dart';
import '../../core/widgets/sync_indicator.dart';
import 'approvals.dart';

const _historyKey = 'kpi_history';

/// Tablero del servidor; cada consulta deja una foto del día en el teléfono
/// para dibujar la tendencia de los últimos días (sin inventar datos: con
/// menos de tres días no hay línea).
final kpisProvider = FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  final k = asMap(unwrap(await ref.watch(apiProvider).get('/kpis')));
  final db = ref.read(localDbProvider);
  final history = asMap(await db.getJson(_historyKey));
  final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
  history[today] = {
    for (final key in const ['sales_today', 'sales_month', 'collections_today', 'collections_month', 'receivables', 'overdue'])
      if (k[key] is Map) key: asMap(k[key])['value'],
  };
  final keys = history.keys.toList()..sort();
  for (final old in keys.take((keys.length - 30).clamp(0, keys.length))) {
    history.remove(old);
  }
  await db.putJson(_historyKey, history);
  ref.invalidate(kpiHistoryProvider);
  return k;
});

/// {indicador: [valor por día, del más viejo al de hoy]}
final kpiHistoryProvider = FutureProvider.autoDispose<Map<String, List<double>>>((ref) async {
  final history = asMap(await ref.watch(localDbProvider).getJson(_historyKey));
  final days = history.keys.toList()..sort();
  final out = <String, List<double>>{};
  for (final d in days) {
    for (final e in asMap(history[d]).entries) {
      out.putIfAbsent(e.key, () => []).add(((e.value as num?) ?? 0).toDouble());
    }
  }
  return out;
});

String formatKpi(Map<String, dynamic> k) {
  final v = (k['value'] as num?) ?? 0;
  return switch (k['format']) {
    'money' => money(v.toString()),
    'percent' => '${v.toStringAsFixed(1)} %',
    _ => NumberFormat.decimalPattern('es_MX').format(v),
  };
}

/// Tablero: venta del mes contra el anterior, ventas y cobranza del día,
/// cartera y vencido, antigüedad, artículos más vendidos y venta por vendedor.
class KpisPage extends ConsumerWidget {
  const KpisPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(kpisProvider);
    final history = ref.watch(kpiHistoryProvider).valueOrNull ?? const {};
    final pending = ref.watch(pendingApprovalsProvider);
    final session = ref.watch(sessionProvider);
    final nr = context.nr;
    return NrScrollPage(
      eyebrow: DateFormat("MMMM 'de' y", 'es_MX').format(DateTime.now()),
      title: 'Tablero',
      subtitle: const Text('Venta, cobranza y cartera al momento.'),
      actions: const [SyncIndicator()],
      onRefresh: () async {
        ref.invalidate(kpisProvider);
        await ref.read(pendingApprovalsProvider.notifier).refresh();
      },
      children: [
        if (session?.isApprover ?? false) ...[
          NrCard(
            onTap: () => context.push('/authorizations'),
            accent: pending.isNotEmpty ? nr.warning : null,
            child: Row(children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(color: pending.isEmpty ? nr.successBg : nr.warningBg, borderRadius: BorderRadius.circular(NrRadius.lg)),
                child: Icon(pending.isEmpty ? Icons.verified_rounded : Icons.pending_actions_rounded, color: pending.isEmpty ? nr.success : nr.warning),
              ),
              const SizedBox(width: NrSpace.md),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(pending.isEmpty ? 'Sin autorizaciones pendientes' : '${pending.length} por autorizar', style: NrText.headline(context)),
                  if (pending.isNotEmpty)
                    Text('${pending.first['label']}${pending.length > 1 ? ' y ${pending.length - 1} más' : ''}', style: NrText.caption(context), maxLines: 1, overflow: TextOverflow.ellipsis),
                ]),
              ),
              Icon(Icons.chevron_right_rounded, color: nr.muted),
            ]),
          ),
          const SizedBox(height: NrSpace.lg),
        ],
        ...async.when(
          skipLoadingOnReload: true,
          loading: () => [const _KpiSkeleton()],
          error: (e, _) => [NrErrorView(e, onRetry: () => ref.invalidate(kpisProvider))],
          data: (k) {
            Map<String, dynamic> m(String key) => asMap(k[key]);
            List<double>? spark(String key) => (history[key]?.length ?? 0) >= 3 ? history[key] : null;
            Widget tile(String key, String label, Color dot, {bool inverse = false}) {
              final v = m(key);
              if (v.isEmpty) return const SizedBox.shrink();
              final s = spark(key);
              return NrMetric(
                label: label,
                value: formatKpi(v),
                amount: v['format'] == 'money' ? v['value'] : null,
                dot: dot,
                inverse: inverse,
                change: v['change_percent'] as num?,
                caption: v['previous'] == null ? null : 'vs ${moneyCompact(v['previous'])}',
                spark: s == null ? null : NrSparkline(values: s, height: 28, color: dot, dot: false),
              );
            }

            final month = m('sales_month');
            return [
              if (month.isNotEmpty) NrEntrance(child: _HeroSales(month: month, spark: spark('sales_month'))),
              const SizedBox(height: NrSpace.md),
              GridView.count(
                crossAxisCount: MediaQuery.sizeOf(context).width > 600 ? 3 : 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: NrSpace.md,
                crossAxisSpacing: NrSpace.md,
                childAspectRatio: 1.25,
                children: [
                  for (final (i, w) in [
                    tile('sales_today', 'Venta hoy', nr.accent),
                    tile('collections_today', 'Cobrado hoy', nr.success),
                    tile('collections_month', 'Cobrado mes', NrColors.hues[1]),
                    tile('receivables', 'Cartera', NrColors.hues[2]),
                    tile('overdue', 'Vencido', nr.danger, inverse: true),
                  ].where((w) => w is! SizedBox).indexed)
                    NrEntrance(index: i + 1, child: w),
                ],
              ),
              if (asList(k['aging']).any((r) => ((r['value'] as num?) ?? 0) > 0)) ...[
                NrSectionHeader('Antigüedad de cartera'),
                NrCard(
                  child: NrStackBar(
                    format: (v) => money(v.toStringAsFixed(2)),
                    segments: [
                      for (final (i, r) in asList(k['aging']).indexed)
                        NrSegment('${r['label']}', ((r['value'] as num?) ?? 0).toDouble(), [nr.success, nr.accent, nr.warning, NrColors.hues[4], nr.danger][i.clamp(0, 4)]),
                    ],
                  ),
                ),
              ],
              _Ranking(title: 'Artículos más vendidos', rows: asList(k['top_items']), color: NrColors.hues[0]),
              _Ranking(title: 'Por vendedor', rows: asList(k['by_seller']), color: NrColors.hues[2]),
              _Ranking(title: 'Por sucursal', rows: asList(k['by_branch']), color: NrColors.hues[5]),
              if ((history['sales_month']?.length ?? 0) < 3)
                Padding(
                  padding: const EdgeInsets.only(top: NrSpace.lg),
                  child: Text('Las líneas de tendencia aparecen después de abrir el tablero tres días distintos.', style: NrText.caption(context), textAlign: TextAlign.center),
                ),
            ];
          },
        ),
      ],
    );
  }
}

class _KpiSkeleton extends StatelessWidget {
  const _KpiSkeleton();

  @override
  Widget build(BuildContext context) => NrShimmer(
        child: Column(children: [
          const NrCard(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              NrSkeleton(width: 110, height: 10),
              SizedBox(height: 12),
              NrSkeleton(width: 210, height: 36),
              SizedBox(height: 18),
              NrSkeleton(height: 10),
              SizedBox(height: 8),
              NrSkeleton(height: 10),
            ]),
          ),
          const SizedBox(height: NrSpace.md),
          for (var r = 0; r < 2; r++)
            Padding(
              padding: const EdgeInsets.only(bottom: NrSpace.md),
              child: Row(children: [
                for (var c = 0; c < 2; c++) ...[
                  if (c > 0) const SizedBox(width: NrSpace.md),
                  const Expanded(child: NrCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [NrSkeleton(width: 70, height: 10), SizedBox(height: 12), NrSkeleton(width: 110, height: 24)]))),
                ],
              ]),
            ),
        ]),
      );
}

/// Venta del mes: la cifra, la variación y dos barras (este mes contra el anterior al mismo día).
class _HeroSales extends StatelessWidget {
  const _HeroSales({required this.month, this.spark});

  final Map<String, dynamic> month;
  final List<double>? spark;

  @override
  Widget build(BuildContext context) {
    final nr = context.nr;
    final value = ((month['value'] as num?) ?? 0).toDouble();
    final previous = (month['previous'] as num?)?.toDouble();
    final top = [value, previous ?? 0].reduce((a, b) => a > b ? a : b);
    Widget bar(String label, double v, Color c, {bool strong = false}) => Padding(
          padding: const EdgeInsets.only(top: NrSpace.sm),
          child: Row(children: [
            SizedBox(width: 92, child: Text(label, style: NrText.caption(context).copyWith(fontWeight: strong ? FontWeight.w600 : null, color: strong ? nr.body : null))),
            Expanded(child: NrMeter(value: top == 0 ? 0 : v / top, height: 10, color: c)),
            const SizedBox(width: NrSpace.sm),
            SizedBox(width: 72, child: Text(moneyCompact(v.toStringAsFixed(2)), textAlign: TextAlign.right, style: NrText.money(context, size: 13).copyWith(color: strong ? null : nr.secondary))),
          ]),
        );
    return NrCard(
      depth: NrDepth.floating,
      radius: NrRadius.hero,
      padding: const EdgeInsets.all(NrSpace.xl),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Container(width: 7, height: 7, decoration: BoxDecoration(color: nr.accent, shape: BoxShape.circle)),
          const SizedBox(width: 6),
          Expanded(child: Text('VENTA DEL MES', style: NrText.eyebrow(context))),
          if (month['change_percent'] != null) NrDelta(month['change_percent'] as num),
        ]),
        const SizedBox(height: NrSpace.sm),
        NrAmount(month['value'], size: 40, animate: true),
        if (spark != null) ...[const SizedBox(height: NrSpace.md), NrSparkline(values: spark!, height: 56)],
        if (previous != null) ...[
          const SizedBox(height: NrSpace.md),
          bar('Este mes', value, nr.accent, strong: true),
          bar('Mes anterior', previous, nr.muted.withValues(alpha: 0.6)),
        ],
      ]),
    );
  }
}

/// Ranking con posición, barra relativa al primero y cifra.
class _Ranking extends StatelessWidget {
  const _Ranking({required this.title, required this.rows, required this.color});

  final String title;
  final List<Map<String, dynamic>> rows;
  final Color color;

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) return const SizedBox.shrink();
    final nr = context.nr;
    final max = rows.map((r) => (r['value'] as num?) ?? 0).fold<num>(0, (a, b) => b > a ? b : a);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      NrSectionHeader(title),
      NrCard(
        padding: const EdgeInsets.symmetric(horizontal: NrSpace.lg, vertical: NrSpace.sm),
        child: Column(children: [
          for (final (i, r) in rows.take(8).indexed)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(children: [
                Container(
                  width: 24,
                  height: 24,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(color: i == 0 ? nr.tint(color, 0.18) : (nr.night ? nr.raised : nr.sunken), shape: BoxShape.circle),
                  child: Text('${i + 1}', style: NrText.caption(context).copyWith(fontWeight: FontWeight.w700, color: i == 0 ? nr.tone(color) : nr.secondary)),
                ),
                const SizedBox(width: NrSpace.md),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      Expanded(child: Text('${r['label']}', style: NrText.label(context), maxLines: 1, overflow: TextOverflow.ellipsis)),
                      const SizedBox(width: NrSpace.sm),
                      Text(money('${r['value'] ?? 0}'), style: NrText.money(context, size: 13, weight: FontWeight.w700)),
                    ]),
                    const SizedBox(height: 6),
                    NrMeter(value: max == 0 ? 0 : (((r['value'] as num?) ?? 0) / max).toDouble(), height: 5, color: color),
                  ]),
                ),
              ]),
            ),
        ]),
      ),
    ]);
  }
}
