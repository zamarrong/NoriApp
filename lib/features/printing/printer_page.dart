import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/design/design.dart';
import 'escpos.dart';
import 'printer.dart';
import 'templates.dart';

/// Más › Impresora: buscar y elegir la impresora térmica, ancho de papel,
/// acentos, copias, impresión automática por tipo y prueba.
class PrinterPage extends ConsumerStatefulWidget {
  const PrinterPage({super.key});

  @override
  ConsumerState<PrinterPage> createState() => _PrinterPageState();
}

class _PrinterPageState extends ConsumerState<PrinterPage> {
  final found = <String, FoundPrinter>{};
  StreamSubscription<List<FoundPrinter>>? _sub;
  bool scanning = false;
  bool testing = false;
  late final footer = TextEditingController(text: ref.read(printerSettingsProvider).footer);

  @override
  void dispose() {
    _sub?.cancel();
    if (scanning) FlutterBluePlus.stopScan();
    footer.dispose();
    super.dispose();
  }

  PrinterSettings get s => ref.read(printerSettingsProvider);
  void _set(PrinterSettings next) => ref.read(printerSettingsProvider.notifier).set(next);

  Future<void> _scan() async {
    if (!await ensureBluetoothPermission()) {
      if (mounted) showSnack(context, 'Se necesita el permiso de Bluetooth (Ajustes del teléfono).');
      return;
    }
    setState(() {
      found.clear();
      scanning = true;
    });
    try {
      for (final p in await pairedClassic()) {
        found['c:${p.id}'] = p;
      }
      if (mounted) setState(() {});
      await _sub?.cancel();
      _sub = scanBle().listen((list) {
        if (!mounted) return;
        setState(() {
          for (final p in list) {
            found['b:${p.id}'] = p;
          }
        });
      });
      await Future<void>.delayed(const Duration(seconds: 8));
    } catch (e) {
      if (mounted) showSnack(context, 'No se pudo buscar: $e');
    } finally {
      if (mounted) setState(() => scanning = false);
    }
  }

