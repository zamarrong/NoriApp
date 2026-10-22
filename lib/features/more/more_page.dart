import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/api/api_client.dart';
import '../../core/api/api_error.dart';
import '../../core/authorizations/authorization_flow.dart';
import '../../core/design/design.dart';
import '../../core/providers.dart';
import '../../core/sync/outbox.dart';
import '../../core/sync/sync_engine.dart';
import '../../core/widgets/pickers.dart';
import '../../core/widgets/sync_indicator.dart';

class MorePage extends ConsumerWidget {
  const MorePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(sessionProvider);
    final auth = ref.read(authProvider.notifier);
    final mode = ref.watch(themeModeProvider);
    if (s == null) return const SizedBox.shrink();
    return Scaffold(
      appBar: AppBar(title: const Text('Más'), actions: const [SyncIndicator()]),
      body: ListView(padding: const EdgeInsets.all(NrSpace.gutter), children: [
        NrCard(
          child: Row(children: [
            NrAvatar(s.userName, size: 48),
            const SizedBox(width: NrSpace.md),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(s.userName, style: NrText.headline(context)),
                Text('${s.tenantName} · ${s.warehouseName ?? 'sin almacén'}', style: NrText.bodySm(context)),
              ]),
            ),
          ]),
        ),
        NrSectionHeader('Trabajo'),
        NrGroup(children: [
          NrListRow(leading: const Icon(Icons.sync), title: 'Sincronización', subtitle: 'Cola, errores y catálogos', trailing: const Icon(Icons.chevron_right), onTap: () => context.push('/sync')),
          if (s.canSell) NrListRow(leading: const Icon(Icons.description_outlined), title: 'Mis documentos', trailing: const Icon(Icons.chevron_right), onTap: () => context.push('/documents')),
          NrListRow(leading: const Icon(Icons.history), title: 'Mis solicitudes de autorización', trailing: const Icon(Icons.chevron_right), onTap: () => context.push('/authorizations/mine')),
          NrListRow(leading: const Icon(Icons.warehouse_outlined), title: 'Almacén de trabajo', subtitle: s.warehouseName, trailing: const Icon(Icons.chevron_right), onTap: () => context.push('/warehouse')),
        ]),
        NrSectionHeader('Preferencias'),
        NrGroup(children: [
          Padding(
            padding: const EdgeInsets.all(NrSpace.md),
            child: SegmentedButton<ThemeMode>(
              segments: const [
                ButtonSegment(value: ThemeMode.system, label: Text('Sistema')),
                ButtonSegment(value: ThemeMode.light, label: Text('Claro')),
                ButtonSegment(value: ThemeMode.dark, label: Text('Oscuro')),
              ],
              selected: {mode},
              onSelectionChanged: (v) => ref.read(themeModeProvider.notifier).set(v.first),
            ),
          ),
          StatefulBuilder(
            builder: (context, setState) => SwitchListTile(
              title: const Text('Desbloqueo con huella o rostro'),
              value: auth.biometricEnabled,
              onChanged: (v) async {
                try {
                  await auth.setBiometric(v);
                  setState(() {});
                } on ApiException catch (e) {
                  if (context.mounted) showSnack(context, e.userMessage);
                }
              },
            ),
          ),
        ]),
        const SizedBox(height: NrSpace.xl),
        OutlinedButton.icon(
          icon: const Icon(Icons.logout),
          label: const Text('Cerrar sesión'),
          onPressed: () async {
            final (pending, _) = await ref.read(outboxProvider).counts();
            if (!context.mounted) return;
            final ok = await showDialog<bool>(
              context: context,
              builder: (ctx) => AlertDialog(
                title: const Text('Cerrar sesión'),
                content: Text(pending > 0 ? 'Hay $pending operaciones sin enviar. Se enviarán cuando vuelvas a entrar con este mismo usuario.' : '¿Cerrar la sesión de este dispositivo?'),
                actions: [
                  TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
                  FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Cerrar sesión')),
                ],
              ),
            );
            if (ok == true) await auth.logout();
          },
        ),
      ]),
    );
  }
}

final _outboxListProvider = FutureProvider.autoDispose<List<OutboxOp>>((ref) {
  ref.watch(syncStatusProvider);
  return ref.watch(outboxProvider).list();
});

final _catalogCountsProvider = FutureProvider.autoDispose<Map<String, int>>((ref) async {
  ref.watch(syncStatusProvider.select((s) => s.lastSync));
  final db = ref.watch(localDbProvider);
  return {for (final e in syncEntities) e: await db.count(e)};
});

