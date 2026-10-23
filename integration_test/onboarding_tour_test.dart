// Visual pass over the onboarding and the sign-in on the simulator: prints
// "SHOT:<name>" so a script takes the screenshot with `xcrun simctl io <id> screenshot`
// (same pattern as tool/tour.sh). It only checks the company against the server
// (TOUR_SERVER, a public call); it never signs in.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:nori_mobile/core/design/design.dart';
import 'package:nori_mobile/core/providers.dart';
import 'package:nori_mobile/features/auth/auth_pages.dart';
import 'package:nori_mobile/features/onboarding/onboarding_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _server = String.fromEnvironment('TOUR_SERVER', defaultValue: 'http://demo.localhost:8000');

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;

  testWidgets('onboarding and sign-in', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    Future<void> wait([int ms = 1200]) async {
      final end = DateTime.now().add(Duration(milliseconds: ms));
      while (DateTime.now().isBefore(end)) {
        await tester.pump(const Duration(milliseconds: 50));
      }
    }

    Future<void> shot(String name, {int settle = 1400}) async {
      await wait(settle);
      // ignore: avoid_print
      print('SHOT:$name');
      await wait(1200);
    }

    for (final theme in ['light', 'dark']) {
      Future<void> show(Widget home) async {
        await tester.pumpWidget(ProviderScope(
          key: UniqueKey(),
          overrides: [prefsProvider.overrideWithValue(prefs)],
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: NrTheme.light(NrColors.defaultAccent),
            darkTheme: NrTheme.dark(NrColors.defaultAccent),
            themeMode: theme == 'dark' ? ThemeMode.dark : ThemeMode.light,
            locale: const Locale('es', 'MX'),
            home: home,
          ),
        ));
        await wait(600);
      }

      await show(const OnboardingPage());
      for (var i = 0; i < OnboardingPage.slides.length; i++) {
        // The scene plays its loop; the shot lands when its idea is complete.
        await shot('onboarding_${i + 1}_$theme', settle: i == 0 ? 3000 : 3500);
        if (i < OnboardingPage.slides.length - 1) {
          await tester.tap(find.text('Siguiente'));
          await wait(300);
        }
      }

      await prefs.clear();
      await show(const LoginPage());
      await shot('login_1_empresa_$theme');
      await tester.tap(find.text('Continuar'));
      await shot('login_2_empresa_error_$theme', settle: 600);
      await tester.enterText(find.byType(TextField).first, _server);
      await tester.testTextInput.receiveAction(TextInputAction.done);
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.tap(find.text('Continuar'));
      await wait(2500);
      FocusManager.instance.primaryFocus?.unfocus();
      await shot('login_3_credenciales_$theme');
      await tester.tap(find.text('Entrar'));
      await shot('login_4_credenciales_error_$theme', settle: 600);
    }
  });
}
