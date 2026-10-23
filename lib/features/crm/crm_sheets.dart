import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/api/api_client.dart';
import '../../core/authorizations/authorization_flow.dart';
import '../../core/design/design.dart';
import '../../core/providers.dart';
import '../../core/sync/outbox.dart';
import '../../core/sync/writer.dart';
import '../../core/widgets/pickers.dart';
import 'crm_repo.dart';
import 'crm_widgets.dart';

/// Escritura del CRM por la cola: en línea guarda la respuesta; sin señal
/// aplica [optimistic] (y la [activity] supuesta) a lo guardado y lo avisa.
/// Regresa null si no se hizo.
Future<WriteResult?> crmWrite(
  BuildContext context,
  WidgetRef ref,
  OutboxOp op, {
  required int dealId,
  Map<String, dynamic> optimistic = const {},
  Map<String, dynamic>? activity,
}) async {
  final r = await sendWithAuthorization(context, ref, op);
  if (r == null) return null;
  final repo = ref.read(crmRepoProvider);
  if (r.queued) {
    await repo.patchLocal(dealId, optimistic, activity: activity == null ? null : {...activity, 'local': true});
    if (context.mounted) showSnack(context, 'Guardado sin señal; se enviará solo.', tone: NrTone.warning);
  } else {
    final body = asMap(unwrap(r.response));
    if (body.containsKey('timeline')) await repo.applyDetail(body);
  }
  refreshCrm(ref, dealId: dealId);
  return r;
}

Widget _chips<T>(BuildContext context, {required List<T> values, required T? selected, required String Function(T) label, IconData Function(T)? icon, required ValueChanged<T> onSelected}) {
  final nr = context.nr;
  return Wrap(spacing: NrSpace.sm, runSpacing: NrSpace.sm, children: [
    for (final v in values)
      ChoiceChip(
        avatar: icon == null ? null : Icon(icon(v), size: 16, color: v == selected ? nr.onInk : nr.secondary),
        label: Text(label(v)),
        selected: v == selected,
        onSelected: (_) {
          NrHaptics.tap();
          onSelected(v);
        },
      ),
  ]);
}

// ───────────────────────── Nueva oportunidad ─────────────────────────

/// Alta de oportunidad para un cliente (si no viene, se elige). Sin señal queda
/// en la cola y se ve en el tablero como "por enviar".
Future<void> showNewDealSheet(BuildContext context, WidgetRef ref, {Map<String, dynamic>? customer, int? pipelineId, int? stageId}) async {
  var c = customer;
  c ??= await pickCustomer(context);
  if (c == null || !context.mounted) return;
  final pipelines = (await ref.read(crmPipelinesProvider.future)).value;
  if (!context.mounted || pipelines.isEmpty) return;
  final pipeline = pipelines.where((p) => p['id'] == pipelineId).firstOrNull ?? pipelines.first;
  final open = asList(pipeline['stages']).where((s) => s['outcome'] == 'open').toList();
  final name = '${c['trade_name'] ?? c['name']}';
  final result = await showNrSheet<Map<String, dynamic>>(
    context,
    title: 'Nueva oportunidad',
    subtitle: name,
    builder: (ctx) => _NewDealForm(customerName: name, stages: open, stageId: stageId ?? open.firstOrNull?['id'] as int?),
  );
  if (result == null || !context.mounted) return;
  final body = {'business_partner_id': c['id'], 'crm_pipeline_id': pipeline['id'], ...result};
  final op = OutboxOp.create('POST', '/crm/deals', body: body, label: 'Oportunidad $name');
  final r = await sendWithAuthorization(context, ref, op);
  if (r == null || !context.mounted) return;
  final repo = ref.read(crmRepoProvider);
  NrHaptics.success();
  if (r.queued) {
    final stage = open.where((s) => s['id'] == result['crm_stage_id']).firstOrNull ?? open.firstOrNull;
    await repo.addLocalDeal(op, {
      'title': (result['title'] as String?) ?? name,
      'status': 'open',
      'pipeline_id': pipeline['id'],
      'stage_id': stage?['id'],
      'stage': stage,
      'business_partner_id': c['id'],
      'partner': {'id': c['id'], 'code': c['code'], 'name': c['name'], 'trade_name': c['trade_name'], 'phone': c['phone'], 'mobile': c['mobile']},
      'amount': '${result['amount'] ?? 0}',
      'weighted_amount': '${result['amount'] ?? 0}',
      'expected_close_date': result['expected_close_date'],
      'owner': {'id': ref.read(sessionProvider)?.userId, 'name': ref.read(sessionProvider)?.userName},
      'tags': const [],
      'updated_at': DateTime.now().toIso8601String(),
    });
    refreshCrm(ref);
    if (context.mounted) showSnack(context, 'Oportunidad guardada sin señal; se enviará sola.', tone: NrTone.warning);
    return;
  }
  final d = asMap(unwrap(r.response));
  await repo.applyDetail(d);
  refreshCrm(ref);
  if (context.mounted) {
    showSnack(context, 'Oportunidad creada', tone: NrTone.success);
    context.push('/crm/deals/${d['id']}');
  }
}

