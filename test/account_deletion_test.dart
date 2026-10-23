import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nori_mobile/core/api/api_error.dart';
import 'package:nori_mobile/core/design/design.dart';
import 'package:nori_mobile/features/more/account_deletion_page.dart';

/// Scripted service: no network, no database; records what the screen asked for.
class _FakeService implements AccountDeletionService {
  _FakeService({this.unsent = 0, this.isOnline = true, this.message = 'Recibimos tu solicitud.', this.error});

  int unsent;
  final bool isOnline;
  final String? message;
  final ApiException? error;
  final requests = <String?>[];
  int flushes = 0;
  bool signedOut = false;

  @override
  Future<int> unsentCount() async => unsent;

  @override
  bool get online => isOnline;

  @override
  Future<void> sendPending() async {
    flushes++;
    unsent = 0;
  }

  @override
  Future<String?> request(String? reason) async {
    requests.add(reason);
    if (error != null) throw error!;
    return message;
  }

  @override
  Future<void> signOutAndWipe() async => signedOut = true;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Future<void> _open(WidgetTester tester, _FakeService service) async {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 2.5;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [accountDeletionServiceProvider.overrideWithValue(service)],
      child: MaterialApp(
        theme: NrTheme.light(NrColors.defaultAccent),
        builder: (context, child) => MediaQuery(data: MediaQuery.of(context).copyWith(disableAnimations: true), child: child!),
        home: const AccountDeletionPage(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _confirmAndSend(WidgetTester tester) async {
  await tester.tap(find.text('Entiendo que no se puede deshacer'));
  await tester.pump();
  await tester.ensureVisible(find.text('Solicitar eliminación'));
  await tester.tap(find.text('Solicitar eliminación'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('explica qué se borra, qué se conserva y el plazo', (tester) async {
    await _open(tester, _FakeService());
    expect(find.text('Qué se borra'), findsOneWidget);
    expect(find.textContaining('historial de ubicación'), findsOneWidget);
    expect(find.text('Qué se conserva'), findsOneWidget);
    expect(find.textContaining('cinco años'), findsOneWidget);
    expect(find.textContaining('30 días'), findsOneWidget);
    expect(find.textContaining('desactivar tu usuario al momento'), findsOneWidget);
    expect(find.text('Más información'), findsOneWidget);
  });

  testWidgets('no envía sin confirmar', (tester) async {
    final service = _FakeService();
    await _open(tester, service);
    await tester.ensureVisible(find.text('Solicitar eliminación'));
    await tester.tap(find.text('Solicitar eliminación'));
    await tester.pumpAndSettle();
    expect(service.requests, isEmpty);
  });

  testWidgets('envía la solicitud, muestra el mensaje y cierra sesión borrando lo local', (tester) async {
    final service = _FakeService();
    await _open(tester, service);
    await tester.enterText(find.byType(TextField), 'Ya no trabajo ahí');
    await _confirmAndSend(tester);
    expect(service.requests, ['Ya no trabajo ahí']);
    expect(find.text('Solicitud enviada'), findsOneWidget);
    expect(find.text('Recibimos tu solicitud.'), findsOneWidget);
    expect(service.signedOut, isFalse);

    await tester.tap(find.text('Cerrar sesión'));
    await tester.pump();
    expect(service.signedOut, isTrue);
  });

  testWidgets('sin mensaje del servidor muestra el texto propio', (tester) async {
    await _open(tester, _FakeService(message: null));
    await _confirmAndSend(tester);
    expect(find.textContaining('máximo de 30 días y te avisaremos'), findsOneWidget);
  });

  testWidgets('un error se muestra y no cierra sesión', (tester) async {
    final service = _FakeService(
      error: ApiException(code: 'network', message: 'Sin conexión con el servidor.'),
    );
    await _open(tester, service);
    await _confirmAndSend(tester);
    expect(find.text('Sin conexión con el servidor.'), findsOneWidget);
    expect(find.text('Solicitud enviada'), findsNothing);
    expect(service.signedOut, isFalse);
  });

  testWidgets('con pendientes en línea avisa y ofrece enviarlos primero', (tester) async {
    final service = _FakeService(unsent: 3);
    await _open(tester, service);
    await _confirmAndSend(tester);
    expect(find.text('Tienes operaciones sin enviar'), findsOneWidget);
    expect(find.textContaining('se pierden'), findsOneWidget);
    expect(service.requests, isEmpty);

    await tester.tap(find.text('Enviar pendientes primero'));
    await tester.pumpAndSettle();
    expect(service.flushes, 1);
    expect(service.requests, hasLength(1));
    expect(find.text('Solicitud enviada'), findsOneWidget);
  });

  testWidgets('con pendientes puede continuar sin enviarlos', (tester) async {
    final service = _FakeService(unsent: 2);
    await _open(tester, service);
    await _confirmAndSend(tester);
    await tester.tap(find.text('Continuar sin enviar'));
    await tester.pumpAndSettle();
    expect(service.flushes, 0);
    expect(service.requests, hasLength(1));
  });

  testWidgets('sin conexión y con pendientes no envía y lo explica', (tester) async {
    final service = _FakeService(unsent: 4, isOnline: false);
    await _open(tester, service);
    await _confirmAndSend(tester);
    expect(find.textContaining('Estás sin conexión'), findsOneWidget);
    expect(service.requests, isEmpty);
  });
}
