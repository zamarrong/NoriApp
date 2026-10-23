import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/api/api_client.dart';
import '../../core/api/api_error.dart';
import '../../core/db/local_db.dart';
import '../../core/providers.dart';
import '../../core/sync/outbox.dart';
import '../../core/util/decimal.dart';
import '../route/route_repo.dart' show Cached;

/// CRM (API v1 `/crm`): embudos, oportunidades, agenda y detalle, guardados
/// para trabajar sin señal.
///
/// - Las oportunidades se bajan completas la primera vez y después solo lo que
///   cambió (`updated_since` = `meta.server_time` de la vez anterior, con
///   `meta.deleted`).
/// - Lo que se hace sin señal entra a la cola (como el resto de la app) y se
///   refleja aquí al momento: la oportunidad cambia de etapa, una nueva aparece
///   como "por enviar" y la actividad sale en la línea de tiempo.
class CrmRepo {
  CrmRepo(this.api, this.db, this.outbox);

  final ApiClient api;
  final LocalDb db;
  final OutboxRepo outbox;

  static const dealsKey = 'crm_deals';
  static const sinceKey = 'crm_deals_since';
  static const pipelinesKey = 'crm_pipelines';
  static const agendaKey = 'crm_agenda';
  static const reasonsKey = 'crm_loss_reasons';
  static String detailKey(int id) => 'crm_deal_$id';

  /// Lista guardada o la respuesta del servidor (y se guarda).
  Future<Cached<List<Map<String, dynamic>>>> _list(String path, String key) async {
    try {
      final rows = asList(unwrap(await api.get(path)));
      await db.putJson(key, rows);
      return Cached(rows);
    } on ApiException catch (e) {
      if (!e.isTransient) rethrow;
      final cached = await db.getJson(key);
      if (cached == null) rethrow;
      return Cached(asList(cached), offline: true);
    }
  }

  Future<Cached<List<Map<String, dynamic>>>> pipelines() => _list('/crm/pipelines', pipelinesKey);

  Future<Cached<List<Map<String, dynamic>>>> lossReasons() => _list('/crm/loss-reasons', reasonsKey);

  Future<Map<String, Map<String, dynamic>>> _cachedDeals() async {
    final raw = await db.getJson(dealsKey);
    return raw is Map ? {for (final e in raw.entries) '${e.key}': asMap(e.value)} : {};
  }

  Future<void> _saveDeals(Map<String, Map<String, dynamic>> deals) => db.putJson(dealsKey, deals);

  /// Todas las oportunidades que el usuario puede ver: delta desde la última vez.
  Future<Cached<List<Map<String, dynamic>>>> deals() async {
    final deals = await _cachedDeals();
    var offline = false;
    try {
      final since = await db.getJson(sinceKey) as String?;
      String? cursor;
      String? serverTime;
      for (var page = 0; page < 50; page++) {
        final r = asMap(await api.get('/crm/deals', query: {'per_page': 200, 'updated_since': ?since, 'cursor': ?cursor}));
        for (final d in asList(r['data'])) {
          deals['${d['id']}'] = d;
        }
        final meta = asMap(r['meta']);
        for (final id in (meta['deleted'] as List? ?? const [])) {
          deals.remove('$id');
        }
        serverTime ??= meta['server_time'] as String?;
        cursor = meta['next_cursor'] as String?;
        if (cursor == null) break;
      }
      // Las creadas sin señal que ya se enviaron llegan con su id real: la copia local sobra.
      final pendingKeys = (await outbox.list()).map((o) => o.key).toSet();
      deals.removeWhere((_, d) => d['local'] == true && !pendingKeys.contains(d['outbox_key']));
      await _saveDeals(deals);
      if (serverTime != null) await db.putJson(sinceKey, serverTime);
    } on ApiException catch (e) {
      if (!e.isTransient) rethrow;
      if (deals.isEmpty && await db.getJson(sinceKey) == null) rethrow;
      offline = true;
    }
    final list = deals.values.toList()..sort(compareDeals);
    return Cached(list, offline: offline);
  }

