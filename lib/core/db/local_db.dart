import 'dart:convert';

import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

/// Base local (SQLite) para trabajar sin señal.
///
/// - `records`: filas de los catálogos sincronizados, por entidad e id, con dos
///   referencias indexadas (p. ej. artículo y almacén de una existencia) y un
///   texto de búsqueda (código, nombre, códigos de barras).
/// - `sync_state`: el `sync_token` de la última sincronización completa.
/// - `outbox`: la cola de escrituras con su llave de idempotencia.
/// - `kv`: respuestas guardadas (ruta del día, visitas, cliente 360).
class LocalDb {
  LocalDb(this.db);

  final Database db;

  static const _version = 1;

  static Future<LocalDb> open({DatabaseFactory? factory, String? path}) async {
    final f = factory ?? databaseFactory;
    final dbPath = path ?? p.join(await f.getDatabasesPath(), 'nori.db');
    final db = await f.openDatabase(dbPath, options: OpenDatabaseOptions(version: _version, onCreate: _create));
    return LocalDb(db);
  }

  static Future<void> _create(Database db, int version) async {
    await db.execute('''CREATE TABLE records (
      entity TEXT NOT NULL, id INTEGER NOT NULL, ref1 INTEGER, ref2 INTEGER,
      search TEXT, active INTEGER NOT NULL DEFAULT 1, json TEXT NOT NULL,
      PRIMARY KEY (entity, id))''');
    await db.execute('CREATE INDEX records_ref ON records (entity, ref1, ref2)');
    await db.execute('CREATE TABLE sync_state (entity TEXT PRIMARY KEY, token TEXT, synced_at TEXT)');
    await db.execute('''CREATE TABLE outbox (
      key TEXT PRIMARY KEY, created_at TEXT NOT NULL, method TEXT NOT NULL, path TEXT NOT NULL,
      body TEXT, label TEXT, status TEXT NOT NULL, attempts INTEGER NOT NULL DEFAULT 0,
      error TEXT, error_code TEXT, auth_json TEXT, updated_at TEXT)''');
    await db.execute('CREATE TABLE kv (k TEXT PRIMARY KEY, v TEXT NOT NULL, updated_at TEXT)');
  }

  // ───────────── Catálogos ─────────────

  /// Referencias indexadas y texto de búsqueda de cada entidad.
  static (int?, int?, String?) _index(String entity, Map<String, dynamic> row) {
    int? n(Object? v) => v is num ? v.toInt() : int.tryParse('${v ?? ''}');
    String s(List<Object?> parts) => parts.where((e) => e != null && '$e'.isNotEmpty).join(' ').toLowerCase();
    switch (entity) {
      case 'items':
        final barcodes = ((row['barcodes'] as List?) ?? const []).map((b) => b is Map ? b['barcode'] : b);
        return (null, null, s([row['code'], row['name'], row['alternate_code'], ...barcodes]));
      case 'item_prices':
        return (n(row['item_id']), n(row['price_list_id']), null);
      case 'stock':
        return (n(row['item_id']), n(row['warehouse_id']), null);
      case 'customers':
        return (n(row['sales_employee_id']), null, s([row['code'], row['name'], row['trade_name'], row['rfc'], row['phone'], row['mobile']]));
      default:
        return (null, null, s([row['code'], row['name']]));
    }
  }

