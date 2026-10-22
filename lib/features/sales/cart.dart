import 'package:flutter/foundation.dart';

import '../../core/api/api_client.dart';
import '../../core/api/api_error.dart';
import '../../core/db/local_db.dart';
import '../../core/util/decimal.dart';

class CartLine {
  CartLine({required this.item, required this.quantity, this.uomId, this.uomName, this.choices, this.baseLineId, this.maxQuantity});

  final Map<String, dynamic> item;
  Dec quantity;

  /// Unidad de venta elegida (null = la unidad de venta del artículo).
  int? uomId;
  String? uomName;

  /// Elección de un paquete: {id de grupo: {id de artículo: cuántos}} por unidad.
  Map<String, Map<String, int>>? choices;

  /// Copiada de esta línea de un documento base (devolución de una entrega).
  final int? baseLineId;

  /// Lo que queda abierto en la línea base: no se puede pasar.
  final Dec? maxQuantity;

  /// Precio unitario y total según el motor (en línea) o la lista guardada (sin señal).
  Dec? price;
  Dec? total;
  String? error;

  int get itemId => (item['id'] as num).toInt();
  String get name => '${item['name'] ?? item['description'] ?? ''}';
  String get code => '${item['code'] ?? item['item_code'] ?? ''}';
  bool get isPackage => item['is_package'] == true;

  Map<String, dynamic> toApi() => {
        'item_id': itemId,
        'quantity': quantity.toJson(4),
        'uom_id': ?uomId,
        'base_line_id': ?baseLineId,
        if (choices != null && choices!.isNotEmpty) 'choices': choices,
      };
}

class CartTotals {
  const CartTotals({required this.subtotal, required this.tax, required this.total, required this.estimated, this.discount});

  final Dec subtotal;
  final Dec tax;
  final Dec total;
  final Dec? discount;

  /// true = calculado en el teléfono con precios de lista (sin descuentos ni impuestos del motor).
  final bool estimated;

  static final empty = CartTotals(subtotal: Dec.zero, tax: Dec.zero, total: Dec.zero, estimated: false);
}

/// Precio de referencia sin señal: precio de lista × cantidad, menos el
/// descuento del encabezado. Las líneas sin precio guardado quedan marcadas.
/// [byLine] (precio por línea, p. ej. según su unidad) manda sobre [listPrices]
/// (precio por artículo). El servidor recalcula al guardar.
CartTotals estimateOffline(List<CartLine> lines, Map<int, Dec> listPrices, {Map<CartLine, Dec>? byLine, Dec? discountPercent}) {
  var subtotal = Dec.zero;
  for (final l in lines) {
    final p = byLine?[l] ?? listPrices[l.itemId];
    l.price = p;
    l.error = p == null ? 'Sin precio guardado' : null;
    l.total = p == null ? null : (p * l.quantity).round(2);
    if (l.total != null) subtotal += l.total!;
  }
  final discount = discountPercent == null || discountPercent.isZero ? Dec.zero : (subtotal * discountPercent.divide(Dec.parse('100'))).round(2);
  return CartTotals(subtotal: subtotal, tax: Dec.zero, total: subtotal - discount, estimated: true, discount: discount.isZero ? null : discount);
}

/// Aplica la respuesta de `/pricing/recalculate` o `/route/visits/{id}/quote`.
CartTotals applyQuote(List<CartLine> lines, Map<String, dynamic> data) {
  final quoted = asList(data['lines']);
  final errors = asMap(data['errors']);
  for (var i = 0; i < lines.length; i++) {
    final q = i < quoted.length ? quoted[i] : null;
    lines[i]
      ..price = q == null ? null : Dec.parse(q['unit_price'] ?? q['price'])
      ..total = q == null ? null : Dec.parse(q['total'])
      ..error = errors['$i']?.toString();
  }
  final t = asMap(data['totals']);
  final discount = Dec.tryParse('${t['discount_total'] ?? ''}');
  return CartTotals(
    subtotal: Dec.parse(t['subtotal']),
    tax: Dec.parse(t['tax_total']),
    total: Dec.parse(t['total']),
    estimated: false,
    discount: discount == null || discount.isZero ? null : discount,
  );
}

