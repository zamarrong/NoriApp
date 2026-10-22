import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:nori_mobile/core/util/decimal.dart';
import 'package:nori_mobile/features/printing/escpos.dart';
import 'package:nori_mobile/features/printing/templates.dart';

bool _contains(List<int> haystack, List<int> needle) {
  for (var i = 0; i + needle.length <= haystack.length; i++) {
    var ok = true;
    for (var j = 0; j < needle.length && ok; j++) {
      ok = haystack[i + j] == needle[j];
    }
    if (ok) return true;
  }
  return false;
}

void main() {
  test('los acentos y la ñ salen en CP858; sin la página se escriben sin acento', () {
    expect(encodeTicketText('Año ¿Sí? €', TicketCharset.cp858), [0x41, 0xA4, 0x6F, 0x20, 0xA8, 0x53, 0xA1, 0x3F, 0x20, 0xD5]);
    expect(String.fromCharCodes(encodeTicketText('Año €', TicketCharset.ascii)), 'Ano EUR');
    expect(String.fromCharCodes(encodeTicketText('Peña', TicketCharset.cp850)).codeUnitAt(2), 0xA4);
  });

  test('renglones: texto partido por palabras e importe a la derecha', () {
    expect(wrapText('Harina de maíz blanca extra fina', 12), ['Harina de', 'maíz blanca', 'extra fina']);
    final row = layoutText(const TRow('TOTAL', r'$150.00'), 32).single.text;
    expect(row.length, 32);
    expect(row, startsWith('TOTAL'));
    expect(row, endsWith(r'$150.00'));
    final long = layoutText(const TRow('Totopos de maíz bolsa grande de 500 gramos', r'$1,234.00'), 32);
    expect(long.last.text, endsWith(r'$1,234.00'));
    expect(long.every((l) => l.text.length <= 32), isTrue);
  });

  test('ticket de venta: líneas, totales, cambio y QR del folio en ESC/POS', () async {
    final doc = PrintDoc(
      type: 'delivery',
      folio: 'A-120',
      date: DateTime(2026, 10, 22, 9, 30),
      customer: 'Abarrotes Ejemplo',
      lines: [PrintLine(quantity: Dec.parse('10'), description: 'Harina', price: Dec.parse('15'), amount: Dec.parse('150'))],
      total: Dec.parse('150'),
      tenders: [PrintTender('Efectivo', Dec.parse('200'))],
      change: Dec.parse('50'),
    );
    final logo = img.Image(width: 40, height: 10)..clear(img.ColorRgb8(0, 0, 0));
    final t = documentTicket(doc, TicketBrand(companyName: 'Empresa Demo', seller: 'Vendedor Uno', logo: logo));
    final text = t.ops.expand((o) => layoutText(o, 32)).map((l) => l.text).join('\n');
    expect(text, contains('NOTA DE VENTA'));
    expect(text, contains('Folio A-120'));
    expect(text, contains(r'10 x $15.00'));
    expect(text, contains('Cambio'));

    final bytes = await EscPosEncoder(paperMm: 58).encode(t);
    expect(bytes.take(5), [0x1B, 0x40, 0x1B, 0x74, 19]); // inicializar + CP858
    expect(_contains(bytes, [0x1D, 0x76, 0x30, 0x00, 5, 0, 10, 0]), isTrue); // logo 40×10 → 5 bytes por renglón
    expect(_contains(bytes, [0x1D, 0x28, 0x6B, 8, 0, 0x31, 0x50, 0x30, ...'A-120'.codeUnits]), isTrue); // QR
    expect(bytes.sublist(bytes.length - 4), [0x1D, 0x56, 0x42, 0x00]); // corte
  });
}
