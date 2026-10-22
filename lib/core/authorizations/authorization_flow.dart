import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/api_client.dart';
import '../api/api_error.dart';
import '../design/design.dart';
import '../providers.dart';
import '../sync/outbox.dart';
import '../sync/writer.dart';

/// Manda una escritura y, si el servidor contesta `authorization_required`,
/// pide la autorización (a distancia o en sitio) y reintenta con la misma
/// llave y `authorizations[]`. Muestra los demás errores. Null = cancelado o error.
Future<WriteResult?> sendWithAuthorization(BuildContext context, WidgetRef ref, OutboxOp op, {bool offline = true}) async {
  final writer = ref.read(writerProvider);
  final granted = <int>[];
  for (var attempt = 0; attempt < 4; attempt++) {
    try {
      return granted.isEmpty ? await writer.send(op, offline: offline) : await writer.retryAuthorized(op, granted, offline: offline);
    } on ApiException catch (e) {
      if (!context.mounted) return null;
      if (!e.isAuthorizationRequired) {
        showSnack(context, e.userMessage);
        return null;
      }
      final id = await showAuthorizationSheet(context, e.authorization!);
      if (id == null) return null;
      granted.add(id);
    }
  }
  return null;
}

/// Hoja para conseguir una autorización. Regresa el id aprobado o null.
Future<int?> showAuthorizationSheet(BuildContext context, AuthorizationChallenge challenge) => showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      isDismissible: false,
      builder: (_) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: AuthorizationSheet(challenge: challenge),
      ),
    );

class AuthorizationSheet extends ConsumerStatefulWidget {
  const AuthorizationSheet({super.key, required this.challenge});

  final AuthorizationChallenge challenge;

  @override
  ConsumerState<AuthorizationSheet> createState() => _AuthorizationSheetState();
}

class _AuthorizationSheetState extends ConsumerState<AuthorizationSheet> {
  bool onSite = false;
  bool busy = false;
  String? error;
  Map<String, dynamic>? request; // estado de la solicitud remota
  Timer? _poll;
  final comment = TextEditingController();
  final username = TextEditingController();
  final secret = TextEditingController();

  @override
  void dispose() {
    _poll?.cancel();
    comment.dispose();
    username.dispose();
    secret.dispose();
    super.dispose();
  }

  Future<void> _askRemote() async {
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final op = OutboxOp.create('POST', '/authorizations',
          body: {'token': widget.challenge.token, if (comment.text.trim().isNotEmpty) 'comment': comment.text.trim()});
      final r = await ref.read(writerProvider).send(op, offline: false);
      setState(() => request = asMap(unwrap(r.response)));
      _poll = Timer.periodic(const Duration(seconds: 4), (_) => _check());
    } on ApiException catch (e) {
      setState(() => error = e.userMessage);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _check() async {
    final id = request?['id'];
    if (id == null) return;
    try {
      final r = asMap(unwrap(await ref.read(apiProvider).get('/authorizations/$id')));
      if (!mounted) return;
      setState(() => request = r);
      if (r['status'] == 'approved') {
        _poll?.cancel();
        Navigator.of(context).pop((r['id'] as num).toInt());
      } else if (r['status'] != 'pending') {
        _poll?.cancel();
      }
    } catch (_) {
      // Sin señal: se sigue intentando.
    }
  }

  Future<void> _approveOnSite() async {
    final isPin = RegExp(r'^\d{4,12}$').hasMatch(secret.text);
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final op = OutboxOp.create('POST', '/authorizations/on-site', body: {
        'token': widget.challenge.token,
        'username': username.text.trim(),
        if (isPin) 'pin': secret.text else 'password': secret.text,
      });
      final r = asMap(unwrap((await ref.read(writerProvider).send(op, offline: false)).response));
      if (!mounted) return;
      if (r['status'] == 'approved') {
        Navigator.of(context).pop((r['id'] as num).toInt());
      } else {
        setState(() => error = 'El supervisor no pudo aprobar.');
      }
    } on ApiException catch (e) {
      setState(() => error = e.userMessage);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.challenge;
    final nr = context.nr;
    final status = request?['status'] as String?;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(NrSpace.xl, 0, NrSpace.xl, NrSpace.xl),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            Icon(Icons.verified_user_outlined, color: nr.warning),
            const SizedBox(width: NrSpace.sm),
            Expanded(child: Text(c.label, style: NrText.title(context))),
          ]),
          if (c.reference.isNotEmpty) ...[
            const SizedBox(height: NrSpace.xs),
            Text(c.reference, style: NrText.bodySm(context)),
          ],
          const SizedBox(height: NrSpace.lg),
          if (request != null) ...[
            NrCard(
              child: Column(children: [
                if (status == 'pending') ...[
                  const LinearProgressIndicator(),
                  const SizedBox(height: NrSpace.md),
                  Text('Esperando al supervisor…', style: NrText.headline(context)),
                  Text('Te avisamos aquí en cuanto decida.', style: NrText.bodySm(context)),
                ] else if (status == 'rejected') ...[
                  Icon(Icons.block, color: nr.danger, size: 32),
                  Text('Rechazada${request?['decided_by'] != null ? ' por ${request!['decided_by']}' : ''}', style: NrText.headline(context)),
                  if (request?['decision_comment'] != null) Text('${request!['decision_comment']}', style: NrText.bodySm(context)),
                ] else
                  Text('Solicitud ${request?['status']}', style: NrText.headline(context)),
              ]),
            ),
            const SizedBox(height: NrSpace.md),
            OutlinedButton(onPressed: () => Navigator.of(context).pop(), child: Text(status == 'pending' ? 'Cancelar espera' : 'Cerrar')),
          ] else ...[
            SegmentedButton<bool>(
              segments: const [
                ButtonSegment(value: false, label: Text('Pedir a distancia'), icon: Icon(Icons.send_outlined)),
                ButtonSegment(value: true, label: Text('Autorizar aquí'), icon: Icon(Icons.pin_outlined)),
              ],
              selected: {onSite},
              onSelectionChanged: (v) => setState(() => onSite = v.first),
            ),
            const SizedBox(height: NrSpace.lg),
            if (!onSite)
              TextField(controller: comment, decoration: const InputDecoration(labelText: 'Comentario para el supervisor (opcional)'))
            else ...[
              TextField(controller: username, decoration: const InputDecoration(labelText: 'Usuario del supervisor'), autocorrect: false),
              const SizedBox(height: NrSpace.md),
              TextField(controller: secret, decoration: const InputDecoration(labelText: 'Contraseña o PIN'), obscureText: true),
            ],
            if (error != null) ...[
              const SizedBox(height: NrSpace.md),
              Text(error!, style: NrText.bodySm(context).copyWith(color: nr.danger)),
            ],
            const SizedBox(height: NrSpace.lg),
            Row(children: [
              Expanded(child: OutlinedButton(onPressed: busy ? null : () => Navigator.of(context).pop(), child: const Text('Cancelar'))),
              const SizedBox(width: NrSpace.md),
              Expanded(
                child: FilledButton(
                  onPressed: busy ? null : (onSite ? _approveOnSite : _askRemote),
                  child: Text(onSite ? 'Aprobar' : 'Pedir'),
                ),
              ),
            ]),
          ],
        ]),
      ),
    );
  }
}
