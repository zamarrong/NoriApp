import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_client.dart';
import '../../core/authorizations/authorization_flow.dart';
import '../../core/design/design.dart';
import '../../core/providers.dart';
import '../../core/sync/outbox.dart';
import '../../core/widgets/pickers.dart';

class MoveLine {
  MoveLine(this.item, this.quantity, {this.baseLineId, this.open});

  final Map<String, dynamic> item;
  Dec quantity;
  Dec? cost;
  final int? baseLineId;

  /// Pendiente de la solicitud (surtido).
  final Dec? open;

  int get itemId => (item['id'] ?? item['item_id'] as num).toInt();
}

const movementTitles = {
  'transfer-requests': 'Solicitud de traslado',
  'transfers': 'Traslado',
  'goods-receipts': 'Entrada de mercancía',
  'goods-issues': 'Salida de mercancía',
};

/// Captura de un movimiento de inventario: almacén, destino o causalidad y
/// líneas por escaneo. Con [request] surte una solicitud (base_line_id).
class MovementPage extends ConsumerStatefulWidget {
  const MovementPage({super.key, required this.movement, this.request});

  final String movement;
  final Map<String, dynamic>? request;

  @override
  ConsumerState<MovementPage> createState() => _MovementPageState();
}

class _MovementPageState extends ConsumerState<MovementPage> {
  final lines = <MoveLine>[];
  List<Map<String, dynamic>> warehouses = [];
  List<Map<String, dynamic>> causalities = [];
  int? from;
  int? to;
  int? causality;
  bool busy = false;
  final scan = TextEditingController();
  final scanFocus = FocusNode();

