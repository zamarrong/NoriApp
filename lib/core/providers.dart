import 'dart:async';
import 'dart:convert';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'api/api_client.dart';
import 'api/api_error.dart';
import 'api/server_config.dart';
import 'auth/session.dart';
import 'db/local_db.dart';
import 'design/nr_tokens.dart';
import 'sync/outbox.dart';
import 'sync/sync_engine.dart';
import 'sync/writer.dart';

/// Se sobreescriben en main() una vez abiertos.
final localDbProvider = Provider<LocalDb>((ref) => throw UnimplementedError('LocalDb no abierta'));
final prefsProvider = Provider<SharedPreferences>((ref) => throw UnimplementedError('Prefs no cargadas'));
final secureStorageProvider = Provider<FlutterSecureStorage>((ref) => const FlutterSecureStorage());

// ───────────────────────── Sesión ─────────────────────────

enum AuthStatus { loading, signedOut, locked, signedIn }

class AuthState {
  const AuthState(this.status, {this.session});
  final AuthStatus status;
  final Session? session;
}

class AuthController extends Notifier<AuthState> {
  static const _tokenKey = 'nori.token';
  static const _sessionKey = 'nori.session';
  static const biometricKey = 'nori.biometric';
  static const lastServerKey = 'nori.last_server';
  static const lastTenantKey = 'nori.last_tenant';
  static const lastUserKey = 'nori.last_user';

  FlutterSecureStorage get _secure => ref.read(secureStorageProvider);
  SharedPreferences get _prefs => ref.read(prefsProvider);

  @override
  AuthState build() {
    Future.microtask(_restore);
    return const AuthState(AuthStatus.loading);
  }

  bool get biometricEnabled => _prefs.getBool(biometricKey) ?? false;

  Future<void> _restore() async {
    try {
      final token = await _secure.read(key: _tokenKey);
      final raw = await _secure.read(key: _sessionKey);
      if (token == null || raw == null) {
        state = const AuthState(AuthStatus.signedOut);
        return;
      }
      final session = Session.fromJson(Map<String, dynamic>.from(jsonDecode(raw) as Map), token);
      state = AuthState(biometricEnabled ? AuthStatus.locked : AuthStatus.signedIn, session: session);
      if (!biometricEnabled) unawaited(refreshMe());
    } catch (_) {
      state = const AuthState(AuthStatus.signedOut);
    }
  }

  Future<String> _deviceName() async {
    try {
      final info = DeviceInfoPlugin();
      if (defaultTargetPlatform == TargetPlatform.android) {
        final a = await info.androidInfo;
        return '${a.manufacturer} ${a.model}';
      }
      if (defaultTargetPlatform == TargetPlatform.iOS) {
        final i = await info.iosInfo;
        return i.name;
      }
    } catch (_) {}
    return 'Nori móvil';
  }

  Future<void> login({required String server, String? tenantCode, required String username, required String password}) async {
    final config = ServerConfig.resolve(server, tenantCode: tenantCode);
    final api = ApiClient(config: config);
    final r = await api.post('/auth/login', body: {
      'username': username.trim(),
      'password': password,
      'device_name': await _deviceName(),
      'tenant': ?config.tenant,
    });
    final session = Session.fromApi(asMap(unwrap(r)), server: config);
    // Otra empresa u otro usuario: lo guardado no les pertenece.
    final prevUser = _prefs.getString(lastUserKey);
    final prevServer = _prefs.getString(lastServerKey);
    if (prevUser != username.trim() || prevServer != server.trim()) await ref.read(localDbProvider).wipe();
    await _prefs.setString(lastServerKey, server.trim());
    await _prefs.setString(lastTenantKey, tenantCode?.trim() ?? '');
    await _prefs.setString(lastUserKey, username.trim());
    await _persist(session);
    state = AuthState(AuthStatus.signedIn, session: session);
  }

  Future<void> _persist(Session s) async {
    await _secure.write(key: _tokenKey, value: s.token);
    await _secure.write(key: _sessionKey, value: jsonEncode(s.toJson()));
  }

  /// Desbloqueo con huella o rostro.
  Future<bool> unlock() async {
    try {
      final ok = await LocalAuthentication().authenticate(
        localizedReason: 'Desbloquea Nori',
        options: const AuthenticationOptions(stickyAuth: true),
      );
      if (ok && state.session != null) {
        state = AuthState(AuthStatus.signedIn, session: state.session);
        unawaited(refreshMe());
      }
      return ok;
    } catch (_) {
      return false;
    }
  }

  Future<void> setBiometric(bool enabled) async {
    if (enabled) {
      final la = LocalAuthentication();
      final can = await la.canCheckBiometrics || await la.isDeviceSupported();
      if (!can) throw ApiException(code: 'device', message: 'Este dispositivo no tiene huella ni rostro configurados.');
    }
    await _prefs.setBool(biometricKey, enabled);
  }

