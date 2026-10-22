import '../../core/api/api_client.dart';
import '../../core/util/decimal.dart';
import 'escpos.dart';
import 'templates.dart';

/// Representación impresa condensada de un CFDI 4.0 (factura, nota de crédito
/// o complemento de pagos 2.0) a partir de `GET /documents/{id}/cfdi` o
/// `GET /payments/{id}/cfdi` (esquema `CfdiPrint`). Los importes vienen como
/// cadenas tal cual el XML.
class CfdiPrint {
  CfdiPrint(this.data);

  factory CfdiPrint.fromApi(Object? json) => CfdiPrint(asMap(json));

  final Map<String, dynamic> data;

  String get status => '${data['status'] ?? 'unstamped'}';
  bool get fiscal => data['fiscal'] == true;
  bool get stamped => data['stamped'] == true || status == 'stamped' || status == 'cancelled';
  bool get cancelled => data['cancelled'] == true || status == 'cancelled';

  /// Es (o debe ser) CFDI pero el PAC aún no lo timbra.
  bool get pendingStamp => fiscal && !stamped && !cancelled;

  Map<String, dynamic> toJson() => data;
}

String? _s(Object? v) {
  final s = v == null ? '' : '$v'.trim();
  return s.isEmpty ? null : s;
}

/// "601 General de Ley Personas Morales" de un código del catálogo del SAT.
String? _code(Object? v) {
  final m = asMap(v);
  final code = _s(m['code']);
  final name = _s(m['name']);
  if (code == null) return name;
  return name == null ? code : '$code $name';
}

String _m(Object? v) => money(v);

/// "ABCD…WXYZ" para los sellos en modo abreviado.
String abbreviateSeal(String s, {int head = 20, int tail = 20}) =>
    s.length <= head + tail + 3 ? s : '${s.substring(0, head)}...${s.substring(s.length - tail)}';

void _labelled(Ticket t, String label, Object? value) {
  final v = _s(value);
  if (v != null) t.text('$label: $v');
}

/// Encabezado fiscal: emisor, comprobante, lugar y estado (timbrado o no).
void _cfdiHeader(Ticket t, TicketBrand b, CfdiPrint c, String fallbackTitle) {
  final d = c.data;
  final issuer = asMap(d['issuer']);
  if (b.logo != null) {
    t.add(TImage(b.logo!));
    t.feed();
  }
  t.center(_s(issuer['name']) ?? b.companyName ?? '', bold: true);
  if (_s(issuer['rfc']) != null) t.center('RFC ${issuer['rfc']}', bold: true);
  final regime = _code(issuer['tax_regime']);
  if (regime != null) t.center('Régimen: $regime');
  t.feed();
  t.center((_s(d['title']) ?? fallbackTitle).toUpperCase(), bold: true, big: true);
  if (c.cancelled) {
    t.center('*** CANCELADO ***', bold: true, big: true);
    if (_s(d['cancelled_at']) != null) t.center('Cancelado el ${d['cancelled_at']}');
  } else if (c.pendingStamp) {
    t.center('SIN TIMBRAR', bold: true, big: true);
    t.center('No válido como comprobante fiscal', bold: true);
  }
  final serie = [_s(d['series']), _s(d['folio'])].whereType<String>().join('-');
  if (serie.isNotEmpty) t.center('Serie-Folio $serie', bold: true);
  _labelled(t, 'Fecha', d['date']);
  _labelled(t, 'Lugar de expedición', d['place_of_issue']);
  _labelled(t, 'Tipo', _code(d['voucher_type']));
  _labelled(t, 'Versión', d['version']);
  _labelled(t, 'Exportación', _code(d['export']));
  t.divider();
  final r = asMap(d['receiver']);
  t.text('RECEPTOR', bold: true);
  _labelled(t, 'RFC', r['rfc']);
  if (_s(r['name']) != null) t.text('${r['name']}');
  _labelled(t, 'C.P.', r['tax_address'] ?? r['postal_code']);
  _labelled(t, 'Régimen', _code(r['tax_regime']));
  _labelled(t, 'Uso CFDI', _code(r['cfdi_use']));
  _labelled(t, 'NumRegIdTrib', r['foreign_tax_id']);
  _labelled(t, 'Residencia fiscal', r['tax_residence']);
  final global = d['global_information'];
  if (global is Map) {
    final g = asMap(global);
    t.small('Información global: ${[_code(g['periodicity']), _code(g['months']), _s(g['year'])].whereType<String>().join(' · ')}');
  }
  for (final rel in asList(d['related'])) {
    t.small('CFDI relacionado (${_code(rel['relation_type']) ?? ''}): ${rel['uuid'] ?? ''}');
  }
}

