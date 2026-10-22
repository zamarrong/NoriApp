import 'package:dio/dio.dart';

/// Lo que el servidor pide cuando una escritura necesita un supervisor
/// (`error.authorization`). El token es firmado: la app no lo toca.
class AuthorizationChallenge {
  const AuthorizationChallenge({required this.concept, required this.label, required this.reference, required this.token});

  final String concept;
  final String label;
  final String reference;
  final String token;

  factory AuthorizationChallenge.fromJson(Map<String, dynamic> j) => AuthorizationChallenge(
        concept: '${j['concept'] ?? ''}',
        label: '${j['label'] ?? 'Requiere autorización'}',
        reference: '${j['reference'] ?? ''}',
        token: '${j['token'] ?? ''}',
      );

  Map<String, dynamic> toJson() => {'concept': concept, 'label': label, 'reference': reference, 'token': token};
}

/// Error de la API v1 con su sobre (`{message, error: {code, ...}}`) o de red.
class ApiException implements Exception {
  ApiException({
    required this.code,
    required this.message,
    this.status,
    this.field,
    this.fields = const {},
    this.authorization,
    this.requestId,
  });

  /// `network` cuando no hubo respuesta (sin señal, tiempo agotado).
  final String code;
  final String message;
  final int? status;
  final String? field;
  final Map<String, List<String>> fields;
  final AuthorizationChallenge? authorization;
  final String? requestId;

  bool get isNetwork => code == 'network';
  bool get isAuthorizationRequired => code == 'authorization_required' && authorization != null;
  bool get isUnauthenticated => status == 401;

  /// Reintentable con la misma llave: red, 5xx o límite de peticiones.
  bool get isTransient => isNetwork || (status != null && (status! >= 500 || status == 429));

  /// Construye el error a partir del cuerpo de una respuesta (también sirve para
  /// las operaciones fallidas de `/sync/push`).
  factory ApiException.fromBody(int? status, Object? body) {
    if (body is Map) {
      final err = body['error'];
      if (err is Map) {
        final fields = <String, List<String>>{};
        final f = err['fields'];
        if (f is Map) {
          f.forEach((k, v) => fields['$k'] = v is List ? v.map((e) => '$e').toList() : ['$v']);
        }
        final auth = err['authorization'];
        return ApiException(
          code: '${err['code'] ?? 'server_error'}',
          message: '${err['message'] ?? body['message'] ?? 'Error del servidor'}',
          status: status,
          field: err['field']?.toString(),
          fields: fields,
          authorization: auth is Map ? AuthorizationChallenge.fromJson(Map<String, dynamic>.from(auth)) : null,
          requestId: err['request_id']?.toString(),
        );
      }
      // Cola de ruta (ADR 0012) y respuestas sin sobre.
      final msg = body['message'] ?? body['mensaje'];
      if (msg != null) return ApiException(code: _codeFor(status), message: '$msg', status: status);
    }
    return ApiException(code: _codeFor(status), message: _defaultMessage(status), status: status);
  }

  factory ApiException.fromDio(DioException e) {
    final r = e.response;
    if (r == null) {
      return ApiException(code: 'network', message: 'Sin conexión con el servidor.');
    }
    return ApiException.fromBody(r.statusCode, r.data);
  }

  static String _codeFor(int? status) => switch (status) {
        401 => 'unauthenticated',
        403 => 'forbidden',
        404 => 'not_found',
        422 => 'validation',
        429 => 'rate_limited',
        _ => 'server_error',
      };

  static String _defaultMessage(int? status) => switch (status) {
        401 => 'Tu sesión terminó. Vuelve a iniciar sesión.',
        403 => 'No tienes permiso para esto.',
        404 => 'No se encontró.',
        429 => 'Demasiadas peticiones; espera un momento.',
        _ => 'Error del servidor.',
      };

  /// Mensaje para el usuario; los errores inesperados llevan el folio de soporte.
  String get userMessage {
    final first = fields.values.expand((e) => e).firstOrNull;
    final base = code == 'validation' && first != null ? first : message;
    return (code == 'server_error' && requestId != null) ? '$base (folio $requestId)' : base;
  }

  @override
  String toString() => userMessage;
}