  /// Vuelve a leer permisos y contexto; renueva el token si está por vencer.
  Future<void> refreshMe() async {
    final s = state.session;
    if (s == null) return;
    try {
      // Cliente propio: leer apiProvider desde aquí sería una dependencia circular (api → sesión → auth).
      final api = ApiClient(config: s.server, token: s.token, onUnauthenticated: expired);
      if (s.needsRefresh) {
        final r = await api.post('/auth/refresh');
        final next = Session.fromApi(asMap(unwrap(r)), server: s.server, previous: s);
        await _persist(next);
        state = AuthState(state.status, session: next);
        return;
      }
      final r = await api.get('/me');
      final next = Session.fromApi(asMap(unwrap(r)), server: s.server, token: s.token, previous: s);
      await _persist(next);
      state = AuthState(state.status, session: next);
    } on ApiException catch (_) {
      // Sin señal se sigue con lo guardado.
    }
  }

  Future<void> setWorkingWarehouse(int warehouseId) async {
    final s = state.session!;
    final op = OutboxOp.create('PUT', '/me/working-warehouse', body: {'warehouse_id': warehouseId}, label: 'Almacén de trabajo');
    final r = await ref.read(writerProvider).send(op, offline: false);
    final next = Session.fromApi(asMap(unwrap(r.response)), server: s.server, token: s.token, previous: s);
    await _persist(next);
    state = AuthState(AuthStatus.signedIn, session: next);
  }

  /// Token vencido o revocado (401).
  void expired() {
    if (state.status == AuthStatus.signedIn) unawaited(logout(remote: false));
  }

  Future<void> logout({bool remote = true}) async {
    if (remote) {
      try {
        await ref.read(apiProvider).post('/auth/logout');
      } catch (_) {}
    }
    await _secure.delete(key: _tokenKey);
    await _secure.delete(key: _sessionKey);
    state = const AuthState(AuthStatus.signedOut);
  }
}

final authProvider = NotifierProvider<AuthController, AuthState>(AuthController.new);

final sessionProvider = Provider<Session?>((ref) => ref.watch(authProvider).session);

/// Cliente con el token de la sesión (sin sesión, solo sirve para el login).
final apiProvider = Provider<ApiClient>((ref) {
  final session = ref.watch(sessionProvider);
  return ApiClient(
    config: session?.server ?? const ServerConfig(baseUrl: 'https://nori.mx'),
    token: session?.token,
    onUnauthenticated: () => ref.read(authProvider.notifier).expired(),
  );
});

// ───────────────────────── Sincronización ─────────────────────────

class SyncStatusNotifier extends Notifier<SyncStatus> {
  @override
  SyncStatus build() => const SyncStatus();

  void update(SyncStatus Function(SyncStatus) f) => state = f(state);
}

final syncStatusProvider = NotifierProvider<SyncStatusNotifier, SyncStatus>(SyncStatusNotifier.new);

final outboxProvider = Provider<OutboxRepo>((ref) => OutboxRepo(ref.watch(localDbProvider)));

final syncEngineProvider = Provider<SyncEngine?>((ref) {
  final session = ref.watch(sessionProvider);
  if (session == null) return null;
  return SyncEngine(
    api: ref.watch(apiProvider),
    db: ref.watch(localDbProvider),
    session: session,
    onStatus: (f) => ref.read(syncStatusProvider.notifier).update(f),
  );
});

final writerProvider = Provider<Writer>((ref) => Writer(
      api: ref.watch(apiProvider),
      outbox: ref.watch(outboxProvider),
      onChanged: () => ref.read(syncEngineProvider)?.refreshCounts(),
    ));

/// Sincroniza al entrar, cada 3 minutos y al recuperar la señal.
final autoSyncProvider = Provider<void>((ref) {
  final engine = ref.watch(syncEngineProvider);
  final signedIn = ref.watch(authProvider.select((s) => s.status == AuthStatus.signedIn));
  if (engine == null || !signedIn) return;
  // Después de construir: el motor cambia el estado de sincronización.
  final first = Timer(Duration.zero, () => unawaited(engine.syncNow()));
  final timer = Timer.periodic(const Duration(minutes: 3), (_) => engine.syncNow());
  StreamSubscription<List<ConnectivityResult>>? sub;
  try {
    sub = Connectivity().onConnectivityChanged.listen((r) {
      final online = r.any((c) => c != ConnectivityResult.none);
      ref.read(syncStatusProvider.notifier).update((s) => s.copyWith(online: online));
      if (online) unawaited(engine.syncNow(pull: false));
    });
  } catch (_) {}
  ref.onDispose(() {
    first.cancel();
    timer.cancel();
    sub?.cancel();
  });
});

// ───────────────────────── Apariencia ─────────────────────────

class ThemeModeNotifier extends Notifier<ThemeMode> {
  static const _key = 'nori.theme_mode';

  @override
  ThemeMode build() => ThemeMode.values.byName(ref.read(prefsProvider).getString(_key) ?? ThemeMode.system.name);

  void set(ThemeMode mode) {
    ref.read(prefsProvider).setString(_key, mode.name);
    state = mode;
  }
}

final themeModeProvider = NotifierProvider<ThemeModeNotifier, ThemeMode>(ThemeModeNotifier.new);

/// Acento: el de la empresa (si el servidor lo expone) o el azul de Nori.
final accentProvider = Provider<Color>((ref) {
  final session = ref.watch(sessionProvider);
  return parseHexColor(session?.accentColor) ?? NrColors.defaultAccent;
});