  bool get isTransfer => widget.movement == 'transfers' || widget.movement == 'transfer-requests';
  bool get isReceipt => widget.movement == 'goods-receipts';
  bool get isAdjustment => widget.movement == 'goods-receipts' || widget.movement == 'goods-issues';

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    scan.dispose();
    scanFocus.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final db = ref.read(localDbProvider);
    final session = ref.read(sessionProvider)!;
    warehouses = await db.all('warehouses');
    if (warehouses.isEmpty) warehouses = session.warehouses;
    final direction = isReceipt ? 'receipt' : 'issue';
    causalities = (await db.all('causalities')).where((c) => c['applies_to'] == null || c['applies_to'] == 'both' || c['applies_to'] == direction).toList();
    from = session.warehouseId;
    final req = widget.request;
    if (req != null) {
      from = (req['warehouse_id'] as num?)?.toInt() ?? from;
      to = (req['to_warehouse_id'] as num?)?.toInt();
      for (final l in asList(req['lines'])) {
        lines.add(MoveLine({'id': l['item_id'], 'code': l['code'], 'name': l['name']}, Dec.zero,
            baseLineId: (l['base_line_id'] as num).toInt(), open: Dec.parse(l['open'])));
      }
    }
    if (mounted) setState(() {});
  }

  /// Escaneo: "3*CODIGO" suma 3; con solicitud, solo cuenta lo pedido.
  Future<void> _onScan(String text) async {
    scan.clear();
    scanFocus.requestFocus();
    var qty = Dec.one;
    var code = text.trim();
    final m = RegExp(r'^(\d+(?:\.\d+)?)\*(.+)$').firstMatch(code);
    if (m != null) {
      qty = Dec.parse(m.group(1));
      code = m.group(2)!;
    }
    if (code.isEmpty) return;
    final item = await ref.read(localDbProvider).itemByCode(code);
    if (!mounted) return;
    if (item == null) {
      showSnack(context, 'No se encontró $code');
      return;
    }
    _addItem(item, qty);
  }

  void _addItem(Map<String, dynamic> item, Dec qty) {
    final id = (item['id'] as num).toInt();
    final line = lines.where((l) => l.itemId == id && (l.open == null || l.quantity < l.open!)).firstOrNull ??
        lines.where((l) => l.itemId == id).firstOrNull;
    setState(() {
      if (line != null) {
        line.quantity += qty;
        if (line.open != null && line.quantity > line.open!) showSnack(context, 'Llevas más de lo pedido en ${line.item['name']}');
      } else if (widget.request != null) {
        showSnack(context, '${item['name']} no está en la solicitud');
      } else {
        lines.insert(0, MoveLine(item, qty));
      }
    });
  }

  Future<void> _submit() async {
    final ready = lines.where((l) => l.quantity > Dec.zero).toList();
    if (from == null || ready.isEmpty) return;
    if (isTransfer && to == null) return showSnack(context, 'Elige el almacén destino.');
    if (isAdjustment && causality == null) return showSnack(context, 'Elige la causalidad.');
    if (isReceipt && ready.any((l) => l.cost == null)) return showSnack(context, 'Captura el costo de cada artículo.');
    final body = {
      'warehouse_id': from,
      'to_warehouse_id': ?to,
      'causality_id': ?causality,
      'lines': [
        for (final l in ready)
          {
            'item_id': l.itemId,
            'quantity': l.quantity.toJson(4),
            if (l.baseLineId != null) 'base_line_id': l.baseLineId,
            if (l.cost != null) 'cost': l.cost!.toJson(6),
          }
      ],
    };
    setState(() => busy = true);
    final r = await sendWithAuthorization(context, ref, OutboxOp.create('POST', '/inventory/${widget.movement}', body: body, label: movementTitles[widget.movement]!));
    if (!mounted) return;
    setState(() => busy = false);
    if (r == null) return;
    final doc = r.queued ? null : asMap(unwrap(r.response));
    showSnack(context, r.queued ? 'Guardado sin señal; se enviará solo.' : '${movementTitles[widget.movement]} ${doc?['folio'] ?? ''} guardado.');
    Navigator.of(context).pop(true);
  }

  Future<void> _edit(MoveLine l) async {
    final q = TextEditingController(text: l.quantity.toQty());
    final c = TextEditingController(text: l.cost?.toFixed(2) ?? '');
    await showNrSheet<void>(
      context,
      title: '${l.item['name']}',
      subtitle: '${l.item['code'] ?? ''}',
      builder: (ctx) => Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        TextField(
          controller: q,
          autofocus: true,
          textAlign: TextAlign.center,
          style: NrText.huge(ctx).copyWith(fontSize: 48),
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(labelText: 'Cantidad'),
        ),
        if (isReceipt) ...[
          const SizedBox(height: NrSpace.md),
          TextField(controller: c, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Costo unitario', prefixText: r'$ ')),
        ],
        const SizedBox(height: NrSpace.lg),
        NrButton(label: 'Listo', onPressed: () => Navigator.pop(ctx)),
      ]),
    );
    setState(() {
      l.quantity = Dec.tryParse(q.text) ?? l.quantity;
      l.cost = Dec.tryParse(c.text) ?? l.cost;
      if (l.quantity <= Dec.zero && l.baseLineId == null) lines.remove(l);
    });
  }

  @override
  Widget build(BuildContext context) {
    final nr = context.nr;
    final whItems = [
      for (final w in warehouses)
        DropdownMenuItem(value: (w['id'] as num).toInt(), child: Text('${w['code'] ?? ''} ${w['name']}', maxLines: 1, overflow: TextOverflow.ellipsis)),
    ];
    final picked = lines.fold(Dec.zero, (s, l) => s + l.quantity);
    final requested = lines.fold(Dec.zero, (s, l) => s + (l.open ?? Dec.zero));
    final (icon, hue) = switch (widget.movement) {
      'transfer-requests' => (Icons.move_down_rounded, NrColors.hues[0]),
      'transfers' => (Icons.swap_horiz_rounded, NrColors.hues[5]),
      'goods-receipts' => (Icons.add_box_rounded, NrColors.hues[1]),
      _ => (Icons.indeterminate_check_box_rounded, NrColors.hues[4]),
    };
    return Scaffold(
      appBar: AppBar(title: Text(widget.request != null ? 'Surtir ${widget.request!['folio']}' : movementTitles[widget.movement]!)),
      body: ListView(padding: const EdgeInsets.fromLTRB(NrSpace.gutter, NrSpace.xs, NrSpace.gutter, NrSpace.xxxl), children: [
        NrCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(color: nr.tint(hue, 0.13), borderRadius: BorderRadius.circular(NrRadius.lg)),
                child: Icon(icon, color: nr.tone(hue), size: 20),
              ),
              const SizedBox(width: NrSpace.md),
              Expanded(child: Text(isTransfer ? 'DE DÓNDE A DÓNDE' : 'ALMACÉN', style: NrText.eyebrow(context))),
            ]),
            const SizedBox(height: NrSpace.md),
            DropdownButtonFormField<int>(
              isExpanded: true,
              initialValue: whItems.any((i) => i.value == from) ? from : null,
              items: whItems,
              decoration: InputDecoration(labelText: isTransfer ? 'Almacén origen' : 'Almacén', prefixIcon: const Icon(Icons.warehouse_outlined)),
              onChanged: widget.request != null ? null : (v) => setState(() => from = v),
            ),
            if (isTransfer) ...[
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Icon(Icons.south_rounded, color: nr.muted, size: 20),
              ),
              DropdownButtonFormField<int>(
                isExpanded: true,
                initialValue: whItems.any((i) => i.value == to) ? to : null,
                items: whItems,
                decoration: const InputDecoration(labelText: 'Almacén destino', prefixIcon: Icon(Icons.flag_outlined)),
                onChanged: widget.request != null ? null : (v) => setState(() => to = v),
              ),
            ],
            if (isAdjustment) ...[
              const SizedBox(height: NrSpace.md),
              DropdownButtonFormField<int>(
                isExpanded: true,
                initialValue: causality,
                items: [for (final c in causalities) DropdownMenuItem(value: (c['id'] as num).toInt(), child: Text('${c['name']}', maxLines: 1, overflow: TextOverflow.ellipsis))],
                decoration: const InputDecoration(labelText: 'Causalidad', prefixIcon: Icon(Icons.rule_rounded)),
                onChanged: (v) => setState(() => causality = v),
              ),
            ],
          ]),
        ),
        const SizedBox(height: NrSpace.lg),
        // Lector de la terminal (teclado) o cámara.
        TextField(
          controller: scan,
          focusNode: scanFocus,
          autofocus: true,
          style: NrText.body(context).copyWith(fontSize: 18, fontWeight: FontWeight.w500),
          decoration: InputDecoration(
            hintText: 'Escanea o escribe 3*CÓDIGO',
            prefixIcon: Icon(Icons.qr_code_2_rounded, color: nr.night ? nr.link : nr.accent),
            contentPadding: const EdgeInsets.symmetric(vertical: 20),
            suffixIcon: Row(mainAxisSize: MainAxisSize.min, children: [
              IconButton(icon: const Icon(Icons.search_rounded), tooltip: 'Buscar', onPressed: () async {
                final item = await pickItem(context);
                if (item != null) _addItem(item, Dec.one);
              }),
              IconButton(icon: const Icon(Icons.photo_camera_outlined), tooltip: 'Cámara', onPressed: () async {
                final code = await scanBarcode(context);
                if (code != null) _onScan(code);
              }),
            ]),
          ),
          onSubmitted: _onScan,
        ),
        if (widget.request != null) ...[
          const SizedBox(height: NrSpace.lg),
          NrMeter(value: requested.isZero ? 0 : picked.min(requested).divide(requested).toDouble(), height: 8, color: nr.success),
          const SizedBox(height: 6),
          Text('${picked.toQty()} de ${requested.toQty()} surtido', style: NrText.caption(context)),
        ],
        NrSectionHeader('Artículos', count: lines.length, trailing: lines.isEmpty ? null : Text('${picked.toQty()} pzas', style: NrText.money(context, size: 13).copyWith(color: nr.secondary))),
        if (lines.isEmpty)
          const NrCard(depth: NrDepth.flat, child: NrEmpty(compact: true, icon: Icons.qr_code_scanner_rounded, title: 'Escanea el primer artículo', message: 'Con el lector o la cámara. "3*CÓDIGO" suma tres piezas.'))
        else
          for (final (i, l) in lines.indexed)
            Padding(
              padding: const EdgeInsets.only(bottom: NrSpace.sm),
              child: NrEntrance(
                index: i,
                child: NrCard(
                  padding: const EdgeInsets.all(NrSpace.md),
                  onTap: () => _edit(l),
                  accent: l.open == null ? null : (l.quantity == l.open ? nr.success : (l.quantity > l.open! ? nr.danger : null)),
                  child: Row(children: [
                    NrThumb(name: '${l.item['name']}', url: l.item['image_url'] as String?, size: 44),
                    const SizedBox(width: NrSpace.md),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('${l.item['name']}', style: NrText.headline(context).copyWith(fontSize: 15), maxLines: 2, overflow: TextOverflow.ellipsis),
                        Text(
                          [
                            '${l.item['code']}',
                            if (l.open != null) 'pedido ${l.open!.toQty()}',
                            if (l.cost != null) 'costo ${money(l.cost)}',
                          ].join(' · '),
                          style: NrText.caption(context),
                        ),
                      ]),
                    ),
                    Text(l.quantity.toQty(),
                        style: NrText.money(context, size: 24, weight: FontWeight.w700).copyWith(
                          color: l.open == null ? null : (l.quantity == l.open ? nr.success : (l.quantity > l.open! ? nr.danger : null)),
                        )),
                  ]),
                ),
              ),
            ),
      ]),
      bottomNavigationBar: NrBottomAction(label: 'Guardar', icon: Icons.check_rounded, busy: busy, onPressed: lines.isEmpty ? null : _submit),
    );
  }
}

