import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/api/api_client.dart';
import '../../core/api/api_error.dart';
import '../../core/design/design.dart';
import '../../core/providers.dart';
import '../../core/sync/outbox.dart';

/// Public page with the full explanation (Google Play / App Store requirement).
final accountDeletionInfoUrl = Uri.parse('https://nori.software/account-deletion');

/// What the account-deletion screen needs from the app: the offline queue, the
/// request itself and the sign-out with the local data wiped. Overridable in tests.
class AccountDeletionService {
  AccountDeletionService(this.ref);

  final Ref ref;

  /// Operations that never reached the server (pending and failed): signing out loses them.
  Future<int> unsentCount() async {
    final (pending, failed) = await ref.read(outboxProvider).counts();
    return pending + failed;
  }

  bool get online => ref.read(syncStatusProvider).online;

  /// Sends the queue now (no catalog download) and waits for it.
  Future<void> sendPending() async => ref.read(syncEngineProvider)?.syncNow(pull: false);

  /// POST /me/deletion-request with an idempotency key; returns the server's message.
  Future<String?> request(String? reason) async {
    final op = OutboxOp.create('POST', '/me/deletion-request', body: {if (reason != null && reason.trim().isNotEmpty) 'reason': reason.trim()}, label: 'Eliminar mi cuenta');
    final r = await ref.read(writerProvider).send(op, offline: false);
    final message = asMap(unwrap(r.response))['message'];
    return message is String && message.trim().isNotEmpty ? message : null;
  }

  /// Signs out of this device and wipes the cache, the catalogs and the queue.
  Future<void> signOutAndWipe() async {
    await ref.read(authProvider.notifier).logout();
    await ref.read(localDbProvider).wipe();
  }
}

final accountDeletionServiceProvider = Provider<AccountDeletionService>(AccountDeletionService.new);

/// Más › Cuenta › Eliminar mi cuenta: explains what is deleted and what the
/// company keeps, asks for confirmation and sends the request.
class AccountDeletionPage extends ConsumerStatefulWidget {
  const AccountDeletionPage({super.key});

  @override
  ConsumerState<AccountDeletionPage> createState() => _AccountDeletionPageState();
}

class _AccountDeletionPageState extends ConsumerState<AccountDeletionPage> {
  static const _defaultSuccess = 'Recibimos tu solicitud. La atenderemos en un máximo de 30 días y te avisaremos por correo.';

  final _reason = TextEditingController();
  bool _understood = false;
  bool _busy = false;
  String? _error;
  String? _done;

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  AccountDeletionService get _service => ref.read(accountDeletionServiceProvider);

