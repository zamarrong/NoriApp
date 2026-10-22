import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_client.dart';
import '../../core/api/api_error.dart';
import '../../core/db/local_db.dart';
import '../../core/providers.dart';

/// Respuesta con marca de si viene de lo guardado (sin señal).
class Cached<T> {
  const Cached(this.value, {this.offline = false});
  final T value;
  final bool offline;
}

/// Venta en ruta (ADR 0012): el día y las visitas se guardan para verlos sin
/// señal; los cambios hechos sin señal se reflejan aquí mientras la cola espera.
class RouteRepo {
  RouteRepo(this.api, this.db);

  final ApiClient api;
  final LocalDb db;

  static const todayKey = 'route_today';

  Future<Cached<Map<String, dynamic>>> today() async {
    try {
      final r = asMap(await api.get('/route/today'));
      await db.putJson(todayKey, r);
      return Cached(r);
    } on ApiException catch (e) {
      if (!e.isTransient) rethrow;
      final cached = await db.getJson(todayKey);
      if (cached == null) rethrow;
      return Cached(asMap(cached), offline: true);
    }
  }

  Future<Cached<Map<String, dynamic>>> visit(int id) async {
    try {
      final r = asMap(asMap(await api.get('/route/visits/$id'))['visit']);
      await db.putJson('visit_$id', r);
      return Cached(r);
    } on ApiException catch (e) {
      if (!e.isTransient) rethrow;
      final cached = await db.getJson('visit_$id');
      if (cached != null) return Cached(asMap(cached), offline: true);
      // Sin la visita guardada, la parada del día alcanza para operar.
      final stop = await _stop(id);
      if (stop == null) rethrow;
      return Cached(stop, offline: true);
    }
  }

  Future<Map<String, dynamic>?> _stop(int id) async {
    final today = asMap(await db.getJson(todayKey));
    for (final p in asList(today['plans'])) {
      for (final s in asList(p['stops'])) {
        if (s['id'] == id) return {...s, 'plan_id': p['id'], 'owed': [], 'orders': [], 'assets': [], 'done': []};
      }
    }
    return null;
  }

  /// Guarda lo que respondió el servidor (o lo que se supone sin señal).
  Future<void> saveVisit(Map<String, dynamic> visit) async {
    final id = visit['id'];
    if (id == null) return;
    await db.putJson('visit_$id', visit);
    await patchStop((id as num).toInt(), visit);
  }

  /// Cambio local de una parada en el día guardado.
  Future<void> patchStop(int visitId, Map<String, dynamic> changes) async {
    const keys = ['status', 'status_label', 'check_in_at', 'check_out_at', 'outcome', 'sale_total', 'collected_total'];
    final today = asMap(await db.getJson(todayKey));
    var touched = false;
    final plans = asList(today['plans']);
    for (final p in plans) {
      final stops = asList(p['stops']);
      for (var i = 0; i < stops.length; i++) {
        if (stops[i]['id'] == visitId) {
          stops[i] = {...stops[i], for (final k in keys) if (changes.containsKey(k)) k: changes[k]};
          touched = true;
        }
      }
      p['stops'] = stops;
    }
    if (touched) {
      today['plans'] = plans;
      await db.putJson(todayKey, today);
    }
  }
}

final routeRepoProvider = Provider<RouteRepo>((ref) => RouteRepo(ref.watch(apiProvider), ref.watch(localDbProvider)));

final routeTodayProvider = FutureProvider.autoDispose<Cached<Map<String, dynamic>>>((ref) => ref.watch(routeRepoProvider).today());

final visitProvider = FutureProvider.autoDispose.family<Cached<Map<String, dynamic>>, int>((ref, id) => ref.watch(routeRepoProvider).visit(id));
