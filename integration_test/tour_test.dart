// Recorrido visual de la app en el simulador: abre cada pantalla principal e
// imprime "SHOT:<nombre>" para que un script tome la captura con
// `xcrun simctl io <id> screenshot` (ver tool/tour.sh). Usa la sesión ya
// abierta en el equipo y los catálogos sincronizados; la ruta del día y la
// visita son datos de ejemplo (ficticios) porque no siempre hay una ruta hoy.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:nori_mobile/core/api/api_client.dart';
import 'package:nori_mobile/core/db/local_db.dart';
import 'package:nori_mobile/core/providers.dart';
import 'package:nori_mobile/core/router.dart';
import 'package:nori_mobile/features/auth/auth_pages.dart';
import 'package:nori_mobile/features/collections/collection_page.dart';
import 'package:nori_mobile/features/collections/tender_sheet.dart';
import 'package:nori_mobile/features/route/route_repo.dart';
import 'package:nori_mobile/features/route/visit_page.dart';
import 'package:nori_mobile/features/sales/cart.dart';
import 'package:nori_mobile/features/supervisor/approvals.dart';
import 'package:nori_mobile/features/sales/cart_page.dart';
import 'package:nori_mobile/features/sales/quick_capture.dart';
import 'package:nori_mobile/core/util/decimal.dart';
import 'package:nori_mobile/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _only = String.fromEnvironment('TOUR_ONLY');
const _themes = String.fromEnvironment('TOUR_THEMES', defaultValue: 'light,dark');

// Sin sesión en el equipo (flutter test desinstala la app al terminar), se
// entra con estos datos; tool/tour.sh los toma del entorno.
const _server = String.fromEnvironment('TOUR_SERVER');
const _user = String.fromEnvironment('TOUR_USER');
const _password = String.fromEnvironment('TOUR_PASSWORD');

Map<String, dynamic> _stop(int id, int seq, String name, String status, String label, {String? sale, String? addr, List<String>? window}) => {
      'id': id,
      'sequence': seq,
      'status': status,
      'status_label': label,
      'reasons': [
        {'id': 1, 'name': 'Venta', 'action': 'sale', 'color': '#16a34a'},
        if (seq.isEven) {'id': 6, 'name': 'Cobranza', 'action': 'collection', 'color': '#0f766e'},
      ],
      'window': window,
      'outcome': status == 'completed' ? 'sale' : null,
      'sale_total': sale ?? '0.00',
      'collected_total': sale ?? '0.00',
      'customer': {'id': null, 'code': 'C-${100 + id}', 'name': name, 'phone': '5512345678', 'address': addr ?? 'Av. Juárez 120, Centro', 'lat': 19.43 + id / 400, 'lng': -99.13 - id / 500},
      'navigate_url': 'https://www.google.com/maps',
    };

final _sampleDay = {
  'date': '2026-10-22',
  'plans': [
    {
      'id': 1,
      'status': 'in_progress',
      'status_label': 'En ruta',
      'route': {'id': 1, 'code': 'R-03', 'name': 'Ruta Norte 03', 'depot': {'lat': 19.42, 'lng': -99.12}},
      'vehicle': 'Camioneta 7 · ABC-123',
      'truck_warehouse_id': 9,
      'target': '18000.00',
      'sales': '11240.50',
      'counts': {'planned': 9, 'completed': 5, 'skipped': 1, 'pending': 3},
      'stops': [
        _stop(1, 1, 'Abarrotes La Esquina', 'completed', 'Visitada', sale: '2310.00', window: ['08:00', '09:00']),
        _stop(2, 2, 'Miscelánea San Rafael', 'completed', 'Visitada', sale: '1840.50'),
        _stop(3, 3, 'Tienda Doña Lupe', 'skipped', 'No visitada'),
        _stop(4, 4, 'Cremería El Rancho', 'completed', 'Visitada', sale: '3120.00'),
        _stop(5, 5, 'Minisúper Las Palmas', 'completed', 'Visitada', sale: '2410.00'),
        _stop(6, 6, 'Depósito Los Pinos', 'completed', 'Visitada', sale: '1560.00'),
        _stop(7, 7, 'Abarrotes Mary', 'in_progress', 'En visita', window: ['12:00', '13:30']),
        _stop(8, 8, 'Tienda El Sol', 'pending', 'Pendiente'),
        _stop(9, 9, 'Recaudería Hermanos Cruz', 'pending', 'Pendiente', window: ['16:00', '18:00']),
      ],
    }
  ],
  'tenders': [
    {'id': 1, 'name': 'Efectivo', 'gives_change': true},
    {'id': 2, 'name': 'Transferencia', 'requires_reference': true},
    {'id': 3, 'name': 'Tarjeta'},
  ],
};

