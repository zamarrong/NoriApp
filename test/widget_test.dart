import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nori_mobile/core/auth/session.dart';
import 'package:nori_mobile/core/api/server_config.dart';
import 'package:nori_mobile/core/design/design.dart';
import 'package:nori_mobile/core/providers.dart';
import 'package:nori_mobile/core/router.dart';
import 'package:nori_mobile/core/sync/sync_engine.dart';
import 'package:nori_mobile/core/widgets/sync_indicator.dart';

Session _session(List<String> permissions) => Session.fromApi(
      {'token': 't', 'user': {'id': 1, 'name': 'Ana'}, 'permissions': permissions, 'working_context': {}},
      server: const ServerConfig(baseUrl: 'https://demo.nori.mx'),
    );

void main() {
  test('las pestañas siguen a los permisos', () {
    final seller = tabsFor(_session(['route_execution.use', 'sales_orders.create']));
    expect(seller.map((t) => t.path), ['/today', '/sell', '/customers', '/supervisor', '/more']);
    final counter = tabsFor(_session(['invoices.create']));
    expect(counter.map((t) => t.path).first, '/sell');
    final picker = tabsFor(_session(['inventory_counts.update']));
    expect(picker.map((t) => t.path), ['/inventory', '/more']);
  });

  testWidgets('el indicador muestra pendientes y errores', (tester) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: MaterialApp(theme: NrTheme.light(NrColors.defaultAccent), home: const Scaffold(body: SyncIndicator())),
    ));
    expect(find.text('Al día'), findsOneWidget);

    container.read(syncStatusProvider.notifier).update((s) => s.copyWith(pending: 3, online: false));
    await tester.pump();
    expect(find.text('Sin señal · 3'), findsOneWidget);

    container.read(syncStatusProvider.notifier).update((_) => const SyncStatus(failed: 2));
    await tester.pump();
    expect(find.text('2 con error'), findsOneWidget);
  });
}
