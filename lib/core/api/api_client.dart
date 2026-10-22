import 'package:dio/dio.dart';

import 'api_error.dart';
import 'server_config.dart';

/// Cliente HTTP de la API v1. Las rutas se escriben relativas a `/api/v1`
/// ("/me", "/route/today"); [v1] da la ruta completa que usa la cola.
class ApiClient {
  ApiClient({required this.config, this.token, this.onUnauthenticated, Dio? dio})
      : _dio = dio ??
            Dio(BaseOptions(
              connectTimeout: const Duration(seconds: 12),
              receiveTimeout: const Duration(seconds: 40),
              sendTimeout: const Duration(seconds: 40),
            )) {
    _dio.options.baseUrl = config.baseUrl;
  }

  final ServerConfig config;
  final String? token;
  final void Function()? onUnauthenticated;
  final Dio _dio;

  static String v1(String path) => path.startsWith('/api/') ? path : '/api/v1${path.startsWith('/') ? '' : '/'}$path';

  Map<String, String> headers({String? idempotencyKey}) => {
        'Accept': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
        if (config.tenant != null) 'X-Tenant': config.tenant!,
        if (idempotencyKey != null) 'Idempotency-Key': idempotencyKey,
      };

  Future<dynamic> get(String path, {Map<String, dynamic>? query}) =>
      request('GET', path, query: query);

  Future<dynamic> post(String path, {Object? body, String? key}) => request('POST', path, body: body, key: key);

  Future<dynamic> put(String path, {Object? body, String? key}) => request('PUT', path, body: body, key: key);

  Future<dynamic> delete(String path, {Object? body, String? key}) => request('DELETE', path, body: body, key: key);

  /// Petición con el sobre de errores de la API traducido a [ApiException].
  Future<dynamic> request(String method, String path, {Object? body, Map<String, dynamic>? query, String? key}) async {
    try {
      final r = await _dio.request<dynamic>(
        v1(path),
        data: body,
        queryParameters: query,
        options: Options(method: method, headers: headers(idempotencyKey: key), contentType: body is FormData ? null : 'application/json'),
      );
      return r.data;
    } on DioException catch (e) {
      final err = ApiException.fromDio(e);
      if (err.isUnauthenticated && token != null) onUnauthenticated?.call();
      throw err;
    }
  }

  /// Recorre todas las páginas de una lista con cursor (`meta.next_cursor`).
  Future<List<Map<String, dynamic>>> getAll(String path, {Map<String, dynamic>? query, int maxPages = 20}) async {
    final out = <Map<String, dynamic>>[];
    String? cursor;
    for (var i = 0; i < maxPages; i++) {
      final r = await get(path, query: {...?query, 'per_page': 200, 'cursor': ?cursor});
      out.addAll(((r['data'] as List?) ?? const []).cast<Map>().map((e) => Map<String, dynamic>.from(e)));
      cursor = (r['meta'] as Map?)?['next_cursor'] as String?;
      if (cursor == null) break;
    }
    return out;
  }
}

/// `{"data": x}` → x (las rutas de venta en ruta no van envueltas).
dynamic unwrap(dynamic body) => body is Map && body.containsKey('data') ? body['data'] : body;

Map<String, dynamic> asMap(Object? v) => v is Map ? Map<String, dynamic>.from(v) : <String, dynamic>{};

List<Map<String, dynamic>> asList(Object? v) =>
    v is List ? v.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList() : <Map<String, dynamic>>[];
