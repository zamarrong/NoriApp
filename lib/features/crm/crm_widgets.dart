import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/api/api_client.dart';
import '../../core/design/design.dart';
import '../../core/providers.dart';
import 'crm_repo.dart';

// ───────────────────────── Tipos de actividad ─────────────────────────

class ActivityKind {
  const ActivityKind(this.type, this.label, this.icon, this.color, {this.verb});
  final String type;
  final String label;
  final IconData icon;
  final Color color;

  /// "Llamar", "Visitar"…: para programar.
  final String? verb;
}

final activityKinds = <String, ActivityKind>{
  'call': ActivityKind('call', 'Llamada', Icons.call_rounded, NrColors.hues[1], verb: 'Llamar'),
  'visit': ActivityKind('visit', 'Visita', Icons.storefront_rounded, NrColors.hues[4], verb: 'Visitar'),
  'task': ActivityKind('task', 'Tarea', Icons.task_alt_rounded, NrColors.hues[0], verb: 'Hacer'),
  'whatsapp': ActivityKind('whatsapp', 'WhatsApp', Icons.chat_rounded, NrColors.hues[6], verb: 'Escribir'),
  'meeting': ActivityKind('meeting', 'Reunión', Icons.groups_rounded, NrColors.hues[5], verb: 'Reunirse'),
  'note': ActivityKind('note', 'Nota', Icons.sticky_note_2_rounded, NrColors.hues[7]),
  'email': ActivityKind('email', 'Correo', Icons.mail_rounded, NrColors.hues[2], verb: 'Escribir'),
  'stage': const ActivityKind('stage', 'Cambio de etapa', Icons.swap_horiz_rounded, Color(0xFF64748B)),
  'document': ActivityKind('document', 'Documento', Icons.description_rounded, NrColors.hues[2]),
  'system': const ActivityKind('system', 'Nori', Icons.bolt_rounded, Color(0xFF64748B)),
};

ActivityKind kindOf(Object? type) => activityKinds['$type'] ?? activityKinds['note']!;

DateTime? parseAt(Object? v) => v == null ? null : DateTime.tryParse('$v')?.toLocal();

/// "Hoy 16:00", "Mañana 9:30", "Hace 3 d", "12 nov" (como las tarjetas de la web).
String dueLabel(DateTime due, [DateTime? now]) {
  final n = now ?? DateTime.now();
  final today = DateUtils.dateOnly(n);
  final day = DateUtils.dateOnly(due);
  final time = DateFormat('H:mm', 'es_MX').format(due);
  final diff = day.difference(today).inDays;
  if (diff == 0) return 'Hoy $time';
  if (diff == 1) return 'Mañana $time';
  if (diff < 0) return diff == -1 ? 'Ayer' : 'Hace ${-diff} d';
  if (diff < 7) return '${toBeginningOfSentenceCase(DateFormat('EEEE', 'es_MX').format(due))} $time';
  return DateFormat("d MMM", 'es_MX').format(due).replaceAll('.', '');
}

String closeLabel(String? date) {
  final d = date == null ? null : DateTime.tryParse(date);
  if (d == null) return 'Sin fecha de cierre';
  return 'Cierre ${DateFormat("d MMM", 'es_MX').format(d).replaceAll('.', '')}';
}

Color stageColor(BuildContext context, Map<String, dynamic>? stage) => parseHexColor(stage?['color'] as String?) ?? context.nr.accent;

String partnerName(Map<String, dynamic> deal) {
  final p = asMap(deal['partner']);
  return '${p['trade_name'] ?? p['name'] ?? ''}';
}

String? partnerPhone(Map<String, dynamic> deal) {
  final p = asMap(deal['partner']);
  final v = '${p['mobile'] ?? p['phone'] ?? ''}'.trim();
  return v.isEmpty ? null : v;
}

Future<void> callPhone(String phone) => launchUrl(Uri.parse('tel:$phone'));

Future<void> openWhatsApp(String phone, {String? text}) {
  final digits = phone.replaceAll(RegExp(r'\D'), '');
  final number = digits.length == 10 ? '52$digits' : digits;
  return launchUrl(Uri.parse('https://wa.me/$number${text == null ? '' : '?text=${Uri.encodeComponent(text)}'}'), mode: LaunchMode.externalApplication);
}

Future<void> navigateTo(double lat, double lng) =>
    launchUrl(Uri.parse('https://www.google.com/maps/dir/?api=1&destination=$lat,$lng'), mode: LaunchMode.externalApplication);

// ───────────────────────── Tarjeta de oportunidad ─────────────────────────

