import 'dart:convert';

import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

import '../api/api_client.dart';
import '../api/api_error.dart';
import '../db/local_db.dart';

enum OutboxStatus { pending, sending, failed, needsAuthorization }

/// Una escritura de la API guardada con su llave de idempotencia. La llave se
/// genera cuando el usuario actúa; cada reintento usa la misma.
class OutboxOp {
  OutboxOp({
    required this.key,
    required this.method,
    required this.path,
    this.body,
    this.label = '',
    this.status = OutboxStatus.pending,
    this.attempts = 0,
    this.error,
    this.errorCode,
    this.authorization,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  factory OutboxOp.create(String method, String path, {Map<String, dynamic>? body, String label = ''}) =>
      OutboxOp(key: const Uuid().v4(), method: method, path: ApiClient.v1(path), body: body, label: label);

  final String key;
  final String method;
  final String path;
  Map<String, dynamic>? body;
  final String label;
  OutboxStatus status;
  int attempts;
  String? error;
  String? errorCode;
  AuthorizationChallenge? authorization;
  final DateTime createdAt;

  Map<String, dynamic> toPush() => {'key': key, 'method': method, 'path': path, 'body': ?body};

  Map<String, Object?> toRow() => {
        'key': key,
        'created_at': createdAt.toIso8601String(),
        'method': method,
        'path': path,
        'body': body == null ? null : jsonEncode(body),
        'label': label,
        'status': status.name,
        'attempts': attempts,
        'error': error,
        'error_code': errorCode,
        'auth_json': authorization == null ? null : jsonEncode(authorization!.toJson()),
        'updated_at': DateTime.now().toIso8601String(),
      };

  factory OutboxOp.fromRow(Map<String, Object?> r) => OutboxOp(
        key: r['key'] as String,
        method: r['method'] as String,
        path: r['path'] as String,
        body: r['body'] == null ? null : Map<String, dynamic>.from(jsonDecode(r['body'] as String) as Map),
        label: (r['label'] as String?) ?? '',
        status: OutboxStatus.values.byName(r['status'] as String),
        attempts: (r['attempts'] as int?) ?? 0,
        error: r['error'] as String?,
        errorCode: r['error_code'] as String?,
        authorization: r['auth_json'] == null
            ? null
            : AuthorizationChallenge.fromJson(Map<String, dynamic>.from(jsonDecode(r['auth_json'] as String) as Map)),
        createdAt: DateTime.parse(r['created_at'] as String),
      );
}

class OutboxRepo {
  OutboxRepo(this._db);

  final LocalDb _db;
  Database get _sql => _db.db;

  Future<void> save(OutboxOp op) => _sql.insert('outbox', op.toRow(), conflictAlgorithm: ConflictAlgorithm.replace);

  Future<void> remove(String key) => _sql.delete('outbox', where: 'key = ?', whereArgs: [key]);

  Future<List<OutboxOp>> list({OutboxStatus? status}) async {
    final rows = await _sql.query('outbox',
        where: status == null ? null : 'status = ?', whereArgs: status == null ? null : [status.name], orderBy: 'created_at, rowid');
    return rows.map(OutboxOp.fromRow).toList();
  }

  /// Lo que se puede mandar: pendientes y las que se quedaron "enviando" (la app se cerró a medio envío).
  Future<List<OutboxOp>> sendable() async {
    final rows = await _sql.query('outbox', where: 'status IN (?, ?)', whereArgs: ['pending', 'sending'], orderBy: 'created_at, rowid');
    return rows.map(OutboxOp.fromRow).toList();
  }

  Future<(int pending, int failed)> counts() async {
    final r = await _sql.rawQuery("SELECT SUM(CASE WHEN status IN ('pending','sending') THEN 1 ELSE 0 END) AS p, "
        "SUM(CASE WHEN status IN ('failed','needsAuthorization') THEN 1 ELSE 0 END) AS f FROM outbox");
    return ((r.first['p'] as int?) ?? 0, (r.first['f'] as int?) ?? 0);
  }
}

/// Qué hacer con una operación según la respuesta de `/sync/push`:
/// quitarla (ok), dejarla para reintento (red, 5xx, 429) o marcarla con su error
/// para que el usuario la vea (validación, regla de negocio, permiso, autorización).
enum PushOutcome { done, retry, failed, needsAuthorization }

PushOutcome classifyPushResult(Map<String, dynamic> result) {
  if (result['ok'] == true) return PushOutcome.done;
  final status = (result['status'] as num?)?.toInt() ?? 500;
  final err = ApiException.fromBody(status, result['body']);
  if (err.isAuthorizationRequired) return PushOutcome.needsAuthorization;
  if (status >= 500 || status == 429 || status == 408) return PushOutcome.retry;
  return PushOutcome.failed;
}
