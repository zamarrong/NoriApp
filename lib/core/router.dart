import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/more/settings_page.dart';
import '../features/printing/printer_page.dart';
import '../features/auth/auth_pages.dart';
import '../features/checker/checker_page.dart';
import '../features/customers/customers_page.dart';
import '../features/inventory/count_page.dart';
import '../features/onboarding/onboarding_page.dart';
import '../features/inventory/inventory_page.dart';
import '../features/inventory/movement_page.dart';
import '../features/more/more_page.dart';
import '../features/route/route_today_page.dart';
import '../features/route/visit_page.dart';
import '../features/sales/sell_page.dart';
import '../features/supervisor/approvals.dart';
import '../features/supervisor/kpis_page.dart';
import 'auth/session.dart';
import 'design/design.dart';
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
      if (s.canRoute) const NavTab('/today', 'Hoy', Icons.wb_sunny_outlined, Icons.wb_sunny_rounded),
      if (s.canFreeSell) const NavTab('/sell', 'Vender', Icons.add_shopping_cart_rounded, Icons.add_shopping_cart_rounded),
      if (s.canCustomers) const NavTab('/customers', 'Clientes', Icons.people_outline_rounded, Icons.people_rounded),
      if (s.canInventory) const NavTab('/inventory', 'Inventario', Icons.inventory_2_outlined, Icons.inventory_2_rounded),
      if (s.canKpis) const NavTab('/supervisor', 'Tablero', Icons.insights_rounded, Icons.insights_rounded),
      const NavTab('/more', 'Más', Icons.grid_view_rounded, Icons.grid_view_rounded),
    ];

final routerProvider = Provider<GoRouter>((ref) {
  final refresh = ValueNotifier(0);
  ref.listen(authProvider, (_, _) => refresh.value++);
  ref.listen(onboardingSeenProvider, (_, _) => refresh.value++);
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
          // First launch: the onboarding once (finished or skipped), then sign-in.
          final to = ref.read(onboardingSeenProvider) ? '/login' : '/onboarding';
          return loc == to ? null : to;
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
      GoRoute(path: '/splash', builder: (_, _) => const SplashPage()),
      GoRoute(path: '/onboarding', pageBuilder: (_, s) => _fadePage(s, const OnboardingPage())),
      GoRoute(path: '/login', pageBuilder: (_, s) => _fadePage(s, const LoginPage())),
      GoRoute(path: '/unlock', builder: (_, _) => const UnlockPage()),
      GoRoute(path: '/warehouse', builder: (_, _) => const WarehousePage()),
      ShellRoute(
        builder: (context, state, child) => MainShell(location: state.matchedLocation, child: child),
        routes: [
          GoRoute(path: '/today', pageBuilder: (_, s) => _tabPage(s, const RouteTodayPage())),
          GoRoute(path: '/sell', pageBuilder: (_, s) => _tabPage(s, const SellPage())),
          GoRoute(path: '/customers', pageBuilder: (_, s) => _tabPage(s, const CustomersPage())),
          GoRoute(path: '/inventory', pageBuilder: (_, s) => _tabPage(s, const InventoryPage())),
          GoRoute(path: '/supervisor', pageBuilder: (_, s) => _tabPage(s, const KpisPage())),
          GoRoute(path: '/more', pageBuilder: (_, s) => _tabPage(s, const MorePage())),
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
      GoRoute(path: '/settings', builder: (_, _) => const SettingsPage()),
      GoRoute(path: '/printer', builder: (_, _) => const PrinterPage()),
    ],
  );
});

/// Cambio de pestaña: fundido corto (sin deslizar, las pestañas son hermanas).
Page<void> _tabPage(GoRouterState state, Widget child) => CustomTransitionPage<void>(
      key: state.pageKey,
      child: child,
      transitionDuration: const Duration(milliseconds: 220),
      reverseTransitionDuration: const Duration(milliseconds: 120),
      transitionsBuilder: (context, a, _, child) => FadeTransition(
        opacity: CurvedAnimation(parent: a, curve: Curves.easeOut),
        child: ScaleTransition(scale: Tween(begin: 0.985, end: 1.0).animate(CurvedAnimation(parent: a, curve: NrMotion.ease)), child: child),
      ),
    );

