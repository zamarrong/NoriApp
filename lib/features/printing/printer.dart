import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image/image.dart' as img;
import 'package:permission_handler/permission_handler.dart';
import 'package:print_bluetooth_thermal/print_bluetooth_thermal.dart';

import '../../core/api/api_client.dart';
import '../../core/api/api_error.dart';
import '../../core/design/design.dart';
import '../../core/providers.dart';
import '../sales/cart.dart';
import 'cfdi.dart';
import 'escpos.dart';
import 'templates.dart';

/// Impresora térmica del dispositivo (Más › Impresora). Se guarda por equipo.
class PrinterSettings {
  const PrinterSettings({
    this.id,
    this.name,
    this.transport = 'ble',
    this.paperMm = 58,
    this.charset = TicketCharset.cp858,
    this.copies = 1,
    this.logo = true,
    this.footer = '¡Gracias por su compra!',
    this.code = 'qr',
    this.auto = const {},
    this.fullSeals = true,
  });

  /// MAC (Bluetooth clásico) o identificador BLE.
  final String? id;
  final String? name;

  /// 'ble' o 'classic' (SPP, solo Android).
  final String transport;
  final int paperMm;
  final TicketCharset charset;
  final int copies;
  final bool logo;
  final String footer;
  final String code;

  /// Tipos que se imprimen solos al guardar ([printKinds]).
  final Set<String> auto;

  /// CFDI: sellos completos (true) o abreviados.
  final bool fullSeals;

  bool get configured => id != null && id!.isNotEmpty;
  int get columns => paperMm >= 80 ? 48 : 32;

  PrinterSettings copyWith({
    String? id,
    String? name,
    String? transport,
    int? paperMm,
    TicketCharset? charset,
    int? copies,
    bool? logo,
    String? footer,
    String? code,
    Set<String>? auto,
    bool? fullSeals,
  }) =>
      PrinterSettings(
        id: id ?? this.id,
        name: name ?? this.name,
        transport: transport ?? this.transport,
        paperMm: paperMm ?? this.paperMm,
        charset: charset ?? this.charset,
        copies: copies ?? this.copies,
        logo: logo ?? this.logo,
        footer: footer ?? this.footer,
        code: code ?? this.code,
        auto: auto ?? this.auto,
        fullSeals: fullSeals ?? this.fullSeals,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'transport': transport,
        'paper_mm': paperMm,
        'charset': charset.name,
        'copies': copies,
        'logo': logo,
        'footer': footer,
        'code': code,
        'auto': auto.toList(),
        'full_seals': fullSeals,
      };

  factory PrinterSettings.fromJson(Map<String, dynamic> j) => PrinterSettings(
        id: j['id'] as String?,
        name: j['name'] as String?,
        transport: (j['transport'] as String?) ?? 'ble',
        paperMm: (j['paper_mm'] as num?)?.toInt() ?? 58,
        charset: TicketCharset.values.asNameMap()[j['charset']] ?? TicketCharset.cp858,
        copies: (j['copies'] as num?)?.toInt() ?? 1,
        logo: j['logo'] != false,
        footer: (j['footer'] as String?) ?? '',
        code: (j['code'] as String?) ?? 'qr',
        auto: {...((j['auto'] as List?) ?? const []).map((e) => '$e')},
        fullSeals: j['full_seals'] != false,
      );
}

class PrinterSettingsNotifier extends Notifier<PrinterSettings> {
  static const _key = 'nori.printer';

  @override
  PrinterSettings build() {
    final raw = ref.read(prefsProvider).getString(_key);
    if (raw == null) return const PrinterSettings();
    try {
      return PrinterSettings.fromJson(Map<String, dynamic>.from(jsonDecode(raw) as Map));
    } catch (_) {
      return const PrinterSettings();
    }
  }

  void set(PrinterSettings s) {
    ref.read(prefsProvider).setString(_key, jsonEncode(s.toJson()));
    state = s;
  }
}

