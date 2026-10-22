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
  if (rows.isNotEmpty) {
    await db.putJson(_lastOrderKey(customerId), rows);
    await db.putJson(lastOrderAtKey(customerId), {'at': DateTime.now().toIso8601String(), 'lines': rows.length});
  }
}

/// Cuándo se le vendió por última vez desde este equipo (y cuántos renglones).
String lastOrderAtKey(int customerId) => 'last_order_at_$customerId';

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
  String filter = '';

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
    final (sourceLabel, sourceIcon) = switch (source) {
      QuickSource.truck => ('Lo cargado en el camión', Icons.local_shipping_rounded),
      QuickSource.favorites => ('Mis favoritos', Icons.star_rounded),
      QuickSource.frequent => ('Lo más vendido en 30 días', Icons.trending_up_rounded),
      null => ('', Icons.list_rounded),
    };
    final f = filter.trim().toLowerCase();
    final visible = [
      for (var i = 0; i < items.length; i++)
        if (f.isEmpty || items[i].name.toLowerCase().contains(f) || '${items[i].item['code'] ?? ''}'.toLowerCase().contains(f)) i,
    ];
    return Scaffold(
      appBar: AppBar(
        title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(widget.title),
          Text(widget.customerName, style: NrText.caption(context), maxLines: 1, overflow: TextOverflow.ellipsis),
        ]),
        actions: [
          if (qty.isNotEmpty)
            TextButton(
              onPressed: () => setState(() {
                NrHaptics.action();
                for (final i in items) {
                  _setQty(i.id, Dec.zero);
                }
              }),
              child: const Text('Limpiar'),
            ),
        ],
      ),
      body: loading
          ? const NrSkeletonList(count: 7)
          : error != null
              ? NrErrorView(error!, onRetry: () {
                  setState(() {
                    loading = true;
                    error = null;
                  });
                  _load();
                })
              : ListView(padding: const EdgeInsets.fromLTRB(NrSpace.gutter, NrSpace.xs, NrSpace.gutter, NrSpace.xxxl), children: [
                  Row(children: [
                    Icon(sourceIcon, size: 16, color: nr.secondary),
                    const SizedBox(width: 6),
                    Expanded(child: Text(sourceLabel.toUpperCase(), style: NrText.eyebrow(context))),
                    if (last.isNotEmpty)
                      TextButton.icon(onPressed: _repeatLast, icon: const Icon(Icons.replay_rounded, size: 18), label: const Text('Repetir último')),
                  ]),
                  if (items.length > 8) ...[
                    const SizedBox(height: NrSpace.xs),
                    NrSearchField(hint: 'Filtrar la lista', onChanged: (v) => setState(() => filter = v)),
                  ],
                  const SizedBox(height: NrSpace.sm),
                  if (items.isEmpty)
                    NrEmpty(
                      icon: source == QuickSource.truck ? Icons.local_shipping_rounded : Icons.star_rounded,
                      title: 'La libreta está vacía',
                      message: source == QuickSource.truck
                          ? 'El camión no tiene carga registrada (o no se ha descargado sin señal).'
                          : 'Elige tus favoritos en Más › Configuración o agrega artículos aquí.',
                      action: 'Agregar artículo',
                      onAction: _addOther,
                    )
                  else
                    for (final (n, i) in visible.indexed)
                      Padding(padding: const EdgeInsets.only(bottom: NrSpace.sm), child: NrEntrance(index: n, child: _row(context, i))),
                  if (items.isNotEmpty) ...[
                    const SizedBox(height: NrSpace.xs),
                    NrButton(label: 'Otro artículo', icon: Icons.add_rounded, variant: NrButtonVariant.secondary, height: NrTouch.min, onPressed: _addOther),
                  ],
                ]),
      bottomNavigationBar: NrBottomBar(
        child: Row(children: [
          Expanded(
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              AnimatedSwitcher(
                duration: NrMotion.fast,
                child: Text('$count ${count == 1 ? 'artículo' : 'artículos'}', key: ValueKey(count), style: NrText.caption(context)),
              ),
              NrAmount(_total, size: 24, animate: true),
            ]),
          ),
          NrButton(
            label: 'Continuar',
            icon: Icons.arrow_forward_rounded,
            expand: false,
            onPressed: count == 0 ? null : () {
              NrHaptics.action();
              _continue();
            },
          ),
        ]),
      ),
    );
  }

  Widget _row(BuildContext context, int index) {
    final i = items[index];
    final q = qty[i.id] ?? Dec.zero;
    final active = q > Dec.zero;
    final over = i.onHand != null && q > i.onHand!;
    final low = i.onHand != null && !over && active && q.toDouble() >= i.onHand!.toDouble() * 0.8;
    final nr = context.nr;
    return AnimatedContainer(
      duration: NrMotion.base,
      curve: NrMotion.ease,
      decoration: BoxDecoration(
        color: active ? Color.alphaBlend(nr.accent.withValues(alpha: nr.night ? 0.10 : 0.05), nr.surface) : nr.surface,
        borderRadius: BorderRadius.circular(NrRadius.xxl),
        border: Border.all(color: over ? nr.danger : (active ? nr.accent.withValues(alpha: 0.5) : (nr.night || nr.highContrast ? nr.border : Colors.transparent)), width: active || over ? 1.5 : 1),
        boxShadow: active ? null : nr.shadow,
      ),
      padding: const EdgeInsets.fromLTRB(NrSpace.md, NrSpace.md, NrSpace.sm, NrSpace.md),
      child: Row(children: [
        NrThumb(name: i.name, url: i.item['image_url'] as String?, size: 46),
        const SizedBox(width: NrSpace.md),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(i.name, style: NrText.headline(context).copyWith(fontSize: 15), maxLines: 2, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 3),
            Row(children: [
              if (i.price != null) Text(money(i.price), style: NrText.money(context, size: 13).copyWith(color: nr.body)),
              if (i.price != null && i.onHand != null) const SizedBox(width: 6),
              if (i.onHand != null)
                Flexible(
                  child: NrPill(
                    i.onHand! <= Dec.zero ? 'Sin existencia' : '${i.onHand!.toQty()} ${source == QuickSource.truck ? 'en camión' : 'disp.'}',
                    tone: over ? NrTone.danger : (low ? NrTone.warning : (i.onHand! <= Dec.zero ? NrTone.danger : NrTone.neutral)),
                  ),
                ),
            ]),
            if ('${i.item['code'] ?? ''}'.isNotEmpty) Text('${i.item['code']}${i.uom == null ? '' : ' · ${i.uom}'}', style: NrText.caption(context).copyWith(fontSize: 11)),
          ]),
        ),
        _padBtn(context, Icons.remove_rounded, q.isZero ? null : () => setState(() => _setQty(i.id, q - Dec.one))),
        SizedBox(
          width: 56,
          child: TextField(
            controller: ctrls[i.id],
            focusNode: nodes[i.id],
            textAlign: TextAlign.center,
            style: NrText.money(context, size: 22, weight: FontWeight.w700).copyWith(color: over ? nr.danger : (active ? (nr.night ? nr.link : nr.accent) : null)),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
            textInputAction: index + 1 < items.length ? TextInputAction.next : TextInputAction.done,
            decoration: InputDecoration(
              hintText: '0',
              isDense: true,
              filled: false,
              contentPadding: const EdgeInsets.symmetric(vertical: 10),
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: nr.accent, width: 2)),
            ),
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
        _padBtn(context, Icons.add_rounded, () => setState(() => _setQty(i.id, q + Dec.one)), primary: true),
      ]),
    );
  }

  Widget _padBtn(BuildContext context, IconData icon, VoidCallback? onTap, {bool primary = false}) {
    final nr = context.nr;
    return Material(
      color: primary ? nr.accent : (nr.night ? nr.raised : nr.sunken),
      borderRadius: BorderRadius.circular(NrRadius.lg),
      child: InkWell(
        borderRadius: BorderRadius.circular(NrRadius.lg),
        onTap: onTap == null
            ? null
            : () {
                NrHaptics.tap();
                onTap();
              },
        child: SizedBox.square(dimension: 44, child: Icon(icon, color: primary ? nr.onAccent : (onTap == null ? nr.muted : nr.headline))),
      ),
    );
  }
}