void _taxLines(Ticket t, List<dynamic> taxes, {bool small = false}) {
  for (final x in taxes) {
    final label = _s(x['label']) ?? [_code(x['tax']), _s(x['rate'])].whereType<String>().join(' ');
    final amount = x['amount'] == null ? '' : _m(x['amount']);
    if (small) {
      final base = x['base'] == null ? '' : ' base ${_m(x['base'])}';
      t.small('  $label$base: $amount');
    } else {
      t.row(x['kind'] == 'withholding' ? '$label (-)' : label, amount);
    }
  }
}

/// Conceptos con claves del SAT, en renglones compactos.
void _concepts(Ticket t, CfdiPrint c) {
  t.row('CANT  DESCRIPCIÓN', 'IMPORTE', bold: true);
  for (final x in asList(c.data['concepts'])) {
    t.text('${x['description'] ?? ''}');
    final keys = [
      if (_s(x['product_code']) != null) 'ClaveProdServ ${x['product_code']}',
      if (_s(x['identification']) != null) 'NoId ${x['identification']}',
      if (_s(x['unit_code']) != null) 'ClaveUnidad ${x['unit_code']}${_s(x['unit']) == null ? '' : ' ${x['unit']}'}',
      if (_s(asMap(x['tax_object'])['code']) != null) 'ObjImp ${asMap(x['tax_object'])['code']}',
    ];
    if (keys.isNotEmpty) t.small(keys.join(' · '));
    t.row('  ${Dec.parse(x['quantity']).toQty()} x ${_m(x['unit_price'])}', _m(x['amount']));
    if (x['discount'] != null && !Dec.parse(x['discount']).isZero) t.row('  Descuento', '-${_m(x['discount'])}');
    _taxLines(t, asList(x['taxes']), small: true);
  }
  t.divider();
  t.row('Subtotal', _m(c.data['subtotal']));
  if (c.data['discount'] != null && !Dec.parse(c.data['discount']).isZero) t.row('Descuento', '-${_m(c.data['discount'])}');
  _taxLines(t, asList(c.data['taxes']));
  t.row('TOTAL', _m(c.data['total']), bold: true, big: true);
}

void _amountAndTerms(Ticket t, CfdiPrint c) {
  final d = c.data;
  if (_s(d['amount_in_words']) != null) t.text('${d['amount_in_words']}');
  t.divider();
  _labelled(t, 'Forma de pago', _code(d['payment_form']));
  _labelled(t, 'Método de pago', _code(d['payment_method']));
  final currency = _s(d['currency']);
  if (currency != null) {
    final rate = _s(d['exchange_rate']);
    t.text('Moneda: $currency${rate == null || currency == 'MXN' || currency == 'XXX' ? '' : ' · T.C. $rate'}');
  }
  _labelled(t, 'Condiciones de pago', d['payment_terms']);
}

/// Complemento de pagos 2.0: cada pago y los documentos que salda.
void _payments(Ticket t, CfdiPrint c) {
  final pays = asList(c.data['payments']);
  for (var i = 0; i < pays.length; i++) {
    final p = pays[i];
    t.text(pays.length > 1 ? 'PAGO ${i + 1}' : 'PAGO', bold: true);
    _labelled(t, 'Fecha de pago', p['date']);
    _labelled(t, 'Forma', _code(p['form']));
    final rate = _s(p['exchange_rate']);
    _labelled(t, 'Moneda', '${p['currency'] ?? ''}${rate == null || p['currency'] == 'MXN' ? '' : ' · T.C. $rate'}');
    _labelled(t, 'Núm. operación', p['operation_number']);
    t.row('Monto', _m(p['amount']), bold: true);
    final docs = asList(p['documents']);
    if (docs.isNotEmpty) t.text('Documentos relacionados', bold: true);
    for (final doc in docs) {
      final serie = [_s(doc['series']), _s(doc['folio'])].whereType<String>().join('-');
      t.text('${serie.isEmpty ? 'S/F' : serie} Parc. ${doc['installment'] ?? '-'}');
      if (_s(doc['uuid']) != null) t.small('${doc['uuid']}'.toUpperCase());
      if (_s(doc['currency']) != null && doc['currency'] != p['currency']) {
        t.small('  ${doc['currency']} · Equivalencia ${doc['equivalence'] ?? '1'}');
      }
      t.row('  Saldo anterior', _m(doc['previous_balance']));
      t.row('  Pagado', _m(doc['paid']));
      t.row('  Saldo insoluto', _m(doc['outstanding']));
      final obj = _code(doc['tax_object']);
      if (obj != null) t.small('  ObjetoImpDR $obj');
    }
    _taxLines(t, asList(p['taxes']), small: true);
    t.divider();
  }
  final totals = asMap(c.data['payment_totals']);
  for (final l in asList(totals['lines'])) {
    t.row('${l['label'] ?? l['name'] ?? ''}', _m(l['amount']));
  }
  t.row('TOTAL PAGOS', _m(totals['total'] ?? c.data['total']), bold: true, big: true);
}

