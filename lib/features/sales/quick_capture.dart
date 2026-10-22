import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_client.dart';
import '../../core/api/api_error.dart';
import '../../core/db/local_db.dart';
import '../../core/design/design.dart';
import '../../core/providers.dart';
import '../../core/widgets/pickers.dart';
import '../route/route_repo.dart';
import 'cart.dart';

/// Captura rápida (Más › Configuración, por equipo): la venta abre una lista
/// fija de artículos (lo cargado en el camión de la ruta o, sin ruta, los
/// favoritos o lo más vendido en 30 días) y se teclean cantidades como en una
/// libreta de pedidos.
class QuickCaptureSettings {
  const QuickCaptureSettings({this.enabled = false, this.favorites = const []});
  final bool enabled;

  /// Artículos favoritos para vender sin ruta (vacío = lo más vendido).
  final List<int> favorites;
}

class QuickCaptureNotifier extends Notifier<QuickCaptureSettings> {
  static const _key = 'nori.quick_capture';

  @override
  QuickCaptureSettings build() {
    try {
      final j = Map<String, dynamic>.from(jsonDecode(ref.read(prefsProvider).getString(_key) ?? '{}') as Map);
      return QuickCaptureSettings(enabled: j['enabled'] == true, favorites: [...((j['favorites'] as List?) ?? const []).map((e) => (e as num).toInt())]);
    } catch (_) {
      return const QuickCaptureSettings();
    }
  }

  void _save(QuickCaptureSettings s) {
    ref.read(prefsProvider).setString(_key, jsonEncode({'enabled': s.enabled, 'favorites': s.favorites}));
    state = s;
  }

  void setEnabled(bool v) => _save(QuickCaptureSettings(enabled: v, favorites: state.favorites));
  void setFavorites(List<int> ids) => _save(QuickCaptureSettings(enabled: state.enabled, favorites: ids));
}

final quickCaptureProvider = NotifierProvider<QuickCaptureNotifier, QuickCaptureSettings>(QuickCaptureNotifier.new);

/// Un renglón de la libreta.
class QuickItem {
  QuickItem({required this.item, this.uom, this.onHand, this.price});
  final Map<String, dynamic> item;
  final String? uom;

  /// Existencia en el camión (o en el almacén de trabajo sin ruta).
  final Dec? onHand;
  final Dec? price;

  int get id => (item['id'] as num).toInt();
  String get name => '${item['name'] ?? ''}';
}

/// De dónde salen los artículos.
enum QuickSource { truck, favorites, frequent }

String truckStockKey(int planId) => 'truck_stock_$planId';

/// Lo que carga el camión del día (`/route/plans/{id}/stock`), guardado para trabajar sin señal.
Future<List<Map<String, dynamic>>> truckStock(ApiClient api, LocalDb db, int planId) async {
  try {
    final items = asList(asMap(await api.get('/route/plans/$planId/stock'))['items']);
    await db.putJson(truckStockKey(planId), items);
    return items;
  } on ApiException catch (e) {
    if (!e.isTransient) rethrow;
    return asList(await db.getJson(truckStockKey(planId)));
  }
}

/// Descuenta del camión guardado lo vendido (para la siguiente venta sin señal).
Future<void> consumeTruckStock(LocalDb db, int planId, List<CartLine> lines) async {
  final stock = asList(await db.getJson(truckStockKey(planId)));
  if (stock.isEmpty) return;
  for (final l in lines) {
    final row = stock.where((s) => (s['item_id'] as num?)?.toInt() == l.itemId).firstOrNull;
    if (row == null || l.uomId != null) continue; // en otra unidad no se sabe la conversión
    final left = Dec.parse(row['on_hand']) - l.quantity;
    row['on_hand'] = (left.isNegative ? Dec.zero : left).toJson(4);
  }
  await db.putJson(truckStockKey(planId), stock);
}

/// El día de ruta de hoy con camión, si el usuario tiene uno (para la venta libre).
Future<int?> todayTruckPlanId(LocalDb db) async {
  final today = asMap(await db.getJson(RouteRepo.todayKey));
  for (final p in asList(today['plans'])) {
    if (p['truck_warehouse_id'] != null) return (p['id'] as num).toInt();
  }
  return null;
}

