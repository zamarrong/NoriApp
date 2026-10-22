import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../core/api/api_client.dart';
import '../../core/api/api_error.dart';
import '../../core/design/design.dart';
import '../../core/providers.dart';
import '../../core/widgets/pickers.dart';
import '../sales/item_support.dart';
import '../sales/sell_page.dart' show pendingSaleItemsProvider;

/// Lo que muestra el checador. [offline] = armado con lo guardado en el teléfono.
class PriceCheck {
  const PriceCheck(this.data, {this.offline = false});

  final Map<String, dynamic> data;
  final bool offline;
}

/// Checador de precios en línea (`/items/{id}/price-check`) o, sin señal (o con
/// un servidor que aún no lo tiene), con los catálogos guardados.
Future<PriceCheck> loadPriceCheck(WidgetRef ref, Map<String, dynamic> item) async {
  final id = (item['id'] as num).toInt();
  try {
    return PriceCheck(asMap(unwrap(await ref.read(apiProvider).get('/items/$id/price-check'))));
  } on ApiException catch (_) {
    return PriceCheck(await _offlineCheck(ref, item), offline: true);
  }
}

Future<Map<String, dynamic>> _offlineCheck(WidgetRef ref, Map<String, dynamic> item) async {
  final db = ref.read(localDbProvider);
  final session = ref.read(sessionProvider);
  final id = (item['id'] as num).toInt();
  final full = await db.find('items', id) ?? item;
  final lists = {for (final l in await db.all('price_lists')) (l['id'] as num).toInt(): '${l['name'] ?? l['code']}'};
  final warehouses = {for (final w in await db.all('warehouses', activeOnly: false)) (w['id'] as num).toInt(): w};
  final uoms = await uomNames(ref);
  final allowedLists = session?.allowedPriceListIds ?? const [];
  final salesUom = (full['sales_uom_id'] as num?)?.toInt();
  final prices = (await db.byRefs('item_prices', ref1: id))
      .where((p) => allowedLists.isEmpty || allowedLists.contains((p['price_list_id'] as num).toInt()))
      .map((p) {
    final uom = (p['uom_id'] as num?)?.toInt();
    return {
      'price_list_id': p['price_list_id'],
      'price_list': lists[(p['price_list_id'] as num).toInt()] ?? 'Lista ${p['price_list_id']}',
      'uom_id': uom,
      'uom': uoms[uom ?? salesUom],
      'price': p['price'],
    };
  }).toList();
  final working = session?.warehouseId;
  final stock = (await db.byRefs('stock', ref1: id)).map((s) {
    final w = warehouses[(s['warehouse_id'] as num).toInt()];
    return {...s, 'warehouse': w, 'is_working': s['warehouse_id'] == working};
  }).toList()
    ..sort((a, b) => (a['is_working'] == true ? 0 : 1).compareTo(b['is_working'] == true ? 0 : 1));
  return {...full, 'prices': prices, 'stock': stock, 'images': const []};
}

/// "Checador": busca por texto o escanea con la cámara (uno o en continuo) y
/// muestra imagen, precios por lista y unidad, existencias por almacén y la
/// ubicación habitual donde el almacén usa ubicaciones.
class CheckerPage extends ConsumerStatefulWidget {
  const CheckerPage({super.key});

  @override
  ConsumerState<CheckerPage> createState() => _CheckerPageState();
}

class _CheckerPageState extends ConsumerState<CheckerPage> {
  final _text = TextEditingController();
  Timer? _debounce;
  List<Map<String, dynamic>> _results = [];
  PriceCheck? _check;
  bool _loading = false;
  bool _continuous = false;
  MobileScannerController? _scanner;
  String? _lastCode;
  DateTime _lastAt = DateTime(2000);

  @override
  void dispose() {
    _debounce?.cancel();
    _text.dispose();
    _scanner?.dispose();
    super.dispose();
  }

