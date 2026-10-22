import 'package:flutter_test/flutter_test.dart';
import 'package:nori_mobile/core/util/decimal.dart';
import 'package:nori_mobile/features/printing/cfdi.dart';
import 'package:nori_mobile/features/printing/escpos.dart';
import 'package:nori_mobile/features/printing/templates.dart';

final _seal = '${'A' * 30}SELLOMEDIO${'Z' * 30}';

Map<String, dynamic> _invoice({String status = 'stamped'}) => {
      'status': status,
      'stamped': status != 'unstamped',
      'fiscal': true,
      'cancelled': status == 'cancelled',
      'title': 'Factura',
      'version': '4.0',
      'series': 'A',
      'folio': '120',
      'date': '2026-10-22T10:15:00',
      'place_of_issue': '01000',
      'voucher_type': {'code': 'I', 'name': 'Ingreso'},
      'payment_form': {'code': '01', 'name': 'Efectivo'},
      'payment_method': {'code': 'PUE', 'name': 'Pago en una sola exhibición'},
      'currency': 'MXN',
      'issuer': {'rfc': 'AAA010101AAA', 'name': 'EMPRESA DEMO', 'tax_regime': {'code': '601', 'name': 'General de Ley Personas Morales'}},
      'receiver': {
        'rfc': 'XAXX010101000',
        'name': 'CLIENTE EJEMPLO',
        'tax_address': '01000',
        'tax_regime': {'code': '616', 'name': 'Sin obligaciones fiscales'},
        'cfdi_use': {'code': 'S01', 'name': 'Sin efectos fiscales'},
      },
      'concepts': [
        {
          'product_code': '50181900',
          'quantity': '2.00',
          'unit_code': 'H87',
          'unit': 'Pieza',
          'description': 'Harina',
          'unit_price': '150.00',
          'amount': '300.00',
          'tax_object': {'code': '02'},
          'taxes': [
            {'kind': 'transfer', 'base': '300.00', 'amount': '48.00', 'label': 'IVA trasladado 16 %'}
          ],
        }
      ],
      'subtotal': '300.00',
      'taxes': [
        {'kind': 'transfer', 'amount': '48.00', 'label': 'IVA trasladado 16 %'}
      ],
      'total': '348.00',
      'amount_in_words': '(TRESCIENTOS CUARENTA Y OCHO PESOS 00/100 M.N.)',
      'stamp': status == 'unstamped'
          ? null
          : {
              'uuid': 'aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee',
              'stamped_at': '2026-10-22T10:16:00',
              'pac_rfc': 'PAC010101AAA',
              'sat_certificate': '00001000000500000001',
              'issuer_certificate': '00001000000500000002',
              'cfd_seal': _seal,
              'sat_seal': _seal,
              'original_string': '||1.1|aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee|2026-10-22T10:16:00||',
            },
      'verification_url': 'https://verificacfdi.facturaelectronica.sat.gob.mx/default.aspx?id=X&re=AAA010101AAA&rr=XAXX010101000&tt=348.0&fe=ABCDEFGH',
      'legend': 'Este documento es una representación impresa de un CFDI',
      'payments': [],
    };

String _text(Ticket t) => t.ops.expand((o) => layoutText(o, t.columns)).map((l) => l.text.trim()).join(' ');

final _doc = PrintDoc(type: 'invoice', folio: 'A-120', date: DateTime(2026, 10, 22), customer: 'Cliente Ejemplo', total: Dec.parse('348'));

