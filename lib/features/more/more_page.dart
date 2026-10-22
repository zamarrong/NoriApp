import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/api/api_error.dart';
import '../../core/authorizations/authorization_flow.dart';
import '../../core/design/design.dart';
import '../../core/providers.dart';
import '../../core/sync/outbox.dart';
import '../../core/sync/sync_engine.dart';
import '../../core/widgets/sync_indicator.dart';
import '../printing/printer.dart';

Widget _lead(BuildContext context, IconData icon, Color c) => Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(color: context.nr.tint(c, 0.13), borderRadius: BorderRadius.circular(NrRadius.lg)),
      child: Icon(icon, color: context.nr.tone(c), size: 20),
    );

class MorePage extends ConsumerWidget {
  const MorePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(sessionProvider);
    final auth = ref.read(authProvider.notifier);
    final mode = ref.watch(themeModeProvider);
    final hc = ref.watch(highContrastProvider);
    final sync = ref.watch(syncStatusProvider);
    final nr = context.nr;
    if (s == null) return const SizedBox.shrink();
    final chevron = Icon(Icons.chevron_right_rounded, color: nr.muted);
    return NrScrollPage(
      title: 'Más',
      actions: const [SyncIndicator()],
      children: [
        NrCard(
          depth: NrDepth.floating,
          radius: NrRadius.hero,
          child: Row(children: [
            NrAvatar(s.userName, size: 56, color: nr.accent),
            const SizedBox(width: NrSpace.md),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(s.userName, style: NrText.title(context).copyWith(fontSize: 18)),
                const SizedBox(height: 2),
                Text(s.tenantName, style: NrText.bodySm(context), maxLines: 1, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 6),
                Wrap(spacing: 6, runSpacing: 6, children: [
                  NrPill(s.warehouseName ?? 'Sin almacén', icon: Icons.warehouse_rounded),
                  if (s.isAdmin) const NrPill('Administrador', tone: NrTone.accent),
                ]),
              ]),
            ),
          ]),
        ),
        NrSectionHeader('Trabajo'),
        NrGroup(inset: 64, children: [
          NrListRow(
            leading: _lead(context, Icons.sync_rounded, NrColors.hues[0]),
            title: 'Sincronización',
            subtitle: sync.pending > 0 || sync.failed > 0 ? '${sync.pending} por enviar · ${sync.failed} con error' : 'Cola, errores y catálogos',
            trailing: chevron,
            onTap: () => context.push('/sync'),
          ),
          if (s.canCheckPrices)
            NrListRow(leading: _lead(context, Icons.qr_code_scanner_rounded, NrColors.hues[1]), title: 'Checador de precios', trailing: chevron, onTap: () => context.push('/checker')),
          if (s.canFreeSell || s.canSell)
            NrListRow(leading: _lead(context, Icons.receipt_long_rounded, NrColors.hues[2]), title: 'Mis documentos', trailing: chevron, onTap: () => context.push('/documents')),
          NrListRow(leading: _lead(context, Icons.history_rounded, NrColors.hues[7]), title: 'Mis solicitudes de autorización', trailing: chevron, onTap: () => context.push('/authorizations/mine')),
          NrListRow(leading: _lead(context, Icons.warehouse_rounded, NrColors.hues[5]), title: 'Almacén de trabajo', subtitle: s.warehouseName, trailing: chevron, onTap: () => context.push('/warehouse')),
        ]),
        NrSectionHeader('Equipo'),
        NrGroup(inset: 64, children: [
          NrListRow(leading: _lead(context, Icons.tune_rounded, NrColors.hues[3]), title: 'Configuración', subtitle: 'Captura rápida y favoritos', trailing: chevron, onTap: () => context.push('/settings')),
          NrListRow(
            leading: _lead(context, Icons.print_rounded, NrColors.hues[6]),
            title: 'Impresora',
            subtitle: ref.watch(printerSettingsProvider).name ?? 'Térmica Bluetooth 58/80 mm',
            trailing: chevron,
            onTap: () => context.push('/printer'),
          ),
        ]),
        NrSectionHeader('Apariencia'),
        NrCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            NrSegmented<ThemeMode>(
              values: const [ThemeMode.system, ThemeMode.light, ThemeMode.dark],
              labels: const ['Sistema', 'Claro', 'Oscuro'],
              icons: const [Icons.brightness_auto_rounded, Icons.light_mode_rounded, Icons.dark_mode_rounded],
              selected: mode,
              onChanged: (v) => ref.read(themeModeProvider.notifier).set(v),
            ),
            const SizedBox(height: NrSpace.sm),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              secondary: _lead(context, Icons.wb_sunny_rounded, NrColors.hues[7]),
              title: const Text('Alto contraste'),
              subtitle: const Text('Texto más oscuro y bordes visibles para leer a pleno sol.'),
              value: hc,
              onChanged: (v) {
                NrHaptics.tap();
                ref.read(highContrastProvider.notifier).set(v);
              },
            ),
            StatefulBuilder(
              builder: (context, setState) => SwitchListTile(
                contentPadding: EdgeInsets.zero,
                secondary: _lead(context, Icons.fingerprint_rounded, NrColors.hues[1]),
                title: const Text('Desbloqueo con huella o rostro'),
                value: auth.biometricEnabled,
                onChanged: (v) async {
                  try {
                    await auth.setBiometric(v);
                    setState(() {});
                  } on ApiException catch (e) {
                    if (context.mounted) showSnack(context, e.userMessage, tone: NrTone.danger);
                  }
                },
              ),
            ),
          ]),
        ),
        const SizedBox(height: NrSpace.xxl),
        NrButton(
          icon: Icons.logout_rounded,
          label: 'Cerrar sesión',
          variant: NrButtonVariant.danger,
          onPressed: () async {
            final (pending, _) = await ref.read(outboxProvider).counts();
            if (!context.mounted) return;
            final ok = await showNrSheet<bool>(
              context,
              title: 'Cerrar sesión',
              subtitle: pending > 0 ? 'Hay $pending operaciones sin enviar. Se enviarán cuando vuelvas a entrar con este mismo usuario.' : 'Se cerrará la sesión de este dispositivo.',
              builder: (ctx) => Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                NrButton(label: 'Cerrar sesión', variant: NrButtonVariant.danger, onPressed: () => Navigator.pop(ctx, true)),
                const SizedBox(height: NrSpace.sm),
                NrButton(label: 'Cancelar', variant: NrButtonVariant.ghost, onPressed: () => Navigator.pop(ctx, false)),
              ]),
            );
            if (ok == true) await auth.logout();
          },
        ),
        const SizedBox(height: NrSpace.lg),
        Center(child: Text('Nori móvil · ${s.server.label}', style: NrText.caption(context))),
      ],
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
    final fmt = DateFormat("d 'de' MMM, HH:mm", 'es_MX');
    final nr = context.nr;
    final (icon, color, title) = switch (status) {
      _ when status.syncing => (Icons.sync_rounded, nr.accent, 'Sincronizando…'),
      _ when status.failed > 0 => (Icons.error_outline_rounded, nr.danger, '${status.failed} con error'),
      _ when !status.online => (Icons.cloud_off_rounded, nr.warning, 'Sin conexión'),
      _ when status.pending > 0 => (Icons.cloud_upload_rounded, nr.warning, '${status.pending} por enviar'),
      _ => (Icons.cloud_done_rounded, nr.success, 'Todo al día'),
    };
    return Scaffold(
      appBar: AppBar(title: const Text('Sincronización')),
      body: ListView(padding: const EdgeInsets.fromLTRB(NrSpace.gutter, NrSpace.xs, NrSpace.gutter, NrSpace.xxxl), children: [
        NrCard(
          depth: NrDepth.floating,
          radius: NrRadius.hero,
          padding: const EdgeInsets.all(NrSpace.xl),
          child: Column(children: [
            NrIllustration(icon: icon, color: color, size: 0.8),
            const SizedBox(height: NrSpace.md),
            Text(title, style: NrText.title(context)),
            const SizedBox(height: 4),
            Text(status.lastSync == null ? 'Nunca sincronizado' : 'Última: ${fmt.format(status.lastSync!.toLocal())}', style: NrText.bodySm(context)),
            if (status.progress != null) ...[const SizedBox(height: 4), Text(status.progress!, style: NrText.caption(context))],
            if (status.lastError != null) ...[
              const SizedBox(height: NrSpace.sm),
              NrBanner(message: status.lastError!, tone: NrTone.danger, icon: Icons.error_outline_rounded),
            ],
            const SizedBox(height: NrSpace.lg),
            NrButton(
              label: status.syncing ? 'Sincronizando' : 'Sincronizar ahora',
              icon: Icons.sync_rounded,
              busy: status.syncing,
              onPressed: status.syncing || engine == null ? null : () => engine.syncNow(),
            ),
          ]),
        ),
        NrSectionHeader('Cola', count: ops.length),
        if (ops.isEmpty)
          NrCard(
            child: Row(children: [
              Icon(Icons.check_circle_rounded, color: nr.success),
              const SizedBox(width: NrSpace.md),
              Text('Todo enviado.', style: NrText.headline(context).copyWith(fontSize: 15)),
            ]),
          )
        else
          NrGroup(children: [for (final op in ops) _OpRow(op: op)]),
        NrSectionHeader('Catálogos guardados'),
        GridView.count(
          crossAxisCount: 3,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: NrSpace.sm,
          crossAxisSpacing: NrSpace.sm,
          childAspectRatio: 1.25,
          children: [
            for (final e in syncEntities)
              NrCard(
                padding: const EdgeInsets.all(NrSpace.md),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  NrCountUp(value: (counts[e] ?? 0).toDouble(), builder: (context, v) => Text(NumberFormat.decimalPattern('es_MX').format(v.round()), style: NrText.stat(context).copyWith(fontSize: 20))),
                  Text(entityLabels[e] ?? e, style: NrText.caption(context), maxLines: 2, overflow: TextOverflow.ellipsis),
                ]),
              ),
          ],
        ),
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
      trailing: NrPill(label, tone: tone, dot: true),
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