final printerSettingsProvider = NotifierProvider<PrinterSettingsNotifier, PrinterSettings>(PrinterSettingsNotifier.new);

/// Una impresora encontrada al buscar.
class FoundPrinter {
  const FoundPrinter(this.id, this.name, this.transport, {this.rssi});
  final String id;
  final String name;
  final String transport;
  final int? rssi;
}

bool get classicSupported => !kIsWeb && Platform.isAndroid;

/// Permisos de Bluetooth. En iOS el sistema los pide al primer uso.
Future<bool> ensureBluetoothPermission() async {
  if (kIsWeb || !Platform.isAndroid) return true;
  final r = await [Permission.bluetoothScan, Permission.bluetoothConnect, Permission.locationWhenInUse].request();
  // Android 12+: escanear y conectar; Android ≤ 11: ubicación.
  final scan = r[Permission.bluetoothScan];
  final connect = r[Permission.bluetoothConnect];
  if (scan == PermissionStatus.granted && connect == PermissionStatus.granted) return true;
  return r[Permission.locationWhenInUse] == PermissionStatus.granted && scan != PermissionStatus.permanentlyDenied;
}

/// Impresoras BLE cercanas (Android y iOS).
Stream<List<FoundPrinter>> scanBle({Duration timeout = const Duration(seconds: 8)}) async* {
  if (await FlutterBluePlus.isSupported == false) return;
  await FlutterBluePlus.startScan(timeout: timeout);
  yield* FlutterBluePlus.onScanResults.map((results) => [
        for (final r in results)
          if (r.device.platformName.isNotEmpty || r.advertisementData.advName.isNotEmpty)
            FoundPrinter(r.device.remoteId.str, r.device.platformName.isNotEmpty ? r.device.platformName : r.advertisementData.advName, 'ble', rssi: r.rssi),
      ]);
}

/// Impresoras de Bluetooth clásico ya emparejadas en Ajustes (solo Android).
Future<List<FoundPrinter>> pairedClassic() async {
  if (!classicSupported) return [];
  final list = await PrintBluetoothThermal.pairedBluetooths;
  return [for (final b in list) FoundPrinter(b.macAdress, b.name, 'classic')];
}

/// Servicios de impresión conocidos (genéricas chinas, Xprinter, Zjiang, ISSC) y,
/// si no, la primera característica que acepte escritura.
const _knownWrite = ['2af1', 'bef8d6c9-9c21-4c9e-b632-bd58c1009f9f', '49535343-8841-43f4-a8d4-ecbe34729bb3', 'ff02'];

Future<void> _sendBle(String id, List<int> bytes) async {
  final device = BluetoothDevice.fromId(id);
  if (!device.isConnected) await device.connect(timeout: const Duration(seconds: 12));
  final services = await device.discoverServices();
  BluetoothCharacteristic? target;
  for (final s in services) {
    for (final c in s.characteristics) {
      final writable = c.properties.write || c.properties.writeWithoutResponse;
      if (!writable) continue;
      if (_knownWrite.any((u) => c.uuid.str128.toLowerCase().contains(u) || c.uuid.str.toLowerCase() == u)) {
        target = c;
        break;
      }
      target ??= c;
    }
  }
  if (target == null) throw ApiException(code: 'printer', message: 'La impresora no acepta datos por BLE.');
  final noResponse = target.properties.writeWithoutResponse;
  final chunk = (device.mtuNow - 3).clamp(20, noResponse ? 180 : 509);
  for (var i = 0; i < bytes.length; i += chunk) {
    final end = i + chunk > bytes.length ? bytes.length : i + chunk;
    await target.write(bytes.sublist(i, end), withoutResponse: noResponse);
    // Sin confirmación, una pausa corta evita llenar el búfer de la impresora.
    if (noResponse) await Future<void>.delayed(const Duration(milliseconds: 15));
  }
}

