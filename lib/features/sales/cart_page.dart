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
    final picked = await showNrSheet<Map<String, dynamic>>(
      context,
      title: 'Unidad',
      subtitle: line.name,
      builder: (ctx) => Column(mainAxisSize: MainAxisSize.min, children: [
        for (final u in units)
          Padding(
            padding: const EdgeInsets.only(bottom: NrSpace.sm),
            child: NrCard(
              depth: NrDepth.flat,
              color: u['id'] == line.uomId ? ctx.nr.accentSoft : null,
              borderColor: u['id'] == line.uomId ? ctx.nr.accent : null,
              padding: const EdgeInsets.symmetric(horizontal: NrSpace.lg, vertical: NrSpace.md),
              onTap: () => Navigator.pop(ctx, u),
              child: Row(children: [
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('${u['name']}', style: NrText.headline(ctx)),
                    if (u['base_quantity'] != null) Text('Equivale a ${Dec.parse(u['base_quantity']).toQty()}', style: NrText.caption(ctx)),
                  ]),
                ),
                if (u['id'] == line.uomId) Icon(Icons.check_circle_rounded, color: ctx.nr.accent),
              ]),
            ),
          ),
      ]),
    );
    if (picked != null) cart.setUom(line, (picked['id'] as num?)?.toInt(), '${picked['name']}');
  }

  Future<void> _editQty(CartLine line) async {
    final ctrl = TextEditingController(text: line.quantity.toQty());
    final v = await showNrSheet<String>(
      context,
      title: line.name,
      subtitle: line.maxQuantity == null ? 'Cantidad' : 'Máximo ${line.maxQuantity!.toQty()}',
      builder: (ctx) => Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        TextField(
          controller: ctrl,
          autofocus: true,
          textAlign: TextAlign.center,
          style: NrText.huge(ctx).copyWith(fontSize: 48),
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(hintText: '0'),
          onSubmitted: (t) => Navigator.pop(ctx, t),
        ),
        const SizedBox(height: NrSpace.lg),
        Row(children: [
          Expanded(child: NrButton(label: 'Quitar', icon: Icons.delete_outline_rounded, variant: NrButtonVariant.danger, onPressed: () => Navigator.pop(ctx, '0'))),
          const SizedBox(width: NrSpace.md),
          Expanded(flex: 2, child: NrButton(label: 'Listo', onPressed: () => Navigator.pop(ctx, ctrl.text))),
        ]),
      ]),
    );
    final q = Dec.tryParse(v);
    if (q != null) cart.setQuantity(line, q);
  }

  void _remove(CartLine line) {
    final index = cart.lines.indexOf(line);
    final qty = line.quantity;
    NrHaptics.action();
    cart.setQuantity(line, Dec.zero);
    showSnack(context, '${line.name} quitado', action: 'Deshacer', onAction: () {
      line.quantity = qty;
      cart.lines.insert(index.clamp(0, cart.lines.length), line);
      cart.reprice();
    });
  }

  Future<void> _header() async {
    final discount = TextEditingController(text: cart.discountPercent?.toQty() ?? '');
    final notes = TextEditingController(text: cart.notes);
    final ok = await showNrSheet<bool>(
      context,
      title: 'Descuento y notas',
      builder: (ctx) => Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        TextField(
          controller: discount,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(labelText: 'Descuento general', suffixText: '%', prefixIcon: Icon(Icons.percent_rounded)),
        ),
        const SizedBox(height: NrSpace.md),
        TextField(controller: notes, maxLines: 3, decoration: const InputDecoration(labelText: 'Notas para el documento')),
        const SizedBox(height: NrSpace.xl),
        NrButton(label: 'Aplicar', onPressed: () => Navigator.pop(ctx, true)),
      ]),
    );
    if (ok != true) return;
    cart.notes = notes.text.trim();
    cart.setDiscount(Dec.tryParse(discount.text));
  }

  Future<void> _submit() async {
    setState(() => busy = true);
    try {
      final done = await widget.onSubmit(context, cart);
      if (done && mounted) Navigator.of(context).pop(true);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final nr = context.nr;
    return ListenableBuilder(
      listenable: cart,
      builder: (context, _) {
        final units = cart.lines.fold(Dec.zero, (s, l) => s + l.quantity);
        return Scaffold(
          appBar: AppBar(
            title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(widget.title),
              Text(widget.customerName, style: NrText.caption(context), maxLines: 1, overflow: TextOverflow.ellipsis),
            ]),
            actions: [
              if (widget.allowHeader)
                IconButton(
                  icon: Badge(isLabelVisible: cart.discountPercent != null || cart.notes.isNotEmpty, smallSize: 8, backgroundColor: nr.accent, child: const Icon(Icons.tune_rounded)),
                  tooltip: 'Descuento y notas',
                  onPressed: _header,
                ),
            ],
          ),
          body: cart.lines.isEmpty
              ? NrEmpty(
                  icon: Icons.shopping_basket_rounded,
                  title: 'Carrito vacío',
                  message: 'Busca o escanea artículos. Los precios se calculan con la lista del cliente.',
                  action: widget.allowAdd ? 'Buscar artículo' : null,
                  onAction: widget.allowAdd ? _add : null,
                )
              : ListView(padding: const EdgeInsets.fromLTRB(NrSpace.gutter, NrSpace.sm, NrSpace.gutter, NrSpace.xxxl), children: [
                  for (final (i, l) in cart.lines.indexed)
                    Padding(
                      key: ObjectKey(l),
                      padding: const EdgeInsets.only(bottom: NrSpace.sm),
                      child: NrEntrance(index: i, child: _lineCard(context, l)),
                    ),
                  if (widget.allowAdd)
                    Row(children: [
                      Expanded(child: NrButton(label: 'Agregar', icon: Icons.add_rounded, variant: NrButtonVariant.secondary, height: NrTouch.min, onPressed: _add)),
                      const SizedBox(width: NrSpace.sm),
                      Expanded(child: NrButton(label: 'Escanear', icon: Icons.qr_code_scanner_rounded, variant: NrButtonVariant.secondary, height: NrTouch.min, onPressed: _scan)),
                    ]),
                  const SizedBox(height: NrSpace.lg),
                  _summary(context),
                  if (widget.allowHeader && (cart.discountPercent != null || cart.notes.isNotEmpty)) ...[
                    const SizedBox(height: NrSpace.md),
                    NrCard(
                      onTap: _header,
                      child: Row(children: [
                        Icon(Icons.sticky_note_2_outlined, color: nr.muted),
                        const SizedBox(width: NrSpace.md),
                        Expanded(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            if (cart.discountPercent != null && !cart.discountPercent!.isZero)
                              Text('Descuento general ${cart.discountPercent!.toQty()} %', style: NrText.headline(context).copyWith(fontSize: 15)),
                            if (cart.notes.isNotEmpty) Text(cart.notes, style: NrText.bodySm(context)),
                          ]),
                        ),
                      ]),
                    ),
                  ],
                ]),
          bottomNavigationBar: NrBottomBar(
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Row(children: [
                AnimatedSwitcher(
                  duration: NrMotion.base,
                  transitionBuilder: (c, a) => ScaleTransition(scale: a, child: c),
                  child: Container(
                    key: ValueKey(cart.lines.length),
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(color: nr.accentSoft, borderRadius: BorderRadius.circular(NrRadius.pill)),
                    child: Text('${cart.lines.length} ${cart.lines.length == 1 ? 'artículo' : 'artículos'} · ${units.toQty()} pzas',
                        style: NrText.caption(context).copyWith(color: nr.night ? nr.link : nr.accent, fontWeight: FontWeight.w700)),
                  ),
                ),
                const Spacer(),
                if (cart.pricing) ...[SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 1.6, color: nr.muted)), const SizedBox(width: 8)],
                NrAmount(cart.totals.total, size: 24, animate: true),
              ]),
              const SizedBox(height: NrSpace.md),
              NrButton(label: widget.submitLabel, icon: Icons.check_rounded, busy: busy, onPressed: cart.lines.isEmpty || cart.pricing ? null : _submit),
            ]),
          ),
        );
      },
    );
  }

  Widget _lineCard(BuildContext context, CartLine l) {
    final nr = context.nr;
    final card = NrCard(
      padding: const EdgeInsets.all(NrSpace.md),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          NrThumb(name: l.name, url: l.item['image_url'] as String?, size: 52),
          const SizedBox(width: NrSpace.md),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(l.name, style: NrText.headline(context).copyWith(fontSize: 15), maxLines: 2, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 2),
              Text(
                [
                  l.code,
                  if (l.price != null) '${money(l.price)} c/u',
                  if (l.choices != null) 'Paquete con elección',
                ].where((e) => e.isNotEmpty).join(' · '),
                style: NrText.caption(context),
              ),
            ]),
          ),
          const SizedBox(width: NrSpace.sm),
          l.total == null ? Text('—', style: NrText.money(context, size: 16).copyWith(color: nr.muted)) : NrAmount(l.total, size: 17, animate: true),
        ]),
        if (l.error != null) ...[
          const SizedBox(height: NrSpace.sm),
          Row(children: [
            Icon(Icons.error_outline_rounded, size: 14, color: nr.danger),
            const SizedBox(width: 4),
            Expanded(child: Text(l.error!, style: NrText.caption(context).copyWith(color: nr.danger))),
          ]),
        ],
        const SizedBox(height: NrSpace.sm),
        Row(children: [
          if (l.baseLineId == null)
            InkWell(
              borderRadius: BorderRadius.circular(NrRadius.md),
              onTap: () => _unit(l),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(border: Border.all(color: nr.border), borderRadius: BorderRadius.circular(NrRadius.md)),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Text(l.uomName ?? 'Unidad', style: NrText.caption(context).copyWith(color: nr.body, fontWeight: FontWeight.w600)),
                  Icon(Icons.expand_more_rounded, size: 16, color: nr.muted),
                ]),
              ),
            ),
          const Spacer(),
          NrStepper(
            value: l.quantity,
            max: l.maxQuantity,
            compact: true,
            onTapValue: () => _editQty(l),
            onChanged: (q) => q.isZero ? _remove(l) : cart.setQuantity(l, q),
          ),
        ]),
      ]),
    );
    return Dismissible(
      key: ObjectKey(l),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: NrSpace.xl),
        decoration: BoxDecoration(color: nr.danger, borderRadius: BorderRadius.circular(NrRadius.xxl)),
        child: const Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.delete_outline_rounded, color: Colors.white),
          SizedBox(width: 6),
          Text('Quitar', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
        ]),
      ),
      onDismissed: (_) => _remove(l),
      child: card,
    );
  }

  Widget _summary(BuildContext context) {
    final nr = context.nr;
    final t = cart.totals;
    return NrCard(
      child: AnimatedSize(
        duration: NrMotion.base,
        curve: NrMotion.ease,
        alignment: Alignment.topCenter,
        child: Column(children: [
          _row(context, 'Subtotal', money(t.subtotal)),
          if (t.discount != null) _row(context, 'Descuento', '−${money(t.discount)}', color: nr.success),
          if (!t.tax.isZero) _row(context, 'Impuestos', money(t.tax)),
          Padding(padding: const EdgeInsets.symmetric(vertical: NrSpace.sm), child: Divider(color: nr.border, height: 1)),
          Row(children: [
            Expanded(child: Text('Total', style: NrText.headline(context))),
            NrAmount(t.total, size: 26, animate: true),
          ]),
          if (t.estimated) ...[
            const SizedBox(height: NrSpace.md),
            const NrBanner(message: 'Estimado con precios de lista guardados. El servidor calcula el precio final al guardar.', icon: Icons.cloud_off_rounded),
          ],
        ]),
      ),
    );
  }

  Widget _row(BuildContext context, String label, String value, {Color? color}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(children: [
          Expanded(child: Text(label, style: NrText.body(context).copyWith(color: context.nr.secondary))),
          Text(value, style: NrText.money(context, size: 15).copyWith(color: color)),
        ]),
      );
}
