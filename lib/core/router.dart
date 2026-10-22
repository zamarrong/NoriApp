import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/auth/auth_pages.dart';
import '../features/checker/checker_page.dart';
import '../features/customers/customers_page.dart';
import '../features/inventory/count_page.dart';
import '../features/inventory/inventory_page.dart';
import '../features/inventory/movement_page.dart';
import '../features/more/more_page.dart';
import '../features/route/route_today_page.dart';
import '../features/route/visit_page.dart';
import '../features/sales/sell_page.dart';
import '../features/supervisor/approvals.dart';
import '../features/supervisor/kpis_page.dart';
import 'auth/session.dart';
import 'providers.dart';

class NavTab {
  const NavTab(this.path, this.label, this.icon, this.selectedIcon);
  final String path;
  final String label;
  final IconData icon;
  final IconData selectedIcon;
}

/// Pestañas según permisos: lo que no se puede, no se ve (el servidor igual verifica).
List<NavTab> tabsFor(Session s) => [
      if (s.canRoute) const NavTab('/today', 'Hoy', Icons.route_outlined, Icons.route),
      if (s.canFreeSell) const NavTab('/sell', 'Vender', Icons.point_of_sale_outlined, Icons.point_of_sale),
      if (s.canCustomers) const NavTab('/customers', 'Clientes', Icons.people_outline, Icons.people),
      if (s.canInventory) const NavTab('/inventory', 'Inventario', Icons.inventory_2_outlined, Icons.inventory_2),
      if (s.canKpis) const NavTab('/supervisor', 'Indicadores', Icons.insights_outlined, Icons.insights),
      const NavTab('/more', 'Más', Icons.menu, Icons.menu),
    ];

final routerProvider = Provider<GoRouter>((ref) {
  final refresh = ValueNotifier(0);
  ref.listen(authProvider, (_, _) => refresh.value++);
  ref.onDispose(refresh.dispose);

  return GoRouter(
    initialLocation: '/splash',
    refreshListenable: refresh,
    redirect: (context, state) {
      final auth = ref.read(authProvider);
      final loc = state.matchedLocation;
      switch (auth.status) {
        case AuthStatus.loading:
          return loc == '/splash' ? null : '/splash';
        case AuthStatus.signedOut:
          return loc == '/login' ? null : '/login';
        case AuthStatus.locked:
          return loc == '/unlock' ? null : '/unlock';
        case AuthStatus.signedIn:
          final s = auth.session!;
          if (s.mustChooseWarehouse && s.warehouseId == null && loc != '/warehouse') return '/warehouse';
          if (loc == '/splash' || loc == '/login' || loc == '/unlock' || loc == '/') return tabsFor(s).first.path;
          return null;
      }
    },
    routes: [
      GoRoute(path: '/', builder: (_, _) => const SizedBox.shrink()),
      GoRoute(path: '/splash', builder: (_, _) => const Scaffold(body: Center(child: CircularProgressIndicator()))),
      GoRoute(path: '/login', builder: (_, _) => const LoginPage()),
      GoRoute(path: '/unlock', builder: (_, _) => const UnlockPage()),
      GoRoute(path: '/warehouse', builder: (_, _) => const WarehousePage()),
      ShellRoute(
        builder: (context, state, child) => MainShell(location: state.matchedLocation, child: child),
        routes: [
          GoRoute(path: '/today', pageBuilder: (_, _) => const NoTransitionPage(child: RouteTodayPage())),
          GoRoute(path: '/sell', pageBuilder: (_, _) => const NoTransitionPage(child: SellPage())),
          GoRoute(path: '/customers', pageBuilder: (_, _) => const NoTransitionPage(child: CustomersPage())),
          GoRoute(path: '/inventory', pageBuilder: (_, _) => const NoTransitionPage(child: InventoryPage())),
          GoRoute(path: '/supervisor', pageBuilder: (_, _) => const NoTransitionPage(child: KpisPage())),
          GoRoute(path: '/more', pageBuilder: (_, _) => const NoTransitionPage(child: MorePage())),
        ],
      ),
      GoRoute(path: '/route/visit/:id', builder: (_, s) => VisitPage(visitId: int.parse(s.pathParameters['id']!))),
      GoRoute(path: '/customers/:id', builder: (_, s) => CustomerPage(customerId: int.parse(s.pathParameters['id']!))),
      GoRoute(path: '/inventory/movement/:kind', builder: (_, s) => MovementPage(movement: s.pathParameters['kind']!)),
      GoRoute(path: '/inventory/requests', builder: (_, _) => const TransferRequestsPage()),
      GoRoute(path: '/inventory/counts', builder: (_, _) => const CountsPage()),
      GoRoute(path: '/authorizations', builder: (_, _) => const AuthorizationsPage()),
      GoRoute(path: '/authorizations/mine', builder: (_, _) => const MyAuthorizationsPage()),
      GoRoute(path: '/sync', builder: (_, _) => const SyncPage()),
      GoRoute(path: '/documents', builder: (_, _) => const MyDocumentsPage()),
      GoRoute(path: '/checker', builder: (_, _) => const CheckerPage()),
    ],
  );
});

class MainShell extends ConsumerWidget {
  const MainShell({super.key, required this.location, required this.child});

  final String location;
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(autoSyncProvider);
    final session = ref.watch(sessionProvider);
    final pending = ref.watch(pendingApprovalsProvider).length;
    if (session == null) return child;
    final tabs = tabsFor(session);
    final index = tabs.indexWhere((t) => location.startsWith(t.path));
    return Scaffold(
      body: child,
      bottomNavigationBar: NavigationBar(
        selectedIndex: index < 0 ? 0 : index,
        onDestinationSelected: (i) => context.go(tabs[i].path),
        destinations: [
          for (final t in tabs)
            NavigationDestination(
              icon: t.path == '/supervisor' && pending > 0 ? Badge.count(count: pending, child: Icon(t.icon)) : Icon(t.icon),
              selectedIcon: Icon(t.selectedIcon),
              label: t.label,
            ),
        ],
      ),
    );
  }
}