Future<void> _sendClassic(String mac, List<int> bytes) async {
  if (!classicSupported) throw ApiException(code: 'printer', message: 'Bluetooth clásico solo funciona en Android.');
  if (!await PrintBluetoothThermal.bluetoothEnabled) throw ApiException(code: 'printer', message: 'Enciende el Bluetooth.');
  if (!await PrintBluetoothThermal.connectionStatus) {
    final ok = await PrintBluetoothThermal.connect(macPrinterAddress: mac);
    if (!ok) throw ApiException(code: 'printer', message: 'No se pudo conectar con la impresora. ¿Está encendida y emparejada?');
  }
  final ok = await PrintBluetoothThermal.writeBytes(bytes);
  if (!ok) throw ApiException(code: 'printer', message: 'La impresora no recibió el ticket.');
}

/// Pinta renglones en letra monoespaciada (acentos como imagen).
Future<img.Image> rasterizeLines(List<TicketLine> lines, int columns, int widthDots) async {
  final charW = widthDots / columns;
  final fontSize = charW / 0.6;
  final lineH = (fontSize * 1.25).ceilToDouble();
  final smallFont = widthDots / smallColumns(columns) / 0.6;
  final heights = [for (final l in lines) l.big ? lineH * 2 : (l.small ? (smallFont * 1.2).ceilToDouble() : lineH)];
  final total = heights.fold(0.0, (a, b) => a + b).ceil();
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  canvas.drawRect(Rect.fromLTWH(0, 0, widthDots.toDouble(), total.toDouble()), Paint()..color = Colors.white);
  var y = 0.0;
  for (var i = 0; i < lines.length; i++) {
    final l = lines[i];
    final tp = TextPainter(
      text: TextSpan(
        text: l.text,
        style: TextStyle(
          fontFamily: 'monospace',
          fontFamilyFallback: const ['Courier', 'Menlo', 'RobotoMono'],
          fontSize: l.big ? fontSize * 2 : (l.small ? smallFont : fontSize),
          fontWeight: l.bold ? FontWeight.w700 : FontWeight.w400,
          color: Colors.black,
        ),
      ),
      textDirection: TextDirection.ltr,
      maxLines: 1,
    )..layout(maxWidth: widthDots.toDouble());
    final x = switch (l.align) {
      TAlign.left => 0.0,
      TAlign.center => (widthDots - tp.width) / 2,
      TAlign.right => widthDots - tp.width,
    };
    tp.paint(canvas, Offset(x, y));
    y += heights[i];
  }
  final picture = recorder.endRecording();
  final image = await picture.toImage(widthDots, total < 1 ? 1 : total);
  final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
  return img.Image.fromBytes(width: widthDots, height: total < 1 ? 1 : total, bytes: data!.buffer, numChannels: 4);
}

img.Image? _logoCache;
String? _logoKey;

/// El logo de la empresa (data: URI de la sesión) listo para el ticket.
img.Image? companyLogo(WidgetRef ref) {
  final uri = '${asMap(ref.read(sessionProvider)?.tenant['company'])['logo'] ?? ''}';
  if (uri.isEmpty) return null;
  if (uri == _logoKey) return _logoCache;
  _logoKey = uri;
  try {
    final comma = uri.indexOf(',');
    final bytes = base64Decode(uri.substring(comma + 1));
    _logoCache = img.decodeImage(bytes);
  } catch (_) {
    _logoCache = null; // SVG u otro formato que no se puede rasterizar aquí
  }
  return _logoCache;
}

TicketBrand ticketBrand(WidgetRef ref, PrinterSettings s) {
  final session = ref.read(sessionProvider);
  final company = asMap(session?.tenant['company']);
  return TicketBrand(
    companyName: '${company['name'] ?? session?.tenantName ?? ''}',
    logo: s.logo ? companyLogo(ref) : null,
    seller: '${session?.salesEmployee?['name'] ?? session?.userName ?? ''}',
    footer: s.footer,
    code: s.code,
    columns: s.columns,
    fullSeals: s.fullSeals,
  );
}