  Future<void> _search(String q) async {
    if (q.trim().isEmpty) {
      setState(() => _results = []);
      return;
    }
    var rows = await ref.read(localDbProvider).search('items', q, limit: 40);
    if (rows.isEmpty && q.trim().length >= 2) {
      try {
        rows = asList(unwrap(await ref.read(apiProvider).get('/items', query: {'search': q, 'per_page': 30})));
      } on ApiException catch (_) {}
    }
    if (mounted) setState(() => _results = rows);
  }

  Future<void> _show(Map<String, dynamic> item) async {
    FocusScope.of(context).unfocus();
    setState(() {
      _loading = true;
      _results = [];
    });
    final check = await loadPriceCheck(ref, item);
    if (mounted) {
      setState(() {
        _check = check;
        _loading = false;
      });
    }
  }

  Future<void> _byCode(String code) async {
    setState(() => _loading = true);
    final item = await findItemByCode(ref, code);
    if (!mounted) return;
    if (item == null) {
      setState(() => _loading = false);
      NrHaptics.warning();
      showSnack(context, 'No se encontró el código $code', tone: NrTone.danger);
      return;
    }
    _text.text = '';
    await _show(item);
  }

  Future<void> _scanOnce() async {
    final code = await scanBarcode(context);
    if (code != null && mounted) await _byCode(code);
  }

  void _toggleContinuous() {
    setState(() {
      _continuous = !_continuous;
      if (_continuous) {
        _scanner = MobileScannerController(detectionSpeed: DetectionSpeed.noDuplicates);
      } else {
        _scanner?.dispose();
        _scanner = null;
      }
    });
  }

  void _onDetect(BarcodeCapture capture) {
    final code = capture.barcodes.map((b) => b.rawValue).whereType<String>().firstOrNull;
    if (code == null) return;
    final now = DateTime.now();
    // El mismo código se vuelve a leer después de 2 s (otra pieza del mismo artículo).
    if (code == _lastCode && now.difference(_lastAt) < const Duration(seconds: 2)) return;
    _lastCode = code;
    _lastAt = now;
    NrHaptics.tap();
    _byCode(code);
  }

