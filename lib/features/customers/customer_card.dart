import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_client.dart';
import '../../core/design/design.dart';
import '../../core/providers.dart';
import '../route/route_repo.dart';
import '../sales/quick_capture.dart' show lastOrderAtKey;

/// Lo que el teléfono sabe del cliente sin preguntarle al servidor: cuándo se
/// le vendió desde este equipo y si está en la ruta de hoy.
class CustomerInsights {
  const CustomerInsights({this.lastAt, this.lastLines, this.stopSequence, this.stopStatus});

  final DateTime? lastAt;
  final int? lastLines;
  final int? stopSequence;
  final String? stopStatus;
}

final customerInsightsProvider = FutureProvider.autoDispose.family<CustomerInsights, int>((ref, id) async {
  final db = ref.watch(localDbProvider);
  final last = asMap(await db.getJson(lastOrderAtKey(id)));
  final today = asMap(await db.getJson(RouteRepo.todayKey));
  Map<String, dynamic>? stop;
  for (final p in asList(today['plans'])) {
    for (final s in asList(p['stops'])) {
      if (asMap(s['customer'])['id'] == id) stop = s;
    }
  }
  return CustomerInsights(
    lastAt: DateTime.tryParse('${last['at'] ?? ''}'),
    lastLines: (last['lines'] as num?)?.toInt(),
    stopSequence: (stop?['sequence'] as num?)?.toInt(),
    stopStatus: stop?['status'] as String?,
  );
});

/// "hace 3 días", "hoy", "ayer".
String relativeDay(DateTime d) {
  final today = DateUtils.dateOnly(DateTime.now());
  final days = today.difference(DateUtils.dateOnly(d.toLocal())).inDays;
  return switch (days) {
    <= 0 => 'hoy',
    1 => 'ayer',
    < 30 => 'hace $days días',
    < 60 => 'hace un mes',
    _ => 'hace ${days ~/ 30} meses',
  };
}

/// Crédito: usado contra el límite. Sin límite, solo el saldo.
class CreditGauge extends StatelessWidget {
  const CreditGauge({super.key, required this.balance, required this.limit, this.compact = false});

  final Dec balance;
  final Dec limit;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final nr = context.nr;
    if (limit <= Dec.zero) {
      return Text('Sin límite de crédito', style: NrText.caption(context));
    }
    final used = balance.toDouble() / limit.toDouble();
    final available = limit - balance;
    final over = available.isNegative;
    final c = over ? nr.danger : (used > 0.8 ? nr.warning : nr.success);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
      NrMeter(value: used, height: compact ? 5 : 8, color: c, danger: over),
      SizedBox(height: compact ? 4 : 6),
      Row(children: [
        Expanded(
          child: Text(
            over ? 'Excedido por ${moneyCompact(-available.toDouble())}' : 'Disponible ${moneyCompact(available)}',
            style: NrText.caption(context).copyWith(color: over ? nr.danger : null, fontWeight: over ? FontWeight.w600 : null),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        Text('de ${moneyCompact(limit)}', style: NrText.caption(context)),
      ]),
    ]);
  }
}

/// Tarjeta del cliente elegido para vender: saldo, crédito, última venta y si
/// está en la ruta de hoy.
class CustomerCard extends ConsumerWidget {
  const CustomerCard({super.key, required this.customer, this.onChange, this.onTap});

  final Map<String, dynamic> customer;
  final VoidCallback? onChange;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final nr = context.nr;
    final id = (customer['id'] as num).toInt();
    final name = '${customer['trade_name'] ?? customer['name'] ?? ''}';
    final balance = Dec.parse(customer['balance']);
    final limit = Dec.parse(customer['credit_limit']);
    final insights = ref.watch(customerInsightsProvider(id)).valueOrNull;
    return NrCard(
      depth: NrDepth.floating,
      radius: NrRadius.hero,
      onTap: onTap,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          NrAvatar(name, size: 48, heroTag: 'customer-$id', imageUrl: customer['image_url'] as String?),
          const SizedBox(width: NrSpace.md),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(name, style: NrText.headline(context).copyWith(fontSize: 17), maxLines: 2, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 2),
              Text([?customer['code'] as String?, ?customer['rfc'] as String?].join(' · '), style: NrText.caption(context), maxLines: 1, overflow: TextOverflow.ellipsis),
            ]),
          ),
          if (onChange != null) TextButton(onPressed: onChange, child: const Text('Cambiar')),
        ]),
        const SizedBox(height: NrSpace.lg),
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('SALDO', style: NrText.eyebrow(context)),
              const SizedBox(height: 4),
              NrAmount(balance, size: 22, animate: true, color: balance > Dec.zero && limit > Dec.zero && balance > limit ? nr.danger : null),
            ]),
          ),
          const SizedBox(width: NrSpace.lg),
          Expanded(
            flex: 2,
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Text('CRÉDITO', style: NrText.eyebrow(context)),
              const SizedBox(height: 10),
              CreditGauge(balance: balance, limit: limit, compact: true),
            ]),
          ),
        ]),
        if (insights != null && (insights.lastAt != null || insights.stopSequence != null)) ...[
          const SizedBox(height: NrSpace.md),
          Wrap(spacing: 6, runSpacing: 6, children: [
            if (insights.stopSequence != null)
              NrPill(
                insights.stopStatus == 'completed' ? 'Visitado hoy' : 'En tu ruta hoy · parada ${insights.stopSequence}',
                tone: insights.stopStatus == 'completed' ? NrTone.success : NrTone.accent,
                icon: Icons.route_rounded,
              ),
            if (insights.lastAt != null)
              NrPill('Última venta ${relativeDay(insights.lastAt!)}${insights.lastLines == null ? '' : ' · ${insights.lastLines} art.'}', icon: Icons.history_rounded),
          ]),
        ],
      ]),
    );
  }
}
