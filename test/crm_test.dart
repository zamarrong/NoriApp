import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:nori_mobile/core/api/api_client.dart';
import 'package:nori_mobile/core/api/api_error.dart';
import 'package:nori_mobile/core/api/server_config.dart';
import 'package:nori_mobile/core/auth/session.dart';
import 'package:nori_mobile/core/db/local_db.dart';
import 'package:nori_mobile/core/design/design.dart';
import 'package:nori_mobile/core/providers.dart';
import 'package:nori_mobile/core/sync/outbox.dart';
import 'package:nori_mobile/core/sync/writer.dart';
import 'package:nori_mobile/features/crm/crm_page.dart';
import 'package:nori_mobile/features/crm/crm_repo.dart';
import 'package:nori_mobile/features/crm/crm_widgets.dart';
import 'package:nori_mobile/features/crm/deal_page.dart';
import 'package:nori_mobile/features/route/route_repo.dart' show Cached;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

Session _session(List<String> permissions, {int id = 7}) => Session.fromApi(
      {'token': 't', 'user': {'id': id, 'name': 'Ernesto Villalobos'}, 'permissions': permissions, 'working_context': {}},
      server: const ServerConfig(baseUrl: 'https://demo.nori.software'),
    );

const _seller = ['crm_deals.view', 'crm_deals.create', 'crm_deals.update', 'quotations.create'];

final _stages = [
  {'id': 1, 'name': 'Prospecto', 'color': '#64748b', 'probability': '10.00', 'outcome': 'open', 'sort_order': 0},
  {'id': 2, 'name': 'Calificado', 'color': '#2563eb', 'probability': '30.00', 'outcome': 'open', 'sort_order': 1},
  {'id': 3, 'name': 'Cotización enviada', 'color': '#f59e0b', 'probability': '50.00', 'outcome': 'open', 'sort_order': 2},
  {'id': 5, 'name': 'Ganado', 'color': '#16a34a', 'probability': '100.00', 'outcome': 'won', 'sort_order': 4},
  {'id': 6, 'name': 'Perdido', 'color': '#dc2626', 'probability': '0.00', 'outcome': 'lost', 'sort_order': 5},
];
final _pipelines = [
  {'id': 1, 'name': 'Ventas', 'is_default': true, 'idle_days': 14, 'stages': _stages},
];

Map<String, dynamic> _deal(int id, String title, int stage, String amount, {String status = 'open', Map<String, dynamic>? next, int overdue = 0, int owner = 7, String? closedAt}) => {
      'id': id,
      'title': title,
      'status': status,
      'pipeline_id': 1,
      'stage_id': stage,
      'stage': _stages.firstWhere((s) => s['id'] == stage),
      'business_partner_id': 40 + id,
      'partner': {'id': 40 + id, 'code': 'C$id', 'name': 'Cliente $id', 'trade_name': 'Tienda $id', 'type': 'customer', 'mobile': '3312345678', 'latitude': 20.6, 'longitude': -103.3},
      'owner': {'id': owner, 'name': 'Ernesto Villalobos'},
      'amount': amount,
      'weighted_amount': (double.parse(amount) * ((_stages.firstWhere((s) => s['id'] == stage)['probability'] as String) == '' ? 0 : double.parse(_stages.firstWhere((s) => s['id'] == stage)['probability'] as String)) / 100).toStringAsFixed(2),
      'effective_probability': _stages.firstWhere((s) => s['id'] == stage)['probability'],
      'expected_close_date': '2026-12-15',
      'tags': [],
      'next_activity': next,
      'pending_count': next == null ? 0 : 1,
      'overdue_count': overdue,
      'idle': false,
      'closed_at': closedAt,
      'updated_at': '2026-10-23T10:00:00-06:00',
    };

/// Cliente de la API con respuestas preparadas por ruta (sin red).
class _FakeApi extends ApiClient {
  _FakeApi(this.handler) : super(config: const ServerConfig(baseUrl: 'https://demo.nori.software'));

  final dynamic Function(String method, String path, Map<String, dynamic>? query) handler;
  final calls = <String>[];