  void _addToSale() {
    final c = _check;
    if (c == null) return;
    final item = {...c.data}..removeWhere((k, _) => const ['prices', 'stock', 'images', 'units'].contains(k));
    ref.read(pendingSaleItemsProvider.notifier).update((l) => [...l, item]);
    NrHaptics.success();
    showSnack(context, '${item['name']} agregado a la venta', tone: NrTone.success, action: 'Ir a vender', onAction: () => context.go('/sell'));
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(sessionProvider);
    final pending = ref.watch(pendingSaleItemsProvider).length;
    final nr = context.nr;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Checador de precios'),
        actions: [
          IconButton(
            icon: Icon(_continuous ? Icons.videocam_off_rounded : Icons.center_focus_strong_rounded),
            tooltip: _continuous ? 'Apagar escaneo continuo' : 'Escaneo continuo',
            onPressed: _toggleContinuous,
          ),
        ],
      ),
      body: Column(children: [
        AnimatedSize(
          duration: NrMotion.base,
          curve: NrMotion.ease,
          child: _continuous && _scanner != null
              ? Padding(
                  padding: const EdgeInsets.fromLTRB(NrSpace.gutter, 0, NrSpace.gutter, NrSpace.sm),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(NrRadius.xxl),
                    child: SizedBox(
                      height: 190,
                      child: Stack(fit: StackFit.expand, children: [
                        MobileScanner(controller: _scanner!, onDetect: _onDetect),
                        Center(
                          child: Container(
                            width: 240,
                            height: 104,
                            decoration: BoxDecoration(border: Border.all(color: Colors.white, width: 2.5), borderRadius: BorderRadius.circular(NrRadius.lg)),
                          ),
                        ),
                        Positioned(
                          left: 12,
                          top: 12,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(NrRadius.pill)),
                            child: Row(mainAxisSize: MainAxisSize.min, children: [
                              NrPulseDot(color: nr.danger, size: 7),
                              const Text('Escaneo continuo', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
                            ]),
                          ),
                        ),
                      ]),
                    ),
                  ),
                )
              : const SizedBox(width: double.infinity),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(NrSpace.gutter, 0, NrSpace.gutter, NrSpace.sm),
          child: NrSearchField(
            controller: _text,
            hint: 'Código, nombre o código de barras',
            onScan: _scanOnce,
            onChanged: (v) {
              _debounce?.cancel();
              _debounce = Timer(const Duration(milliseconds: 250), () => _search(v));
            },
            onSubmitted: (v) async {
              final item = await findItemByCode(ref, v);
              if (item != null) {
                _text.text = '';
                await _show(item);
              }
            },
          ),
        ),
        SizedBox(height: 2, child: _loading ? LinearProgressIndicator(color: nr.accent, backgroundColor: Colors.transparent) : null),
        Expanded(
          child: NrSwitcher(
            child: _results.isNotEmpty
                ? ListView.builder(
                    key: const ValueKey('results'),
                    padding: const EdgeInsets.fromLTRB(NrSpace.gutter, NrSpace.sm, NrSpace.gutter, NrSpace.xl),
                    itemCount: _results.length,
                    itemBuilder: (_, i) {
                      final it = _results[i];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: NrSpace.sm),
                        child: NrCard(
                          padding: const EdgeInsets.all(NrSpace.md),
                          onTap: () => _show(it),
                          child: Row(children: [
                            NrThumb(name: '${it['name']}', url: it['image_url'] as String?, size: 44),
                            const SizedBox(width: NrSpace.md),
                            Expanded(
                              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                Text('${it['name']}', style: NrText.headline(context).copyWith(fontSize: 15), maxLines: 2, overflow: TextOverflow.ellipsis),
                                Text('${it['code']}', style: NrText.caption(context)),
                              ]),
                            ),
                            Icon(Icons.chevron_right_rounded, color: nr.muted),
                          ]),
                        ),
                      );
                    },
                  )
                : _check == null
                    ? NrEmpty(
                        key: const ValueKey('empty'),
                        icon: Icons.qr_code_scanner_rounded,
                        title: 'Escanea o busca un artículo',
                        message: 'Verás su imagen, precios por lista y existencias por almacén.',
                        action: 'Escanear',
                        onAction: _scanOnce,
                      )
                    : _CheckResult(key: ValueKey(_check!.data['id']), check: _check!),
          ),
        ),
      ]),
      bottomNavigationBar: _check == null || !(session?.canFreeSell ?? false)
          ? null
          : NrBottomBar(
              child: Row(children: [
                if (pending > 0) ...[
                  NrSquareButton(icon: Icons.shopping_basket_rounded, tooltip: 'Ir a vender', size: NrTouch.comfy, onPressed: () => context.go('/sell')),
                  const SizedBox(width: NrSpace.md),
                ],
                Expanded(
                  child: NrButton(
                    label: 'Agregar a la venta',
                    icon: Icons.add_shopping_cart_rounded,
                    onPressed: _addToSale,
                    trailing: pending == 0
                        ? null
                        : Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(color: nr.onAccent.withValues(alpha: 0.22), borderRadius: BorderRadius.circular(NrRadius.pill)),
                            child: Text('$pending', style: NrText.caption(context).copyWith(color: nr.onAccent, fontWeight: FontWeight.w700)),
                          ),
                  ),
                ),
              ]),
            ),
    );
  }
}

class _CheckResult extends StatelessWidget {
  const _CheckResult({super.key, required this.check});

  final PriceCheck check;

