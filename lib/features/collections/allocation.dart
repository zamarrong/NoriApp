import '../../core/util/decimal.dart';

/// Reparte un cobro entre documentos abiertos en el orden dado (la API los
/// manda del vencimiento más viejo al más nuevo). Las notas de crédito
/// (saldo negativo) no se tocan. Regresa {document_id: monto} y el sobrante
/// (que en un pago a cuenta queda como saldo a favor).
(Map<int, Dec> applied, Dec leftover) allocatePayment(Dec amount, List<Map<String, dynamic>> openDocs) {
  final applied = <int, Dec>{};
  var left = amount;
  for (final d in openDocs) {
    if (left <= Dec.zero) break;
    final balance = Dec.parse(d['balance']);
    if (balance <= Dec.zero) continue;
    final take = left.min(balance);
    applied[(d['id'] as num).toInt()] = take;
    left -= take;
  }
  return (applied, left);
}
