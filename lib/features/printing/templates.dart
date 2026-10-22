import 'package:image/image.dart' as img;
import 'package:intl/intl.dart';

import '../../core/api/api_client.dart';
import '../../core/util/decimal.dart';
import 'escpos.dart';

/// Formatos fijos de impresión (no los del diseñador de la web): venta
/// (entrega/factura), pedido, cotización, recibo de cobro, comprobante de
/// visita o no venta, liquidación de ruta y hoja de carga.

/// Lo que va en todos los formatos: la empresa, quién imprime y el pie.
class TicketBrand {
  const TicketBrand({this.companyName, this.logo, this.seller, this.footer = '', this.code = 'qr', this.columns = 32});

  final String? companyName;
  final img.Image? logo;
  final String? seller;
  final String footer;

  /// 'qr', 'barcode' o 'none': el código del folio al final.
  final String code;
  final int columns;
}

/// Clave → tipo de impresión automática ([PrinterSettings.auto]).
const printKinds = {
  'sale': 'Venta (entrega o factura)',
  'order': 'Pedido',
  'quotation': 'Cotización',
  'payment': 'Recibo de cobro',
  'visit': 'Visita o no venta',
  'settlement': 'Liquidación de ruta',
  'load': 'Hoja de carga',
};

String printKindOf(String? documentType) => switch (documentType) {
      'sales_order' || 'order' => 'order',
      'quotation' => 'quotation',
      _ => 'sale',
    };

const _titles = {
  'quotation': 'COTIZACIÓN',
  'sales_order': 'PEDIDO',
  'order': 'PEDIDO',
  'delivery': 'NOTA DE VENTA',
  'sale': 'NOTA DE VENTA',
  'invoice': 'FACTURA',
  'return': 'DEVOLUCIÓN',
  'pickup': 'RECOLECCIÓN',
  'credit_memo': 'NOTA DE CRÉDITO',
};

final _when = DateFormat('dd/MM/yyyy HH:mm');

String _m(Dec? v) => v == null ? '' : money(v);

class PrintLine {
  const PrintLine({required this.quantity, required this.description, this.uom, this.price, this.amount});
  final Dec quantity;
  final String description;
  final String? uom;
  final Dec? price;
  final Dec? amount;
}

class PrintTender {
  const PrintTender(this.name, this.amount, {this.reference});
  final String name;
  final Dec amount;
  final String? reference;
}

/// Un documento de venta listo para imprimir (del servidor o, sin señal, del carrito).
class PrintDoc {
  PrintDoc({
    required this.type,
    required this.date,
    required this.customer,
    this.folio,
    this.customerCode,
    this.lines = const [],
    this.subtotal,
    this.discount,
    this.tax,
    required this.total,
    this.tenders = const [],
    this.change,
    this.balance,
    this.onCredit = false,
    this.notes,
    this.estimated = false,
  });

  final String type;

  /// null = guardado sin señal: aún no tiene folio.
  final String? folio;
  final DateTime date;
  final String customer;
  final String? customerCode;
  final List<PrintLine> lines;
  final Dec? subtotal;
  final Dec? discount;
  final Dec? tax;
  final Dec total;
  final List<PrintTender> tenders;
  final Dec? change;
  final Dec? balance;
  final bool onCredit;
  final String? notes;

  /// Totales calculados en el teléfono (sin señal).
  final bool estimated;