class _NewDealForm extends StatefulWidget {
  const _NewDealForm({required this.customerName, required this.stages, this.stageId});

  final String customerName;
  final List<Map<String, dynamic>> stages;
  final int? stageId;

  @override
  State<_NewDealForm> createState() => _NewDealFormState();
}

class _NewDealFormState extends State<_NewDealForm> {
  final title = TextEditingController();
  final amount = TextEditingController();
  int? stageId;
  DateTime? close;

  @override
  void initState() {
    super.initState();
    stageId = widget.stageId;
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final endOfMonth = DateTime(now.year, now.month + 1, 0);
    final endOfNext = DateTime(now.year, now.month + 2, 0);
    return SingleChildScrollView(
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        TextField(
          controller: title,
          textCapitalization: TextCapitalization.sentences,
          decoration: InputDecoration(labelText: 'Qué le vas a vender', hintText: widget.customerName, prefixIcon: const Icon(Icons.flag_rounded)),
        ),
        const SizedBox(height: NrSpace.md),
        TextField(
          controller: amount,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
          style: NrText.money(context, size: 20),
          decoration: const InputDecoration(labelText: 'Monto estimado', prefixText: r'$ ', prefixIcon: Icon(Icons.payments_rounded)),
        ),
        const SizedBox(height: NrSpace.lg),
        Text('CIERRE ESTIMADO', style: NrText.eyebrow(context)),
        const SizedBox(height: NrSpace.sm),
        _chips<String>(
          context,
          values: const ['month', 'next', 'pick'],
          selected: close == null ? null : (close == endOfMonth ? 'month' : (close == endOfNext ? 'next' : 'pick')),
          label: (v) => switch (v) {
            'month' => 'Este mes',
            'next' => 'Próximo mes',
            _ => close != null && close != endOfMonth && close != endOfNext ? DateFormat('d MMM', 'es_MX').format(close!).replaceAll('.', '') : 'Elegir fecha',
          },
          icon: (v) => v == 'pick' ? Icons.event_rounded : Icons.calendar_month_rounded,
          onSelected: (v) async {
            if (v == 'month') return setState(() => close = endOfMonth);
            if (v == 'next') return setState(() => close = endOfNext);
            final d = await showDatePicker(context: context, firstDate: DateTime(now.year - 1), lastDate: DateTime(now.year + 3), initialDate: close ?? now.add(const Duration(days: 30)));
            if (d != null) setState(() => close = d);
          },
        ),
        if (widget.stages.length > 1) ...[
          const SizedBox(height: NrSpace.lg),
          Text('ETAPA', style: NrText.eyebrow(context)),
          const SizedBox(height: NrSpace.sm),
          _chips<int>(
            context,
            values: [for (final s in widget.stages) s['id'] as int],
            selected: stageId,
            label: (id) => '${widget.stages.firstWhere((s) => s['id'] == id)['name']}',
            onSelected: (id) => setState(() => stageId = id),
          ),
        ],
        const SizedBox(height: NrSpace.xl),
        NrButton(
          label: 'Crear oportunidad',
          icon: Icons.add_rounded,
          onPressed: () => Navigator.pop(context, {
            if (title.text.trim().isNotEmpty) 'title': title.text.trim(),
            if (Dec.tryParse(amount.text) != null) 'amount': Dec.parse(amount.text).toJson(2),
            if (close != null) 'expected_close_date': DateFormat('yyyy-MM-dd').format(close!),
            'crm_stage_id': ?stageId,
          }),
        ),
      ]),
    );
  }
}