  /// Detalle con etapas, documentos y línea de tiempo.
  Future<Cached<Map<String, dynamic>>> deal(int id) async {
    if (id < 0) {
      final local = (await _cachedDeals())['$id'];
      if (local == null) throw ApiException(code: 'not_found', message: 'La oportunidad ya se envió; actualiza la lista.');
      return Cached(local, offline: true);
    }
    try {
      final d = asMap(unwrap(await api.get('/crm/deals/$id')));
      await applyDetail(d);
      return Cached(d);
    } on ApiException catch (e) {
      if (!e.isTransient) rethrow;
      final cached = await db.getJson(detailKey(id)) ?? (await _cachedDeals())['$id'];
      if (cached == null) rethrow;
      return Cached(asMap(cached), offline: true);
    }
  }

  Future<Cached<Map<String, dynamic>>> agenda() async {
    try {
      final r = asMap(await api.get('/crm/agenda', query: {'days': 14}));
      await db.putJson(agendaKey, r);
      return Cached(r);
    } on ApiException catch (e) {
      if (!e.isTransient) rethrow;
      final cached = await db.getJson(agendaKey);
      if (cached == null) rethrow;
      return Cached(asMap(cached), offline: true);
    }
  }

  /// Lo que respondió el servidor a una escritura (o a GET): detalle y lista al día.
  Future<void> applyDetail(Map<String, dynamic> detail) async {
    final id = detail['id'];
    if (id == null) return;
    await db.putJson(detailKey((id as num).toInt()), detail);
    final deals = await _cachedDeals();
    final slim = Map<String, dynamic>.from(detail)
      ..remove('timeline')
      ..remove('documents')
      ..remove('pipeline');
    deals['$id'] = {...?deals['$id'], ...slim};
    await _saveDeals(deals);
  }

  /// Cambio supuesto mientras la cola espera (sin señal).
  Future<void> patchLocal(int id, Map<String, dynamic> changes, {Map<String, dynamic>? activity}) async {
    final deals = await _cachedDeals();
    if (deals['$id'] != null) deals['$id'] = {...deals['$id']!, ...changes};
    await _saveDeals(deals);
    final detail = await db.getJson(detailKey(id));
    if (detail is Map) {
      final d = {...asMap(detail), ...changes};
      if (activity != null) {
        final timeline = asMap(d['timeline']);
        final bucket = activity['pending'] == true ? 'pending' : 'history';
        timeline[bucket] = [if (bucket == 'history') activity, ...asList(timeline[bucket]), if (bucket == 'pending') activity];
        d['timeline'] = timeline;
      }
      await db.putJson(detailKey(id), d);
    }
  }

  /// Una oportunidad creada sin señal: se ve en el tablero hasta que se envía.
  Future<void> addLocalDeal(OutboxOp op, Map<String, dynamic> preview) async {
    final deals = await _cachedDeals();
    final id = -DateTime.now().millisecondsSinceEpoch;
    deals['$id'] = {...preview, 'id': id, 'local': true, 'outbox_key': op.key};
    await _saveDeals(deals);
  }
}

/// Abiertas primero, luego por actualización más reciente.
int compareDeals(Map<String, dynamic> a, Map<String, dynamic> b) {
  final sa = a['status'] == 'open' ? 0 : 1;
  final sb = b['status'] == 'open' ? 0 : 1;
  if (sa != sb) return sa - sb;
  return '${b['updated_at'] ?? ''}'.compareTo('${a['updated_at'] ?? ''}');
}

final crmRepoProvider = Provider<CrmRepo>((ref) => CrmRepo(ref.watch(apiProvider), ref.watch(localDbProvider), ref.watch(outboxProvider)));

final crmPipelinesProvider = FutureProvider.autoDispose<Cached<List<Map<String, dynamic>>>>((ref) => ref.watch(crmRepoProvider).pipelines());

final crmDealsProvider = FutureProvider.autoDispose<Cached<List<Map<String, dynamic>>>>((ref) => ref.watch(crmRepoProvider).deals());