void main() {
  test('factura timbrada: datos fiscales, claves SAT, impuestos, timbre, QR y leyenda', () {
    final t = documentTicket(_doc, const TicketBrand(), cfdi: CfdiPrint(_invoice()));
    final text = _text(t);
    for (final s in [
      'RFC AAA010101AAA',
      'Régimen: 601 General de Ley Personas Morales',
      'Lugar de expedición: 01000',
      'Uso CFDI: S01 Sin efectos fiscales',
      'C.P.: 01000',
      'Tipo: I Ingreso',
      'ClaveProdServ 50181900',
      'ClaveUnidad H87 Pieza',
      'IVA trasladado 16 %',
      'TRESCIENTOS CUARENTA Y OCHO',
      'Método de pago: PUE',
      'AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE',
      'RFC proveedor de certificación: PAC010101AAA',
      'No. certificado SAT: 00001000000500000001',
      'SELLOMEDIO', // sellos completos por omisión
      'representación impresa de un CFDI',
    ]) {
      expect(text, contains(s));
    }
    expect(text, isNot(contains('SIN TIMBRAR')));
    expect(t.ops.whereType<TQr>().single.data, startsWith('https://verificacfdi.facturaelectronica.sat.gob.mx/'));
    // Sellos en letra chica, partidos a las columnas de la fuente B.
    final small = t.ops.expand((o) => layoutText(o, 32)).where((l) => l.small).toList();
    expect(small, isNotEmpty);
    expect(small.every((l) => l.text.length <= smallColumns(32)), isTrue);

    final short = _text(documentTicket(_doc, const TicketBrand(fullSeals: false), cfdi: CfdiPrint(_invoice())));
    expect(short, isNot(contains('SELLOMEDIO')));
    expect(short, contains('...'));
  });

  test('sin timbrar, cancelado y no fiscal', () {
    final pending = CfdiPrint(_invoice(status: 'unstamped'));
    expect(pending.pendingStamp, isTrue);
    final p = _text(documentTicket(_doc, const TicketBrand(), cfdi: pending));
    expect(p, contains('SIN TIMBRAR'));
    expect(p, contains('No válido como comprobante fiscal'));
    expect(documentTicket(_doc, const TicketBrand(), cfdi: pending).ops.whereType<TQr>(), isEmpty);

    expect(_text(documentTicket(_doc, const TicketBrand(), cfdi: CfdiPrint(_invoice(status: 'cancelled')))), contains('CANCELADO'));

    final plain = _text(documentTicket(_doc, const TicketBrand(), cfdi: CfdiPrint({..._invoice(), 'fiscal': false})));
    expect(plain, contains('Folio A-120'));
    expect(plain, isNot(contains('RFC')));
  });

  test('recibo de cobro con complemento de pagos 2.0', () {
    final c = CfdiPrint({
      ..._invoice(),
      'title': 'Recibo electrónico de pago',
      'voucher_type': {'code': 'P', 'name': 'Pago'},
      'payments': [
        {
          'date': '2026-10-22T12:00:00',
          'form': {'code': '01', 'name': 'Efectivo'},
          'currency': 'MXN',
          'amount': '200.00',
          'documents': [
            {
              'uuid': 'aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee',
              'series': 'A',
              'folio': '120',
              'installment': '1',
              'previous_balance': '348.00',
              'paid': '200.00',
              'outstanding': '148.00',
              'tax_object': {'code': '02'},
            }
          ],
        }
      ],
      'payment_totals': {
        'total': '200.00',
        'lines': [
          {'label': 'Total traslados base IVA 16 %', 'amount': '172.41'}
        ],
      },
    });
    final receipt = PrintPayment(folio: 'P-15', date: DateTime(2026, 10, 22), customer: 'Cliente Ejemplo', total: Dec.parse('200'));
    final text = _text(paymentTicket(receipt, const TicketBrand(), cfdi: c));
    for (final s in ['ELECTRÓNICO DE PAGO', 'A-120 Parc. 1', 'Saldo anterior', r'$348.00', 'Pagado', 'Saldo insoluto', r'$148.00', 'TOTAL PAGOS', 'AAAAAAAA-BBBB']) {
      expect(text, contains(s));
    }
  });

  test('la letra chica se manda con ESC M 1', () async {
    final t = Ticket(32)..small('sello');
    final bytes = await EscPosEncoder(paperMm: 58).encode(t);
    final i = bytes.indexOf(0x4D);
    expect(bytes.sublist(i - 1, i + 2), [0x1B, 0x4D, 1]);
  });
}