  /// De `GET /documents/{id}` o de la respuesta de `POST /documents`.
  factory PrintDoc.fromApi(Map<String, dynamic> d, {List<PrintTender> tenders = const [], Dec? change, bool onCredit = false, String? Function(int?)? uomOf}) {
    final partner = asMap(d['partner']);
    Dec? dec(Object? v) => v == null ? null : Dec.tryParse('$v');
    return PrintDoc(
      type: '${d['type'] ?? 'sale'}',
      folio: d['folio'] as String?,
      date: DateTime.tryParse('${d['created_at'] ?? d['document_date'] ?? ''}')?.toLocal() ?? DateTime.now(),
      customer: '${d['partner_name'] ?? partner['name'] ?? ''}',
      customerCode: partner['code'] as String?,
      lines: [
        for (final l in asList(d['lines']))
          PrintLine(
            quantity: Dec.parse(l['quantity']),
            description: '${l['description'] ?? l['item_code'] ?? ''}',
            uom: uomOf?.call((l['uom_id'] as num?)?.toInt()),
            price: dec(l['price']),
            amount: dec(l['subtotal'] ?? l['total']),
          ),
      ],
      subtotal: dec(d['subtotal']),
      discount: dec(d['discount_total']),
      tax: dec(d['tax_total']),
      total: Dec.parse(d['total']),
      tenders: tenders,
      change: change,
      balance: dec(d['balance']),
      onCredit: onCredit,
      notes: d['notes'] as String?,
    );
  }
}

void _header(Ticket t, TicketBrand b, String title, {String? folio, DateTime? date, String? customer, String? customerCode}) {
  if (b.logo != null) {
    t.add(TImage(b.logo!));
    t.feed();
  }
  if ((b.companyName ?? '').isNotEmpty) t.center(b.companyName!, bold: true);
  t.center(title, bold: true, big: true);
  t.center(folio == null ? 'Folio pendiente (sin señal)' : 'Folio $folio', bold: true);
  t.center(_when.format(date ?? DateTime.now()));
  t.divider();
  if ((b.seller ?? '').isNotEmpty) t.text('Vendedor: ${b.seller}');
  if (customer != null && customer.isNotEmpty) t.text('Cliente: ${customerCode == null || customerCode.isEmpty ? '' : '$customerCode '}$customer');
}

void _footer(Ticket t, TicketBrand b, String? code) {
  if (b.footer.trim().isNotEmpty) {
    t.feed();
    t.center(b.footer.trim());
  }
  if (code != null && code.isNotEmpty && b.code != 'none') {
    t.feed();
    t.add(b.code == 'barcode' ? TBarcode(code) : TQr(code));
  }
}

/// Venta, pedido, cotización, devolución o recolección.
Ticket documentTicket(PrintDoc d, TicketBrand b) {
  final t = Ticket(b.columns);
  _header(t, b, _titles[d.type] ?? d.type.toUpperCase(), folio: d.folio, date: d.date, customer: d.customer, customerCode: d.customerCode);
  t.divider();
  t.row('CANT  DESCRIPCIÓN', 'IMPORTE', bold: true);
  for (final l in d.lines) {
    t.text(l.description);
    final qty = '${l.quantity.toQty()}${l.uom == null || l.uom!.isEmpty ? '' : ' ${l.uom}'}';
    t.row(l.price == null ? '  $qty' : '  $qty x ${_m(l.price)}', _m(l.amount));
  }
  t.divider();
  final items = d.lines.fold(Dec.zero, (s, l) => s + l.quantity);
  t.row('Artículos', items.toQty());
  if (d.subtotal != null && (d.tax != null && !d.tax!.isZero || d.discount != null && !d.discount!.isZero)) t.row('Subtotal', _m(d.subtotal));
  if (d.discount != null && !d.discount!.isZero) t.row('Descuento', '-${_m(d.discount)}');
  if (d.tax != null && !d.tax!.isZero) t.row('Impuestos', _m(d.tax));
  t.row('TOTAL', _m(d.total), bold: true, big: true);
  if (d.estimated) t.text('Total estimado; el servidor confirma el precio final.');
  if (d.tenders.isNotEmpty) {
    t.divider();
    for (final p in d.tenders) {
      t.row(p.reference == null || p.reference!.isEmpty ? p.name : '${p.name} (${p.reference})', _m(p.amount));
    }
    if (d.change != null && d.change! > Dec.zero) t.row('Cambio', _m(d.change), bold: true);
  }
  if (d.onCredit) t.text('Venta a crédito', bold: true);
  if (d.balance != null && d.balance! > Dec.zero && d.type != 'quotation' && d.type != 'sales_order') t.row('Saldo', _m(d.balance), bold: true);
  if ((d.notes ?? '').isNotEmpty) {
    t.divider();
    t.text(d.notes!);
  }
  if (d.type == 'delivery' || d.type == 'invoice' || d.type == 'sale') {
    t.feed(2);
    t.center('_______________________');
    t.center('Recibí de conformidad');
  }
  _footer(t, b, d.folio);
  return t;
}