/// Estado de sincronización: cola por enviar, operaciones con error (con su
/// motivo, para descartarlas o pedir autorización) y catálogos guardados.
class SyncPage extends ConsumerWidget {
  const SyncPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(syncStatusProvider);
    final ops = ref.watch(_outboxListProvider).valueOrNull ?? [];
    final counts = ref.watch(_catalogCountsProvider).valueOrNull ?? {};
    final engine = ref.watch(syncEngineProvider);
    final fmt = DateFormat('d MMM HH:mm', 'es_MX');
    return Scaffold(
      appBar: AppBar(title: const Text('Sincronización')),
      body: ListView(padding: const EdgeInsets.all(NrSpace.gutter), children: [
        NrCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(child: Text(status.online ? 'En línea' : 'Sin conexión', style: NrText.headline(context))),
              const SyncIndicator(),
            ]),
            Text(status.lastSync == null ? 'Nunca sincronizado' : 'Última: ${fmt.format(status.lastSync!.toLocal())}', style: NrText.bodySm(context)),
            if (status.progress != null) Text(status.progress!, style: NrText.caption(context)),
            if (status.lastError != null) Text(status.lastError!, style: NrText.caption(context).copyWith(color: context.nr.danger)),
            const SizedBox(height: NrSpace.md),
            FilledButton.icon(onPressed: status.syncing || engine == null ? null : () => engine.syncNow(), icon: const Icon(Icons.sync), label: const Text('Sincronizar ahora')),
          ]),
        ),
        NrSectionHeader('Cola', count: ops.length),
        if (ops.isEmpty)
          const NrCard(child: Text('Todo enviado.'))
        else
          NrGroup(children: [for (final op in ops) _OpRow(op: op)]),
        NrSectionHeader('Catálogos guardados'),
        NrGroup(children: [
          for (final e in syncEntities)
            NrListRow(title: entityLabels[e] ?? e, trailing: Text('${counts[e] ?? 0}', style: NrText.money(context))),
        ]),
      ]),
    );
  }
}

class _OpRow extends ConsumerWidget {
  const _OpRow({required this.op});

  final OutboxOp op;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final (label, tone) = switch (op.status) {
      OutboxStatus.pending || OutboxStatus.sending => ('Por enviar', NrTone.warning),
      OutboxStatus.failed => ('Error', NrTone.danger),
      OutboxStatus.needsAuthorization => ('Requiere autorización', NrTone.danger),
    };
    return NrListRow(
      title: op.label.isEmpty ? '${op.method} ${op.path}' : op.label,
      subtitle: [DateFormat('d MMM HH:mm', 'es_MX').format(op.createdAt), ?op.error].join(' · '),
      trailing: NrPill(label, tone: tone),
      onTap: op.status == OutboxStatus.pending || op.status == OutboxStatus.sending
          ? null
          : () => showModalBottomSheet<void>(
                context: context,
                builder: (ctx) => SafeArea(
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    if (op.authorization != null)
                      ListTile(
                        leading: const Icon(Icons.verified_user_outlined),
                        title: const Text('Pedir autorización y reenviar'),
                        onTap: () async {
                          Navigator.pop(ctx);
                          final id = await showAuthorizationSheet(context, op.authorization!);
                          if (id == null || !context.mounted) return;
                          try {
                            final r = await ref.read(writerProvider).retryAuthorized(op, [id], offline: true);
                            if (context.mounted) showSnack(context, r.queued ? 'En cola.' : 'Enviado.');
                          } on ApiException catch (e) {
                            if (context.mounted) showSnack(context, e.userMessage);
                          }
                        },
                      ),
                    ListTile(
                      leading: const Icon(Icons.replay),
                      title: const Text('Reintentar'),
                      onTap: () async {
                        Navigator.pop(ctx);
                        op.status = OutboxStatus.pending;
                        await ref.read(outboxProvider).save(op);
                        await ref.read(syncEngineProvider)?.syncNow(pull: false);
                      },
                    ),
                    ListTile(
                      leading: Icon(Icons.delete_outline, color: context.nr.danger),
                      title: const Text('Descartar'),
                      onTap: () async {
                        Navigator.pop(ctx);
                        await ref.read(outboxProvider).remove(op.key);
                        await ref.read(syncEngineProvider)?.refreshCounts();
                      },
                    ),
                  ]),
                ),
              ),
    );
  }
}

/// Documentos del vendedor (con PDF para compartir).
class DocumentsPage extends ConsumerWidget {
  const DocumentsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('Mis documentos')),
      body: FutureBuilder(
        future: ref.read(apiProvider).get('/documents', query: {'mine': 1, 'per_page': 50}),
        builder: (context, snap) {
          if (snap.hasError) return NrErrorView(snap.error!);
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());
          final rows = asList(asMap(snap.data)['data']);
          if (rows.isEmpty) return const NrEmpty(icon: Icons.description_outlined, title: 'Sin documentos');
          return ListView.separated(
            itemCount: rows.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (_, i) {
              final d = rows[i];
              return NrListRow(
                title: '${d['folio']} · ${d['partner_name'] ?? ''}',
                subtitle: '${d['type']} · ${d['document_date']} · ${d['status']}',
                trailing: NrMoney(d['total']),
                onTap: () => shareDocument(context, ref, kind: 'document', id: (d['id'] as num).toInt(), title: '${d['folio']}'),
              );
            },
          );
        },
      ),
    );
  }
}
