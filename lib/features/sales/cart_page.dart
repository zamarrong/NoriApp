import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/design/design.dart';
import '../../core/providers.dart';
import '../../core/widgets/pickers.dart';
import 'cart.dart';

/// Captura de artículos para venta, pedido, cotización o recolección.
/// [onSubmit] arma y manda la escritura; regresa true si terminó.
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
  });

  final String title;
  final String customerName;
  final String submitLabel;
  final Future<Map<String, dynamic>> Function(List<Map<String, dynamic>> lines)? quote;
  final Future<bool> Function(BuildContext context, CartController cart) onSubmit;
  final int? priceListId;

  /// Carrito sugerido ({item_id, quantity}).
  final List<Map<String, dynamic>> initial;

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
    if (widget.initial.isNotEmpty) cart.reprice();
  }

  @override
  void dispose() {
    cart.dispose();
    super.dispose();
  }

  Future<void> _add() async {
    final item = await pickItem(context);
    if (item != null) cart.add(item);
  }

  Future<void> _scan() async {
    final code = await scanBarcode(context);
    if (code == null) return;
    final item = await ref.read(localDbProvider).itemByCode(code);
    if (!mounted) return;
    if (item == null) {
      showSnack(context, 'No se encontró el código $code');
    } else {
      cart.add(item);
    }
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
          decoration: const InputDecoration(labelText: 'Cantidad'),
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
          actions: [IconButton(icon: const Icon(Icons.qr_code_scanner), tooltip: 'Escanear', onPressed: _scan)],
        ),
        floatingActionButton: FloatingActionButton.extended(onPressed: _add, icon: const Icon(Icons.add), label: const Text('Artículo')),
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
                          onPressed: () => cart.setQuantity(l, l.quantity + Dec.one),
                        ),
                      ]),
                      trailing: l.total == null ? null : NrMoney(l.total),
                      onTap: () => _editQty(l),
                    ),
                ]),
                const SizedBox(height: NrSpace.lg),
                NrCard(
                  child: Column(children: [
                    _row(context, 'Subtotal', money(cart.totals.subtotal)),
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
