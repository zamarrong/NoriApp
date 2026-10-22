import 'dart:async';

import '../api/api_client.dart';
import '../api/api_error.dart';
import '../auth/session.dart';
import '../db/local_db.dart';
import 'outbox.dart';

/// Catálogos que la app guarda (GET /sync los filtra según permisos).
const syncEntities = ['warehouses', 'price_lists', 'tender_types', 'causalities', 'visit_reasons', 'customers', 'items', 'item_prices', 'stock'];

const entityLabels = {
  'items': 'Artículos',
  'item_prices': 'Precios',
  'stock': 'Existencias',
  'customers': 'Clientes',
  'price_lists': 'Listas de precios',
  'tender_types': 'Formas de pago',
  'warehouses': 'Almacenes',
  'causalities': 'Causalidades',
  'visit_reasons': 'Motivos de visita',
};

class SyncStatus {
  const SyncStatus({
    this.online = true,
    this.syncing = false,
    this.pending = 0,
    this.failed = 0,
    this.lastSync,
    this.lastError,
    this.progress,
  });

  final bool online;
  final bool syncing;
  final int pending;
  final int failed;
  final DateTime? lastSync;
  final String? lastError;
  final String? progress;

  SyncStatus copyWith({bool? online, bool? syncing, int? pending, int? failed, DateTime? lastSync, String? lastError, String? progress, bool clearError = false}) =>
      SyncStatus(
        online: online ?? this.online,
        syncing: syncing ?? this.syncing,
        pending: pending ?? this.pending,
        failed: failed ?? this.failed,
        lastSync: lastSync ?? this.lastSync,
        lastError: clearError ? null : (lastError ?? this.lastError),
        progress: syncing == false ? null : (progress ?? this.progress),
      );
}

/// Sube la cola y baja los cambios de catálogos (protocolo de ADR 0014).
class SyncEngine {
  SyncEngine({required this.api, required this.db, required this.session, required this.onStatus});

  final ApiClient api;
  final LocalDb db;
  final Session session;
  final void Function(SyncStatus Function(SyncStatus)) onStatus;

  late final OutboxRepo outbox = OutboxRepo(db);
  bool _running = false;

  Future<void> refreshCounts() async {
    final (p, f) = await outbox.counts();
    final last = await db.lastSyncedAt();
    onStatus((s) => s.copyWith(pending: p, failed: f, lastSync: last));
  }

  /// Push y luego pull. Sin red marca "sin conexión" y no lanza.
  Future<void> syncNow({bool pull = true}) async {
    if (_running) return;
    _running = true;
    onStatus((s) => s.copyWith(syncing: true, clearError: true, progress: 'Enviando pendientes'));
    try {
      await push();
      if (pull) await pullAll();
      onStatus((s) => s.copyWith(online: true, lastSync: DateTime.now()));
    } on ApiException catch (e) {
      onStatus((s) => s.copyWith(online: !e.isNetwork, lastError: e.isNetwork ? null : e.userMessage));
    } catch (e) {
      onStatus((s) => s.copyWith(lastError: '$e'));
    } finally {
      _running = false;
      onStatus((s) => s.copyWith(syncing: false));
      await refreshCounts();
    }
  }

  /// Envía la cola en lotes de 100 por `/sync/push`, en orden.
  Future<void> push() async {
    final ops = await outbox.sendable();
    for (var i = 0; i < ops.length; i += 100) {
      final chunk = ops.sublist(i, i + 100 > ops.length ? ops.length : i + 100);
      final r = await api.post('/sync/push', body: {'operations': chunk.map((o) => o.toPush()).toList()});
      final results = asList(r['data']);
      final byKey = {for (final res in results) '${res['key']}': res};
      for (final op in chunk) {
        final res = byKey[op.key];
        if (res == null) continue;
        switch (classifyPushResult(res)) {
          case PushOutcome.done:
            await outbox.remove(op.key);
          case PushOutcome.retry:
            op
              ..status = OutboxStatus.pending
              ..attempts += 1;
            await outbox.save(op);
          case PushOutcome.failed:
          case PushOutcome.needsAuthorization:
            final err = ApiException.fromBody((res['status'] as num?)?.toInt(), res['body']);
            op
              ..status = err.isAuthorizationRequired ? OutboxStatus.needsAuthorization : OutboxStatus.failed
              ..attempts += 1
              ..error = err.userMessage
              ..errorCode = err.code
              ..authorization = err.authorization;
            await outbox.save(op);
        }
      }
    }
  }

  /// Baja todas las entidades permitidas.
  Future<void> pullAll() async {
    final manifest = asMap(unwrap(await api.get('/sync')));
    final allowed = ((manifest['entities'] as List?) ?? const []).map((e) => '$e').toSet();
    for (final entity in syncEntities.where(allowed.contains)) {
      onStatus((s) => s.copyWith(progress: entityLabels[entity] ?? entity));
      await pull(entity);
    }
  }

  Map<String, dynamic> _extraQuery(String entity) {
    if (entity == 'stock') {
      final ids = {if (session.warehouseId != null) session.warehouseId!, ...session.allowedWarehouseIds};
      return {if (ids.isNotEmpty) 'warehouse_ids[]': ids.toList()};
    }
    // Un vendedor sin aprobación guarda solo sus clientes.
    if (entity == 'customers' && session.salesEmployee != null && !session.isApprover) return {'scope': 'mine'};
    return {};
  }

  /// Algoritmo de README "Protocolo de sincronización": reset, borrar, upsert,
  /// seguir el cursor y guardar el token solo al terminar todas las páginas.
  Future<void> pull(String entity) async {
    final token = await db.syncToken(entity);
    String? cursor;
    String? newToken;
    while (true) {
      final r = asMap(await api.get('/sync/$entity', query: {
        'updated_since': ?token,
        'cursor': ?cursor,
        'limit': 1000,
        ..._extraQuery(entity),
      }));
      final meta = asMap(r['meta']);
      final deleted = ((r['deleted'] as List?) ?? const []).map((e) => (e as num).toInt()).toList();
      await db.applySyncPage(entity,
          rows: asList(r['data']), deleted: deleted, reset: meta['reset'] == true && cursor == null);
      newToken = meta['sync_token'] as String? ?? newToken;
      if (meta['has_more'] != true) break;
      cursor = meta['next_cursor'] as String?;
      if (cursor == null) break;
    }
    await db.saveSyncToken(entity, newToken);
  }
}
