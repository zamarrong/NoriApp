import 'dart:typed_data';

import 'package:image/image.dart' as img;

/// Ticket de impresora térmica: una lista de renglones independiente de la
/// impresora. [EscPosEncoder] lo convierte a bytes ESC/POS (texto con página de
/// códigos o todo como imagen).
enum TAlign { left, center, right }

sealed class TicketOp {
  const TicketOp();
}

class TText extends TicketOp {
  const TText(this.text, {this.align = TAlign.left, this.bold = false, this.big = false});
  final String text;
  final TAlign align;
  final bool bold;

  /// Doble alto y ancho (la mitad de columnas).
  final bool big;
}

/// Texto a la izquierda y a la derecha del mismo renglón.
class TRow extends TicketOp {
  const TRow(this.left, this.right, {this.bold = false, this.big = false});
  final String left;
  final String right;
  final bool bold;
  final bool big;
}

class TDivider extends TicketOp {
  const TDivider([this.char = '-']);
  final String char;
}

class TFeed extends TicketOp {
  const TFeed([this.lines = 1]);
  final int lines;
}

class TQr extends TicketOp {
  const TQr(this.data);
  final String data;
}

class TBarcode extends TicketOp {
  const TBarcode(this.data);
  final String data;
}

class TImage extends TicketOp {
  const TImage(this.image, {this.maxWidthFraction = 0.6});
  final img.Image image;
  final double maxWidthFraction;
}

class Ticket {
  Ticket(this.columns);

  /// Columnas de la letra normal: 32 en 58 mm, 48 en 80 mm.
  final int columns;
  final List<TicketOp> ops = [];

  void text(String s, {TAlign align = TAlign.left, bool bold = false, bool big = false}) => ops.add(TText(s, align: align, bold: bold, big: big));
  void center(String s, {bool bold = false, bool big = false}) => text(s, align: TAlign.center, bold: bold, big: big);
  void row(String left, String right, {bool bold = false, bool big = false}) => ops.add(TRow(left, right, bold: bold, big: big));
  void divider([String c = '-']) => ops.add(TDivider(c));
  void feed([int n = 1]) => ops.add(TFeed(n));
  void add(TicketOp op) => ops.add(op);
}

/// Cómo salen los acentos: página de códigos (CP858 o CP850), sin acentos, o
/// todo el texto como imagen (para impresoras sin esas páginas).
enum TicketCharset { cp858, cp850, ascii, raster }

/// Un renglón ya acomodado a lo ancho del papel.
class TicketLine {
  const TicketLine(this.text, {this.align = TAlign.left, this.bold = false, this.big = false});
  final String text;
  final TAlign align;
  final bool bold;
  final bool big;
}

/// Pinta renglones como imagen de [widthDots] puntos de ancho (para [TicketCharset.raster]).
typedef TicketRasterizer = Future<img.Image> Function(List<TicketLine> lines, int columns, int widthDots);

/// Comillas, guiones y puntos suspensivos tipográficos a su equivalente simple.
String normalizeTicketText(String s) => s
    .replaceAll(RegExp('[‘’´`]'), "'")
    .replaceAll(RegExp('[“”«»]'), '"')
    .replaceAll(RegExp('[–—−]'), '-')
    .replaceAll('…', '...')
    .replaceAll(RegExp('[ \t]'), ' ')
    .replaceAll(RegExp('[\r\n]+'), ' ');

/// Partes un texto en renglones de [width] columnas, por palabras.
List<String> wrapText(String text, int width) {
  final out = <String>[];
  var line = '';
  for (final raw in text.split(' ')) {
    var word = raw;
    if (word.isEmpty) continue;
    while (word.length > width) {
      if (line.isNotEmpty) {
        out.add(line);
        line = '';
      }
      out.add(word.substring(0, width));
      word = word.substring(width);
    }
    if (line.isEmpty) {
      line = word;
    } else if (line.length + 1 + word.length <= width) {
      line = '$line $word';
    } else {
      out.add(line);
      line = word;
    }
  }
  if (line.isNotEmpty || out.isEmpty) out.add(line);
  return out;
}