/// Bytes de un ticket con la configuración del equipo.
Future<List<int>> ticketBytes(Ticket t, PrinterSettings s) =>
    EscPosEncoder(paperMm: s.paperMm, charset: s.charset, rasterizer: rasterizeLines).encode(t);

Future<void> sendToPrinter(PrinterSettings s, List<int> bytes) async {
  if (!s.configured) throw ApiException(code: 'printer', message: 'Configura una impresora en Más › Impresora.');
  if (s.transport == 'classic') {
    await _sendClassic(s.id!, bytes);
  } else {
    await _sendBle(s.id!, bytes);
  }
}

/// Imprime (con las copias configuradas) y avisa si algo falla.
/// [build] arma el ticket con la marca de la empresa.
Future<bool> printTicket(BuildContext context, WidgetRef ref, TicketBuilder build) async {
  final s = ref.read(printerSettingsProvider);
  if (!s.configured) {
    showSnack(context, 'Configura una impresora en Más › Impresora.');
    return false;
  }
  try {
    final bytes = await ticketBytes(await build(ticketBrand(ref, s)), s);
    for (var i = 0; i < s.copies.clamp(1, 5); i++) {
      await sendToPrinter(s, bytes);
    }
    return true;
  } catch (e) {
    if (context.mounted) showSnack(context, e is ApiException ? e.userMessage : 'No se pudo imprimir: $e');
    return false;
  }
}

/// Arma el ticket con la marca de la empresa; puede esperar datos (el CFDI).
typedef TicketBuilder = FutureOr<Ticket> Function(TicketBrand brand);

/// ¿Se imprimiría solo al guardar este tipo?
bool willAutoPrint(WidgetRef ref, String kind) {
  final s = ref.read(printerSettingsProvider);
  return s.configured && s.auto.contains(kind);
}

/// Impresión automática al guardar, si está activa para ese tipo.
Future<void> autoPrint(BuildContext context, WidgetRef ref, String kind, TicketBuilder build) async {
  final s = ref.read(printerSettingsProvider);
  if (!s.configured || !s.auto.contains(kind)) return;
  await printTicket(context, ref, build);
}

/// Nombres de las formas de pago (sesión, día de ruta o catálogo guardado).
Future<Map<int, String>> tenderNames(WidgetRef ref) async {
  final out = <int, String>{};
  for (final t in [...(ref.read(sessionProvider)?.tenderTypes ?? []), ...await ref.read(localDbProvider).all('tender_types')]) {
    final id = (t['id'] as num?)?.toInt();
    if (id != null) out.putIfAbsent(id, () => '${t['name']}');
  }
  return out;
}

/// Formas de pago como las pide la API → renglones del ticket, con el cambio.
Future<(List<PrintTender>, Dec?)> printTenders(WidgetRef ref, List<Map<String, dynamic>> tenders, Dec total) async {
  final names = await tenderNames(ref);
  final list = [
    for (final t in tenders)
      PrintTender(names[(t['tender_type_id'] as num?)?.toInt()] ?? 'Pago', Dec.parse(t['amount']), reference: t['reference'] as String?),
  ];
  final received = list.fold(Dec.zero, (s, t) => s + t.amount);
  return (list, received > total ? received - total : null);
}

