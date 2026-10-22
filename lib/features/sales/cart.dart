import 'package:flutter/foundation.dart';

import '../../core/api/api_client.dart';
import '../../core/api/api_error.dart';
import '../../core/db/local_db.dart';
import '../../core/util/decimal.dart';

class CartLine {
  CartLine({required this.item, required this.quantity});

  final Map<String, dynamic> item;
  Dec quantity;

  /// Precio unitario y total según el motor (en línea) o la lista guardada (sin señal).
  Dec? price;
  Dec? total;
  String? error;

  int get itemId => (item['id'] as num).toInt();
  String get name => '${item['name'] ?? item['description'] ?? ''}';
  String get code => '${item['code'] ?? item['item_code'] ?? ''}';

  Map<String, dynamic> toApi() => {'item_id': itemId, 'quantity': quantity.toJson(4)};
}

class CartTotals {
  const CartTotals({required this.subtotal, required this.tax, required this.total, required this.estimated});

  final Dec subtotal;
  final Dec tax;
  final Dec total;

  /// true = calculado en el teléfono con precios de lista (sin descuentos ni impuestos del motor).
  final bool estimated;

  static final empty = CartTotals(subtotal: Dec.zero, tax: Dec.zero, total: Dec.zero, estimated: false);
}

/// Precio de referencia sin señal: precio de lista × cantidad. Las líneas sin
/// precio guardado quedan marcadas. El servidor recalcula al guardar.
CartTotals estimateOffline(List<CartLine> lines, Map<int, Dec> listPrices) {
  var subtotal = Dec.zero;
  for (final l in lines) {
    final p = listPrices[l.itemId];
    l.price = p;
    l.error = p == null ? 'Sin precio guardado' : null;
    l.total = p == null ? null : (p * l.quantity).round(2);
    if (l.total != null) subtotal += l.total!;
  }
  return CartTotals(subtotal: subtotal, tax: Dec.zero, total: subtotal, estimated: true);
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
  return CartTotals(subtotal: Dec.parse(t['subtotal']), tax: Dec.parse(t['tax_total']), total: Dec.parse(t['total']), estimated: false);
}

/// Precios de lista guardados para un cliente (su lista o la primera permitida).
Future<Map<int, Dec>> cachedListPrices(LocalDb db, List<int> itemIds, int? priceListId) async {
  final out = <int, Dec>{};
  for (final id in itemIds) {
    final rows = await db.byRefs('item_prices', ref1: id, ref2: priceListId);
    final candidates = rows.isNotEmpty || priceListId == null ? rows : await db.byRefs('item_prices', ref1: id);
    if (candidates.isEmpty) continue;
    // La unidad base (uom_id nulo) primero.
    candidates.sort((a, b) => (a['uom_id'] == null ? 0 : 1).compareTo(b['uom_id'] == null ? 0 : 1));
    out[id] = Dec.parse(candidates.first['price']);
  }
  return out;
}

/// Carrito con precio del motor cuando hay señal y estimado cuando no.
class CartController extends ChangeNotifier {
  CartController({required this.quote, required this.db, this.priceListId});

  /// Llama al motor de precios con las líneas; null = no hay cotizador.
  final Future<Map<String, dynamic>> Function(List<Map<String, dynamic>> lines)? quote;
  final LocalDb db;
  final int? priceListId;

  final List<CartLine> lines = [];
  CartTotals totals = CartTotals.empty;
  bool pricing = false;
  int _seq = 0;

  void add(Map<String, dynamic> item, [Dec? qty]) {
    final id = (item['id'] as num).toInt();
    final existing = lines.where((l) => l.itemId == id).firstOrNull;
    if (existing != null) {
      existing.quantity += qty ?? Dec.one;
    } else {
      lines.add(CartLine(item: item, quantity: qty ?? Dec.one));
    }
    reprice();
  }

  void setQuantity(CartLine line, Dec qty) {
    if (qty <= Dec.zero) {
      lines.remove(line);
    } else {
      line.quantity = qty;
    }
    reprice();
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
        next = applyQuote(lines, await quote!(lines.map((l) => l.toApi()).toList()));
      } on ApiException catch (e) {
        if (!e.isNetwork) {
          // El motor rechazó el carrito: se muestra el motivo y se estima.
          next = estimateOffline(lines, await cachedListPrices(db, lines.map((l) => l.itemId).toList(), priceListId));
          lines.first.error ??= e.userMessage;
        } else {
          next = estimateOffline(lines, await cachedListPrices(db, lines.map((l) => l.itemId).toList(), priceListId));
        }
      }
    }
    if (seq != _seq) return; // llegó una respuesta más nueva
    totals = next;
    pricing = false;
    notifyListeners();
  }
}
