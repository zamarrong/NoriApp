import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/design/design.dart';
import '../../core/providers.dart';
import '../../core/widgets/pickers.dart';
import 'cart.dart';
import 'item_support.dart';

/// Captura de artículos para venta, pedido, cotización, entrega, factura,
/// devolución o recolección. [onSubmit] arma y manda la escritura; regresa
/// true si terminó.
class CartPage extends ConsumerStatefulWidget {
  const CartPage({
    super.key,
    required this.title,
    required this.customerName,
    required this.submitLabel,
    required this.quote,
    required this.onSubmit,
    this.priceListId,
    this.initial = const [],
    this.initialLines = const [],
    this.allowHeader = false,
    this.allowAdd = true,
  });

  final String title;
  final String customerName;
  final String submitLabel;
  final CartQuote? quote;
  final Future<bool> Function(BuildContext context, CartController cart) onSubmit;
  final int? priceListId;

  /// Carrito sugerido ({item_id, quantity}).
  final List<Map<String, dynamic>> initial;

  /// Líneas ya armadas (copiadas de un documento o traídas del checador).
  final List<CartLine> initialLines;

  /// Descuento del encabezado y notas.
  final bool allowHeader;

  /// false = solo se ajustan las líneas dadas (devolución de una entrega).
  final bool allowAdd;

  @override
  ConsumerState<CartPage> createState() => _CartPageState();
}

class _CartPageState extends ConsumerState<CartPage> {
  late final CartController cart;
  bool busy = false;

  @override
  void initState() {
    super.initState();
    cart = CartController(quote: widget.quote, db: ref.read(localDbProvider), priceListId: widget.priceListId);
    _loadInitial();
  }

  Future<void> _loadInitial() async {
    final db = ref.read(localDbProvider);
    for (final s in widget.initial) {
      final id = (s['item_id'] as num).toInt();
      final item = await db.find('items', id) ?? {'id': id, 'name': s['name'] ?? 'Artículo $id', 'code': s['code'] ?? ''};
      cart.lines.add(CartLine(item: item, quantity: Dec.parse(s['quantity'])));
    }
    cart.lines.addAll(widget.initialLines);
    if (cart.lines.isNotEmpty) cart.reprice();
  }

  @override
  void dispose() {
    cart.dispose();
    super.dispose();
  }

  Future<void> _addItem(Map<String, dynamic> item) async {
    final choices = await pickPackageChoices(context, ref, item);
    if (choices == null) return;
    cart.add(item, null, null, null, choices.isEmpty ? null : choices);
  }

  Future<void> _add() async {
    final item = await pickItem(context);
    if (item != null && mounted) await _addItem(item);
  }

  Future<void> _scan() async {
    final code = await scanBarcode(context);
    if (code == null || !mounted) return;
    final item = await findItemByCode(ref, code);
    if (!mounted) return;
    if (item == null) {
      showSnack(context, 'No se encontró el código $code');
    } else {
      await _addItem(item);
    }
  }

