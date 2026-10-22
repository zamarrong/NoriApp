import 'package:intl/intl.dart';

/// Decimal de punto fijo (6 decimales) sobre [BigInt]. La API manda importes y
/// cantidades como cadenas ("232.000000"); nunca se suman como `double`.
class Dec implements Comparable<Dec> {
  const Dec._(this._units);

  static const int scale = 6;
  static final BigInt _factor = BigInt.from(10).pow(scale);

  final BigInt _units;

  static final Dec zero = Dec._(BigInt.zero);
  static final Dec one = Dec.parse('1');

  /// Acepta cadenas ("12.5", "-3", "1,234.50"), números y null (= 0).
  factory Dec.parse(Object? value) {
    if (value == null) return Dec._(BigInt.zero);
    if (value is Dec) return value;
    if (value is int) return Dec._(BigInt.from(value) * _factor);
    var s = value.toString().trim().replaceAll(',', '');
    if (s.isEmpty) return Dec._(BigInt.zero);
    if (value is double) s = value.toStringAsFixed(scale);
    final negative = s.startsWith('-');
    if (negative || s.startsWith('+')) s = s.substring(1);
    final parts = s.split('.');
    final whole = BigInt.tryParse(parts[0].isEmpty ? '0' : parts[0]);
    if (whole == null) return Dec._(BigInt.zero);
    var frac = parts.length > 1 ? parts[1] : '';
    var roundUp = false;
    if (frac.length > scale) {
      roundUp = int.tryParse(frac[scale]) != null && int.parse(frac[scale]) >= 5;
      frac = frac.substring(0, scale);
    }
    frac = frac.padRight(scale, '0');
    var units = whole * _factor + (BigInt.tryParse(frac) ?? BigInt.zero);
    if (roundUp) units += BigInt.one;
    return Dec._(negative ? -units : units);
  }

  static Dec? tryParse(String? s) {
    if (s == null || s.trim().isEmpty) return null;
    if (!RegExp(r'^\s*[-+]?[\d,]*\.?\d*\s*$').hasMatch(s)) return null;
    return Dec.parse(s);
  }

  Dec operator +(Dec o) => Dec._(_units + o._units);
  Dec operator -(Dec o) => Dec._(_units - o._units);
  Dec operator -() => Dec._(-_units);
  Dec operator *(Dec o) => Dec._(_roundDiv(_units * o._units, _factor));

  Dec divide(Dec o) => o.isZero ? Dec.zero : Dec._(_roundDiv(_units * _factor, o._units));

  static BigInt _roundDiv(BigInt a, BigInt b) {
    final q = a ~/ b;
    final r = a.remainder(b);
    if (r.abs() * BigInt.two >= b.abs()) {
      return (a.isNegative != b.isNegative) ? q - BigInt.one : q + BigInt.one;
    }
    return q;
  }

  /// Redondeo comercial (mitad lejos de cero) a [places] decimales.
  Dec round([int places = 2]) {
    final f = BigInt.from(10).pow(scale - places);
    return Dec._(_roundDiv(_units, f) * f);
  }

  bool get isZero => _units == BigInt.zero;
  bool get isNegative => _units.isNegative;
  bool operator >(Dec o) => _units > o._units;
  bool operator <(Dec o) => _units < o._units;
  bool operator >=(Dec o) => _units >= o._units;
  bool operator <=(Dec o) => _units <= o._units;
  Dec min(Dec o) => this <= o ? this : o;
  Dec max(Dec o) => this >= o ? this : o;

  @override
  int compareTo(Dec other) => _units.compareTo(other._units);

  @override
  bool operator ==(Object other) => other is Dec && other._units == _units;

  @override
  int get hashCode => _units.hashCode;

  /// Cadena con [places] decimales, como la espera la API ("232.00").
  String toFixed([int places = 2]) {
    final r = round(places)._units;
    final neg = r.isNegative;
    final abs = r.abs();
    final whole = abs ~/ _factor;
    final frac = (abs % _factor).toString().padLeft(scale, '0').substring(0, places);
    final body = places == 0 ? '$whole' : '$whole.$frac';
    return neg ? '-$body' : body;
  }

  /// Número para el JSON de la API (los cuerpos piden `number`).
  num toJson([int places = 6]) => num.parse(toFixed(places));

  /// Cantidad sin ceros sobrantes ("2", "2.5").
  String toQty() {
    var s = toFixed(4);
    if (s.contains('.')) s = s.replaceFirst(RegExp(r'\.?0+$'), '');
    return s;
  }

  @override
  String toString() => toFixed(scale);
}

final _money = NumberFormat.currency(locale: 'es_MX', symbol: r'$', decimalDigits: 2);

/// "$1,234.50" a partir de un decimal de la API.
String money(Object? value) {
  final d = Dec.parse(value).round(2);
  return _money.format(num.parse(d.toFixed(2)));
}