/// Tarjeta del tablero (como la del kanban de la web): título, cliente, monto,
/// siguiente seguimiento con su marca de vencido, etiquetas y responsable.
class DealCard extends StatelessWidget {
  const DealCard({super.key, required this.deal, this.onTap, this.showStage = false});

  final Map<String, dynamic> deal;
  final VoidCallback? onTap;
  final bool showStage;

  @override
  Widget build(BuildContext context) {
    final nr = context.nr;
    final next = asMap(deal['next_activity']);
    final due = parseAt(next['due_at']);
    final overdue = next['overdue'] == true || (due != null && due.isBefore(DateTime.now()));
    final status = deal['status'] as String?;
    final tags = asList(deal['tags']);
    final owner = asMap(deal['owner']);
    final local = deal['local'] == true;
    final stage = asMap(deal['stage']);
    final weighted = Dec.parse(deal['weighted_amount']);
    final amount = Dec.parse(deal['amount']);
    return NrCard(
      onTap: onTap,
      padding: const EdgeInsets.fromLTRB(NrSpace.md, NrSpace.md, NrSpace.md, NrSpace.md),
      radius: NrRadius.xl,
      accent: overdue && status == 'open' ? nr.danger : null,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(
            child: Text('${deal['title'] ?? ''}', style: NrText.headline(context).copyWith(fontSize: 15), maxLines: 2, overflow: TextOverflow.ellipsis),
          ),
          const SizedBox(width: NrSpace.sm),
          if (owner.isNotEmpty) NrAvatar('${owner['name']}', size: 26),
        ]),
        const SizedBox(height: 2),
        Text(partnerName(deal), style: NrText.bodySm(context), maxLines: 1, overflow: TextOverflow.ellipsis),
        const SizedBox(height: NrSpace.sm),
        Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Expanded(
            child: Text.rich(
              TextSpan(children: [
                TextSpan(text: money(amount).replaceFirst(RegExp(r'\.00$'), ''), style: NrText.money(context, size: 17, weight: FontWeight.w700)),
                if (status == 'open' && !amount.isZero && weighted < amount)
                  TextSpan(text: '  ${moneyCompact(weighted, from: 1000).replaceFirst(RegExp(r'\.\d\d$'), '')} pond.', style: NrText.caption(context).copyWith(color: nr.muted)),
              ]),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (deal['expected_close_date'] != null && status == 'open') ...[
            const SizedBox(width: NrSpace.sm),
            Text(closeLabel(deal['expected_close_date'] as String?),
                style: NrText.caption(context).copyWith(color: deal['close_overdue'] == true ? nr.danger : nr.secondary, fontWeight: deal['close_overdue'] == true ? FontWeight.w600 : null)),
          ],
        ]),
        if (showStage || local || status != 'open' || next.isNotEmpty || tags.isNotEmpty || deal['idle'] == true) const SizedBox(height: NrSpace.sm),
        Wrap(spacing: 6, runSpacing: 6, crossAxisAlignment: WrapCrossAlignment.center, children: [
          if (local) const NrPill('Por enviar', tone: NrTone.warning, icon: Icons.cloud_upload_outlined),
          if (status == 'won') const NrPill('Ganada', tone: NrTone.success, icon: Icons.emoji_events_rounded),
          if (status == 'lost') NrPill(asMap(deal['loss_reason'])['name'] as String? ?? 'Perdida', tone: NrTone.danger, icon: Icons.close_rounded),
          if (showStage && stage.isNotEmpty && status == 'open') _StageDot(stage: stage),
          if (next.isNotEmpty && status == 'open')
            NrPill(
              '${kindOf(next['type']).verb ?? kindOf(next['type']).label} · ${due == null ? '' : dueLabel(due)}',
              tone: overdue ? NrTone.danger : NrTone.accent,
              icon: kindOf(next['type']).icon,
            )
          else if (status == 'open' && !local)
            const NrPill('Sin seguimiento', icon: Icons.event_busy_rounded),
          if (deal['idle'] == true && status == 'open') const NrPill('Inactiva', tone: NrTone.warning, icon: Icons.hourglass_bottom_rounded),
          for (final t in tags.take(2)) _TagChip(tag: t),
        ]),
      ]),
    );
  }
}

class _StageDot extends StatelessWidget {
  const _StageDot({required this.stage});
  final Map<String, dynamic> stage;

  @override
  Widget build(BuildContext context) {
    final c = stageColor(context, stage);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: context.nr.tint(c, 0.12), borderRadius: BorderRadius.circular(NrRadius.pill)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 6, height: 6, decoration: BoxDecoration(color: c, shape: BoxShape.circle)),
        const SizedBox(width: 5),
        Text('${stage['name']}', style: NrText.caption(context).copyWith(color: context.nr.tone(c), fontWeight: FontWeight.w600)),
      ]),
    );
  }
}

