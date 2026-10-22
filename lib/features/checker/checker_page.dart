import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
      showSnack(context, 'No se encontró el código $code');
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
    HapticFeedback.selectionClick();
    _byCode(code);
  }

  void _addToSale() {
    final c = _check;
    if (c == null) return;
    final item = {...c.data}..removeWhere((k, _) => const ['prices', 'stock', 'images', 'units'].contains(k));
    ref.read(pendingSaleItemsProvider.notifier).update((l) => [...l, item]);
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text('${item['name']} agregado a la venta'),
        action: SnackBarAction(label: 'Ir a vender', onPressed: () => context.go('/sell')),
      ));
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(sessionProvider);
    final pending = ref.watch(pendingSaleItemsProvider).length;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Checador de precios'),
        actions: [
          IconButton(
            icon: Icon(_continuous ? Icons.videocam_off_outlined : Icons.center_focus_strong),
            tooltip: _continuous ? 'Apagar escaneo continuo' : 'Escaneo continuo',
            onPressed: _toggleContinuous,
          ),
        ],
      ),
      body: Column(children: [
        if (_continuous && _scanner != null)
          SizedBox(
            height: 200,
            child: Stack(fit: StackFit.expand, children: [
              MobileScanner(controller: _scanner!, onDetect: _onDetect),
              Center(
                child: Container(
                  width: 240,
                  height: 110,
                  decoration: BoxDecoration(border: Border.all(color: Colors.white70, width: 2), borderRadius: BorderRadius.circular(NrRadius.lg)),
                ),
              ),
            ]),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(NrSpace.gutter, NrSpace.sm, NrSpace.gutter, NrSpace.sm),
          child: TextField(
            controller: _text,
            decoration: InputDecoration(
              hintText: 'Código, nombre o código de barras',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: IconButton(icon: const Icon(Icons.qr_code_scanner), tooltip: 'Escanear', onPressed: _scanOnce),
            ),
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
        if (_loading) const LinearProgressIndicator(),
        Expanded(
          child: _results.isNotEmpty
              ? ListView.separated(
                  itemCount: _results.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (_, i) {
                    final it = _results[i];
                    return NrListRow(title: '${it['name']}', subtitle: '${it['code']}', onTap: () => _show(it));
                  },
                )
              : _check == null
                  ? NrEmpty(
                      icon: Icons.qr_code_2,
                      title: 'Escanea o busca un artículo',
                      message: 'Verás su imagen, precios y existencias.',
                      action: 'Escanear',
                      onAction: _scanOnce,
                    )
                  : _CheckResult(check: _check!),
        ),
      ]),
      bottomNavigationBar: _check == null || !(session?.canFreeSell ?? false)
          ? null
          : NrBottomAction(
              label: pending > 0 ? 'Agregar a la venta ($pending)' : 'Agregar a la venta',
              leading: const Icon(Icons.add_shopping_cart),
              onPressed: _addToSale,
            ),
    );
  }
}

class _CheckResult extends StatelessWidget {
  const _CheckResult({required this.check});

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
    final byList = <String, List<Map<String, dynamic>>>{};
    for (final p in prices) {
      byList.putIfAbsent('${p['price_list']}', () => []).add(p);
    }

    return ListView(padding: const EdgeInsets.fromLTRB(NrSpace.gutter, 0, NrSpace.gutter, NrSpace.xl), children: [
      if (check.offline)
        const Padding(
          padding: EdgeInsets.only(bottom: NrSpace.md),
          child: NrPill('Datos guardados: precio sin impuestos y existencia de la última sincronización', tone: NrTone.warning, icon: Icons.cloud_off),
        ),
      if (imageUrls.isNotEmpty) _Gallery(urls: imageUrls),
      const SizedBox(height: NrSpace.md),
      Text('${d['name']}', style: NrText.title(context)),
      const SizedBox(height: NrSpace.xs),
      Wrap(spacing: NrSpace.sm, runSpacing: NrSpace.xs, crossAxisAlignment: WrapCrossAlignment.center, children: [
        Text('${d['code']}', style: NrText.bodySm(context)),
        if (d['is_package'] == true) const NrPill('Paquete', tone: NrTone.accent),
        if (d['is_active'] == false) const NrPill('Inactivo', tone: NrTone.danger),
        for (final b in barcodes) NrPill(b, icon: Icons.qr_code),
      ]),
      if (prices.isNotEmpty) ...[
        NrSectionHeader('Precios'),
        NrGroup(children: [
          for (final e in byList.entries)
            for (final p in e.value)
              NrListRow(
                title: e.key,
                subtitle: p['uom'] == null ? null : 'Por ${'${p['uom']}'.toLowerCase()}',
                trailing: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.end, children: [
                  NrMoney(p['price_with_tax'] ?? p['price'], size: 18),
                  Text(
                    p['price_with_tax'] != null
                        ? 'Con impuestos${tax == null || tax.isZero ? '' : ' (${tax.toQty()} %)'} · antes ${money(p['price'])}'
                        : 'Sin impuestos',
                    style: NrText.caption(context),
                  ),
                ]),
              ),
        ]),
      ] else ...[
        NrSectionHeader('Precios'),
        const NrCard(child: Text('Sin precio en tus listas.')),
      ],
      NrSectionHeader('Existencias', count: stock.length),
      if (stock.isEmpty)
        const NrCard(child: Text('Sin existencia registrada en tus almacenes.'))
      else
        NrGroup(children: [
          for (final s in stock)
            NrListRow(
              leading: Icon(s['is_working'] == true ? Icons.warehouse : Icons.warehouse_outlined, color: s['is_working'] == true ? nr.accent : nr.secondary),
              title: '${asMap(s['warehouse'])['name'] ?? 'Almacén ${s['warehouse_id']}'}${s['is_working'] == true ? ' · de trabajo' : ''}',
              subtitle: [
                'Existencia ${Dec.parse(s['on_hand']).toQty()}',
                'Comprometido ${Dec.parse(s['committed']).toQty()}',
                if (asMap(s['bin_location']).isNotEmpty) 'Ubicación ${asMap(s['bin_location'])['code']}',
              ].join(' · '),
              trailing: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.end, children: [
                Text(Dec.parse(s['available']).toQty(),
                    style: NrText.money(context, size: 18).copyWith(color: Dec.parse(s['available']) <= Dec.zero ? nr.danger : null)),
                Text('Disponible', style: NrText.caption(context)),
              ]),
            ),
        ]),
    ]);
  }
}

class _Gallery extends StatefulWidget {
  const _Gallery({required this.urls});

  final List<String> urls;

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
        borderRadius: BorderRadius.circular(NrRadius.xxl),
        child: Container(
          height: 220,
          color: nr.raised,
          child: PageView(
            onPageChanged: (i) => setState(() => page = i),
            children: [
              for (final u in widget.urls)
                Image.network(
                  u,
                  fit: BoxFit.contain,
                  errorBuilder: (_, _, _) => Icon(Icons.image_not_supported_outlined, size: 48, color: nr.secondary),
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