// ───────────────────────── Actividad ─────────────────────────

/// Registrar lo que pasó (llamada, visita, nota…) o programar un seguimiento.
Future<void> showActivitySheet(BuildContext context, WidgetRef ref, Map<String, dynamic> deal, {String type = 'visit', bool schedule = false}) async {
  final result = await showNrSheet<Map<String, dynamic>>(
    context,
    title: schedule ? 'Programar seguimiento' : 'Registrar actividad',
    subtitle: '${deal['title']}',
    builder: (ctx) => _ActivityForm(type: type, schedule: schedule),
  );
  if (result == null || !context.mounted) return;
  final id = (deal['id'] as num).toInt();
  final k = kindOf(result['type']);
  final op = OutboxOp.create('POST', '/crm/deals/$id/activities', body: result, label: '${k.label} · ${deal['title']}');
  final due = result['due_at'] as String?;
  final r = await crmWrite(context, ref, op, dealId: id, activity: {
    'type': result['type'],
    'subject': result['subject'] ?? k.label,
    'body': result['body'],
    'due_at': due,
    'occurred_at': DateTime.now().toIso8601String(),
    'is_follow_up': due != null,
    'pending': due != null,
  }, optimistic: due == null ? {} : {'next_activity': {'type': result['type'], 'subject': result['subject'] ?? k.label, 'due_at': due, 'overdue': false}});
  if (r != null && !r.queued && context.mounted) {
    NrHaptics.success();
    showSnack(context, due == null ? '${k.label} registrada' : 'Seguimiento programado', tone: NrTone.success);
  }
}

class _ActivityForm extends StatefulWidget {
  const _ActivityForm({required this.type, required this.schedule});

  final String type;
  final bool schedule;

  @override
  State<_ActivityForm> createState() => _ActivityFormState();
}

class _ActivityFormState extends State<_ActivityForm> {
  late String type = widget.type;
  late bool schedule = widget.schedule;
  final subject = TextEditingController();
  final body = TextEditingController();
  DateTime? due;
  String whenKey = '';
  int? remind = 30;

  static const _logTypes = ['visit', 'call', 'whatsapp', 'note', 'meeting'];
  static const _scheduleTypes = ['call', 'visit', 'task', 'whatsapp', 'meeting'];

  DateTime _at(int addDays, int hour, [int minute = 0]) {
    final n = DateTime.now();
    return DateTime(n.year, n.month, n.day + addDays, hour, minute);
  }

  @override
  void initState() {
    super.initState();
    if (schedule && !_scheduleTypes.contains(type)) type = 'call';
    if (schedule) _pickWhen('tomorrow');
  }

  void _pickWhen(String key) {
    final n = DateTime.now();
    setState(() {
      whenKey = key;
      due = switch (key) {
        'hour' => DateTime(n.year, n.month, n.day, n.hour + 1, n.minute >= 30 ? 30 : 0),
        'tomorrow' => _at(1, 9),
        'three' => _at(3, 9),
        'week' => _at(8 - n.weekday, 9),
        _ => due,
      };
    });
  }

