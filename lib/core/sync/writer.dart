import '../api/api_client.dart';
import '../api/api_error.dart';
import 'outbox.dart';

/// Resultado de una escritura: hecha en línea (con respuesta) o en cola.
class WriteResult {
  const WriteResult.sent(this.response) : queued = false;
  const WriteResult.queued()
      : response = null,
        queued = true;

  final dynamic response;
  final bool queued;
}

/// Toda escritura pasa por aquí: se guarda en la cola con su llave y se
/// intenta en línea con esa misma llave.
///
/// - Éxito → sale de la cola y regresa la respuesta.
/// - Sin red / 5xx → se queda en la cola (se manda luego por `/sync/push`) si
///   [offline] lo permite; si no, se quita y se lanza el error.
/// - Error del dominio (validación, regla, autorización) → sale de la cola y se
///   lanza [ApiException]: la pantalla lo muestra o pide autorización y
///   reintenta con la misma llave (las fallas no se guardan en el servidor).
class Writer {
  Writer({required this.api, required this.outbox, this.onChanged});

  final ApiClient api;
  final OutboxRepo outbox;
  final void Function()? onChanged;

  Future<WriteResult> send(OutboxOp op, {bool offline = true}) async {
    op.status = OutboxStatus.sending;
    await outbox.save(op);
    try {
      final r = await api.request(op.method, op.path, body: op.body, key: op.key);
      await outbox.remove(op.key);
      return WriteResult.sent(r);
    } on ApiException catch (e) {
      if (e.isTransient && offline) {
        op
          ..status = OutboxStatus.pending
          ..attempts += 1;
        await outbox.save(op);
        return const WriteResult.queued();
      }
      await outbox.remove(op.key);
      rethrow;
    } finally {
      onChanged?.call();
    }
  }

  /// Igual que [send] pero con las autorizaciones ya aprobadas en el cuerpo
  /// (`authorizations[]`, como las pantallas web).
  Future<WriteResult> retryAuthorized(OutboxOp op, List<int> authorizationIds, {bool offline = false}) {
    op.body = {...?op.body, 'authorizations': authorizationIds};
    return send(op, offline: offline);
  }
}