  Future<void> applySyncPage(String entity, {required List<Map<String, dynamic>> rows, required List<int> deleted, bool reset = false}) async {
    await db.transaction((txn) async {
      if (reset) await txn.delete('records', where: 'entity = ?', whereArgs: [entity]);
      final batch = txn.batch();
      // Primero borrar, después insertar/actualizar (protocolo de sincronización).
      for (final id in deleted) {
        batch.delete('records', where: 'entity = ? AND id = ?', whereArgs: [entity, id]);
      }
      for (final row in rows) {
        final (r1, r2, search) = _index(entity, row);
        batch.insert(
          'records',
          {
            'entity': entity,
            'id': (row['id'] as num).toInt(),
            'ref1': r1,
            'ref2': r2,
            'search': search,
            'active': row['is_active'] == false ? 0 : 1,
            'json': jsonEncode(row),
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
      await batch.commit(noResult: true);
    });
  }

  Future<String?> syncToken(String entity) async {
    final r = await db.query('sync_state', where: 'entity = ?', whereArgs: [entity]);
    return r.isEmpty ? null : r.first['token'] as String?;
  }

  Future<void> saveSyncToken(String entity, String? token) => db.insert(
        'sync_state',
        {'entity': entity, 'token': token, 'synced_at': DateTime.now().toIso8601String()},
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

  Future<DateTime?> lastSyncedAt() async {
    final r = await db.rawQuery('SELECT MAX(synced_at) AS t FROM sync_state');
    final t = r.first['t'] as String?;
    return t == null ? null : DateTime.tryParse(t);
  }

  List<Map<String, dynamic>> _decode(List<Map<String, Object?>> rows) =>
      rows.map((r) => Map<String, dynamic>.from(jsonDecode(r['json'] as String) as Map)).toList();

  Future<Map<String, dynamic>?> find(String entity, int id) async {
    final r = await db.query('records', where: 'entity = ? AND id = ?', whereArgs: [entity, id], limit: 1);
    return r.isEmpty ? null : _decode(r).first;
  }

  Future<List<Map<String, dynamic>>> all(String entity, {bool activeOnly = true}) async =>
      _decode(await db.query('records', where: activeOnly ? 'entity = ? AND active = 1' : 'entity = ?', whereArgs: [entity]));

  /// Búsqueda por palabras (todas deben aparecer) en código, nombre y códigos de barras.
  Future<List<Map<String, dynamic>>> search(String entity, String text, {int limit = 50, int? ref1}) async {
    final words = text.toLowerCase().split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
    final where = StringBuffer('entity = ? AND active = 1');
    final args = <Object?>[entity];
    for (final w in words) {
      where.write(' AND search LIKE ?');
      args.add('%$w%');
    }
    if (ref1 != null) {
      where.write(' AND ref1 = ?');
      args.add(ref1);
    }
    return _decode(await db.query('records', where: where.toString(), whereArgs: args, limit: limit, orderBy: 'search'));
  }

  /// Artículo por código de barras o código exacto.
  Future<Map<String, dynamic>?> itemByCode(String code) async {
    final c = code.trim().toLowerCase();
    if (c.isEmpty) return null;
    final candidates = await search('items', c, limit: 20);
    for (final item in candidates) {
      if ('${item['code']}'.toLowerCase() == c) return item;
      final barcodes = (item['barcodes'] as List?) ?? const [];
      if (barcodes.any((b) => '${b is Map ? b['barcode'] : b}'.toLowerCase() == c)) return item;
    }
    return null;
  }

  Future<List<Map<String, dynamic>>> byRefs(String entity, {int? ref1, int? ref2}) async {
    final where = ['entity = ?'];
    final args = <Object?>[entity];
    if (ref1 != null) {
      where.add('ref1 = ?');
      args.add(ref1);
    }
    if (ref2 != null) {
      where.add('ref2 = ?');
      args.add(ref2);
    }
    return _decode(await db.query('records', where: where.join(' AND '), whereArgs: args));
  }

  Future<int> count(String entity) async =>
      Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM records WHERE entity = ?', [entity])) ?? 0;

  // ───────────── Respuestas guardadas ─────────────

  Future<void> putJson(String key, Object value) => db.insert(
        'kv',
        {'k': key, 'v': jsonEncode(value), 'updated_at': DateTime.now().toIso8601String()},
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

  Future<dynamic> getJson(String key) async {
    final r = await db.query('kv', where: 'k = ?', whereArgs: [key]);
    return r.isEmpty ? null : jsonDecode(r.first['v'] as String);
  }

  /// Borra todo lo de la sesión (cerrar sesión / cambiar de empresa).
  Future<void> wipe() async {
    await db.delete('records');
    await db.delete('sync_state');
    await db.delete('outbox');
    await db.delete('kv');
  }
}