  Future<void> _unit(CartLine line) async {
    final units = await itemUnits(ref, line.item);
    if (!mounted) return;
    if (units.length <= 1) {
      showSnack(context, 'Este artículo se vende en una sola unidad.');
      return;
    }
    final picked = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Padding(padding: const EdgeInsets.all(NrSpace.lg), child: Text('Unidad de ${line.name}', style: NrText.headline(ctx))),
          for (final u in units)
            ListTile(
              title: Text('${u['name']}'),
              subtitle: u['base_quantity'] == null ? null : Text('Equivale a ${Dec.parse(u['base_quantity']).toQty()}'),
              trailing: u['id'] == line.uomId ? const Icon(Icons.check) : null,
              onTap: () => Navigator.pop(ctx, u),
            ),
        ]),
      ),
    );
    if (picked != null) cart.setUom(line, (picked['id'] as num?)?.toInt(), '${picked['name']}');
  }

  Future<void> _editQty(CartLine line) async {
    final ctrl = TextEditingController(text: line.quantity.toQty());
    final v = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(line.name),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(labelText: 'Cantidad', helperText: line.maxQuantity == null ? null : 'Máximo ${line.maxQuantity!.toQty()}'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, '0'), child: const Text('Quitar')),
          FilledButton(onPressed: () => Navigator.pop(context, ctrl.text), child: const Text('Listo')),
        ],
      ),
    );
    final q = Dec.tryParse(v);
    if (q != null) cart.setQuantity(line, q);
  }

  Future<void> _header() async {
    final discount = TextEditingController(text: cart.discountPercent?.toQty() ?? '');
    final notes = TextEditingController(text: cart.notes);
    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(NrSpace.xl, 0, NrSpace.xl, MediaQuery.of(ctx).viewInsets.bottom + NrSpace.xl),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text('Descuento y notas', style: NrText.title(ctx)),
          const SizedBox(height: NrSpace.lg),
          TextField(
            controller: discount,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(labelText: 'Descuento general', suffixText: '%'),
          ),
          const SizedBox(height: NrSpace.md),
          TextField(controller: notes, maxLines: 3, decoration: const InputDecoration(labelText: 'Notas')),
          const SizedBox(height: NrSpace.lg),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Aplicar')),
        ]),
      ),
    );
    if (ok != true) return;
    cart.notes = notes.text.trim();
    cart.setDiscount(Dec.tryParse(discount.text));
  }

  @override
  Widget build(BuildContext context) {
    final nr = context.nr;
    return ListenableBuilder(
      listenable: cart,
      builder: (context, _) => Scaffold(
        appBar: AppBar(
          title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(widget.title),
            Text(widget.customerName, style: NrText.caption(context)),
          ]),
          actions: [
            if (widget.allowHeader) IconButton(icon: const Icon(Icons.percent), tooltip: 'Descuento y notas', onPressed: _header),
            if (widget.allowAdd) IconButton(icon: const Icon(Icons.qr_code_scanner), tooltip: 'Escanear', onPressed: _scan),
          ],
        ),
        floatingActionButton:
            widget.allowAdd ? FloatingActionButton.extended(onPressed: _add, icon: const Icon(Icons.add), label: const Text('Artículo')) : null,
        body: cart.lines.isEmpty
            ? const NrEmpty(icon: Icons.shopping_basket_outlined, title: 'Carrito vacío', message: 'Busca o escanea artículos.')
            : ListView(padding: const EdgeInsets.fromLTRB(NrSpace.gutter, NrSpace.sm, NrSpace.gutter, 120), children: [
                NrGroup(children: [
                  for (final l in cart.lines)
                    NrListRow(
                      title: l.name,
                      subtitle: [
                        l.code,
                        if (l.price != null) '${l.quantity.toQty()} × ${money(l.price)}',
                        if (l.choices != null) 'Paquete con elección',
                        ?l.error,
                      ].where((e) => e.isNotEmpty).join(' · '),
                      leading: Row(mainAxisSize: MainAxisSize.min, children: [
                        IconButton(
                          visualDensity: VisualDensity.compact,
                          icon: const Icon(Icons.remove_circle_outline),
                          onPressed: () => cart.setQuantity(l, l.quantity - Dec.one),
                        ),
                        GestureDetector(onTap: () => _editQty(l), child: Text(l.quantity.toQty(), style: NrText.money(context, size: 17))),
                        IconButton(
                          visualDensity: VisualDensity.compact,
                          icon: const Icon(Icons.add_circle_outline),
                          onPressed: l.maxQuantity != null && l.quantity >= l.maxQuantity! ? null : () => cart.setQuantity(l, l.quantity + Dec.one),
                        ),
                      ]),
                      trailing: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.end, children: [
                        if (l.total != null) NrMoney(l.total),
                        if (l.baseLineId == null)
                          InkWell(
                            onTap: () => _unit(l),
                            child: Padding(
                              padding: const EdgeInsets.only(top: 2),
                              child: Text(l.uomName ?? 'Unidad', style: NrText.caption(context).copyWith(color: nr.accent)),
                            ),
                          ),
                      ]),
                      onTap: () => _editQty(l),
                    ),
                ]),
                const SizedBox(height: NrSpace.lg),
                NrCard(
                  child: Column(children: [
                    _row(context, 'Subtotal', money(cart.totals.subtotal)),
                    if (cart.totals.discount != null) _row(context, 'Descuento', '−${money(cart.totals.discount)}'),
                    if (!cart.totals.tax.isZero) _row(context, 'Impuestos', money(cart.totals.tax)),
                    const Divider(height: NrSpace.xl),
                    _row(context, 'Total', money(cart.totals.total), strong: true),
                    if (cart.totals.estimated) ...[
                      const SizedBox(height: NrSpace.sm),
                      Row(children: [
                        Icon(Icons.cloud_off, size: 14, color: nr.warning),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text('Estimado con precios de lista guardados. El servidor calcula el precio final al guardar.',
                              style: NrText.caption(context).copyWith(color: nr.warning)),
                        ),
                      ]),
                    ],
                    if (cart.pricing) const Padding(padding: EdgeInsets.only(top: NrSpace.sm), child: LinearProgressIndicator()),
                  ]),
                ),
                if (widget.allowHeader && (cart.discountPercent != null || cart.notes.isNotEmpty)) ...[
                  const SizedBox(height: NrSpace.md),
                  NrCard(
                    onTap: _header,
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      if (cart.discountPercent != null && !cart.discountPercent!.isZero)
                        Text('Descuento general ${cart.discountPercent!.toQty()} %', style: NrText.body(context)),
                      if (cart.notes.isNotEmpty) Text(cart.notes, style: NrText.bodySm(context)),
                    ]),
                  ),
                ],
              ]),
        bottomNavigationBar: NrBottomAction(
          label: widget.submitLabel,
          busy: busy,
          onPressed: cart.lines.isEmpty
              ? null
              : () async {
                  setState(() => busy = true);
                  try {
                    final done = await widget.onSubmit(context, cart);
                    if (done && context.mounted) Navigator.of(context).pop(true);
                  } finally {
                    if (mounted) setState(() => busy = false);
                  }
                },
        ),
      ),
    );
  }

  Widget _row(BuildContext context, String label, String value, {bool strong = false}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(children: [
          Expanded(child: Text(label, style: strong ? NrText.headline(context) : NrText.body(context))),
          Text(value, style: NrText.money(context, size: strong ? 20 : 15)),
        ]),
      );
}