Map<String, dynamic> get _sampleVisit => {
      ..._stop(7, 7, 'Abarrotes Mary', 'in_progress', 'En visita', window: ['12:00', '13:30']),
      'plan_id': 1,
      'orders': [
        {'id': 1, 'folio': 'PED-1042', 'lines': []}
      ],
      'owed': [
        {'id': 11, 'folio': 'FAC-2231', 'type': 'Factura', 'due_date': '2026-10-02', 'balance': '1450.00', 'overdue': true},
        {'id': 12, 'folio': 'FAC-2290', 'type': 'Factura', 'due_date': '2026-10-30', 'balance': '820.00', 'overdue': false},
      ],
      'owed_total': '2270.00',
      'assets': [
        {'id': 1, 'code': 'REF-08', 'name': 'Refrigerador vertical', 'service_due': true}
      ],
      'done': [
        {'role': 'sale', 'role_label': 'Venta', 'folio': 'ENT-5521', 'type': 'Entrega', 'total': '640.00'}
      ],
      'suggested': [],
    };

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;

  testWidgets('recorrido visual', (tester) async {
    await initializeDateFormatting('es_MX');
    final db = await LocalDb.open();
    final prefs = await SharedPreferences.getInstance();
    var withRoute = true;
    final container = ProviderContainer(overrides: [
      localDbProvider.overrideWithValue(db),
      prefsProvider.overrideWithValue(prefs),
      routeTodayProvider.overrideWith((ref) async => Cached(withRoute ? _sampleDay : <String, dynamic>{'plans': []})),
      visitProvider.overrideWith((ref, id) async => Cached(_sampleVisit)),
      pendingApprovalsProvider.overrideWith(_SampleApprovals.new),
    ]);
    await db.putJson(RouteRepo.todayKey, _sampleDay);
    await tester.pumpWidget(UncontrolledProviderScope(container: container, child: const NoriApp()));

    Future<void> wait([int ms = 1200]) async {
      final end = DateTime.now().add(Duration(milliseconds: ms));
      while (DateTime.now().isBefore(end)) {
        await tester.pump(const Duration(milliseconds: 50));
      }
    }

    Future<void> shot(String name) async {
      if (_only.isNotEmpty && !_only.split(',').any(name.startsWith)) return wait(700);
      await wait(1400);
      // ignore: avoid_print
      print('SHOT:$name');
      await wait(1600);
    }

    await wait(3000);
    if (container.read(authProvider).status == AuthStatus.signedOut && _server.isNotEmpty) {
      await container.read(authProvider.notifier).login(server: _server, username: _user, password: _password);
      await wait(2000);
    }
    // Recién instalada, la app baja los catálogos: se espera a tener clientes y artículos.
    for (var i = 0; i < 90 && (await db.count('customers') == 0 || await db.count('items') == 0 || container.read(syncStatusProvider).syncing); i++) {
      await wait(1000);
    }
    final router = container.read(routerProvider);
    final nav = router.routerDelegate.navigatorKey;
    final customers = await db.search('customers', '', limit: 300);
    customers.sort((a, b) => (double.tryParse('${b['balance']}') ?? 0).compareTo(double.tryParse('${a['balance']}') ?? 0));
    final items = await db.search('items', '', limit: 6);
    final customer = customers.first;

    Future<void> push(Widget page) async {
      nav.currentState!.push(MaterialPageRoute<void>(builder: (_) => page));
      await wait(600);
    }

    void pop() => nav.currentState!.maybePop();

    for (final theme in _themes.split(',')) {
      container.read(themeModeProvider.notifier).set(theme == 'dark' ? ThemeMode.dark : ThemeMode.light);
      final t = theme == 'dark' ? 'd' : 'l';

      withRoute = true;
      router.go('/today');
      container.invalidate(routeTodayProvider);
      await shot('01_hoy_$t');
      withRoute = false;
      container.invalidate(routeTodayProvider);
      await shot('02_hoy_sin_ruta_$t');
      withRoute = true;
      container.invalidate(routeTodayProvider);

      router.push('/route/visit/7');
      await shot('03_visita_$t');
      pop();
      await wait(500);

      router.go('/sell');
      await shot('04_vender_$t');

      if (items.isNotEmpty) {
        final favorites = container.read(quickCaptureProvider).favorites;
        container.read(quickCaptureProvider.notifier).setFavorites([for (final it in items) (it['id'] as num).toInt()]);
        await push(QuickCapturePage(customerId: (customer['id'] as num).toInt(), customerName: '${customer['trade_name'] ?? customer['name']}', title: 'Venta'));
        await wait(800);
        final plus = find.byIcon(Icons.add_rounded);
        if (plus.evaluate().length > 2) {
          await tester.tap(plus.at(0));
          await tester.tap(plus.at(0));
          await tester.tap(plus.at(2));
        }
        await shot('05_captura_rapida_$t');
        container.read(quickCaptureProvider.notifier).setFavorites(favorites);
        pop();
        await wait(500);

        await push(CartPage(
          title: 'Pedido',
          customerName: '${customer['trade_name'] ?? customer['name']}',
          submitLabel: 'Guardar pedido',
          quote: null,
          initialLines: [for (final (i, it) in items.take(4).indexed) CartLine(item: it, quantity: Dec.parse('${i + 2}'))],
          allowHeader: true,
          onSubmit: (_, _) async => false,
        ));
        await shot('06_carrito_$t');
        showTenderSheet(nav.currentContext!, tenderTypes: asList(_sampleDay['tenders']), total: Dec.parse('1284.50'), allowCredit: true, title: 'Entrega');
        await shot('07_cobro_$t');
        pop();
        await wait(500);
        showDoneDialog(nav.currentContext!, _RefShim(container), 'Entrega ENT-5530', {'total': '1284.50'});
        await shot('08_listo_$t');
        pop();
        await wait(400);
        pop();
        await wait(500);
      }

      router.go('/customers');
      await shot('09_clientes_$t');
      router.push('/customers/${customer['id']}');
      await shot('10_cliente_$t');
      pop();
      await wait(400);
      await push(CollectionPage(customerId: (customer['id'] as num).toInt(), customerName: '${customer['trade_name'] ?? customer['name']}', tenderTypes: asList(_sampleDay['tenders'])));
      await shot('10b_cobranza_$t');
      pop();
      await wait(400);

      router.push('/documents');
      await shot('11_documentos_$t');
      pop();
      await wait(400);

      router.push('/checker');
      await wait(600);
      if (items.isNotEmpty) {
        await tester.enterText(find.byType(TextField).first, '${items.first['code']}');
        await wait(900);
        final hit = find.text('${items.first['name']}');
        if (hit.evaluate().isNotEmpty) await tester.tap(hit.first);
      }
      await shot('12_checador_$t');
      pop();
      await wait(400);

      router.go('/inventory');
      await shot('13_inventario_$t');
      router.push('/inventory/movement/transfers');
      await shot('14_traslado_$t');
      pop();
      await wait(400);

      router.go('/supervisor');
      await shot('15_indicadores_$t');
      router.push('/authorizations');
      await shot('16_autorizaciones_$t');
      pop();
      await wait(400);

      router.go('/more');
      await shot('17_mas_$t');
      router.push('/settings');
      await shot('18_configuracion_$t');
      pop();
      await wait(300);
      router.push('/printer');
      await shot('19_impresora_$t');
      pop();
      await wait(300);
      router.push('/sync');
      await shot('20_sincronizacion_$t');
      pop();
      await wait(300);

      await push(const LoginPage());
      await shot('21_login_$t');
      pop();
      await wait(400);
    }
    container.read(themeModeProvider.notifier).set(ThemeMode.system);
    router.go('/today');
    await wait(500);
  }, timeout: const Timeout(Duration(minutes: 20)));
}