final crmDealProvider = FutureProvider.autoDispose.family<Cached<Map<String, dynamic>>, int>((ref, id) => ref.watch(crmRepoProvider).deal(id));

final crmAgendaProvider = FutureProvider.autoDispose<Cached<Map<String, dynamic>>>((ref) => ref.watch(crmRepoProvider).agenda());

final crmLossReasonsProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async => (await ref.watch(crmRepoProvider).lossReasons()).value);

/// Después de una escritura: lista, agenda y (si aplica) el detalle.
void refreshCrm(WidgetRef ref, {int? dealId}) {
  ref.invalidate(crmDealsProvider);
  ref.invalidate(crmAgendaProvider);
  if (dealId != null) ref.invalidate(crmDealProvider(dealId));
}

// ───────────────────────── Vista ─────────────────────────

enum CrmView { board, list }

enum CrmStatus { open, won, lost }

class CrmFilter {
  const CrmFilter({this.mineOnly = false, this.overdue = false, this.idle = false, this.search = '', this.status = CrmStatus.open});

  final bool mineOnly;
  final bool overdue;
  final bool idle;
  final String search;

  /// Solo la lista: el tablero enseña abiertas y, en ganadas/perdidas, lo del mes.
  final CrmStatus status;

  bool get any => mineOnly || overdue || idle || search.isNotEmpty;

  CrmFilter copyWith({bool? mineOnly, bool? overdue, bool? idle, String? search, CrmStatus? status}) => CrmFilter(
        mineOnly: mineOnly ?? this.mineOnly,
        overdue: overdue ?? this.overdue,
        idle: idle ?? this.idle,
        search: search ?? this.search,
        status: status ?? this.status,
      );
}

final crmFilterProvider = StateProvider<CrmFilter>((ref) => const CrmFilter());

class CrmViewNotifier extends Notifier<CrmView> {
  static const _key = 'nori.crm_view';

  SharedPreferences get _prefs => ref.read(prefsProvider);

  @override
  CrmView build() {
    try {
      return CrmView.values.byName(_prefs.getString(_key) ?? CrmView.board.name);
    } catch (_) {
      return CrmView.board;
    }
  }

  void set(CrmView v) {
    _prefs.setString(_key, v.name);
    state = v;
  }
}

final crmViewProvider = NotifierProvider<CrmViewNotifier, CrmView>(CrmViewNotifier.new);

/// El embudo elegido (null = el predeterminado).
final crmPipelineIdProvider = StateProvider<int?>((ref) => null);

bool matchesFilter(Map<String, dynamic> d, CrmFilter f, int userId) {
  if (f.mineOnly && asMap(d['owner'])['id'] != userId) return false;
  if (f.overdue && ((d['overdue_count'] as num?) ?? 0) == 0) return false;
  if (f.idle && d['idle'] != true) return false;
  if (f.search.isNotEmpty) {
    final p = asMap(d['partner']);
    final hay = [d['title'], p['name'], p['trade_name'], p['code']].where((e) => e != null).join(' ').toLowerCase();
    if (!f.search.toLowerCase().split(RegExp(r'\s+')).where((w) => w.isNotEmpty).every(hay.contains)) return false;
  }
  return true;
}

/// Cerrada este mes (las columnas de ganada y perdida enseñan solo eso, como la web).
bool closedThisMonth(Map<String, dynamic> d, [DateTime? now]) {
  final at = DateTime.tryParse('${d['closed_at'] ?? ''}')?.toLocal();
  final n = now ?? DateTime.now();
  return at != null && at.year == n.year && at.month == n.month;
}

class StageTotals {
  const StageTotals(this.count, this.amount, this.weighted);
  final int count;
  final Dec amount;
  final Dec weighted;
}

StageTotals stageTotals(Iterable<Map<String, dynamic>> deals) {
  var amount = Dec.zero;
  var weighted = Dec.zero;
  var n = 0;
  for (final d in deals) {
    n++;
    amount = amount + Dec.parse(d['amount']);
    weighted = weighted + Dec.parse(d['weighted_amount'] ?? d['amount']);
  }
  return StageTotals(n, amount, weighted);
}
