import 'package:flutter_test/flutter_test.dart';
import 'package:nori_mobile/core/api/api_error.dart';
import 'package:nori_mobile/core/api/server_config.dart';
import 'package:nori_mobile/core/auth/session.dart';
import 'package:nori_mobile/core/db/local_db.dart';
import 'package:nori_mobile/core/sync/outbox.dart';
import 'package:nori_mobile/core/util/decimal.dart';
import 'package:nori_mobile/features/collections/allocation.dart';
import 'package:nori_mobile/features/sales/cart.dart';
import 'package:nori_mobile/features/sales/sell_page.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  group('Dec', () {
    test('suma cadenas de la API sin errores de punto flotante', () {
      expect((Dec.parse('0.1') + Dec.parse('0.2')).toFixed(2), '0.30');
      expect(Dec.parse('232.000000').toFixed(2), '232.00');
      expect((Dec.parse('2.5') * Dec.parse('19.99')).round(2).toFixed(2), '49.98');
      expect(Dec.parse('-1.005').round(2).toFixed(2), '-1.01');
      expect(Dec.parse('2.0000').toQty(), '2');
      expect(Dec.tryParse('abc'), isNull);
    });
  });

  group('ServerConfig', () {
    test('código simple usa el dominio de la empresa', () {
      final c = ServerConfig.resolve('MiEmpresa');
      expect(c.baseUrl, 'https://miempresa.nori.mx');
      expect(c.tenant, isNull);
    });

    test('dominio central con X-Tenant y limpia /api/v1', () {
      final c = ServerConfig.resolve('api.nori.mx/api/v1/', tenantCode: 'miempresa');
      expect(c.baseUrl, 'https://api.nori.mx');
      expect(c.tenant, 'miempresa');
    });

    test('IP local usa http', () {
      expect(ServerConfig.resolve('192.168.1.5:8000').baseUrl, 'http://192.168.1.5:8000');
    });
  });

  group('errores', () {
    test('authorization_required trae el token del supervisor', () {
      final e = ApiException.fromBody(422, {
        'message': 'Requiere autorización',
        'error': {
          'code': 'authorization_required',
          'message': 'Requiere autorización',
          'authorization': {'concept': 'credit_exceeded', 'label': 'Crédito excedido', 'reference': 'Pedido', 'token': 'abc'},
          'request_id': 'K3J9',
        },
      });
      expect(e.isAuthorizationRequired, isTrue);
      expect(e.authorization!.token, 'abc');
      expect(e.isTransient, isFalse);
    });

    test('resultados de /sync/push: ok, reintento, error, autorización', () {
      expect(classifyPushResult({'ok': true, 'status': 201}), PushOutcome.done);
      expect(classifyPushResult({'ok': false, 'status': 503}), PushOutcome.retry);
      expect(classifyPushResult({'ok': false, 'status': 422, 'body': {'error': {'code': 'business_rule', 'message': 'x'}}}), PushOutcome.failed);
      expect(
        classifyPushResult({
          'ok': false,
          'status': 422,
          'body': {'error': {'code': 'authorization_required', 'message': 'x', 'authorization': {'token': 't'}}},
        }),
        PushOutcome.needsAuthorization,
      );
    });
  });

  test('cobro: reparte de lo más vencido a lo más nuevo y deja el sobrante a cuenta', () {
    final (applied, left) = allocatePayment(Dec.parse('300'), [
      {'id': 1, 'balance': '100.00'},
      {'id': 2, 'balance': '-50.00'}, // nota de crédito
      {'id': 3, 'balance': '150.00'},
      {'id': 4, 'balance': '80.00'},
    ]);
    expect(applied.keys, [1, 3, 4]);
    expect(applied[4]!.toFixed(2), '50.00');
    expect(left.isZero, isTrue);
    final (_, rest) = allocatePayment(Dec.parse('500'), [{'id': 1, 'balance': '100'}]);
    expect(rest.toFixed(2), '400.00');
  });

  test('precio estimado sin señal marca líneas sin precio', () {
    final lines = [
      CartLine(item: {'id': 5, 'name': 'Rosa'}, quantity: Dec.parse('3')),
      CartLine(item: {'id': 6, 'name': 'Tulipán'}, quantity: Dec.one),
    ];
    final t = estimateOffline(lines, {5: Dec.parse('12.50')});
    expect(t.total.toFixed(2), '37.50');
    expect(t.estimated, isTrue);
    expect(lines[1].error, isNotNull);
  });

  test('venta libre: unidad, línea base, descuento estimado y tipos según permisos', () {
    final box = CartLine(item: {'id': 5, 'name': 'Rosa'}, quantity: Dec.parse('2'), uomId: 3);
    final back = CartLine(item: {'id': 6, 'name': 'Tulipán'}, quantity: Dec.one, baseLineId: 90, maxQuantity: Dec.one);
    expect(box.toApi(), {'item_id': 5, 'quantity': Dec.parse('2').toJson(4), 'uom_id': 3});
    expect(back.toApi()['base_line_id'], 90);
    final t = estimateOffline([box, back], {6: Dec.parse('10')}, byLine: {box: Dec.parse('120')}, discountPercent: Dec.parse('10'));
    expect(t.subtotal.toFixed(2), '250.00');
    expect(t.discount!.toFixed(2), '25.00');
    expect(t.total.toFixed(2), '225.00');

    final s = Session.fromApi({
      'user': {'id': 1},
      'permissions': ['sales_orders.create', 'invoices.create'],
    }, server: const ServerConfig(baseUrl: 'https://miempresa.nori.mx'));
    expect(allowedSaleTypes(s).map((t) => t.type), ['sales_order', 'invoice']);
    expect(s.canFreeSell, isTrue);
  });

  group('LocalDb', () {
    late LocalDb db;
    setUp(() async {
      sqfliteFfiInit();
      db = await LocalDb.open(factory: databaseFactoryFfi, path: inMemoryDatabasePath);
    });

    test('sincronización: reset, borrados antes que upserts, búsqueda por código de barras', () async {
      await db.applySyncPage('items', reset: true, deleted: [], rows: [
        {'id': 5, 'code': 'ROSA', 'name': 'Rosa roja', 'is_active': true, 'barcodes': [{'barcode': '7500000000017'}]},
        {'id': 6, 'code': 'TUL', 'name': 'Tulipán', 'is_active': true},
      ]);
      expect((await db.itemByCode('7500000000017'))?['id'], 5);
      expect((await db.search('items', 'roja')).length, 1);

      await db.applySyncPage('items', deleted: [6], rows: [{'id': 5, 'code': 'ROSA', 'name': 'Rosa miempresaa', 'is_active': true}]);
      expect(await db.count('items'), 1);
      expect((await db.find('items', 5))?['name'], 'Rosa miempresaa');

      await db.applySyncPage('stock', deleted: [], rows: [{'id': 1, 'item_id': 5, 'warehouse_id': 3, 'on_hand': '15'}]);
      expect((await db.byRefs('stock', ref1: 5, ref2: 3)).single['on_hand'], '15');
    });

    test('la cola conserva llave, orden y estado', () async {
      final repo = OutboxRepo(db);
      final a = OutboxOp.create('POST', '/documents', body: {'type': 'sales_order'}, label: 'Pedido');
      await repo.save(a);
      await repo.save(OutboxOp.create('POST', '/payments', body: {}));
      final ops = await repo.sendable();
      expect(ops.first.key, a.key);
      expect(ops.first.path, '/api/v1/documents');
      a
        ..status = OutboxStatus.failed
        ..error = 'Sin crédito';
      await repo.save(a);
      expect(await repo.counts(), (1, 1));
    });
    test('a company subdomain of localhost goes to 127.0.0.1 with its code', () {
    final c = ServerConfig.resolve('http://miempresa.localhost:8000/');
    expect(c.baseUrl, 'http://127.0.0.1:8000');
    expect(c.tenant, 'miempresa');
  });
});
}