/// [showDoneDialog] pide un WidgetRef; aquí basta con leer del contenedor.
class _RefShim implements WidgetRef {
  _RefShim(this.c);
  final ProviderContainer c;

  @override
  BuildContext get context => throw UnimplementedError();

  @override
  T read<T>(ProviderListenable<T> provider) => c.read(provider);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Bandeja de ejemplo (sin consultar al servidor ni pedir permiso de notificaciones).
class _SampleApprovals extends PendingApprovals {
  @override
  List<Map<String, dynamic>> build() => [
        {
          'id': 1,
          'label': 'Descuento mayor al permitido',
          'requested_by': 'Vendedor de la Ruta Norte 03',
          'reference': 'Pedido · Abarrotes Mary',
          'requested_at': '2026-10-22T11:42:00',
          'details': [
            {'label': 'Descuento pedido', 'value': '18 %'},
            {'label': 'Máximo permitido', 'value': '10 %'},
            {'label': 'Total', 'value': r'$4,820.00'},
          ],
          'comment': 'Cliente frecuente, compra de temporada.',
        },
        {
          'id': 2,
          'label': 'Venta sobre el límite de crédito',
          'requested_by': 'Vendedor de la Ruta Sur 01',
          'reference': 'Entrega · Tienda El Sol',
          'requested_at': '2026-10-22T10:05:00',
          'details': [
            {'label': 'Crédito disponible', 'value': r'$1,200.00'},
            {'label': 'Total', 'value': r'$2,950.00'},
          ],
        },
      ];

  @override
  Future<void> refresh() async {}
}