  @override
  Widget build(BuildContext context) {
    final nr = context.nr;
    final types = schedule ? _scheduleTypes : _logTypes;
    final k = kindOf(type);
    return SingleChildScrollView(
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        NrSegmented<bool>(
          values: const [false, true],
          labels: const ['Ya lo hice', 'Programar'],
          icons: const [Icons.check_circle_outline_rounded, Icons.event_rounded],
          selected: schedule,
          onChanged: (v) {
            setState(() {
              schedule = v;
              if (!(v ? _scheduleTypes : _logTypes).contains(type)) type = v ? 'call' : 'visit';
            });
            if (v && due == null) _pickWhen('tomorrow');
          },
        ),
        const SizedBox(height: NrSpace.lg),
        Row(children: [
          for (final (i, t) in types.take(5).indexed) ...[
            if (i > 0) const SizedBox(width: 6),
            Expanded(child: _TypeButton(kind: kindOf(t), selected: t == type, onTap: () => setState(() => type = t))),
          ],
        ]),
        const SizedBox(height: NrSpace.lg),
        TextField(
          controller: subject,
          textCapitalization: TextCapitalization.sentences,
          decoration: InputDecoration(
            labelText: 'Asunto',
            hintText: schedule ? '${k.verb ?? k.label} a…' : k.label,
            prefixIcon: Icon(k.icon),
          ),
        ),
        const SizedBox(height: NrSpace.md),
        TextField(
          controller: body,
          minLines: 2,
          maxLines: 5,
          textCapitalization: TextCapitalization.sentences,
          decoration: InputDecoration(labelText: schedule ? 'Notas (opcional)' : '¿Qué pasó?', alignLabelWithHint: true),
        ),
        if (schedule) ...[
          const SizedBox(height: NrSpace.lg),
          Text('¿CUÁNDO?', style: NrText.eyebrow(context)),
          const SizedBox(height: NrSpace.sm),
          _chips<String>(
            context,
            values: const ['hour', 'tomorrow', 'three', 'week', 'pick'],
            selected: whenKey,
            label: (v) => switch (v) {
              'hour' => 'En 1 hora',
              'tomorrow' => 'Mañana 9:00',
              'three' => 'En 3 días',
              'week' => 'Próximo lunes',
              _ => whenKey == 'pick' && due != null ? dueLabel(due!) : 'Elegir…',
            },
            onSelected: (v) async {
              if (v != 'pick') return _pickWhen(v);
              final d = await showDatePicker(context: context, firstDate: DateTime.now().subtract(const Duration(days: 1)), lastDate: DateTime.now().add(const Duration(days: 365)), initialDate: due ?? DateTime.now());
              if (d == null || !context.mounted) return;
              final t = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(due ?? _at(0, 9)));
              setState(() {
                whenKey = 'pick';
                due = DateTime(d.year, d.month, d.day, t?.hour ?? 9, t?.minute ?? 0);
              });
            },
          ),
          const SizedBox(height: NrSpace.lg),
          Text('RECORDATORIO', style: NrText.eyebrow(context)),
          const SizedBox(height: NrSpace.sm),
          _chips<int>(
            context,
            values: const [-1, 15, 30, 60],
            selected: remind ?? -1,
            label: (v) => switch (v) { -1 => 'Sin aviso', 60 => '1 hora antes', _ => '$v min antes' },
            onSelected: (v) => setState(() => remind = v < 0 ? null : v),
          ),
          if (due != null) ...[
            const SizedBox(height: NrSpace.md),
            Row(children: [
              Icon(Icons.event_rounded, size: 16, color: nr.secondary),
              const SizedBox(width: 6),
              Text(toBeginningOfSentenceCase(DateFormat("EEEE d 'de' MMMM, H:mm", 'es_MX').format(due!)), style: NrText.bodySm(context)),
            ]),
          ],
        ],
        const SizedBox(height: NrSpace.xl),
        NrButton(
          label: schedule ? 'Programar' : 'Registrar ${k.label.toLowerCase()}',
          icon: schedule ? Icons.event_available_rounded : Icons.check_rounded,
          onPressed: schedule && due == null
              ? null
              : () => Navigator.pop(context, {
                    'type': type,
                    if (subject.text.trim().isNotEmpty) 'subject': subject.text.trim(),
                    if (body.text.trim().isNotEmpty) 'body': body.text.trim(),
                    if (schedule) 'due_at': due!.toUtc().toIso8601String(),
                    if (schedule && remind != null) 'remind_minutes': remind,
                  }),
        ),
      ]),
    );
  }
}

class _TypeButton extends StatelessWidget {
  const _TypeButton({required this.kind, required this.selected, required this.onTap});