  @override
  Widget build(BuildContext context) {
    final d = check.data;
    final nr = context.nr;
    final images = asList(d['images'])..sort((a, b) => (b['is_main'] == true ? 1 : 0).compareTo(a['is_main'] == true ? 1 : 0));
    final imageUrls = [
      ...images.map((i) => '${i['url']}'),
      if (images.isEmpty && d['image_url'] != null) '${d['image_url']}',
    ];
    final barcodes = asList(d['barcodes']).map((b) => '${b['barcode']}').toList();
    final prices = asList(d['prices']);
    final stock = asList(d['stock']);
    final tax = Dec.tryParse('${d['tax_percent'] ?? ''}');
    final main = prices.firstOrNull;
    final maxAvail = stock.fold<double>(1, (m, s) => Dec.parse(s['available']).toDouble() > m ? Dec.parse(s['available']).toDouble() : m);
    final totalAvail = stock.fold(Dec.zero, (t, s) => t + Dec.parse(s['available']).max(Dec.zero));

    return ListView(padding: const EdgeInsets.fromLTRB(NrSpace.gutter, NrSpace.sm, NrSpace.gutter, NrSpace.xxxl), children: [
      if (check.offline)
        const Padding(
          padding: EdgeInsets.only(bottom: NrSpace.md),
          child: NrBanner(message: 'Datos guardados: precio sin impuestos y existencia de la última sincronización.'),
        ),
      NrEntrance(
        child: NrCard(
          depth: NrDepth.floating,
          radius: NrRadius.hero,
          padding: EdgeInsets.zero,
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            if (imageUrls.isNotEmpty) _Gallery(urls: imageUrls, name: '${d['name']}') else Container(height: 120, color: nr.night ? nr.raised : nr.canvas, child: Center(child: NrThumb(name: '${d['name']}', size: 72))),
            Padding(
              padding: const EdgeInsets.all(NrSpace.lg),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Text('${d['name']}', style: NrText.title(context)),
                const SizedBox(height: NrSpace.xs),
                Wrap(spacing: 6, runSpacing: 6, crossAxisAlignment: WrapCrossAlignment.center, children: [
                  NrPill('${d['code']}', icon: Icons.tag_rounded),
                  if (d['is_package'] == true) const NrPill('Paquete', tone: NrTone.accent),
                  if (d['is_active'] == false) const NrPill('Inactivo', tone: NrTone.danger, dot: true),
                  for (final b in barcodes.take(3)) NrPill(b, icon: Icons.qr_code_rounded),
                ]),
                if (main != null) ...[
                  const SizedBox(height: NrSpace.lg),
                  Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('${main['price_list']}'.toUpperCase(), style: NrText.eyebrow(context)),
                        const SizedBox(height: 4),
                        NrAmount(main['price_with_tax'] ?? main['price'], size: 38, animate: true),
                        Text(
                          [
                            if (main['uom'] != null) 'por ${'${main['uom']}'.toLowerCase()}',
                            main['price_with_tax'] != null ? 'con impuestos${tax == null || tax.isZero ? '' : ' (${tax.toQty()} %)'}' : 'sin impuestos',
                          ].join(' · '),
                          style: NrText.caption(context),
                        ),
                      ]),
                    ),
                    Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                      Text('DISPONIBLE', style: NrText.eyebrow(context)),
                      const SizedBox(height: 4),
                      Text(totalAvail.toQty(), style: NrText.stat(context).copyWith(color: totalAvail.isZero ? nr.danger : nr.success)),
                    ]),
                  ]),
                ],
              ]),
            ),
          ]),
        ),
      ),
      if (prices.length > 1) ...[
        NrSectionHeader('Otras listas', count: prices.length - 1),
        NrGroup(children: [
          for (final p in prices.skip(1))
            NrListRow(
              dense: true,
              title: '${p['price_list']}',
              subtitle: p['uom'] == null ? null : 'Por ${'${p['uom']}'.toLowerCase()}',
              trailing: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.end, children: [
                NrMoney(p['price_with_tax'] ?? p['price'], size: 16, weight: FontWeight.w700),
                if (p['price_with_tax'] != null) Text('antes ${money(p['price'])}', style: NrText.caption(context)),
              ]),
            ),
        ]),
      ] else if (prices.isEmpty) ...[
        NrSectionHeader('Precios'),
        const NrBanner(message: 'Sin precio en tus listas.', tone: NrTone.neutral, icon: Icons.sell_outlined),
      ],
      NrSectionHeader('Existencias', count: stock.length),
      if (stock.isEmpty)
        const NrBanner(message: 'Sin existencia registrada en tus almacenes.', tone: NrTone.neutral, icon: Icons.inventory_2_outlined)
      else
        NrCard(
          padding: const EdgeInsets.symmetric(vertical: NrSpace.xs),
          child: Column(children: [
            for (final (i, s) in stock.take(30).indexed) ...[
              if (i > 0) Divider(height: 1, indent: NrSpace.lg, color: nr.border),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: NrSpace.lg, vertical: NrSpace.md),
                child: Row(children: [
                  Icon(s['is_working'] == true ? Icons.warehouse_rounded : Icons.warehouse_outlined, color: s['is_working'] == true ? nr.accent : nr.muted, size: 20),
                  const SizedBox(width: NrSpace.md),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(children: [
                        Flexible(
                          child: Text('${asMap(s['warehouse'])['name'] ?? 'Almacén ${s['warehouse_id']}'}',
                              style: NrText.headline(context).copyWith(fontSize: 14), maxLines: 1, overflow: TextOverflow.ellipsis),
                        ),
                        if (s['is_working'] == true) ...[const SizedBox(width: 6), const NrPill('De trabajo', tone: NrTone.accent)],
                      ]),
                      const SizedBox(height: 6),
                      NrMeter(value: Dec.parse(s['available']).toDouble() / maxAvail, height: 5, color: Dec.parse(s['available']) <= Dec.zero ? nr.danger : nr.success),
                      const SizedBox(height: 4),
                      Text(
                        [
                          'Existencia ${Dec.parse(s['on_hand']).toQty()}',
                          'Comprometido ${Dec.parse(s['committed']).toQty()}',
                          if (asMap(s['bin_location']).isNotEmpty) 'Ubicación ${asMap(s['bin_location'])['code']}',
                        ].join(' · '),
                        style: NrText.caption(context).copyWith(fontSize: 11),
                      ),
                    ]),
                  ),
                  const SizedBox(width: NrSpace.md),
                  Text(Dec.parse(s['available']).toQty(),
                      style: NrText.money(context, size: 20, weight: FontWeight.w700).copyWith(color: Dec.parse(s['available']) <= Dec.zero ? nr.danger : null)),
                ]),
              ),
            ],
          ]),
        ),
    ]);
  }
}

