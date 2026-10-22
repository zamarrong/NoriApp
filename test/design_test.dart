import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nori_mobile/core/design/design.dart';
import 'package:nori_mobile/features/customers/customer_card.dart';

/// Con "reducir movimiento": sin animaciones que esperar.
Widget _app(Widget child, {bool dark = false, bool highContrast = false}) => MaterialApp(
      theme: dark ? NrTheme.dark(NrColors.defaultAccent, highContrast: highContrast) : NrTheme.light(NrColors.defaultAccent, highContrast: highContrast),
      builder: (context, child) => MediaQuery(data: MediaQuery.of(context).copyWith(disableAnimations: true), child: child!),
      home: Scaffold(body: child),
    );

void main() {
  test('cifras cortas para espacios chicos', () {
    expect(moneyCompact('9500'), r'$9,500.00');
    expect(moneyCompact('184230'), r'$184 k');
    expect(moneyCompact('15731.29'), r'$15.7 k');
    expect(moneyCompact('2500000'), r'$2.5 M');
    expect(moneyCompact('6844.95', from: 1000), r'$6.8 k');
  });

  test('el texto sobre el acento se lee y el alto contraste endurece la paleta', () {
    expect(NrColors.light(const Color(0xFFFACC15)).onAccent, isNot(Colors.white));
    expect(NrColors.light().onAccent, Colors.white);
    final hc = NrColors.light(NrColors.defaultAccent, true);
    expect(hc.highContrast, isTrue);
    expect(hc.body, const Color(0xFF000000));
    expect(hc.shadow, isEmpty);
  });

  test('días relativos', () {
    final now = DateTime.now();
    expect(relativeDay(now), 'hoy');
    expect(relativeDay(now.subtract(const Duration(days: 1))), 'ayer');
    expect(relativeDay(now.subtract(const Duration(days: 5))), 'hace 5 días');
  });

  testWidgets('monto con centavos aparte y estado vacío con acción, claro y oscuro', (tester) async {
    for (final dark in [false, true]) {
      var tapped = false;
      await tester.pumpWidget(_app(
        Column(children: [
          const NrAmount('1284.5', size: 30),
          Expanded(child: NrEmpty(icon: Icons.inbox, title: 'Sin documentos', action: 'Vender', onAction: () => tapped = true)),
        ]),
        dark: dark,
      ));
      expect(find.textContaining(r'$1,284'), findsOneWidget);
      expect(find.text('Sin documentos'), findsOneWidget);
      await tester.tap(find.text('Vender'));
      expect(tapped, isTrue);
    }
  });

  testWidgets('el paso de cantidad respeta el mínimo y el máximo', (tester) async {
    var value = Dec.one;
    await tester.pumpWidget(_app(StatefulBuilder(
      builder: (context, setState) => NrStepper(value: value, min: Dec.one, max: Dec.parse('2'), onChanged: (v) => setState(() => value = v)),
    )));
    await tester.tap(find.byIcon(Icons.remove_rounded));
    expect(value, Dec.one);
    await tester.tap(find.byIcon(Icons.add_rounded));
    await tester.pump();
    expect(value, Dec.parse('2'));
    await tester.tap(find.byIcon(Icons.add_rounded));
    expect(value, Dec.parse('2'));
  });
}