class _TagChip extends StatelessWidget {
  const _TagChip({required this.tag});
  final Map<String, dynamic> tag;

  @override
  Widget build(BuildContext context) {
    final c = parseHexColor(tag['color'] as String?) ?? context.nr.secondary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(NrRadius.sm),
        border: Border.all(color: c.withValues(alpha: 0.45)),
      ),
      child: Text('${tag['name']}', style: NrText.caption(context).copyWith(color: context.nr.tone(c), fontSize: 11, fontWeight: FontWeight.w600)),
    );
  }
}

/// Encabezado de columna: franja del color de la etapa, nombre, cuenta, monto y ponderado.
class StageHeader extends StatelessWidget {
  const StageHeader({super.key, required this.stage, required this.totals, this.closing = false});

  final Map<String, dynamic> stage;
  final StageTotals totals;
  final bool closing;

  @override
  Widget build(BuildContext context) {
    final nr = context.nr;
    final c = stageColor(context, stage);
    final probability = Dec.parse(stage['probability']).toDouble();
    return Container(
      padding: const EdgeInsets.fromLTRB(NrSpace.md, NrSpace.md, NrSpace.md, NrSpace.md),
      decoration: BoxDecoration(
        color: nr.surface,
        borderRadius: BorderRadius.circular(NrRadius.xl),
        border: Border(top: BorderSide(color: c, width: 3)),
        boxShadow: nr.shadow,
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text('${stage['name']}', style: NrText.headline(context), maxLines: 1, overflow: TextOverflow.ellipsis)),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(color: nr.tint(c, 0.14), borderRadius: BorderRadius.circular(NrRadius.pill)),
            child: Text('${totals.count}', style: NrText.label(context).copyWith(color: nr.tone(c), fontWeight: FontWeight.w700)),
          ),
        ]),
        const SizedBox(height: 6),
        Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
          NrAmount(totals.amount, size: 20, showCents: false),
          const SizedBox(width: NrSpace.sm),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 2),
              child: Text(
                closing ? 'este mes' : '${moneyCompact(totals.weighted, from: 1000)} ponderado · ${probability.round()} %',
                style: NrText.caption(context),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
        ]),
      ]),
    );
  }
}

// ───────────────────────── Actividades ─────────────────────────

/// Renglón de la línea de tiempo o de la agenda.
class ActivityTile extends StatelessWidget {
  const ActivityTile({super.key, required this.activity, this.onToggle, this.onTap, this.subtitle, this.dense = false});

  final Map<String, dynamic> activity;

  /// Seguimientos: marcar hecho.
  final VoidCallback? onToggle;
  final VoidCallback? onTap;
  final String? subtitle;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final nr = context.nr;
    final k = kindOf(activity['type']);
    final due = parseAt(activity['due_at']);
    final pending = activity['pending'] == true;
    final done = activity['is_follow_up'] == true && !pending;
    final overdue = pending && due != null && due.isBefore(DateTime.now());
    final at = parseAt(activity['completed_at'] ?? activity['occurred_at']);
    final body = '${activity['body'] ?? ''}'.trim();
    final meta = [
      if (subtitle != null) subtitle!,
      if (pending && due != null) dueLabel(due) else if (at != null) _ago(at),
      if (asMap(activity['created_by'])['name'] != null && !pending) '${asMap(activity['created_by'])['name']}',
    ].join(' · ');
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: NrSpace.lg, vertical: dense ? NrSpace.sm : NrSpace.md),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(color: nr.tint(k.color, 0.13), borderRadius: BorderRadius.circular(NrRadius.lg)),
            child: Icon(k.icon, size: 19, color: nr.tone(k.color)),
          ),
          const SizedBox(width: NrSpace.md),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('${activity['subject'] ?? k.label}',
                  style: NrText.headline(context).copyWith(
                    fontSize: 15,
                    decoration: done ? TextDecoration.lineThrough : null,
                    color: done ? nr.secondary : null,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis),
              if (body.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(body, style: NrText.bodySm(context), maxLines: 3, overflow: TextOverflow.ellipsis),
              ],
              const SizedBox(height: 3),
              Row(children: [
                if (overdue) ...[Icon(Icons.schedule_rounded, size: 13, color: nr.danger), const SizedBox(width: 3)],
                Flexible(
                  child: Text(meta,
                      style: NrText.caption(context).copyWith(color: overdue ? nr.danger : null, fontWeight: overdue ? FontWeight.w600 : null),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                ),
                if (activity['local'] == true) ...[const SizedBox(width: 6), Icon(Icons.cloud_upload_outlined, size: 14, color: nr.warning)],
              ]),
            ]),
          ),
          if (onToggle != null && activity['is_follow_up'] == true)
            Semantics(
              button: true,
              label: pending ? 'Marcar como hecho' : 'Reabrir',
              child: InkResponse(
                onTap: () {
                  NrHaptics.success();
                  onToggle!();
                },
                radius: 24,
                child: Padding(
                  padding: const EdgeInsets.only(left: NrSpace.sm, top: 4),
                  child: AnimatedContainer(
                    duration: NrMotion.fast,
                    width: 26,
                    height: 26,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: pending ? Colors.transparent : nr.success,
                      border: Border.all(color: pending ? (overdue ? nr.danger : nr.borderStrong) : nr.success, width: 2),
                    ),
                    child: pending ? null : Icon(Icons.check_rounded, size: 16, color: nr.night ? nr.canvas : Colors.white),
                  ),
                ),
              ),
            ),
        ]),
      ),
    );
  }

  static String _ago(DateTime at) {
    final today = DateUtils.dateOnly(DateTime.now());
    final days = today.difference(DateUtils.dateOnly(at)).inDays;
    final time = DateFormat('H:mm', 'es_MX').format(at);
    if (days <= 0) return 'Hoy $time';
    if (days == 1) return 'Ayer $time';
    if (days < 7) return 'Hace $days días';
    return DateFormat("d MMM yyyy", 'es_MX').format(at).replaceAll('.', '');
  }
}