  Future<void> _submit() async {
    setState(() => _error = null);
    try {
      if (!await _handleUnsent() || !mounted) return;
      setState(() => _busy = true);
      final message = await _service.request(_reason.text);
      if (mounted) setState(() => _done = message ?? _defaultSuccess);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.userMessage);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Unsent operations are lost when signing out: warn, and offer to send them first when online.
  /// Returns false when the request should not go out.
  Future<bool> _handleUnsent() async {
    var unsent = await _service.unsentCount();
    if (unsent == 0) return true;
    if (!_service.online) {
      if (mounted) {
        setState(() => _error = 'Estás sin conexión. Conéctate para enviar la solicitud y tus $unsent operaciones pendientes.');
      }
      return false;
    }
    while (unsent > 0) {
      if (!mounted) return false;
      final choice = await showNrSheet<String>(
        context,
        title: 'Tienes operaciones sin enviar',
        subtitle: 'Hay $unsent operaciones que no han llegado al servidor. Al cerrar la sesión se borran de este teléfono y se pierden.',
        builder: (ctx) => Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            NrButton(label: 'Enviar pendientes primero', icon: Icons.cloud_upload_rounded, onPressed: () => Navigator.pop(ctx, 'send')),
            const SizedBox(height: NrSpace.sm),
            NrButton(label: 'Continuar sin enviar', variant: NrButtonVariant.danger, onPressed: () => Navigator.pop(ctx, 'skip')),
            const SizedBox(height: NrSpace.sm),
            NrButton(label: 'Cancelar', variant: NrButtonVariant.ghost, onPressed: () => Navigator.pop(ctx)),
          ],
        ),
      );
      if (choice == 'skip') return true;
      if (choice != 'send') return false;
      setState(() => _busy = true);
      try {
        await _service.sendPending();
      } finally {
        if (mounted) setState(() => _busy = false);
      }
      unsent = await _service.unsentCount();
    }
    return mounted;
  }

  Future<void> _finish() async {
    setState(() => _busy = true);
    await _service.signOutAndWipe();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Eliminar mi cuenta')),
      body: _done != null ? _success(context) : _form(context),
    );
  }

  Widget _success(BuildContext context) => ListView(
    padding: const EdgeInsets.all(NrSpace.gutter),
    children: [
      const SizedBox(height: NrSpace.xl),
      Icon(Icons.check_circle_rounded, size: 64, color: context.nr.success),
      const SizedBox(height: NrSpace.md),
      Text('Solicitud enviada', textAlign: TextAlign.center, style: NrText.title(context)),
      const SizedBox(height: NrSpace.sm),
      Text(_done!, textAlign: TextAlign.center, style: NrText.body(context)),
      const SizedBox(height: NrSpace.md),
      Text('Ahora vamos a cerrar tu sesión y borrar los datos de Nori guardados en este teléfono.', textAlign: TextAlign.center, style: NrText.bodySm(context)),
      const SizedBox(height: NrSpace.xl),
      NrButton(label: 'Cerrar sesión', icon: Icons.logout_rounded, busy: _busy, onPressed: _busy ? null : _finish),
    ],
  );

  Widget _form(BuildContext context) {
    Widget section(String title, String text) => Padding(
      padding: const EdgeInsets.only(top: NrSpace.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: NrText.headline(context)),
          const SizedBox(height: 4),
          Text(text, style: NrText.body(context)),
        ],
      ),
    );
    // Not lazy: the whole explanation is short and the button must exist to be reachable
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(NrSpace.gutter, NrSpace.xs, NrSpace.gutter, NrSpace.xxxl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Tu empresa creó tu cuenta de Nori. Puedes pedir que la eliminemos junto con tus datos personales.', style: NrText.body(context)),
          section(
            'Qué se borra',
            'Tu usuario y tus datos personales (nombre, correo y teléfono), tu historial de ubicación de las visitas de ruta, y los accesos de tus dispositivos y sesiones abiertas.',
          ),
          section('Qué se conserva', 'Las ventas, facturas, cobros y demás registros de la empresa. La ley obliga a guardarlos cinco años. En ellos tu nombre aparecerá como «Usuario eliminado».'),
          section('Cuándo', 'Lo hacemos en un máximo de 30 días y te avisamos por correo.'),
          const SizedBox(height: NrSpace.md),
          NrBanner(message: 'Si solo quieres dejar de usar Nori ya, el administrador de tu empresa puede desactivar tu usuario al momento.', tone: NrTone.neutral, icon: Icons.info_outline_rounded),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () => launchUrl(accountDeletionInfoUrl, mode: LaunchMode.externalApplication),
              icon: const Icon(Icons.open_in_new_rounded, size: 18),
              label: const Text('Más información'),
            ),
          ),
          const SizedBox(height: NrSpace.sm),
          TextField(
            controller: _reason,
            maxLength: 2000,
            minLines: 2,
            maxLines: 5,
            decoration: const InputDecoration(labelText: 'Motivo (opcional)'),
          ),
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
            value: _understood,
            onChanged: _busy ? null : (v) => setState(() => _understood = v ?? false),
            title: const Text('Entiendo que no se puede deshacer'),
          ),
          if (_error != null) ...[const SizedBox(height: NrSpace.sm), NrBanner(message: _error!, tone: NrTone.danger, icon: Icons.error_outline_rounded)],
          const SizedBox(height: NrSpace.md),
          NrButton(label: 'Solicitar eliminación', icon: Icons.delete_forever_rounded, variant: NrButtonVariant.danger, busy: _busy, onPressed: _understood && !_busy ? _submit : null),
        ],
      ),
    );
  }
}
