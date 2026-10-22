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
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Rechazar'),
          content: TextField(controller: ctrl, autofocus: true, decoration: const InputDecoration(labelText: 'Motivo')),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Rechazar')),
          ],
        ),
      );
      if (ok != true) return;
      comment = ctrl.text.trim();
    }
    try {
      await ref.read(pendingApprovalsProvider.notifier).decide((a['id'] as num).toInt(), approve, comment);
      if (context.mounted) showSnack(context, approve ? 'Aprobada.' : 'Rechazada.');
    } on ApiException catch (e) {
      if (context.mounted) showSnack(context, e.userMessage);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref.watch(pendingApprovalsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Autorizaciones')),
      body: RefreshIndicator(
        onRefresh: () => ref.read(pendingApprovalsProvider.notifier).refresh(),
        child: items.isEmpty
            ? ListView(children: const [SizedBox(height: 120), NrEmpty(icon: Icons.verified_outlined, title: 'Nada por autorizar')])
            : ListView.separated(
                padding: const EdgeInsets.all(NrSpace.gutter),
                itemCount: items.length,
                separatorBuilder: (_, _) => const SizedBox(height: NrSpace.md),
                itemBuilder: (_, i) {
                  final a = items[i];
                  return NrCard(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(children: [
                        Expanded(child: Text('${a['label']}', style: NrText.headline(context))),
                        if (a['requested_at'] != null) Text('${a['requested_at']}'.substring(11, 16), style: NrText.caption(context)),
                      ]),
                      Text('${a['requested_by'] ?? ''} · ${a['reference'] ?? ''}', style: NrText.bodySm(context)),
                      for (final d in asList(a['details']))
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Row(children: [
                            Expanded(child: Text('${d['label']}', style: NrText.caption(context))),
                            Text('${d['value']}', style: NrText.label(context)),
                          ]),
                        ),
                      if (a['comment'] != null) ...[const SizedBox(height: NrSpace.sm), Text('“${a['comment']}”', style: NrText.body(context))],
                      const SizedBox(height: NrSpace.md),
                      Row(children: [
                        Expanded(child: OutlinedButton(onPressed: () => _decide(context, ref, a, false), child: const Text('Rechazar'))),
                        const SizedBox(width: NrSpace.md),
                        Expanded(child: FilledButton(onPressed: () => _decide(context, ref, a, true), child: const Text('Aprobar'))),
                      ]),
                    ]),
                  );
                },
              ),
      ),
    );
  }
}

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
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());
          final rows = asList(unwrap(snap.data));
          if (rows.isEmpty) return const NrEmpty(icon: Icons.history, title: 'Sin solicitudes recientes');
          return ListView(padding: const EdgeInsets.all(NrSpace.gutter), children: [
            NrGroup(children: [
              for (final a in rows)
                NrListRow(
                  title: '${a['label']}',
                  subtitle: [a['reference'], a['decided_by'], a['decision_comment']].where((e) => e != null).join(' · '),
                  trailing: NrPill('${a['status']}',
                      tone: switch (a['status']) { 'approved' => NrTone.success, 'rejected' => NrTone.danger, 'pending' => NrTone.warning, _ => NrTone.neutral }),
                ),
            ]),
          ]);
        },
      ),
    );
  }
}