/// Solicitudes de traslado pendientes para surtir.
class TransferRequestsPage extends ConsumerStatefulWidget {
  const TransferRequestsPage({super.key});

  @override
  ConsumerState<TransferRequestsPage> createState() => _TransferRequestsPageState();
}

class _TransferRequestsPageState extends ConsumerState<TransferRequestsPage> {
  late Future<List<Map<String, dynamic>>> future = _load();

  Future<List<Map<String, dynamic>>> _load() async {
    final wh = ref.read(sessionProvider)?.warehouseId;
    return asList(unwrap(await ref.read(apiProvider).get('/inventory/transfer-requests/pending', query: {'warehouse_id': ?wh})));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Solicitudes por surtir')),
      body: FutureBuilder(
        future: future,
        builder: (context, snap) {
          if (snap.hasError) return NrErrorView(snap.error!, onRetry: () => setState(() => future = _load()));
          if (!snap.hasData) return const NrSkeletonList(count: 5);
          final rows = snap.data!;
          if (rows.isEmpty) return const NrEmpty(icon: Icons.inbox_rounded, title: 'Nada por surtir', message: 'Las solicitudes de traslado hacia tu almacén aparecerán aquí.');
          return ListView(padding: const EdgeInsets.all(NrSpace.gutter), children: [
            NrGroup(children: [
              for (final r in rows)
                NrListRow(
                  title: '${r['folio']} · ${r['from'] ?? ''} → ${r['to'] ?? ''}',
                  subtitle: '${r['date']} · ${r['lines']} líneas · pendiente ${Dec.parse(r['pending']).toQty()}',
                  trailing: SizedBox(
                    width: 64,
                    child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.end, children: [
                      Text('${r['progress'] ?? 0} %', style: NrText.money(context, size: 14, weight: FontWeight.w700)),
                      const SizedBox(height: 4),
                      NrMeter(value: ((r['progress'] as num?) ?? 0) / 100, height: 4),
                    ]),
                  ),
                  onTap: () async {
                    try {
                      final detail = asMap(unwrap(await ref.read(apiProvider).get('/inventory/transfer-requests/${r['id']}/open-lines')));
                      if (!context.mounted) return;
                      final done = await Navigator.of(context).push<bool>(
                          MaterialPageRoute(builder: (_) => MovementPage(movement: 'transfers', request: detail)));
                      if (done == true) setState(() => future = _load());
                    } catch (e) {
                      if (context.mounted) showSnack(context, '$e');
                    }
                  },
                ),
            ]),
          ]);
        },
      ),
    );
  }
}
