import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nori_mobile/core/design/design.dart';
import 'package:nori_mobile/core/providers.dart';
import 'package:nori_mobile/features/auth/auth_pages.dart';
import 'package:nori_mobile/features/onboarding/onboarding_page.dart';
import 'package:nori_mobile/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<SharedPreferences> _prefs([Map<String, Object> values = const {}]) async {
  SharedPreferences.setMockInitialValues(values);
  FlutterSecureStorage.setMockInitialValues({});
  return SharedPreferences.getInstance();
}

/// The whole app with "reduce motion" on, so nothing loops forever.
Future<void> _pumpApp(WidgetTester tester, SharedPreferences prefs) async {
  tester.platformDispatcher.accessibilityFeaturesTestValue = const FakeAccessibilityFeatures(disableAnimations: true);
  addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
  await tester.pumpWidget(ProviderScope(
    key: UniqueKey(),
    overrides: [prefsProvider.overrideWithValue(prefs)],
    child: const NoriApp(),
  ));
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 8; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Future<void> _pumpLogin(WidgetTester tester, SharedPreferences prefs) async {
  await tester.pumpWidget(ProviderScope(
    overrides: [prefsProvider.overrideWithValue(prefs)],
    child: MaterialApp(
      theme: NrTheme.light(NrColors.defaultAccent),
      builder: (context, child) => MediaQuery(data: MediaQuery.of(context).copyWith(disableAnimations: true), child: child!),
      home: const LoginPage(),
    ),
  ));
}

void main() {
  final first = OnboardingPage.slides.first.title;

  testWidgets('el onboarding sale la primera vez y Saltar lo cierra para siempre', (tester) async {
    final prefs = await _prefs();
    await _pumpApp(tester, prefs);
    expect(find.text(first), findsOneWidget);

    await tester.tap(find.text('Saltar'));
    await _settle(tester);
    expect(find.text('Entra a tu empresa'), findsOneWidget);
    expect(prefs.getBool(OnboardingSeenNotifier.key), isTrue);

    // Next launch: straight to sign-in.
    await _pumpApp(tester, prefs);
    expect(find.text(first), findsNothing);
    expect(find.text('Entra a tu empresa'), findsOneWidget);
  });

  testWidgets('Siguiente recorre las páginas y Empezar lleva a iniciar sesión', (tester) async {
    final prefs = await _prefs();
    await _pumpApp(tester, prefs);
    for (final slide in OnboardingPage.slides.skip(1)) {
      await tester.tap(find.text('Siguiente'));
      await _settle(tester);
      expect(find.text(slide.title), findsOneWidget);
    }
    expect(find.text('Siguiente'), findsNothing);
    await tester.tap(find.text('Empezar'));
    await _settle(tester);
    expect(find.text('Entra a tu empresa'), findsOneWidget);
    expect(prefs.getBool(OnboardingSeenNotifier.key), isTrue);
  });

  testWidgets('un equipo que ya inició sesión antes no ve el onboarding', (tester) async {
    final prefs = await _prefs({'nori.last_server': 'demo', 'nori.last_user': 'ana'});
    await _pumpApp(tester, prefs);
    expect(find.text(first), findsNothing);
    expect(find.text('Inicia sesión'), findsOneWidget);
  });

  testWidgets('el paso de empresa pide la empresa y, si se agrega, el código', (tester) async {
    await _pumpLogin(tester, await _prefs());
    await tester.tap(find.text('Continuar'));
    await tester.pump();
    expect(find.text('Escribe el nombre de tu empresa.'), findsOneWidget);

    await tester.enterText(find.byType(TextField).first, 'api.nori.software');
    await tester.pump();
    expect(find.text('Escribe el nombre de tu empresa.'), findsNothing);

    await tester.tap(find.text('Agregar código de empresa'));
    await tester.pump();
    await tester.tap(find.text('Continuar'));
    await tester.pump();
    expect(find.text('Escribe el código de empresa.'), findsOneWidget);
  });

  testWidgets('con la empresa recordada pide usuario y contraseña, y deja cambiar de empresa', (tester) async {
    await _pumpLogin(tester, await _prefs({'nori.last_server': 'http://demo.localhost:8000'}));
    expect(find.text('Inicia sesión'), findsOneWidget);
    expect(find.text('demo.localhost:8000'), findsOneWidget);

    await tester.tap(find.text('Entrar'));
    await tester.pump();
    expect(find.text('Escribe tu usuario.'), findsOneWidget);
    expect(find.text('Escribe tu contraseña.'), findsOneWidget);

    TextField passwordField() => tester.widget<TextField>(find.byType(TextField).last);
    expect(passwordField().obscureText, isTrue);
    await tester.tap(find.byTooltip('Mostrar contraseña'));
    await tester.pump();
    expect(passwordField().obscureText, isFalse);

    await tester.tap(find.text('Cambiar'));
    await tester.pump();
    expect(find.text('Entra a tu empresa'), findsOneWidget);
    expect(find.widgetWithText(TextField, 'http://demo.localhost:8000'), findsOneWidget);
  });
}