/// Recibo de cobro: lo recibido, a qué documentos se aplicó y el cambio.
class PrintPayment {
  const PrintPayment({
    this.folio,
    required this.date,
    required this.customer,
    required this.total,
    this.tenders = const [],
    this.applications = const [],
    this.change,
    this.unapplied,
    this.balanceAfter,
  });

  final String? folio;
  final DateTime date;
  final String customer;
  final Dec total;
  final List<PrintTender> tenders;

  /// (folio, monto) de cada documento pagado.
  final List<(String, Dec)> applications;
  final Dec? change;
  final Dec? unapplied;

  /// Lo que el cliente sigue debiendo después del cobro.
  final Dec? balanceAfter;
}

Ticket paymentTicket(PrintPayment p, TicketBrand b) {
  final t = Ticket(b.columns);
  _header(t, b, 'RECIBO DE COBRO', folio: p.folio, date: p.date, customer: p.customer);
  t.divider();
  if (p.applications.isNotEmpty) {
    t.text('Aplicado a', bold: true);
    for (final (folio, amount) in p.applications) {
      t.row('  $folio', _m(amount));
    }
    t.divider();
  }
  for (final x in p.tenders) {
    t.row(x.reference == null || x.reference!.isEmpty ? x.name : '${x.name} (${x.reference})', _m(x.amount));
  }
  t.row('TOTAL COBRADO', _m(p.total), bold: true, big: true);
  if (p.change != null && p.change! > Dec.zero) t.row('Cambio', _m(p.change), bold: true);
  if (p.unapplied != null && p.unapplied! > Dec.zero) t.row('Saldo a favor', _m(p.unapplied));
  if (p.balanceAfter != null) t.row('Saldo pendiente', _m(p.balanceAfter), bold: true);
  t.feed(2);
  t.center('_______________________');
  t.center('Recibí');
  _footer(t, b, p.folio);
  return t;
}

/// Comprobante de visita (llegada, salida y resultado) o de no venta.
Ticket visitTicket(Map<String, dynamic> visit, TicketBrand b, {String? reason, String? notes}) {
  final customer = asMap(visit['customer']);
  final t = Ticket(b.columns);
  final noSale = reason != null || visit['outcome'] == 'no_sale';
  _header(t, b, noSale ? 'CONSTANCIA DE NO VENTA' : 'COMPROBANTE DE VISITA',
      folio: 'V-${visit['id']}', customer: '${customer['name'] ?? ''}', customerCode: customer['code'] as String?);
  if (customer['address'] != null) t.text('${customer['address']}');
  t.divider();
  DateTime? at(Object? v) => v == null ? null : DateTime.tryParse('$v')?.toLocal();
  final inAt = at(visit['check_in_at']);
  final outAt = at(visit['check_out_at']);
  if (inAt != null) t.row('Llegada', _when.format(inAt));
  if (outAt != null) t.row('Salida', _when.format(outAt));
  if (visit['status_label'] != null) t.row('Estado', '${visit['status_label']}');
  if (reason != null) t.text('Motivo: $reason', bold: true);
  if ((notes ?? '').isNotEmpty) t.text('Notas: $notes');
  for (final d in asList(visit['done'])) {
    t.row('${d['role_label'] ?? d['role'] ?? ''} ${d['folio'] ?? ''}', d['total'] == null ? '' : money(d['total']));
  }
  t.feed(2);
  t.center('_______________________');
  t.center('Firma del cliente');
  _footer(t, b, 'V-${visit['id']}');
  return t;
}

