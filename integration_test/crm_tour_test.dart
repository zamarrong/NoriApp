// Recorrido visual del CRM en el simulador (ver tool/tour.sh con
// TOUR_TEST=integration_test/crm_tour_test.dart): tablero, lista, detalle,
// hojas de actividad y de pérdida, agenda, "Hoy" y la ficha del cliente.
// Usa el servidor real (TOUR_SERVER, TOUR_USER, TOUR_PASSWORD): las
// oportunidades son las del usuario en ese servidor.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:nori_mobile/core/db/local_db.dart';
import 'package:nori_mobile/core/providers.dart';
import 'package:nori_mobile/core/router.dart';
import 'package:nori_mobile/features/crm/crm_repo.dart';
import 'package:nori_mobile/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _only = String.fromEnvironment('TOUR_ONLY');
const _themes = String.fromEnvironment('TOUR_THEMES', defaultValue: 'light,dark');
const _server = String.fromEnvironment('TOUR_SERVER');
const _user = String.fromEnvironment('TOUR_USER');
const _password = String.fromEnvironment('TOUR_PASSWORD');

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;

  testWidgets('recorrido del CRM', (tester) async {
    await initializeDateFormatting('es_MX');
    final db = await LocalDb.open();
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(overrides: [localDbProvider.overrideWithValue(db), prefsProvider.overrideWithValue(prefs)]);
    await tester.pumpWidget(UncontrolledProviderScope(container: container, child: const NoriApp()));

    Future<void> wait([int ms = 1200]) async {
      final end = DateTime.now().add(Duration(milliseconds: ms));
      while (DateTime.now().isBefore(end)) {
        await tester.pump(const Duration(milliseconds: 50));
      }
    }

    Future<void> shot(String name) async {
      if (_only.isNotEmpty && !_only.split(',').any(name.startsWith)) return wait(700);
      await wait(1500);
      // ignore: avoid_print
      print('SHOT:$name');
      await wait(1500);
    }

    Future<void> tapText(String text, {bool last = false}) async {
      final f = find.text(text);
      if (f.evaluate().isEmpty) return;
      final target = last ? f.last : f.first;
      await tester.ensureVisible(target);
      await wait(300);
      await tester.tap(target);
      await wait(900);
    }

    await wait(3000);
    // Siempre con el usuario y servidor del recorrido (el equipo pudo quedar con otra sesión)
    if (_server.isNotEmpty) {
      final s = container.read(sessionProvider);
      if (s == null || s.username != _user) {
        if (s != null) await container.read(authProvider.notifier).logout(remote: false);
        await db.wipe();
        await container.read(authProvider.notifier).login(server: _server, username: _user, password: _password);
      }
      await wait(2500);
    }
    for (var i = 0; i < 60 && (await db.count('customers') == 0 || container.read(syncStatusProvider).syncing); i++) {
      await wait(1000);
    }
    final router = container.read(routerProvider);
    final nav = router.routerDelegate.navigatorKey;
    void pop() => nav.currentState!.maybePop();

    final deals = (await container.read(crmDealsProvider.future)).value;
    Map<String, dynamic> pick(String text) => deals.firstWhere((d) => '${d['title']}'.contains(text), orElse: () => deals.first);
    final quoted = pick('Don Beto');
    final fridge = pick('Tres Cerros');

    for (final theme in _themes.split(',')) {
      container.read(themeModeProvider.notifier).set(theme == 'dark' ? ThemeMode.dark : ThemeMode.light);
      final t = theme == 'dark' ? 'd' : 'l';

      container.read(crmViewProvider.notifier).set(CrmView.board);
      router.go('/crm');
      await shot('01_crm_tablero_$t');
      final pages = find.byType(PageView);
      if (pages.evaluate().isNotEmpty) {
        await tester.fling(pages.first, const Offset(-320, 0), 1200);
        await wait(500);
        await tester.fling(pages.first, const Offset(-320, 0), 1200);
        await shot('02_crm_tablero_cotizacion_$t');
      }
      container.read(crmViewProvider.notifier).set(CrmView.list);
      await shot('03_crm_lista_$t');
      container.read(crmViewProvider.notifier).set(CrmView.board);

      router.push('/crm/deals/${quoted['id']}');
      await shot('04_oportunidad_$t');
      await tester.drag(find.byType(ListView).last, const Offset(0, -620));
      await shot('05_oportunidad_documentos_$t');
      pop();
      await wait(500);

      router.push('/crm/deals/${fridge['id']}');
      await wait(1500);
      await tapText('Visita');
      await shot('06_registrar_visita_$t');
      pop();
      await wait(600);
      await tapText('Programar');
      await shot('07_programar_seguimiento_$t');
      pop();
      await wait(600);
      await tapText('Perdida');
      await shot('08_perdida_$t');
      pop();
      await wait(600);
      pop();
      await wait(500);

      router.push('/crm/agenda');
      await shot('09_agenda_$t');
      pop();
      await wait(400);

      router.go('/today');
      await wait(1500);
      final agenda = find.text('MI AGENDA');
      if (agenda.evaluate().isNotEmpty) {
        await tester.ensureVisible(agenda);
        await wait(300);
        await tester.drag(find.byType(ListView).first, const Offset(0, 140));
      }
      await shot('10_hoy_agenda_$t');

      router.push('/customers/${fridge['business_partner_id']}');
      await wait(1800);
      final section = find.text('OPORTUNIDADES');
      if (section.evaluate().isNotEmpty) {
        await tester.ensureVisible(section);
        await wait(300);
        await tester.drag(find.byType(ListView).last, const Offset(0, 160));
      }
      await shot('11_cliente_oportunidades_$t');
      await tapText('Nueva');
      await shot('12_nueva_oportunidad_$t');
      pop();
      await wait(500);
      pop();
      await wait(500);
    }
    container.read(themeModeProvider.notifier).set(ThemeMode.system);
    router.go('/crm');
    await wait(800);
  }, timeout: const Timeout(Duration(minutes: 15)));
}