  @override
  Future<dynamic> request(String method, String path, {Object? body, Map<String, dynamic>? query, String? key}) async {
    calls.add('$method $path ${query ?? ''}');
    return handler(method, path, query);
  }
}

/// Escrituras capturadas: responden como el servidor (o como sin señal).
class _FakeWriter extends Writer {
  _FakeWriter({this.queued = false}) : super(api: _FakeApi((_, _, _) => null), outbox: _NoOutbox());

  final bool queued;
  final sent = <OutboxOp>[];

  @override
  Future<WriteResult> send(OutboxOp op, {bool offline = true}) async {
    sent.add(op);
    return queued ? const WriteResult.queued() : WriteResult.sent({'data': {'id': 99, 'type': op.body?['type']}});
  }
}

/// Lo guardado no importa en las pantallas (y sqflite no corre dentro de testWidgets).
class _FakeRepo implements CrmRepo {
  final patched = <int, Map<String, dynamic>>{};

  @override
  Future<void> patchLocal(int id, Map<String, dynamic> changes, {Map<String, dynamic>? activity}) async => patched[id] = changes;

  @override
  Future<void> applyDetail(Map<String, dynamic> detail) async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _NoOutbox implements OutboxRepo {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Widget _app(Widget child, {bool dark = false}) => MaterialApp(
      theme: NrTheme.light(NrColors.defaultAccent),
      darkTheme: NrTheme.dark(NrColors.defaultAccent),
      themeMode: dark ? ThemeMode.dark : ThemeMode.light,
      builder: (context, child) => MediaQuery(data: MediaQuery.of(context).copyWith(disableAnimations: true), child: child!),
      home: child,
    );

void main() {
  setUpAll(() async {
    await initializeDateFormatting('es_MX');
    sqfliteFfiInit();
  });

  group('lógica del tablero', () {
    test('filtros, totales por etapa y cerradas del mes', () {
      final deals = [
        _deal(1, 'Refrigerador', 2, '24500.00', overdue: 1, next: {'type': 'call', 'subject': 'Llamar', 'due_at': '2026-10-21T10:00:00-06:00', 'overdue': true}),
        _deal(2, 'Abarrotes', 2, '1000.00', owner: 9),
        _deal(3, 'Ganada', 5, '500.00', status: 'won', closedAt: DateTime.now().toIso8601String()),
      ];
      expect(deals.where((d) => matchesFilter(d, const CrmFilter(overdue: true), 7)).map((d) => d['id']), [1]);
      expect(deals.where((d) => matchesFilter(d, const CrmFilter(mineOnly: true), 9)).map((d) => d['id']), [2]);
      expect(deals.where((d) => matchesFilter(d, const CrmFilter(search: 'tienda 3'), 7)).map((d) => d['id']), [3]);
      final t = stageTotals(deals.where((d) => d['stage_id'] == 2));
      expect([t.count, t.amount.toFixed(2), t.weighted.toFixed(2)], [2, '25500.00', '7650.00']);
      expect(closedThisMonth(deals[2]), isTrue);
      expect(closedThisMonth({'closed_at': '2020-01-01T00:00:00Z'}), isFalse);
    });

    test('etiquetas de vencimiento como en la web', () {
      final now = DateTime(2026, 10, 23, 9);
      expect(dueLabel(DateTime(2026, 10, 23, 16), now), 'Hoy 16:00');
      expect(dueLabel(DateTime(2026, 10, 24, 9, 30), now), 'Mañana 9:30');
      expect(dueLabel(DateTime(2026, 10, 20, 9), now), 'Hace 3 d');
      expect(dueLabel(DateTime(2026, 12, 2, 9), now), '2 dic');
    });

    test('el CRM sigue los permisos', () {
      expect(_session(_seller).canCrm, isTrue);
      expect(_session(_seller).canCrmAll, isFalse);
      expect(_session(['crm_deals.view', 'crm_deals.view_all']).canCrmAll, isTrue);
      expect(_session(['sales_orders.create']).canCrm, isFalse);
    });
  });

  group('CrmRepo sin conexión', () {
    late LocalDb db;
    setUp(() async {
      db = await LocalDb.open(factory: databaseFactoryFfi, path: inMemoryDatabasePath);
      await db.wipe();
    });

    test('baja todo, luego solo lo que cambió, y sin señal responde lo guardado', () async {
      var round = 0;
      var offline = false;
      final api = _FakeApi((method, path, query) {
        if (offline) throw ApiException(code: 'network', message: 'Sin señal');
        round++;
        if (round == 1) {
          expect(query?['updated_since'], isNull);
          return {
            'data': [_deal(1, 'Uno', 1, '100.00'), _deal(2, 'Dos', 2, '200.00')],
            'meta': {'next_cursor': null, 'server_time': '2026-10-23T10:00:00-06:00', 'deleted': []},
          };
        }
        expect(query?['updated_since'], '2026-10-23T10:00:00-06:00');
        return {
          'data': [_deal(1, 'Uno editada', 3, '150.00')],
          'meta': {'next_cursor': null, 'server_time': '2026-10-23T11:00:00-06:00', 'deleted': [2]},
        };
      });
      final repo = CrmRepo(api, db, OutboxRepo(db));

      expect((await repo.deals()).value.map((d) => d['title']), containsAll(['Uno', 'Dos']));
      final second = await repo.deals();
      expect(second.value.map((d) => d['title']), ['Uno editada']);
      expect(second.offline, isFalse);

      offline = true;
      final cached = await repo.deals();
      expect(cached.offline, isTrue);
      expect(cached.value.single['stage_id'], 3);
    });

    test('lo hecho sin señal se ve al momento y la oportunidad nueva espera su envío', () async {
      final api = _FakeApi((_, _, _) => throw ApiException(code: 'network', message: 'Sin señal'));
      final repo = CrmRepo(api, db, OutboxRepo(db));
      await db.putJson(CrmRepo.dealsKey, {'1': _deal(1, 'Uno', 1, '100.00')});
      await db.putJson(CrmRepo.sinceKey, '2026-10-23T10:00:00-06:00');
      await db.putJson(CrmRepo.detailKey(1), {..._deal(1, 'Uno', 1, '100.00'), 'timeline': {'pending': [], 'history': []}});

      await repo.patchLocal(1, {'stage_id': 2, 'stage': _stages[1]}, activity: {'type': 'visit', 'subject': 'Visita', 'pending': false, 'local': true});
      final detail = (await repo.deal(1)).value;
      expect(detail['stage_id'], 2);
      expect(asList(asMap(detail['timeline'])['history']).single['type'], 'visit');

      final op = OutboxOp.create('POST', '/crm/deals', body: {'business_partner_id': 5});
      await OutboxRepo(db).save(op);
      await repo.addLocalDeal(op, {'title': 'Nueva', 'status': 'open', 'stage_id': 1, 'pipeline_id': 1, 'amount': '0'});
      final list = (await repo.deals()).value;
      expect(list.where((d) => d['local'] == true).single['title'], 'Nueva');
    });
  });

  group('pantallas', () {
    late SharedPreferences prefs;
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
    });

    List<Override> overrides(Session s, List<Map<String, dynamic>> deals, {Map<String, dynamic>? detail, Writer? writer, CrmRepo? repo}) => [
          prefsProvider.overrideWithValue(prefs),
          sessionProvider.overrideWithValue(s),
          syncStatusProvider.overrideWith(SyncStatusNotifier.new),
          crmPipelinesProvider.overrideWith((ref) async => Cached(_pipelines)),
          crmDealsProvider.overrideWith((ref) async => Cached(deals)),
          crmAgendaProvider.overrideWith((ref) async => const Cached(<String, dynamic>{'data': [], 'meta': {'counts': {'overdue': 0}}})),
          crmLossReasonsProvider.overrideWith((ref) async => [
                {'id': 1, 'name': 'Precio'},
                {'id': 2, 'name': 'Eligió a la competencia'},
              ]),
          if (detail != null) crmDealProvider.overrideWith((ref, id) async => Cached(detail)),
          if (writer != null) writerProvider.overrideWithValue(writer),
          crmRepoProvider.overrideWithValue(repo ?? _FakeRepo()),
        ];

    testWidgets('el tablero enseña columnas con totales y cambia a lista', (tester) async {
      await tester.binding.setSurfaceSize(const Size(400, 860));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final deals = [
        _deal(1, 'Refrigerador exhibidor', 1, '24500.00', next: {'type': 'call', 'subject': 'Llamar', 'due_at': DateTime.now().subtract(const Duration(days: 2)).toIso8601String(), 'overdue': true}, overdue: 1),
        _deal(2, 'Pedido mensual', 1, '1000.00'),
        _deal(3, 'Lácteos', 2, '8900.00'),
      ];
      await tester.pumpWidget(ProviderScope(overrides: overrides(_session(_seller), deals), child: _app(const CrmPage())));
      await tester.pumpAndSettle();

      expect(find.text('Mis oportunidades'), findsOneWidget);
      expect(find.text('Refrigerador exhibidor'), findsOneWidget);
      expect(find.text('Pedido mensual'), findsOneWidget);
      expect(find.textContaining('Llamar · Hace 2 d'), findsOneWidget);
      // Columna de Prospecto: 2 oportunidades por $25,500
      expect(find.text(r'$25,500'), findsWidgets);
      expect(find.text('Nueva'), findsOneWidget);
      // Sin view_all no hay filtro "Mías"
      expect(find.text('Mías'), findsNothing);

      await tester.tap(find.text('Lista'));
      await tester.pumpAndSettle();
      expect(find.text('3 OPORTUNIDADES'), findsOneWidget);
      expect(find.text('Lácteos'), findsOneWidget);

      // Solo las que tienen un seguimiento vencido
      await tester.tap(find.text('Tablero'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Con vencidos'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Lista'));
      await tester.pumpAndSettle();
      expect(find.text('1 OPORTUNIDAD'), findsOneWidget);
      expect(find.text('Lácteos'), findsNothing);
    });

    testWidgets('detalle: avance, acciones, documentos y registrar una visita', (tester) async {
      await tester.binding.setSurfaceSize(const Size(400, 1400));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final writer = _FakeWriter();
      final detail = {
        ..._deal(10, 'Refrigerador exhibidor', 2, '24500.00'),
        'pipeline': {'id': 1, 'name': 'Ventas', 'stages': _stages},
        'documents': [
          {'id': 7, 'type': 'quotation', 'status': 'open', 'folio': 'COT-7', 'document_date': '2026-10-23', 'total': '2610.00'},
        ],
        'timeline': {
          'pending': [
            {'id': 5, 'type': 'call', 'subject': 'Confirmar medidas', 'due_at': DateTime.now().add(const Duration(hours: 3)).toIso8601String(), 'is_follow_up': true, 'pending': true},
          ],
          'history': [
            {'id': 4, 'type': 'stage', 'subject': 'Etapa: Prospecto → Calificado', 'occurred_at': '2026-10-22T10:00:00-06:00', 'is_follow_up': false, 'pending': false},
          ],
        },
      };
      await tester.pumpWidget(ProviderScope(overrides: overrides(_session(_seller), [], detail: detail, writer: writer), child: _app(const DealPage(dealId: 10))));
      await tester.pumpAndSettle();

      expect(find.text('Refrigerador exhibidor'), findsOneWidget);
      expect(find.text('Calificado'), findsWidgets);
      expect(find.text('Cotización COT-7'), findsOneWidget);
      expect(find.text('Hacer otra cotización'), findsOneWidget);
      expect(find.text('Confirmar medidas'), findsOneWidget);
      expect(find.text('Ganada'), findsOneWidget);
      expect(find.text('Perdida'), findsOneWidget);

      await tester.tap(find.text('Visita'));
      await tester.pumpAndSettle();
      expect(find.text('Registrar actividad'), findsOneWidget);
      await tester.enterText(find.byType(TextField).last, 'Revisamos el espacio junto a la caja');
      await tester.tap(find.text('Registrar visita'));
      await tester.pumpAndSettle();

      final op = writer.sent.single;
      expect(op.method, 'POST');
      expect(op.path, '/api/v1/crm/deals/10/activities');
      expect(op.body, {'type': 'visit', 'body': 'Revisamos el espacio junto a la caja'});
      expect(find.text('Visita registrada'), findsOneWidget);
    });

    testWidgets('perder pide el motivo y sin señal queda en la cola', (tester) async {
      await tester.binding.setSurfaceSize(const Size(400, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final repo = _FakeRepo();
      final writer = _FakeWriter(queued: true);
      final detail = {..._deal(10, 'Refrigerador exhibidor', 2, '24500.00'), 'pipeline': {'id': 1, 'name': 'Ventas', 'stages': _stages}, 'documents': [], 'timeline': {'pending': [], 'history': []}};
      await tester.pumpWidget(ProviderScope(
        overrides: overrides(_session(_seller), [], detail: detail, writer: writer, repo: repo),
        child: _app(const DealPage(dealId: 10)),
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Perdida'));
      await tester.pumpAndSettle();
      expect(find.text('¿Por qué se perdió?'), findsOneWidget);
      final save = find.widgetWithText(NrButton, 'Marcar como perdida');
      expect(tester.widget<NrButton>(save).onPressed, isNull);
      await tester.tap(find.text('Precio'));
      await tester.pumpAndSettle();
      await tester.tap(save);
      await tester.pumpAndSettle();

      expect(writer.sent.single.path, '/api/v1/crm/deals/10/lose');
      expect(writer.sent.single.body, {'loss_reason_id': 1});
      expect(find.text('Guardado sin señal; se enviará solo.'), findsOneWidget);
      expect(repo.patched[10]?['status'], 'lost');
      expect(asMap(repo.patched[10]?['loss_reason'])['name'], 'Precio');
    });

    testWidgets('la agenda de Hoy marca lo vencido', (tester) async {
      final agenda = {
        'data': [
          {
            'id': 1, 'type': 'task', 'subject': 'Enviar lista de precios', 'due_at': DateTime.now().subtract(const Duration(days: 2)).toIso8601String(),
            'is_follow_up': true, 'pending': true, 'bucket': 'overdue', 'deal': {'id': 13, 'title': 'Insumos', 'partner': {'id': 8, 'name': 'La Huerta'}},
          },
          {
            'id': 2, 'type': 'call', 'subject': 'Confirmar medidas', 'due_at': DateTime.now().add(const Duration(minutes: 30)).toIso8601String(),
            'is_follow_up': true, 'pending': true, 'bucket': 'today', 'deal': {'id': 10, 'title': 'Refrigerador', 'partner': {'id': 4, 'name': 'Tres Cerros'}},
          },
        ],
        'meta': {'counts': {'overdue': 1, 'today': 1, 'upcoming': 0}},
      };
      await tester.pumpWidget(ProviderScope(
        overrides: [sessionProvider.overrideWithValue(_session(_seller)), crmAgendaProvider.overrideWith((ref) async => Cached(agenda))],
        child: _app(const Scaffold(body: SingleChildScrollView(child: AgendaCard())), dark: true),
      ));
      await tester.pumpAndSettle();
      expect(find.text('1 seguimiento vencido'), findsOneWidget);
      expect(find.text('Enviar lista de precios'), findsOneWidget);
      expect(find.textContaining('La Huerta'), findsOneWidget);
      expect(find.text('Confirmar medidas'), findsOneWidget);

      // Sin permiso de CRM no se pinta
      await tester.pumpWidget(ProviderScope(
        overrides: [sessionProvider.overrideWithValue(_session(['sales_orders.create'])), crmAgendaProvider.overrideWith((ref) async => Cached(agenda))],
        child: _app(const Scaffold(body: AgendaCard())),
      ));
      await tester.pumpAndSettle();
      expect(find.text('Enviar lista de precios'), findsNothing);
    });
  });
}