  Future<void> _test() async {
    setState(() => testing = true);
    await printTicket(context, ref, (b) {
      final t = Ticket(b.columns);
      if (b.logo != null) t.add(TImage(b.logo!));
      if ((b.companyName ?? '').isNotEmpty) t.center(b.companyName!, bold: true);
      t.center('PRUEBA DE IMPRESIÓN', bold: true, big: true);
      t.divider();
      t.text('Papel ${s.paperMm} mm · ${b.columns} columnas');
      t.text('Acentos: áéíóú ÁÉÍÓÚ ñÑ ü ¿? ¡! °');
      t.row('Izquierda', 'Derecha');
      t.row('TOTAL', r'$1,234.50', bold: true, big: true);
      t.divider();
      t.center('Si lees bien los acentos, la página de códigos es correcta.');
      if (b.code == 'barcode') {
        t.add(const TBarcode('PRUEBA-123'));
      } else if (b.code == 'qr') {
        t.add(const TQr('PRUEBA-123'));
      }
      return t;
    });
    if (mounted) setState(() => testing = false);
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(printerSettingsProvider);
    final list = found.values.toList()..sort((a, b) => (b.rssi ?? -999).compareTo(a.rssi ?? -999));
    return Scaffold(
      appBar: AppBar(title: const Text('Impresora')),
      body: ListView(padding: const EdgeInsets.all(NrSpace.gutter), children: [
        NrCard(
          depth: NrDepth.floating,
          radius: NrRadius.hero,
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(color: s.configured ? context.nr.successBg : context.nr.accentSoft, borderRadius: BorderRadius.circular(NrRadius.xl)),
                child: Icon(s.configured ? Icons.print_rounded : Icons.print_disabled_outlined, color: s.configured ? context.nr.success : context.nr.accent),
              ),
              const SizedBox(width: NrSpace.md),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(s.configured ? (s.name ?? s.id!) : 'Sin impresora', style: NrText.headline(context)),
                  Text(
                    s.configured ? '${s.transport == 'classic' ? 'Bluetooth clásico' : 'Bluetooth LE'} · ${s.paperMm} mm' : 'Busca y elige una impresora térmica Bluetooth.',
                    style: NrText.caption(context),
                  ),
                ]),
              ),
              if (s.configured)
                TextButton(onPressed: () => _set(PrinterSettings.fromJson({...s.toJson(), 'id': null, 'name': null})), child: const Text('Olvidar')),
            ]),
            if (s.configured) ...[
              const SizedBox(height: NrSpace.md),
              NrButton(label: 'Imprimir prueba', icon: Icons.receipt_long_rounded, busy: testing, onPressed: _test),
            ],
          ]),
        ),
        NrSectionHeader('Buscar'),
        NrButton(
          variant: NrButtonVariant.secondary,
          onPressed: scanning ? null : _scan,
          busy: scanning,
          icon: Icons.bluetooth_searching_rounded,
          label: scanning ? 'Buscando…' : 'Buscar impresoras',
        ),
        const SizedBox(height: NrSpace.sm),
        Text(
          classicSupported
              ? 'Las impresoras de Bluetooth clásico deben emparejarse antes en Ajustes › Bluetooth del teléfono (PIN usual 0000 o 1234). Las BLE aparecen al buscar.'
              : 'En iPhone solo funcionan impresoras Bluetooth LE (BLE). Las de Bluetooth clásico requieren certificación MFi de Apple y no son compatibles.',
          style: NrText.caption(context),
        ),
        if (list.isNotEmpty) ...[
          const SizedBox(height: NrSpace.md),
          NrGroup(children: [
            for (final p in list)
              NrListRow(
                leading: Icon(p.transport == 'classic' ? Icons.bluetooth : Icons.bluetooth_audio),
                title: p.name,
                subtitle: '${p.transport == 'classic' ? 'Clásico (emparejada)' : 'BLE'} · ${p.id}',
                trailing: s.id == p.id ? Icon(Icons.check_circle_rounded, color: context.nr.success) : null,
                onTap: () {
                  _set(s.copyWith(id: p.id, name: p.name, transport: p.transport));
                  showSnack(context, 'Impresora ${p.name} elegida.');
                },
              ),
          ]),
        ],
        NrSectionHeader('Papel y formato'),
        NrSegmented<int>(values: const [58, 80], labels: const ['58 mm', '80 mm'], selected: s.paperMm, onChanged: (v) => _set(s.copyWith(paperMm: v))),
        const SizedBox(height: NrSpace.md),
        DropdownButtonFormField<TicketCharset>(
          isExpanded: true,
          initialValue: s.charset,
          decoration: const InputDecoration(labelText: 'Acentos y ñ'),
          items: const [
            DropdownMenuItem(value: TicketCharset.cp858, child: Text('Página de códigos CP858 (recomendado)')),
            DropdownMenuItem(value: TicketCharset.cp850, child: Text('Página de códigos CP850')),
            DropdownMenuItem(value: TicketCharset.raster, child: Text('Como imagen (más lento)')),
            DropdownMenuItem(value: TicketCharset.ascii, child: Text('Sin acentos')),
          ],
          onChanged: (v) => _set(s.copyWith(charset: v)),
        ),
        const SizedBox(height: NrSpace.md),
        DropdownButtonFormField<String>(
          isExpanded: true,
          initialValue: s.code,
          decoration: const InputDecoration(labelText: 'Código del folio'),
          items: const [
            DropdownMenuItem(value: 'qr', child: Text('Código QR')),
            DropdownMenuItem(value: 'barcode', child: Text('Código de barras')),
            DropdownMenuItem(value: 'none', child: Text('Ninguno')),
          ],
          onChanged: (v) => _set(s.copyWith(code: v)),
        ),
        const SizedBox(height: NrSpace.md),
        TextField(
          controller: footer,
          decoration: const InputDecoration(labelText: 'Texto al pie'),
          onChanged: (v) => _set(s.copyWith(footer: v)),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Logo de la empresa'),
          value: s.logo,
          onChanged: (v) => _set(s.copyWith(logo: v)),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Sellos del CFDI completos'),
          subtitle: Text(s.fullSeals ? 'Sellos y cadena original completos' : 'Sellos abreviados (ticket más corto)'),
          value: s.fullSeals,
          onChanged: (v) => _set(s.copyWith(fullSeals: v)),
        ),
        Row(children: [
          Expanded(child: Text('Copias', style: NrText.body(context))),
          NrStepper(
            compact: true,
            value: Dec.parse(s.copies),
            max: Dec.parse(5),
            min: Dec.one,
            onChanged: (v) => _set(s.copyWith(copies: v.toDouble().round().clamp(1, 5))),
          ),
        ]),
        NrSectionHeader('Imprimir al guardar'),
        NrGroup(children: [
          for (final e in printKinds.entries)
            SwitchListTile(
              title: Text(e.value),
              value: s.auto.contains(e.key),
              onChanged: (v) => _set(s.copyWith(auto: v ? {...s.auto, e.key} : ({...s.auto}..remove(e.key)))),
            ),
        ]),
        const SizedBox(height: NrSpace.xl),
      ]),
    );
  }
}