/// Artículos de la libreta: camión de la ruta, favoritos o lo más vendido.
Future<(List<QuickItem>, QuickSource)> quickCaptureItems(WidgetRef ref, {int? planId, int? priceListId}) async {
  final api = ref.read(apiProvider);
  final db = ref.read(localDbProvider);
  final warehouseId = ref.read(sessionProvider)?.warehouseId;
  final rows = <Map<String, dynamic>>[]; // {item_id, code, name, uom, on_hand?}
  QuickSource source;
  if (planId != null) {
    source = QuickSource.truck;
    rows.addAll(await truckStock(api, db, planId));
  } else if (ref.read(quickCaptureProvider).favorites.isNotEmpty) {
    source = QuickSource.favorites;
    for (final id in ref.read(quickCaptureProvider).favorites) {
      rows.add({'item_id': id});
    }
  } else {
    source = QuickSource.frequent;
    try {
      final data = asList(unwrap(await api.get('/items/frequent', query: {'days': 30, 'limit': 40})));
      await db.putJson('frequent_items', data);
      rows.addAll(data);
    } on ApiException catch (e) {
      if (!e.isTransient) rethrow;
      rows.addAll(asList(await db.getJson('frequent_items')));
    }
  }
  final out = <QuickItem>[];
  for (final r in rows) {
    final id = (r['item_id'] as num).toInt();
    final item = await db.find('items', id) ?? {'id': id, 'code': r['code'], 'name': r['name'] ?? 'Artículo $id'};
    Dec? onHand = r['on_hand'] == null ? null : Dec.parse(r['on_hand']);
    if (onHand == null && warehouseId != null) {
      final s = await db.byRefs('stock', ref1: id, ref2: warehouseId);
      if (s.isNotEmpty) onHand = Dec.parse(s.first['available'] ?? s.first['on_hand']);
    }
    out.add(QuickItem(
      item: item,
      uom: r['uom'] as String?,
      onHand: onHand,
      price: await cachedListPrice(db, id, priceListId: priceListId),
    ));
  }
  return (out, source);
}

String _lastOrderKey(int customerId) => 'last_order_$customerId';

/// Recuerda lo que se le vendió al cliente para "Repetir último pedido".
Future<void> rememberLastOrder(LocalDb db, int customerId, List<CartLine> lines) async {
  final rows = [
    for (final l in lines)
      if (l.uomId == null && l.choices == null && l.baseLineId == null) {'item_id': l.itemId, 'quantity': l.quantity.toJson(4)},
  ];
  if (rows.isNotEmpty) await db.putJson(_lastOrderKey(customerId), rows);
}

Future<Map<int, Dec>> lastOrder(LocalDb db, int customerId) async => {
      for (final r in asList(await db.getJson(_lastOrderKey(customerId)))) (r['item_id'] as num).toInt(): Dec.parse(r['quantity']),
    };

/// Abre la libreta. Regresa las líneas con cantidad (los ceros no van) o null si se cancela.
Future<List<CartLine>?> showQuickCapture(
  BuildContext context, {
  required int customerId,
  required String customerName,
  required String title,
  int? priceListId,
  int? planId,
  List<Map<String, dynamic>> suggested = const [],
}) =>
    Navigator.of(context).push<List<CartLine>>(MaterialPageRoute(
      builder: (_) => QuickCapturePage(
        customerId: customerId,
        customerName: customerName,
        title: title,
        priceListId: priceListId,
        planId: planId,
        suggested: suggested,
      ),
    ));

class QuickCapturePage extends ConsumerStatefulWidget {
  const QuickCapturePage({
    super.key,
    required this.customerId,
    required this.customerName,
    required this.title,
    this.priceListId,
    this.planId,
    this.suggested = const [],
  });

  final int customerId;
  final String customerName;
  final String title;
  final int? priceListId;
  final int? planId;

  /// Cantidades sugeridas ({item_id, quantity}): el pronóstico de la visita.
  final List<Map<String, dynamic>> suggested;

  @override
  ConsumerState<QuickCapturePage> createState() => _QuickCapturePageState();
}