  final ActivityKind kind;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final nr = context.nr;
    return Semantics(
      selected: selected,
      button: true,
      label: kind.label,
      child: NrPressable(
        child: InkWell(
          borderRadius: BorderRadius.circular(NrRadius.lg),
          onTap: () {
            NrHaptics.tap();
            onTap();
          },
          child: AnimatedContainer(
            duration: NrMotion.fast,
            padding: const EdgeInsets.symmetric(vertical: NrSpace.sm),
            decoration: BoxDecoration(
              color: selected ? nr.tint(kind.color, 0.16) : (nr.night ? nr.raised : nr.sunken.withValues(alpha: 0.6)),
              borderRadius: BorderRadius.circular(NrRadius.lg),
              border: Border.all(color: selected ? nr.tone(kind.color) : Colors.transparent, width: 1.5),
            ),
            child: Column(children: [
              Icon(kind.icon, color: selected ? nr.tone(kind.color) : nr.secondary, size: 22),
              const SizedBox(height: 4),
              Text(kind.label,
                  style: NrText.caption(context).copyWith(color: selected ? nr.headline : nr.secondary, fontWeight: selected ? FontWeight.w700 : FontWeight.w500),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis),
            ]),
          ),
        ),
      ),
    );
  }
}

/// Seguimiento hecho (o reabierto).
Future<void> toggleActivity(BuildContext context, WidgetRef ref, Map<String, dynamic> activity, {int? dealId}) async {
  final id = activity['id'];
  if (id == null || activity['local'] == true) return;
  final pending = activity['pending'] == true;
  final op = OutboxOp.create('PATCH', '/crm/activities/$id', body: {'action': pending ? 'complete' : 'reopen'}, label: pending ? 'Seguimiento hecho' : 'Seguimiento reabierto');
  final deal = dealId ?? (activity['deal_id'] as num?)?.toInt() ?? (asMap(activity['deal'])['id'] as num?)?.toInt();
  if (deal == null) return;
  final r = await crmWrite(context, ref, op, dealId: deal);
  if (r != null && !r.queued && context.mounted && pending) showSnack(context, 'Listo: ${activity['subject']}', tone: NrTone.success);
}

// ───────────────────────── Etapas y cierre ─────────────────────────

Future<void> showMoveSheet(BuildContext context, WidgetRef ref, Map<String, dynamic> deal) async {
  final stages = asList(asMap(deal['pipeline'])['stages']).where((s) => s['outcome'] == 'open').toList();
  final current = deal['stage_id'];
  final stage = await showNrSheet<Map<String, dynamic>>(
    context,
    title: 'Mover a otra etapa',
    builder: (ctx) => SingleChildScrollView(
      child: NrGroup(inset: 52, children: [
        for (final s in stages)
          NrListRow(
            leading: Container(width: 14, height: 14, margin: const EdgeInsets.all(5), decoration: BoxDecoration(color: stageColor(ctx, s), shape: BoxShape.circle)),
            title: '${s['name']}',
            subtitle: '${Dec.parse(s['probability']).toDouble().round()} % de probabilidad',
            trailing: s['id'] == current ? Icon(Icons.check_rounded, color: ctx.nr.accent) : null,
            onTap: () => Navigator.pop(ctx, s),
          ),
      ]),
    ),
  );
  if (stage == null || stage['id'] == current || !context.mounted) return;
  await moveDeal(context, ref, deal, stage);
}

Future<void> moveDeal(BuildContext context, WidgetRef ref, Map<String, dynamic> deal, Map<String, dynamic> stage) async {
  final id = (deal['id'] as num).toInt();
  final op = OutboxOp.create('POST', '/crm/deals/$id/move', body: {'stage_id': stage['id']}, label: '${deal['title']} → ${stage['name']}');
  final r = await crmWrite(context, ref, op, dealId: id, optimistic: {
    'stage_id': stage['id'],
    'stage': stage,
    'status': stage['outcome'],
    'updated_at': DateTime.now().toIso8601String(),
  });
  if (r != null && !r.queued && context.mounted) {
    NrHaptics.success();
    showSnack(context, 'Ahora en ${stage['name']}', tone: NrTone.success);
  }
}