/// Acomoda texto y renglones izquierda/derecha a las columnas del papel.
List<TicketLine> layoutText(TicketOp op, int columns) {
  switch (op) {
    case TText(:final text, :final align, :final bold, :final big):
      final width = big ? columns ~/ 2 : columns;
      return [for (final l in wrapText(normalizeTicketText(text), width)) TicketLine(l, align: align, bold: bold, big: big)];
    case TRow(:final left, :final right, :final bold, :final big):
      final width = big ? columns ~/ 2 : columns;
      final l = normalizeTicketText(left).trim();
      final r = normalizeTicketText(right).trim();
      if (l.length + r.length + 1 <= width) {
        return [TicketLine(l + ' ' * (width - l.length - r.length) + r, bold: bold, big: big)];
      }
      // No cabe: la izquierda en sus renglones y la derecha al final, alineada.
      final lines = wrapText(l, width);
      final last = lines.removeLast();
      return [
        for (final x in lines) TicketLine(x, bold: bold, big: big),
        if (last.length + r.length + 1 <= width)
          TicketLine(last + ' ' * (width - last.length - r.length) + r, bold: bold, big: big)
        else ...[
          TicketLine(last, bold: bold, big: big),
          TicketLine(r.length >= width ? r.substring(0, width) : ' ' * (width - r.length) + r, bold: bold, big: big),
        ],
      ];
    case TDivider(:final char):
      return [TicketLine(char * columns)];
    default:
      return const [];
  }
}

/// Unicode → CP850; CP858 es igual con € en 0xD5.
const Map<String, int> _cp850 = {
  'Ç': 0x80, 'ü': 0x81, 'é': 0x82, 'â': 0x83, 'ä': 0x84, 'à': 0x85, 'å': 0x86, 'ç': 0x87,
  'ê': 0x88, 'ë': 0x89, 'è': 0x8A, 'ï': 0x8B, 'î': 0x8C, 'ì': 0x8D, 'Ä': 0x8E, 'Å': 0x8F,
  'É': 0x90, 'æ': 0x91, 'Æ': 0x92, 'ô': 0x93, 'ö': 0x94, 'ò': 0x95, 'û': 0x96, 'ù': 0x97,
  'ÿ': 0x98, 'Ö': 0x99, 'Ü': 0x9A, 'ø': 0x9B, '£': 0x9C, 'Ø': 0x9D, '×': 0x9E,
  'á': 0xA0, 'í': 0xA1, 'ó': 0xA2, 'ú': 0xA3, 'ñ': 0xA4, 'Ñ': 0xA5, 'ª': 0xA6, 'º': 0xA7,
  '¿': 0xA8, '®': 0xA9, '¬': 0xAA, '½': 0xAB, '¼': 0xAC, '¡': 0xAD,
  'Á': 0xB5, 'Â': 0xB6, 'À': 0xB7, '©': 0xB8, '¢': 0xBD, '¥': 0xBE, 'ã': 0xC6, 'Ã': 0xC7,
  'Ê': 0xD2, 'Ë': 0xD3, 'È': 0xD4, 'Í': 0xD6, 'Î': 0xD7, 'Ï': 0xD8, 'Ì': 0xDE,
  'Ó': 0xE0, 'ß': 0xE1, 'Ô': 0xE2, 'Ò': 0xE3, 'õ': 0xE4, 'Õ': 0xE5, 'µ': 0xE6,
  'Ú': 0xE9, 'Û': 0xEA, 'Ù': 0xEB, 'ý': 0xEC, 'Ý': 0xED, '±': 0xF1, '§': 0xF5, '÷': 0xF6,
  '°': 0xF8, '·': 0xFA, '¹': 0xFB, '³': 0xFC, '²': 0xFD,
};

