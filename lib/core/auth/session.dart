import '../api/api_client.dart';
import '../api/server_config.dart';

/// Sesión del dispositivo: lo que responden `/auth/login` y `/me`.
class Session {
  Session({
    required this.server,
    required this.token,
    required this.expiresAt,
    required this.user,
    required this.permissions,
    required this.context,
    required this.tenant,
  });

  final ServerConfig server;
  final String token;
  final DateTime? expiresAt;
  final Map<String, dynamic> user;
  final Set<String> permissions;
  final Map<String, dynamic> context;
  final Map<String, dynamic> tenant;

  int get userId => (user['id'] as num?)?.toInt() ?? 0;
  String get userName => '${user['name'] ?? user['username'] ?? ''}';
  String get username => '${user['username'] ?? ''}';
  bool get isAdmin => user['is_admin'] == true;
  String get tenantName => '${tenant['name'] ?? server.label}';

  /// Color de acento de la empresa si el servidor lo manda (ajustes de
  /// apariencia): llega en `company.accent_color` de la sesión.
  String? get accentColor =>
      (asMap(tenant['company'])['accent_color'] ?? tenant['accent_color']) as String?;

  int? get warehouseId => (context['warehouse_id'] as num?)?.toInt();
  bool get mustChooseWarehouse => context['must_choose_warehouse'] == true;
  List<Map<String, dynamic>> get warehouses => asList(context['warehouses']);
  List<int> get allowedWarehouseIds => ((context['allowed_warehouse_ids'] as List?) ?? const []).map((e) => (e as num).toInt()).toList();
  List<int> get allowedPriceListIds => ((context['allowed_price_list_ids'] as List?) ?? const []).map((e) => (e as num).toInt()).toList();
  Map<String, dynamic>? get salesEmployee => context['sales_employee'] is Map ? asMap(context['sales_employee']) : null;
  List<Map<String, dynamic>> get tenderTypes => asList(context['tender_types']);

  String? get warehouseName {
    final w = warehouses.where((w) => w['id'] == warehouseId).firstOrNull;
    return w == null ? null : '${w['name'] ?? w['code']}';
  }

  /// Los administradores pasan todo; el servidor siempre vuelve a verificar.
  bool can(String permission) => isAdmin || permissions.contains(permission);
  bool canAny(Iterable<String> list) => list.any(can);

  // Módulos de la app según permisos (Spatie, iguales que en la web).
  bool get canRoute => can('route_execution.use');
  bool get canCustomers => canAny(['business_partners.view', 'sales_orders.create', 'quotations.create', 'incoming_payments.create']);
  bool get canSell => canAny(['sales_orders.create', 'quotations.create']);
  bool get canCollect => can('incoming_payments.create');
  bool get canInventory => canAny([
        'transfer_requests.create', 'transfer_requests.view', 'inventory_transfers.create',
        'goods_receipts.create', 'goods_issues.create', 'inventory_counts.update',
      ]);
  bool get isApprover => can('approvals.grant');
  bool get canKpis => isApprover || canSell || canRoute;

  bool get needsRefresh => expiresAt != null && expiresAt!.difference(DateTime.now()).inDays < 5;

  factory Session.fromApi(Map<String, dynamic> data, {required ServerConfig server, String? token, Session? previous}) {
    final exp = data['expires_at'] as String?;
    return Session(
      server: server,
      token: (data['token'] as String?) ?? token ?? previous?.token ?? '',
      expiresAt: exp != null ? DateTime.tryParse(exp) : previous?.expiresAt,
      user: asMap(data['user']),
      permissions: ((data['permissions'] as List?) ?? const []).map((e) => '$e').toSet(),
      context: asMap(data['working_context']),
      // The company's brand (session `company`) travels with the tenant data
      tenant: {
        ...(data['tenant'] is Map ? asMap(data['tenant']) : (previous?.tenant ?? {})),
        if (data['company'] is Map) 'company': asMap(data['company']),
      },
    );
  }

  /// Sin el token: ese va solo al almacén seguro.
  Map<String, dynamic> toJson() => {
        'server': server.toJson(),
        'expires_at': expiresAt?.toIso8601String(),
        'user': user,
        'permissions': permissions.toList(),
        'working_context': context,
        'tenant': tenant,
      };

  factory Session.fromJson(Map<String, dynamic> j, String token) => Session.fromApi(
        {...j, 'token': token},
        server: ServerConfig.fromJson(asMap(j['server'])),
      );
}