/// Splash → onboarding → sign-in: a plain cross-fade.
Page<void> _fadePage(GoRouterState state, Widget child) => CustomTransitionPage<void>(
      key: state.pageKey,
      child: child,
      transitionDuration: const Duration(milliseconds: 320),
      transitionsBuilder: (context, a, _, child) => FadeTransition(opacity: CurvedAnimation(parent: a, curve: Curves.easeOut), child: child),
    );

/// Arranque: el logo sobre el lienzo mientras se lee la sesión.
class SplashPage extends StatelessWidget {
  const SplashPage({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(backgroundColor: authBackground(context.nr), body: Center(child: NrPulseDot(color: context.nr.accent, size: 12)));
}

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
      extendBody: false,
      bottomNavigationBar: NrNavBar(
        tabs: tabs,
        index: index < 0 ? 0 : index,
        badges: {'/supervisor': pending},
        onSelect: (i) => context.go(tabs[i].path),
      ),
    );
  }
}

/// Barra de pestañas: translúcida, con una píldora que sigue a la pestaña
/// activa. "Vender" va resaltada en el acento: es la acción principal del día
/// y queda bajo el pulgar.
class NrNavBar extends StatelessWidget {
  const NrNavBar({super.key, required this.tabs, required this.index, required this.onSelect, this.badges = const {}});

  final List<NavTab> tabs;
  final int index;
  final ValueChanged<int> onSelect;
  final Map<String, int> badges;

  @override
  Widget build(BuildContext context) {
    final nr = context.nr;
    return NrBottomBar(
      child: SizedBox(
        height: 56,
        child: Row(children: [
          for (var i = 0; i < tabs.length; i++)
            Expanded(child: _NavItem(tab: tabs[i], selected: i == index, badge: badges[tabs[i].path] ?? 0, onTap: () {
              if (i != index) NrHaptics.tap();
              onSelect(i);
            }, nr: nr)),
        ]),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({required this.tab, required this.selected, required this.badge, required this.onTap, required this.nr});

  final NavTab tab;
  final bool selected;
  final int badge;
  final VoidCallback onTap;
  final NrColors nr;

  @override
  Widget build(BuildContext context) {
    final primary = tab.path == '/sell';
    final reduce = nrReduceMotion(context);
    final d = reduce ? Duration.zero : NrMotion.base;
    final fg = primary ? nr.onAccent : (selected ? (nr.night ? nr.headline : nr.accent) : nr.muted);
    Widget icon = Icon(selected ? tab.selectedIcon : tab.icon, color: fg, size: 24);
    if (badge > 0) {
      icon = Badge(
        label: Text('$badge'),
        offset: const Offset(8, -6),
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0.6, end: 1),
          duration: reduce ? Duration.zero : const Duration(milliseconds: 500),
          curve: Curves.elasticOut,
          builder: (context, s, child) => Transform.scale(scale: s, child: child),
          child: icon,
        ),
      );
    }
    return Semantics(
      selected: selected,
      button: true,
      label: tab.label,
      child: InkResponse(
        onTap: onTap,
        radius: 36,
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          AnimatedContainer(
            duration: d,
            curve: NrMotion.emphasized,
            width: primary ? 56 : (selected ? 52 : 40),
            height: primary ? 34 : 30,
            decoration: BoxDecoration(
              color: primary ? nr.accent : (selected ? nr.accentSoft : Colors.transparent),
              borderRadius: BorderRadius.circular(NrRadius.pill),
              boxShadow: primary && !nr.highContrast ? [BoxShadow(color: nr.accent.withValues(alpha: 0.4), blurRadius: 14, offset: const Offset(0, 5), spreadRadius: -4)] : null,
            ),
            child: Center(child: icon),
          ),
          const SizedBox(height: 3),
          AnimatedDefaultTextStyle(
            duration: d,
            style: NrText.caption(context).copyWith(
              fontSize: 11,
              fontWeight: selected || primary ? FontWeight.w700 : FontWeight.w500,
              color: selected || primary ? nr.headline : nr.muted,
            ),
            child: Text(tab.label, maxLines: 1, overflow: TextOverflow.fade, softWrap: false),
          ),
        ]),
      ),
    );
  }
}
