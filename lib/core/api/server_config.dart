/// A qué servidor y empresa habla la app.
///
/// - Código simple ("miempresa") → `https://miempresa.nori.software` (dominio de la empresa).
/// - URL o dominio ("https://api.nori.software", "192.168.1.5:8000") → esa base; si
///   además se da un código de empresa, va en `X-Tenant` (dominio central).
class ServerConfig {
  const ServerConfig({required this.baseUrl, this.tenant});

  static const defaultRootDomain = 'nori.software';

  /// Raíz del servidor, sin `/api/v1` ni diagonal final.
  final String baseUrl;

  /// Código de empresa para `X-Tenant` (solo en dominio central).
  final String? tenant;

  factory ServerConfig.resolve(String server, {String? tenantCode}) {
    var s = server.trim();
    final code = (tenantCode ?? '').trim().toLowerCase();
    if (s.isEmpty) throw const FormatException('Escribe el código de tu empresa o la dirección del servidor.');
    final looksLikeCode = RegExp(r'^[a-zA-Z0-9-]+$').hasMatch(s);
    if (looksLikeCode && s != 'localhost') {
      return ServerConfig(baseUrl: 'https://${s.toLowerCase()}.$defaultRootDomain', tenant: code.isEmpty ? null : code);
    }
    if (!s.startsWith('http://') && !s.startsWith('https://')) {
      final isLocal = s.startsWith('localhost') || RegExp(r'^\d+\.\d+\.\d+\.\d+').hasMatch(s);
      s = '${isLocal ? 'http' : 'https'}://$s';
    }
    s = s.replaceFirst(RegExp(r'/+$'), '');
    s = s.replaceFirst(RegExp(r'/api(/v1)?$'), '');
    final uri = Uri.tryParse(s);
    if (uri == null || uri.host.isEmpty) throw const FormatException('La dirección del servidor no es válida.');
    // Local development as typed in the browser ("http://empresa.localhost:8000"): phones and
    // simulators don't always resolve *.localhost, so it goes to 127.0.0.1 with the company code
    final local = RegExp(r'^([a-z0-9-]+)\.localhost$').firstMatch(uri.host.toLowerCase());
    if (local != null) {
      return ServerConfig(baseUrl: uri.replace(host: '127.0.0.1').toString(), tenant: code.isEmpty ? local.group(1) : code);
    }
    return ServerConfig(baseUrl: s, tenant: code.isEmpty ? null : code);
  }

  Map<String, dynamic> toJson() => {'base_url': baseUrl, 'tenant': tenant};

  factory ServerConfig.fromJson(Map<String, dynamic> j) => ServerConfig(baseUrl: '${j['base_url']}', tenant: j['tenant'] as String?);

  /// Texto corto para la pantalla de inicio ("miempresa.nori.software").
  String get label => tenant == null ? Uri.parse(baseUrl).host : '${Uri.parse(baseUrl).host} · $tenant';
}