Future<void> winDeal(BuildContext context, WidgetRef ref, Map<String, dynamic> deal) async {
  final id = (deal['id'] as num).toInt();
  final won = asList(asMap(deal['pipeline'])['stages']).where((s) => s['outcome'] == 'won').firstOrNull;
  final op = OutboxOp.create('POST', '/crm/deals/$id/win', label: 'Ganada: ${deal['title']}');
  final r = await crmWrite(context, ref, op, dealId: id, optimistic: {
    'status': 'won',
    'stage_id': ?won?['id'],
    'stage': ?won,
    'closed_at': DateTime.now().toIso8601String(),
    'updated_at': DateTime.now().toIso8601String(),
  });
  if (r != null && !r.queued && context.mounted) {
    NrHaptics.success();
    showSnack(context, '¡Ganada! ${deal['title']}', tone: NrTone.success);
  }
}

Future<void> showLoseSheet(BuildContext context, WidgetRef ref, Map<String, dynamic> deal) async {
  final reasons = await ref.read(crmLossReasonsProvider.future).catchError((_) => <Map<String, dynamic>>[]);
  if (!context.mounted) return;
  final result = await showNrSheet<Map<String, dynamic>>(
    context,
    title: '¿Por qué se perdió?',
    subtitle: '${deal['title']}',
    builder: (ctx) => _LoseForm(reasons: reasons),
  );
  if (result == null || !context.mounted) return;
  final id = (deal['id'] as num).toInt();
  final lost = asList(asMap(deal['pipeline'])['stages']).where((s) => s['outcome'] == 'lost').firstOrNull;
  final reason = reasons.where((r) => r['id'] == result['loss_reason_id']).firstOrNull;
  final op = OutboxOp.create('POST', '/crm/deals/$id/lose', body: result, label: 'Perdida: ${deal['title']}');
  final r = await crmWrite(context, ref, op, dealId: id, optimistic: {
    'status': 'lost',
    'stage_id': ?lost?['id'],
    'stage': ?lost,
    'loss_reason': ?reason,
    'loss_notes': result['loss_notes'],
    'closed_at': DateTime.now().toIso8601String(),
    'updated_at': DateTime.now().toIso8601String(),
  });
  if (r != null && !r.queued && context.mounted) showSnack(context, 'Marcada como perdida');
}

class _LoseForm extends StatefulWidget {
  const _LoseForm({required this.reasons});
  final List<Map<String, dynamic>> reasons;

  @override
  State<_LoseForm> createState() => _LoseFormState();
}

class _LoseFormState extends State<_LoseForm> {
  int? reason;
  final notes = TextEditingController();

  @override
  Widget build(BuildContext context) {
    final nr = context.nr;
    final canSave = reason != null || notes.text.trim().isNotEmpty;
    return SingleChildScrollView(
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        if (widget.reasons.isNotEmpty)
          NrGroup(inset: 52, children: [
            for (final r in widget.reasons)
              NrListRow(
                dense: true,
                leading: Icon(reason == r['id'] ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded, color: reason == r['id'] ? nr.danger : nr.muted),
                title: '${r['name']}',
                onTap: () {
                  NrHaptics.tap();
                  setState(() => reason = r['id'] as int);
                },
              ),
          ]),
        const SizedBox(height: NrSpace.md),
        TextField(
          controller: notes,
          minLines: 2,
          maxLines: 4,
          onChanged: (_) => setState(() {}),
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(labelText: 'Notas (opcional)', alignLabelWithHint: true),
        ),
        const SizedBox(height: NrSpace.xl),
        NrButton(
          label: 'Marcar como perdida',
          variant: NrButtonVariant.danger,
          icon: Icons.thumb_down_alt_rounded,
          onPressed: canSave ? () => Navigator.pop(context, {'loss_reason_id': ?reason, if (notes.text.trim().isNotEmpty) 'loss_notes': notes.text.trim()}) : null,
        ),
      ]),
    );
  }
}