class _Gallery extends StatefulWidget {
  const _Gallery({required this.urls, required this.name});

  final List<String> urls;
  final String name;

  @override
  State<_Gallery> createState() => _GalleryState();
}

class _GalleryState extends State<_Gallery> {
  int page = 0;

  @override
  Widget build(BuildContext context) {
    final nr = context.nr;
    return Column(children: [
      ClipRRect(
        borderRadius: BorderRadius.zero,
        child: Container(
          height: 240,
          color: nr.raised,
          child: PageView(
            onPageChanged: (i) => setState(() => page = i),
            children: [
              for (final u in widget.urls)
                Image.network(
                  u,
                  fit: BoxFit.contain,
                  errorBuilder: (_, _, _) => Center(child: NrThumb(name: widget.name, size: 96)),
                ),
            ],
          ),
        ),
      ),
      if (widget.urls.length > 1)
        Padding(
          padding: const EdgeInsets.only(top: NrSpace.sm),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            for (var i = 0; i < widget.urls.length; i++)
              Container(
                width: 6,
                height: 6,
                margin: const EdgeInsets.symmetric(horizontal: 3),
                decoration: BoxDecoration(shape: BoxShape.circle, color: i == page ? nr.accent : nr.secondary.withValues(alpha: 0.3)),
              ),
          ]),
        ),
    ]);
  }
}
