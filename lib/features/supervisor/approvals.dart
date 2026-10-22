import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_client.dart';
import '../../core/api/api_error.dart';
import '../../core/design/design.dart';
import '../../core/providers.dart';
import '../../core/sync/outbox.dart';

/// Notificaciones locales (sin servidor de push: la bandeja se consulta cada 20 s).
class LocalNotifier {
  LocalNotifier._();
  static final instance = LocalNotifier._();
  final _plugin = FlutterLocalNotificationsPlugin();
  bool _ready = false;

  Future<void> init() async {
    if (_ready) return;
    try {
      await _plugin.initialize(const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(),
      ));
      await _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()?.requestNotificationsPermission();
      _ready = true;
    } catch (_) {}
  }

  Future<void> show(int id, String title, String body) async {
    if (!_ready) return;
    await _plugin.show(
      id,
      title,
      body,
      const NotificationDetails(
        android: AndroidNotificationDetails('authorizations', 'Autorizaciones', importance: Importance.high, priority: Priority.high),
        iOS: DarwinNotificationDetails(),
      ),
    );
  }
}

/// Bandeja del supervisor: solicitudes que puede decidir. Se consulta cada 20 s
/// y avisa con una notificación local de las nuevas.
class PendingApprovals extends Notifier<List<Map<String, dynamic>>> {
  Timer? _timer;
  final _seen = <int>{};
  bool _first = true;

  @override
  List<Map<String, dynamic>> build() {
    final session = ref.watch(sessionProvider);
    final signedIn = ref.watch(authProvider.select((s) => s.status == AuthStatus.signedIn));
    _timer?.cancel();
    if (session != null && session.isApprover && signedIn) {
      LocalNotifier.instance.init();
      Future.microtask(refresh);
      _timer = Timer.periodic(const Duration(seconds: 20), (_) => refresh());
    }
    ref.onDispose(() => _timer?.cancel());
    return const [];
  }

  Future<void> refresh() async {
    try {
      final r = asMap(await ref.read(apiProvider).get('/authorizations/pending'));
      final items = asList(r['items']);
      for (final a in items) {
        final id = (a['id'] as num).toInt();
        if (_seen.add(id) && !_first) {
          LocalNotifier.instance.show(id, '${a['label']}', '${a['requested_by'] ?? ''} · ${a['reference'] ?? ''}');
        }
      }
      _first = false;
      state = items;
    } on ApiException catch (_) {}
  }

  Future<void> decide(int id, bool approve, String? comment) async {
    final op = OutboxOp.create('POST', '/authorizations/$id/decide',
        body: {'approve': approve, if (comment != null && comment.isNotEmpty) 'comment': comment}, label: approve ? 'Aprobar' : 'Rechazar');
    await ref.read(writerProvider).send(op, offline: false);
    state = state.where((a) => a['id'] != id).toList();
  }
}

final pendingApprovalsProvider = NotifierProvider<PendingApprovals, List<Map<String, dynamic>>>(PendingApprovals.new);

class AuthorizationsPage extends ConsumerWidget {
  const AuthorizationsPage({super.key});