const Map<String, String> _fold = {
  'á': 'a', 'à': 'a', 'ä': 'a', 'â': 'a', 'ã': 'a', 'Á': 'A', 'À': 'A', 'Ä': 'A', 'Â': 'A', 'Ã': 'A',
  'é': 'e', 'è': 'e', 'ë': 'e', 'ê': 'e', 'É': 'E', 'È': 'E', 'Ë': 'E', 'Ê': 'E',
  'í': 'i', 'ì': 'i', 'ï': 'i', 'î': 'i', 'Í': 'I', 'Ì': 'I', 'Ï': 'I', 'Î': 'I',
  'ó': 'o', 'ò': 'o', 'ö': 'o', 'ô': 'o', 'õ': 'o', 'Ó': 'O', 'Ò': 'O', 'Ö': 'O', 'Ô': 'O', 'Õ': 'O',
  'ú': 'u', 'ù': 'u', 'ü': 'u', 'û': 'u', 'Ú': 'U', 'Ù': 'U', 'Ü': 'U', 'Û': 'U',
  'ñ': 'n', 'Ñ': 'N', 'ç': 'c', 'Ç': 'C', '¿': '?', '¡': '!', '°': 'o', 'º': 'o', 'ª': 'a', '€': 'EUR', '×': 'x',
};

/// Bytes de un texto en la página de códigos elegida; lo que no existe en
/// ella se escribe sin acento (y si no, '?').
List<int> encodeTicketText(String text, TicketCharset charset) {
  final out = <int>[];
  for (final ch in text.split('')) {
    final c = ch.codeUnitAt(0);
    if (c < 0x80) {
      out.add(c);
      continue;
    }
    if (charset == TicketCharset.cp858 && ch == '€') {
      out.add(0xD5);
      continue;
    }
    final code = charset == TicketCharset.ascii ? null : _cp850[ch];
    if (code != null) {
      out.add(code);
    } else {
      out.addAll((_fold[ch] ?? '?').codeUnits);
    }
  }
  return out;
}

/// Imagen a 1 bit (difuminado Floyd–Steinberg sobre fondo blanco), escalada a
/// lo más [maxWidth] puntos. Regresa (ancho en bytes, alto, bits; 1 = negro).
(int, int, Uint8List) monochrome(img.Image src, int maxWidth) {
  var image = src.width > maxWidth ? img.copyResize(src, width: maxWidth, interpolation: img.Interpolation.average) : src;
  final w = image.width, h = image.height;
  final lum = Float32List(w * h);
  for (var y = 0; y < h; y++) {
    for (var x = 0; x < w; x++) {
      final p = image.getPixel(x, y);
      final a = p.aNormalized;
      final l = 0.299 * p.rNormalized + 0.587 * p.gNormalized + 0.114 * p.bNormalized;
      lum[y * w + x] = (1 - a + a * l) * 255; // transparente = blanco
    }
  }
  final bytesPerRow = (w + 7) ~/ 8;
  final bits = Uint8List(bytesPerRow * h);
  for (var y = 0; y < h; y++) {
    for (var x = 0; x < w; x++) {
      final i = y * w + x;
      final old = lum[i];
      final black = old < 128;
      final err = old - (black ? 0 : 255);
      if (black) bits[y * bytesPerRow + (x >> 3)] |= 0x80 >> (x & 7);
      if (x + 1 < w) lum[i + 1] += err * 7 / 16;
      if (y + 1 < h) {
        if (x > 0) lum[i + w - 1] += err * 3 / 16;
        lum[i + w] += err * 5 / 16;
        if (x + 1 < w) lum[i + w + 1] += err * 1 / 16;
      }
    }
  }
  return (bytesPerRow, h, bits);
}

/// Convierte un [Ticket] a ESC/POS (Epson y compatibles: Xprinter, GOOJPRT,
/// Zjiang, PT-210, MTP-II, etc.).
class EscPosEncoder {
  EscPosEncoder({required this.paperMm, this.charset = TicketCharset.cp858, this.rasterizer, this.cut = true});

  final int paperMm;
  final TicketCharset charset;
  final TicketRasterizer? rasterizer;
  final bool cut;

  /// Puntos útiles: 384 en 58 mm y 576 en 80 mm (203 dpi).
  int get widthDots => paperMm >= 80 ? 576 : 384;
  int get columns => paperMm >= 80 ? 48 : 32;

  static const _esc = 0x1B, _gs = 0x1D;