/// Timbre fiscal: UUID, fechas, certificados, sellos, cadena original y QR.
void _stamp(Ticket t, CfdiPrint c, {required bool fullSeals}) {
  final d = c.data;
  final stamp = d['stamp'];
  t.divider();
  if (stamp is! Map) {
    if (_s(d['issuer_certificate']) != null) t.small('No. certificado emisor: ${d['issuer_certificate']}');
    if (c.pendingStamp) {
      t.center('SIN TIMBRAR', bold: true);
      t.center('No válido como comprobante fiscal');
    }
    return;
  }
  final s = asMap(stamp);
  String seal(Object? v) => fullSeals ? '${v ?? ''}' : abbreviateSeal('${v ?? ''}');
  t.text('Folio fiscal (UUID)', bold: true);
  t.small('${s['uuid'] ?? ''}'.toUpperCase(), bold: true);
  _labelled(t, 'Certificación', s['stamped_at']);
  t.small('No. certificado emisor: ${s['issuer_certificate'] ?? d['issuer_certificate'] ?? ''}');
  t.small('No. certificado SAT: ${s['sat_certificate'] ?? ''}');
  t.small('RFC proveedor de certificación: ${s['pac_rfc'] ?? ''}');
  t.small('Sello digital del CFDI:', bold: true);
  t.small(seal(s['cfd_seal']));
  t.small('Sello del SAT:', bold: true);
  t.small(seal(s['sat_seal']));
  t.small('Cadena original del complemento de certificación digital del SAT:', bold: true);
  t.small(seal(s['original_string']));
  if (c.cancelled) {
    t.feed();
    t.center('*** CANCELADO ***', bold: true, big: true);
  }
}

void _cfdiFooter(Ticket t, TicketBrand b, CfdiPrint c) {
  final url = _s(c.data['verification_url']);
  if (url != null && c.stamped) {
    t.feed();
    t.add(TQr(url));
  }
  if (_s(c.data['notes']) != null) {
    t.divider();
    t.text('${c.data['notes']}');
  }
  t.feed();
  t.center(_s(c.data['legend']) ?? 'Este documento es una representación impresa de un CFDI');
  if (b.footer.trim().isNotEmpty) {
    t.feed();
    t.center(b.footer.trim());
  }
}

/// Factura o nota de crédito como representación impresa del CFDI. Lo cobrado
/// en el momento (formas de pago y cambio) sale después, como información.
Ticket cfdiDocumentTicket(PrintDoc d, CfdiPrint c, TicketBrand b) {
  final t = Ticket(b.columns);
  _cfdiHeader(t, b, c, 'Factura');
  if ((b.seller ?? '').isNotEmpty) t.small('Vendedor: ${b.seller}  ·  Folio interno ${d.folio ?? ''}');
  t.divider();
  if (asMap(c.data['voucher_type'])['code'] == 'P') {
    _payments(t, c);
  } else {
    _concepts(t, c);
  }
  _amountAndTerms(t, c);
  if (d.tenders.isNotEmpty) {
    t.divider();
    for (final p in d.tenders) {
      t.row(p.reference == null || p.reference!.isEmpty ? p.name : '${p.name} (${p.reference})', money(p.amount));
    }
    if (d.change != null && d.change! > Dec.zero) t.row('Cambio', money(d.change), bold: true);
  }
  _stamp(t, c, fullSeals: b.fullSeals);
  _cfdiFooter(t, b, c);
  return t;
}

/// Recibo de cobro como CFDI con complemento de pagos 2.0.
Ticket cfdiPaymentTicket(PrintPayment p, CfdiPrint c, TicketBrand b) {
  final t = Ticket(b.columns);
  _cfdiHeader(t, b, c, 'Recibo electrónico de pago');
  if ((b.seller ?? '').isNotEmpty) t.small('Cobrador: ${b.seller}  ·  Folio interno ${p.folio ?? ''}');
  t.divider();
  _payments(t, c);
  if (p.change != null && p.change! > Dec.zero) t.row('Cambio entregado', money(p.change), bold: true);
  if (p.balanceAfter != null) t.row('Saldo pendiente', money(p.balanceAfter));
  _stamp(t, c, fullSeals: b.fullSeals);
  _cfdiFooter(t, b, c);
  return t;
}
