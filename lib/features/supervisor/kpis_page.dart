import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/api/api_client.dart';
import '../../core/design/design.dart';
import '../../core/providers.dart';
import '../../core/widgets/sync_indicator.dart';
import 'approvals.dart';

final kpisProvider = FutureProvider.autoDispose<Map<String, dynamic>>((ref) async => asMap(unwrap(await ref.watch(apiProvider).get('/kpis'))));

String formatKpi(Map<String, dynamic> k) {
  final v = (k['value'] as num?) ?? 0;
  return switch (k['format']) {
    'money' => money(v.toString()),
    'percent' => '${v.toStringAsFixed(1)} %',
    _ => NumberFormat.decimalPattern('es_MX').format(v),
  };
}

/// Tablero: ventas hoy y del mes contra el periodo anterior, cobranza,
/// cartera, vencido, artículos más vendidos y venta por vendedor.
class KpisPage extends ConsumerWidget {
  const KpisPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(kpisProvider);
    final pending = ref.watch(pendingApprovalsProvider);
    final session = ref.watch(sessionProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Indicadores'), actions: const [SyncIndicator()]),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(kpisProvider),
        child: ListView(padding: const EdgeInsets.all(NrSpace.gutter), children: [
          if (session?.isApprover ?? false)
            NrCard(
              onTap: () => context.push('/authorizations'),
              borderColor: pending.isNotEmpty ? context.nr.warning : null,
              child: Row(children: [
                Icon(Icons.verified_user_outlined, color: pending.isNotEmpty ? context.nr.warning : context.nr.secondary),
                const SizedBox(width: NrSpace.md),
                Expanded(child: Text(pending.isEmpty ? 'Sin autorizaciones pendientes' : '${pending.length} por autorizar', style: NrText.headline(context))),
                const Icon(Icons.chevron_right),
              ]),
            ),
          async.when(
            loading: () => const Padding(padding: EdgeInsets.all(48), child: Center(child: CircularProgressIndicator())),
            error: (e, _) => NrErrorView(e, onRetry: () => ref.invalidate(kpisProvider)),
            data: (k) {
              Widget metric(String key, String label) {
                final v = k[key];
                if (v is! Map) return const SizedBox.shrink();
                final m = asMap(v);
                return NrMetric(label: label, value: formatKpi(m), change: m['change_percent'] as num?, caption: m['previous'] == null ? null : 'vs ${formatKpi({...m, 'value': m['previous']})}');
              }

              final tiles = [
                metric('sales_today', 'Venta hoy'),
                metric('sales_month', 'Venta del mes'),
                metric('collections_today', 'Cobrado hoy'),
                metric('collections_month', 'Cobrado en el mes'),
                metric('receivables', 'Cartera'),
                metric('overdue', 'Vencido'),
              ].where((w) => w is! SizedBox).toList();
              return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                const SizedBox(height: NrSpace.md),
                GridView.count(
                  crossAxisCount: MediaQuery.sizeOf(context).width > 600 ? 3 : 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: NrSpace.md,
                  crossAxisSpacing: NrSpace.md,
                  childAspectRatio: 1.35,
                  children: tiles,
                ),
                _Series(title: 'Por vendedor', rows: asList(k['by_seller'])),
                _Series(title: 'Artículos más vendidos', rows: asList(k['top_items'])),
                _Series(title: 'Antigüedad de cartera', rows: asList(k['aging'])),
                _Series(title: 'Por sucursal', rows: asList(k['by_branch'])),
              ]);
            },
          ),
        ]),
      ),
    );
  }
}

/// Barras horizontales simples (una sola serie, valor al final).
class _Series extends StatelessWidget {
  const _Series({required this.title, required this.rows});

  final String title;
  final List<Map<String, dynamic>> rows;

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) return const SizedBox.shrink();
    final max = rows.map((r) => (r['value'] as num?) ?? 0).fold<num>(0, (a, b) => b > a ? b : a);
    final nr = context.nr;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      NrSectionHeader(title),
      NrCard(
        child: Column(children: [
          for (final r in rows.take(10))
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Expanded(child: Text('${r['label']}', style: NrText.label(context), maxLines: 1, overflow: TextOverflow.ellipsis)),
                  Text(money('${r['value'] ?? 0}'), style: NrText.money(context, size: 13)),
                ]),
                const SizedBox(height: 4),
                ClipRRect(
                  borderRadius: BorderRadius.circular(NrRadius.pill),
                  child: LinearProgressIndicator(
                    value: max == 0 ? 0 : (((r['value'] as num?) ?? 0) / max).toDouble(),
                    minHeight: 6,
                    color: nr.accent,
                    backgroundColor: nr.raised,
                  ),
                ),
              ]),
            ),
        ]),
      ),
    ]);
  }
}