  Future<List<int>> encode(Ticket t) async {
    final out = <int>[_esc, 0x40]; // inicializar
    switch (charset) {
      case TicketCharset.cp858:
        out.addAll([_esc, 0x74, 19]);
      case TicketCharset.cp850:
        out.addAll([_esc, 0x74, 2]);
      default:
        out.addAll([_esc, 0x74, 0]);
    }
    final pending = <TicketLine>[];

    Future<void> flush() async {
      if (pending.isEmpty) return;
      if (charset == TicketCharset.raster && rasterizer != null) {
        out.addAll(_align(TAlign.left));
        out.addAll(raster(await rasterizer!(List.of(pending), t.columns, widthDots), widthDots));
      } else {
        for (final l in pending) {
          out
            ..addAll(_align(l.align))
            ..addAll([_esc, 0x45, l.bold ? 1 : 0])
            ..addAll([_gs, 0x21, l.big ? 0x11 : 0x00])
            ..addAll(encodeTicketText(l.text, charset))
            ..add(0x0A);
        }
        out.addAll([_esc, 0x45, 0, _gs, 0x21, 0]);
      }
      pending.clear();
    }

    for (final op in t.ops) {
      switch (op) {
        case TText() || TRow() || TDivider():
          pending.addAll(layoutText(op, t.columns));
        case TFeed(:final lines):
          await flush();
          out.addAll([_esc, 0x64, lines.clamp(1, 10)]);
        case TQr(:final data):
          await flush();
          out
            ..addAll(_align(TAlign.center))
            ..addAll(qr(data))
            ..addAll(_align(TAlign.left));
        case TBarcode(:final data):
          await flush();
          out
            ..addAll(_align(TAlign.center))
            ..addAll(barcode128(data))
            ..addAll(_align(TAlign.left));
        case TImage(:final image, :final maxWidthFraction):
          await flush();
          out
            ..addAll(_align(TAlign.center))
            ..addAll(raster(image, (widthDots * maxWidthFraction).round()))
            ..addAll(_align(TAlign.left));
      }
    }
    await flush();
    out.addAll([_esc, 0x64, 4]);
    if (cut) out.addAll([_gs, 0x56, 0x42, 0x00]);
    return out;
  }

  static List<int> _align(TAlign a) => [_esc, 0x61, a.index];

  /// QR modelo 2, módulo 6, corrección M.
  static List<int> qr(String data) {
    final bytes = encodeTicketText(data, TicketCharset.ascii);
    final len = bytes.length + 3;
    return [
      _gs, 0x28, 0x6B, 0x04, 0x00, 0x31, 0x41, 0x32, 0x00,
      _gs, 0x28, 0x6B, 0x03, 0x00, 0x31, 0x43, 0x06,
      _gs, 0x28, 0x6B, 0x03, 0x00, 0x31, 0x45, 0x31,
      _gs, 0x28, 0x6B, len & 0xFF, len >> 8, 0x31, 0x50, 0x30, ...bytes,
      _gs, 0x28, 0x6B, 0x03, 0x00, 0x31, 0x51, 0x30,
      0x0A,
    ];
  }

  /// Código de barras CODE128 (juego B) con el texto debajo.
  static List<int> barcode128(String data) {
    final bytes = encodeTicketText(data, TicketCharset.ascii).take(40).toList();
    return [
      _gs, 0x68, 0x50, // alto
      _gs, 0x77, 0x02, // ancho del módulo
      _gs, 0x48, 0x02, // texto abajo
      _gs, 0x6B, 0x49, bytes.length + 2, 0x7B, 0x42, ...bytes,
      0x0A,
    ];
  }

  /// Imagen con GS v 0, en franjas para no llenar el búfer de la impresora.
  static List<int> raster(img.Image image, int maxWidth) {
    final (bytesPerRow, h, bits) = monochrome(image, maxWidth);
    final out = <int>[];
    const band = 128;
    for (var y = 0; y < h; y += band) {
      final rows = (h - y) < band ? h - y : band;
      out.addAll([_gs, 0x76, 0x30, 0x00, bytesPerRow & 0xFF, bytesPerRow >> 8, rows & 0xFF, rows >> 8]);
      out.addAll(bits.sublist(y * bytesPerRow, (y + rows) * bytesPerRow));
    }
    return out;
  }
}