  Future<void> _decide(BuildContext context, WidgetRef ref, Map<String, dynamic> a, bool approve) async {
    String? comment;
    if (!approve) {
      final ctrl = TextEditingController();
      final ok = await showNrSheet<bool>(
        context,
        title: 'Rechazar',
        subtitle: '${a['label']}',
        builder: (ctx) => Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          TextField(controller: ctrl, autofocus: true, maxLines: 2, decoration: const InputDecoration(labelText: 'Motivo (lo verá quien lo pidió)')),
          const SizedBox(height: NrSpace.lg),
          NrButton(label: 'Rechazar', icon: Icons.close_rounded, variant: NrButtonVariant.danger, onPressed: () => Navigator.pop(ctx, true)),
        ]),
      );
      if (ok != true) return;
      comment = ctrl.text.trim();
    }
    try {
      await ref.read(pendingApprovalsProvider.notifier).decide((a['id'] as num).toInt(), approve, comment);
      if (approve) NrHaptics.success();
      if (context.mounted) showSnack(context, approve ? 'Aprobada.' : 'Rechazada.', tone: approve ? NrTone.success : NrTone.neutral);
    } on ApiException catch (e) {
      NrHaptics.warning();
      if (context.mounted) showSnack(context, e.userMessage, tone: NrTone.danger);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref.watch(pendingApprovalsProvider);
    final nr = context.nr;
    return Scaffold(
      appBar: AppBar(title: const Text('Autorizaciones')),
      body: RefreshIndicator(
        onRefresh: () => ref.read(pendingApprovalsProvider.notifier).refresh(),
        child: items.isEmpty
            ? ListView(children: const [
                SizedBox(height: 80),
                NrEmpty(icon: Icons.verified_rounded, title: 'Nada por autorizar', message: 'Te avisamos con una notificación cuando alguien pida una autorización.'),
              ])
            : ListView.separated(
                padding: const EdgeInsets.fromLTRB(NrSpace.gutter, NrSpace.xs, NrSpace.gutter, NrSpace.xxxl),
                itemCount: items.length,
                separatorBuilder: (_, _) => const SizedBox(height: NrSpace.md),
                itemBuilder: (_, i) {
                  final a = items[i];
                  final who = '${a['requested_by'] ?? ''}';
                  final at = '${a['requested_at'] ?? ''}';
                  return NrEntrance(
                    index: i,
                    child: NrCard(
                      key: ValueKey(a['id']),
                      accent: nr.warning,
                      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          NrAvatar(who, size: 40),
                          const SizedBox(width: NrSpace.md),
                          Expanded(
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text('${a['label']}', style: NrText.headline(context)),
                              const SizedBox(height: 2),
                              Text([who, '${a['reference'] ?? ''}'].where((e) => e.isNotEmpty).join(' · '), style: NrText.caption(context)),
                            ]),
                          ),
                          if (at.length >= 16) NrPill(at.substring(11, 16), icon: Icons.schedule_rounded),
                        ]),
                        if (asList(a['details']).isNotEmpty) ...[
                          const SizedBox(height: NrSpace.md),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: NrSpace.md, vertical: NrSpace.sm),
                            decoration: BoxDecoration(color: nr.night ? nr.raised : nr.canvas, borderRadius: BorderRadius.circular(NrRadius.lg)),
                            child: Column(children: [
                              for (final d in asList(a['details']))
                                Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 4),
                                  child: Row(children: [
                                    Expanded(child: Text('${d['label']}', style: NrText.bodySm(context))),
                                    Text('${d['value']}', style: NrText.money(context, size: 14, weight: FontWeight.w700)),
                                  ]),
                                ),
                            ]),
                          ),
                        ],
                        if (a['comment'] != null) ...[
                          const SizedBox(height: NrSpace.md),
                          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Icon(Icons.format_quote_rounded, size: 18, color: nr.muted),
                            const SizedBox(width: 6),
                            Expanded(child: Text('${a['comment']}', style: NrText.body(context).copyWith(fontStyle: FontStyle.italic, color: nr.secondary))),
                          ]),
                        ],
                        const SizedBox(height: NrSpace.lg),
                        Row(children: [
                          Expanded(child: NrButton(label: 'Rechazar', icon: Icons.close_rounded, variant: NrButtonVariant.danger, height: NrTouch.min, onPressed: () => _decide(context, ref, a, false))),
                          const SizedBox(width: NrSpace.md),
                          Expanded(child: NrButton(label: 'Aprobar', icon: Icons.check_rounded, height: NrTouch.min, onPressed: () => _decide(context, ref, a, true))),
                        ]),
                      ]),
                    ),
                  );
                },
              ),
      ),
    );
  }
}

const _requestStatus = {
  'approved': ('Aprobada', NrTone.success),
  'rejected': ('Rechazada', NrTone.danger),
  'pending': ('Pendiente', NrTone.warning),
  'expired': ('Vencida', NrTone.neutral),
  'used': ('Usada', NrTone.neutral),
};

/// Lo que el usuario ha pedido (últimos días) y qué decidió el supervisor.
class MyAuthorizationsPage extends ConsumerWidget {
  const MyAuthorizationsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('Mis solicitudes')),
      body: FutureBuilder(
        future: ref.read(apiProvider).get('/authorizations/mine'),
        builder: (context, snap) {
          if (snap.hasError) return NrErrorView(snap.error!);
          if (!snap.hasData) return const NrSkeletonList(count: 5);
          final rows = asList(unwrap(snap.data));
          if (rows.isEmpty) {
            return const NrEmpty(icon: Icons.history_rounded, title: 'Sin solicitudes recientes', message: 'Cuando algo necesite el visto bueno de un supervisor, verás aquí su respuesta.');
          }
          return ListView(padding: const EdgeInsets.fromLTRB(NrSpace.gutter, NrSpace.xs, NrSpace.gutter, NrSpace.xxxl), children: [
            NrGroup(children: [
              for (final a in rows)
                NrListRow(
                  title: '${a['label']}',
                  subtitle: [a['reference'], a['decided_by'], a['decision_comment']].where((e) => e != null).join(' · '),
                  trailing: NrPill(_requestStatus[a['status']]?.$1 ?? '${a['status']}', tone: _requestStatus[a['status']]?.$2 ?? NrTone.neutral, dot: true),
                ),
            ]),
          ]);
        },
      ),
    );
  }
}