/// Liquidación del día de ruta: avance, ventas y cobros por parada.
Ticket settlementTicket(Map<String, dynamic> plan, TicketBrand b) {
  final route = asMap(plan['route']);
  final counts = asMap(plan['counts']);
  final stops = asList(plan['stops']);
  final t = Ticket(b.columns);
  _header(t, b, 'LIQUIDACIÓN DE RUTA', folio: 'R-${plan['id']}', date: DateTime.now());
  t.text('Ruta: ${route['code'] ?? ''} ${route['name'] ?? ''}'.trim());
  t.text('Fecha: ${plan['date'] ?? ''}');
  if (plan['vehicle'] != null) t.text('Vehículo: ${plan['vehicle']}');
  t.divider();
  t.row('Visitas planeadas', '${counts['planned'] ?? stops.length}');
  t.row('Visitadas', '${counts['completed'] ?? 0}');
  t.row('No visitadas', '${counts['skipped'] ?? 0}');
  t.row('Pendientes', '${counts['pending'] ?? 0}');
  t.divider();
  t.row('CLIENTE', 'VENTA / COBRO', bold: true);
  var sales = Dec.zero, collected = Dec.zero;
  for (final s in stops) {
    final c = asMap(s['customer']);
    final sale = Dec.parse(s['sale_total']);
    final col = Dec.parse(s['collected_total']);
    sales += sale;
    collected += col;
    t.text('${s['sequence'] ?? ''}. ${c['name'] ?? ''}');
    t.row('  ${s['status_label'] ?? s['status'] ?? ''}', '${money(sale)} / ${money(col)}');
  }
  t.divider();
  t.row('Venta', money(Dec.tryParse('${plan['sales'] ?? ''}') ?? sales), bold: true);
  t.row('Cobrado', money(collected), bold: true);
  final target = Dec.tryParse('${plan['target'] ?? ''}');
  if (target != null && !target.isZero) t.row('Meta', money(target));
  t.feed(2);
  t.center('_______________________');
  t.center('Entregó (vendedor)');
  t.feed(2);
  t.center('_______________________');
  t.center('Recibió (liquidador)');
  _footer(t, b, 'R-${plan['id']}');
  return t;
}

/// Hoja de carga: lo que lleva el camión (`/route/plans/{id}/stock`).
Ticket loadSheetTicket(Map<String, dynamic> plan, List<Map<String, dynamic>> stock, TicketBrand b) {
  final route = asMap(plan['route']);
  final t = Ticket(b.columns);
  _header(t, b, 'HOJA DE CARGA', folio: 'C-${plan['id']}', date: DateTime.now());
  t.text('Ruta: ${route['code'] ?? ''} ${route['name'] ?? ''}'.trim());
  t.text('Fecha: ${plan['date'] ?? ''}');
  if (plan['vehicle'] != null) t.text('Vehículo: ${plan['vehicle']}');
  t.divider();
  t.row('ARTÍCULO', 'CANTIDAD', bold: true);
  var total = Dec.zero;
  for (final s in stock) {
    final q = Dec.parse(s['on_hand']);
    total += q;
    t.text('${s['code'] ?? ''} ${s['name'] ?? ''}'.trim());
    t.row('', '${q.toQty()} ${s['uom'] ?? ''}'.trim());
  }
  t.divider();
  t.row('Artículos', '${stock.length}');
  t.row('Unidades', total.toQty(), bold: true);
  t.feed(2);
  t.center('_______________________');
  t.center('Cargó (almacén)');
  t.feed(2);
  t.center('_______________________');
  t.center('Recibió (vendedor)');
  _footer(t, b, 'C-${plan['id']}');
  return t;
}