/// Precio de lista guardado de un artículo (su lista o la primera permitida),
/// en la unidad pedida; sin ella, la unidad de venta (uom_id nulo) primero.
Future<Dec?> cachedListPrice(LocalDb db, int itemId, {int? priceListId, int? uomId}) async {
  final rows = await db.byRefs('item_prices', ref1: itemId, ref2: priceListId);
  final candidates = rows.isNotEmpty || priceListId == null ? rows : await db.byRefs('item_prices', ref1: itemId);
  if (candidates.isEmpty) return null;
  if (uomId != null) {
    final exact = candidates.where((r) => (r['uom_id'] as num?)?.toInt() == uomId).firstOrNull;
    if (exact != null) return Dec.parse(exact['price']);
  }
  candidates.sort((a, b) => (a['uom_id'] == null ? 0 : 1).compareTo(b['uom_id'] == null ? 0 : 1));
  return Dec.parse(candidates.first['price']);
}

/// Precios de lista guardados para un cliente (su lista o la primera permitida).
Future<Map<int, Dec>> cachedListPrices(LocalDb db, List<int> itemIds, int? priceListId) async {
  final out = <int, Dec>{};
  for (final id in itemIds) {
    final p = await cachedListPrice(db, id, priceListId: priceListId);
    if (p != null) out[id] = p;
  }
  return out;
}

/// Firma del cotizador: líneas y encabezado (descuento, etc.).
typedef CartQuote = Future<Map<String, dynamic>> Function(List<Map<String, dynamic>> lines, Map<String, dynamic> header);

/// Carrito con precio del motor cuando hay señal y estimado cuando no.
class CartController extends ChangeNotifier {
  CartController({required this.quote, required this.db, this.priceListId});

  /// Llama al motor de precios con las líneas; null = no hay cotizador.
  final CartQuote? quote;
  final LocalDb db;
  final int? priceListId;

  final List<CartLine> lines = [];
  CartTotals totals = CartTotals.empty;
  bool pricing = false;
  int _seq = 0;

  /// Descuento del encabezado (%) y notas del documento.
  Dec? discountPercent;
  String notes = '';

  Map<String, dynamic> get header => {if (discountPercent != null && !discountPercent!.isZero) 'discount_percent': discountPercent!.toJson(4)};

  void add(Map<String, dynamic> item, [Dec? qty, int? uomId, String? uomName, Map<String, Map<String, int>>? choices]) {
    final id = (item['id'] as num).toInt();
    final existing = choices == null ? lines.where((l) => l.itemId == id && l.uomId == uomId && l.choices == null && l.baseLineId == null).firstOrNull : null;
    if (existing != null) {
      existing.quantity += qty ?? Dec.one;
    } else {
      lines.add(CartLine(item: item, quantity: qty ?? Dec.one, uomId: uomId, uomName: uomName, choices: choices));
    }
    reprice();
  }

  void setQuantity(CartLine line, Dec qty) {
    if (qty <= Dec.zero) {
      lines.remove(line);
    } else {
      line.quantity = line.maxQuantity != null && qty > line.maxQuantity! ? line.maxQuantity! : qty;
    }
    reprice();
  }

  void setUom(CartLine line, int? uomId, String? uomName) {
    line
      ..uomId = uomId
      ..uomName = uomName;
    reprice();
  }

  void setDiscount(Dec? percent) {
    discountPercent = percent;
    reprice();
  }

  Future<CartTotals> _estimate() async {
    final byLine = <CartLine, Dec>{};
    for (final l in lines) {
      final p = await cachedListPrice(db, l.itemId, priceListId: priceListId, uomId: l.uomId);
      if (p != null) byLine[l] = p;
    }
    return estimateOffline(lines, const {}, byLine: byLine, discountPercent: discountPercent);
  }

  Future<void> reprice() async {
    final seq = ++_seq;
    pricing = true;
    notifyListeners();
    CartTotals next;
    if (lines.isEmpty) {
      next = CartTotals.empty;
    } else {
      try {
        if (quote == null) throw ApiException(code: 'network', message: '');
        next = applyQuote(lines, await quote!(lines.map((l) => l.toApi()).toList(), header));
      } on ApiException catch (e) {
        next = await _estimate();
        // El motor rechazó el carrito: se muestra el motivo y se estima.
        if (!e.isNetwork && lines.isNotEmpty) lines.first.error ??= e.userMessage;
      }
    }
    if (seq != _seq) return; // llegó una respuesta más nueva
    totals = next;
    pricing = false;
    notifyListeners();
  }
}