/// Reimprimir un documento: del servidor o, sin señal, lo que se guardó al imprimirlo.
Future<void> reprintDocument(BuildContext context, WidgetRef ref, int id) async {
  final db = ref.read(localDbProvider);
  Map<String, dynamic>? doc;
  try {
    doc = asMap(unwrap(await ref.read(apiProvider).get('/documents/$id')));
    await db.putJson('print_doc_$id', doc);
  } on ApiException catch (e) {
    if (!e.isTransient) {
      if (context.mounted) showSnack(context, e.userMessage);
      return;
    }
    final cached = await db.getJson('print_doc_$id');
    doc = cached == null ? null : asMap(cached);
  }
  if (!context.mounted) return;
  if (doc == null) {
    showSnack(context, 'Sin señal: este documento no está guardado en el teléfono.');
    return;
  }
  final d = PrintDoc.fromApi(doc);
  final cfdi = mayBeCfdi(d.type) ? await loadCfdi(ref, 'documents', id) : null;
  if (!context.mounted) return;
  await printTicket(context, ref, (b) => documentTicket(d, b, cfdi: cfdi));
}

/// Pide el CFDI la primera vez y otra vez mientras siga sin timbrar (para
/// reimprimir desde el diálogo de guardado ya con el timbre).
Future<CfdiPrint?> Function() cfdiLoader(WidgetRef ref, String kind, int? id, {bool enabled = true}) {
  CfdiPrint? last;
  var done = false;
  return () async {
    if (id == null || !enabled) return null;
    if (done && (last == null || !last!.pendingStamp)) return last;
    last = await loadCfdi(ref, kind, id);
    done = true;
    return last;
  };
}

/// ¿La empresa puede timbrar? Sin país en la sesión decide el servidor
/// (`fiscal` en la respuesta y 404 cuando nunca es CFDI).
bool companyMayStamp(WidgetRef ref) {
  final company = asMap(ref.read(sessionProvider)?.tenant['company']);
  final country = '${company['country'] ?? company['country_code'] ?? ''}'.toUpperCase();
  return country.isEmpty || country == 'MX' || country == 'MEX';
}

/// Datos del CFDI para imprimir ([kind] = 'documents' o 'payments'). Con señal
/// se piden y se guardan con el documento para reimprimir sin señal. Si aún no
/// está timbrado (el PAC timbra en segundo plano) se reintenta [retries] veces.
/// null = no es fiscal: se imprime el ticket normal.
Future<CfdiPrint?> loadCfdi(WidgetRef ref, String kind, int id, {int retries = 2, Duration wait = const Duration(seconds: 3)}) async {
  if (!companyMayStamp(ref)) return null;
  final db = ref.read(localDbProvider);
  final key = 'print_cfdi_${kind}_$id';
  for (var attempt = 0;; attempt++) {
    try {
      final c = CfdiPrint.fromApi(unwrap(await ref.read(apiProvider).get('/$kind/$id/cfdi')));
      await db.putJson(key, c.toJson());
      if (c.pendingStamp && attempt < retries) {
        await Future<void>.delayed(wait);
        continue;
      }
      return c.fiscal ? c : null;
    } on ApiException catch (e) {
      if (e.status == 404) {
        await db.putJson(key, const {'fiscal': false});
        return null;
      }
      final cached = await db.getJson(key);
      if (cached == null) return null;
      final c = CfdiPrint.fromApi(cached);
      return c.fiscal ? c : null;
    }
  }
}

/// Documento para imprimir a partir del carrito (sin señal o venta de ruta).
PrintDoc printDocFromCart(
  CartController cart, {
  required String type,
  required String customer,
  String? folio,
  List<PrintTender> tenders = const [],
  Dec? change,
  bool onCredit = false,
  Dec? balance,
}) =>
    PrintDoc(
      type: type,
      folio: folio,
      date: DateTime.now(),
      customer: customer,
      lines: [
        for (final l in cart.lines)
          PrintLine(quantity: l.quantity, description: l.name, uom: l.uomName, price: l.price, amount: l.total),
      ],
      subtotal: cart.totals.subtotal,
      discount: cart.totals.discount,
      tax: cart.totals.tax,
      total: cart.totals.total,
      tenders: tenders,
      change: change,
      onCredit: onCredit,
      balance: balance,
      notes: cart.notes.isEmpty ? null : cart.notes,
      estimated: cart.totals.estimated,
    );