class _QuickCapturePageState extends ConsumerState<QuickCapturePage> {
  List<QuickItem> items = [];
  QuickSource? source;
  Map<int, Dec> last = {};
  final qty = <int, Dec>{};
  final ctrls = <int, TextEditingController>{};
  final nodes = <int, FocusNode>{};
  bool loading = true;
  Object? error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    for (final c in ctrls.values) {
      c.dispose();
    }
    for (final n in nodes.values) {
      n.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final (list, src) = await quickCaptureItems(ref, planId: widget.planId, priceListId: widget.priceListId);
      last = await lastOrder(ref.read(localDbProvider), widget.customerId);
      items = list;
      source = src;
      for (final i in items) {
        _ensure(i.id);
      }
      for (final s in widget.suggested) {
        final id = (s['item_id'] as num).toInt();
        if (items.any((i) => i.id == id)) _setQty(id, Dec.parse(s['quantity']));
      }
    } catch (e) {
      error = e;
    }
    if (mounted) setState(() => loading = false);
  }

  void _ensure(int id) {
    ctrls.putIfAbsent(id, () => TextEditingController());
    nodes.putIfAbsent(id, () {
      final n = FocusNode();
      // Al entrar al renglón se selecciona todo: lo tecleado reemplaza.
      n.addListener(() {
        final c = ctrls[id]!;
        if (n.hasFocus) c.selection = TextSelection(baseOffset: 0, extentOffset: c.text.length);
      });
      return n;
    });
  }

  void _setQty(int id, Dec v) {
    final q = v.isNegative ? Dec.zero : v;
    if (q.isZero) {
      qty.remove(id);
    } else {
      qty[id] = q;
    }
    ctrls[id]!.text = q.isZero ? '' : q.toQty();
  }

  void _repeatLast() {
    setState(() {
      for (final i in items) {
        _setQty(i.id, last[i.id] ?? Dec.zero);
      }
    });
    final missing = last.keys.where((id) => !items.any((i) => i.id == id)).length;
    if (missing > 0) showSnack(context, '$missing ${missing == 1 ? 'artículo' : 'artículos'} del último pedido no están en la lista.');
  }

  Future<void> _addOther() async {
    final item = await pickItem(context);
    if (item == null || !mounted) return;
    final id = (item['id'] as num).toInt();
    if (!items.any((i) => i.id == id)) {
      final price = await cachedListPrice(ref.read(localDbProvider), id, priceListId: widget.priceListId);
      setState(() {
        items.add(QuickItem(item: item, price: price));
        _ensure(id);
      });
    }
    WidgetsBinding.instance.addPostFrameCallback((_) => nodes[id]?.requestFocus());
  }

  void _next(int index) {
    if (index + 1 < items.length) {
      nodes[items[index + 1].id]!.requestFocus();
    } else {
      FocusScope.of(context).unfocus();
    }
  }

  Dec get _total => items.fold(Dec.zero, (s, i) => s + (i.price == null ? Dec.zero : (i.price! * (qty[i.id] ?? Dec.zero)).round(2)));

  void _continue() {
    final lines = [
      for (final i in items)
        if ((qty[i.id] ?? Dec.zero) > Dec.zero) CartLine(item: i.item, quantity: qty[i.id]!),
    ];
    Navigator.of(context).pop(lines);
  }

  @override
  Widget build(BuildContext context) {
    final nr = context.nr;
    final count = qty.values.where((q) => q > Dec.zero).length;
    final subtitle = switch (source) {
      QuickSource.truck => 'Lo cargado en el camión',
      QuickSource.favorites => 'Mis favoritos',
      QuickSource.frequent => 'Lo más vendido en 30 días',
      null => '',
    };
    return Scaffold(
      appBar: AppBar(
        title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(widget.title),
          Text(widget.customerName, style: NrText.caption(context)),
        ]),
        actions: [
          if (last.isNotEmpty) IconButton(icon: const Icon(Icons.replay), tooltip: 'Repetir último pedido', onPressed: _repeatLast),
          if (qty.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.clear_all),
              tooltip: 'Limpiar',
              onPressed: () => setState(() {
                for (final i in items) {
                  _setQty(i.id, Dec.zero);
                }
              }),
            ),
        ],
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : error != null
              ? NrErrorView(error!, onRetry: () {
                  setState(() {
                    loading = true;
                    error = null;
                  });
                  _load();
                })
              : ListView(padding: const EdgeInsets.fromLTRB(NrSpace.gutter, NrSpace.sm, NrSpace.gutter, 140), children: [
                  Row(children: [
                    Expanded(child: Text(subtitle.toUpperCase(), style: NrText.eyebrow(context))),
                    if (last.isNotEmpty)
                      TextButton.icon(onPressed: _repeatLast, icon: const Icon(Icons.replay, size: 18), label: const Text('Repetir último')),
                  ]),
                  if (items.isEmpty)
                    NrEmpty(
                      icon: Icons.inventory_2_outlined,
                      title: 'Sin artículos en la lista',
                      message: source == QuickSource.truck
                          ? 'El camión no tiene carga registrada (o no se ha descargado sin señal).'
                          : 'Elige tus favoritos en Más › Configuración o agrega artículos aquí.',
                    )
                  else
                    NrGroup(children: [for (var i = 0; i < items.length; i++) _row(context, i)]),
                  const SizedBox(height: NrSpace.md),
                  OutlinedButton.icon(onPressed: _addOther, icon: const Icon(Icons.add), label: const Text('Otro artículo')),
                ]),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Container(
          padding: const EdgeInsets.fromLTRB(NrSpace.lg, NrSpace.md, NrSpace.lg, NrSpace.md),
          decoration: BoxDecoration(color: nr.surface, border: Border(top: BorderSide(color: nr.border))),
          child: Row(children: [
            Expanded(
              child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('$count ${count == 1 ? 'artículo' : 'artículos'}', style: NrText.caption(context)),
                Text(money(_total), style: NrText.money(context, size: 22)),
              ]),
            ),
            FilledButton.icon(onPressed: count == 0 ? null : _continue, icon: const Icon(Icons.arrow_forward), label: const Text('Continuar')),
          ]),
        ),
      ),
    );
  }

  Widget _row(BuildContext context, int index) {
    final i = items[index];
    final q = qty[i.id] ?? Dec.zero;
    final over = i.onHand != null && q > i.onHand!;
    final nr = context.nr;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: NrSpace.md, vertical: NrSpace.sm),
      child: Row(children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(i.name, style: NrText.headline(context), maxLines: 2, overflow: TextOverflow.ellipsis),
            Text(
              [
                '${i.item['code'] ?? ''}',
                ?i.uom,
                if (i.price != null) money(i.price),
                if (i.onHand != null) '${source == QuickSource.truck ? 'Camión' : 'Exist.'} ${i.onHand!.toQty()}',
              ].where((e) => e.isNotEmpty).join(' · '),
              style: NrText.caption(context).copyWith(color: over ? nr.danger : null),
            ),
          ]),
        ),
        IconButton(
          iconSize: 30,
          icon: const Icon(Icons.remove_circle_outline),
          onPressed: q.isZero ? null : () => setState(() => _setQty(i.id, q - Dec.one)),
        ),
        SizedBox(
          width: 64,
          child: TextField(
            controller: ctrls[i.id],
            focusNode: nodes[i.id],
            textAlign: TextAlign.center,
            style: NrText.money(context, size: 22).copyWith(color: over ? nr.danger : null),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
            textInputAction: index + 1 < items.length ? TextInputAction.next : TextInputAction.done,
            decoration: const InputDecoration(hintText: '0', isDense: true, contentPadding: EdgeInsets.symmetric(vertical: 10)),
            onChanged: (v) => setState(() {
              final d = Dec.tryParse(v) ?? Dec.zero;
              if (d.isZero) {
                qty.remove(i.id);
              } else {
                qty[i.id] = d;
              }
            }),
            onSubmitted: (_) => _next(index),
          ),
        ),
        IconButton(
          iconSize: 30,
          icon: const Icon(Icons.add_circle_outline),
          onPressed: () => setState(() => _setQty(i.id, q + Dec.one)),
        ),
      ]),
    );
  }
}