// ───────────────────────── Agenda en "Hoy" ─────────────────────────

/// Tarjeta compacta para "Hoy": vencidos y de hoy, con los primeros tres.
class AgendaCard extends ConsumerWidget {
  const AgendaCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(sessionProvider);
    if (s == null || !s.canCrm) return const SizedBox.shrink();
    final nr = context.nr;
    final agenda = ref.watch(crmAgendaProvider).valueOrNull?.value;
    if (agenda == null) return const SizedBox.shrink();
    final items = asList(agenda['data']).where((a) => a['bucket'] != 'upcoming').toList();
    final counts = asMap(asMap(agenda['meta'])['counts']);
    final overdue = (counts['overdue'] as num?)?.toInt() ?? 0;
    final today = (counts['today'] as num?)?.toInt() ?? 0;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      NrSectionHeader('Mi agenda', count: overdue + today == 0 ? null : overdue + today, action: 'Ver todo', onAction: () => context.push('/crm/agenda')),
      NrCard(
        padding: EdgeInsets.zero,
        onTap: items.isEmpty ? () => context.push('/crm') : null,
        child: items.isEmpty
            ? Padding(
                padding: const EdgeInsets.all(NrSpace.lg),
                child: Row(children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(color: nr.successBg, borderRadius: BorderRadius.circular(NrRadius.lg)),
                    child: Icon(Icons.event_available_rounded, color: nr.success),
                  ),
                  const SizedBox(width: NrSpace.md),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('Nada pendiente para hoy', style: NrText.headline(context).copyWith(fontSize: 15)),
                      Text('Revisa tus oportunidades', style: NrText.caption(context)),
                    ]),
                  ),
                  Icon(Icons.chevron_right_rounded, color: nr.muted),
                ]),
              )
            : Column(children: [
                if (overdue > 0)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.fromLTRB(NrSpace.lg, NrSpace.sm, NrSpace.lg, NrSpace.sm),
                    color: nr.dangerBg,
                    child: Row(children: [
                      Icon(Icons.warning_amber_rounded, size: 16, color: nr.danger),
                      const SizedBox(width: 6),
                      Text(overdue == 1 ? '1 seguimiento vencido' : '$overdue seguimientos vencidos',
                          style: NrText.label(context).copyWith(color: nr.danger, fontWeight: FontWeight.w600)),
                    ]),
                  ),
                for (final (i, a) in items.take(3).indexed) ...[
                  if (i > 0) Divider(height: 1, indent: 64, color: nr.border),
                  ActivityTile(
                    activity: a,
                    dense: true,
                    subtitle: '${asMap(asMap(a['deal'])['partner'])['name'] ?? asMap(a['deal'])['title'] ?? ''}',
                    onTap: () => context.push('/crm/deals/${asMap(a['deal'])['id']}'),
                  ),
                ],
                if (items.length > 3)
                  InkWell(
                    onTap: () => context.push('/crm/agenda'),
                    child: Padding(
                      padding: const EdgeInsets.all(NrSpace.md),
                      child: Text('${items.length - 3} más', style: NrText.label(context).copyWith(color: nr.link, fontWeight: FontWeight.w600)),
                    ),
                  ),
              ]),
      ),
    ]);
  }
}
