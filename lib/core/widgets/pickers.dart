import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:share_plus/share_plus.dart';

import '../api/api_client.dart';
import '../api/api_error.dart';
import '../design/design.dart';
import '../providers.dart';
import '../sync/outbox.dart';

/// Cámara para leer un código de barras o QR. Regresa el texto leído.
Future<String?> scanBarcode(BuildContext context) => Navigator.of(context).push<String>(
      MaterialPageRoute(fullscreenDialog: true, builder: (_) => const _ScanPage()),
    );

class _ScanPage extends StatefulWidget {
  const _ScanPage();

  @override
  State<_ScanPage> createState() => _ScanPageState();
}

class _ScanPageState extends State<_ScanPage> {
  bool _done = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(title: const Text('Escanear'), backgroundColor: Colors.black, foregroundColor: Colors.white, systemOverlayStyle: const SystemUiOverlayStyle(statusBarBrightness: Brightness.dark)),
      body: Stack(fit: StackFit.expand, children: [
        MobileScanner(
          onDetect: (capture) {
            final code = capture.barcodes.map((b) => b.rawValue).whereType<String>().firstOrNull;
            if (code == null || _done) return;
            _done = true;
            NrHaptics.success();
            Navigator.of(context).pop(code);
          },
        ),
        IgnorePointer(
          child: Center(
            child: Container(
              width: 270,
              height: 170,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.white, width: 3),
                borderRadius: BorderRadius.circular(NrRadius.xxl),
                boxShadow: const [BoxShadow(color: Color(0x99000000), spreadRadius: 2000)],
              ),
            ),
          ),
        ),
        const Positioned(
          left: 0,
          right: 0,
          bottom: 72,
          child: Text('Centra el código en el recuadro', textAlign: TextAlign.center, style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600)),
        ),
      ]),
    );
  }
}

/// Busca artículos en la base local (código, nombre o código de barras); con
/// señal y sin resultados locales, pregunta al servidor.
Future<Map<String, dynamic>?> pickItem(BuildContext context) => showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const FractionallySizedBox(heightFactor: 0.9, child: _ItemSearch()),
    );

class _ItemSearch extends ConsumerStatefulWidget {
  const _ItemSearch();

  @override
  ConsumerState<_ItemSearch> createState() => _ItemSearchState();
}

class _ItemSearchState extends ConsumerState<_ItemSearch> {
  final _text = TextEditingController();
  List<Map<String, dynamic>> _results = [];
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _search('');
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _text.dispose();
    super.dispose();
  }

  Future<void> _search(String q) async {
    final db = ref.read(localDbProvider);
    var rows = await db.search('items', q, limit: 60);
    if (rows.isEmpty && q.trim().length >= 2) {
      try {
        rows = asList(unwrap(await ref.read(apiProvider).get('/items', query: {'search': q, 'per_page': 30})));
      } on ApiException catch (_) {}
    }
    if (mounted) setState(() => _results = rows);
  }

  Future<void> _scan() async {
    final code = await scanBarcode(context);
    if (code == null || !mounted) return;
    final item = await ref.read(localDbProvider).itemByCode(code);
    if (!mounted) return;
    if (item != null) {
      Navigator.of(context).pop(item);
    } else {
      _text.text = code;
      _search(code);
    }
  }

  @override
  Widget build(BuildContext context) {
    final nr = context.nr;
    return Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(NrSpace.lg, 0, NrSpace.lg, NrSpace.sm),
        child: NrSearchField(
          controller: _text,
          autofocus: true,
          hint: 'Código, nombre o código de barras',
          onScan: _scan,
          onChanged: (v) {
            _debounce?.cancel();
            _debounce = Timer(const Duration(milliseconds: 250), () => _search(v));
          },
          onSubmitted: (v) async {
            final item = await ref.read(localDbProvider).itemByCode(v);
            if (item != null && context.mounted) Navigator.of(context).pop(item);
          },
        ),
      ),
      Expanded(
        child: _results.isEmpty
            ? const NrEmpty(icon: Icons.inventory_2_rounded, title: 'Sin artículos', message: 'Sincroniza o busca con otro texto.')
            : ListView.separated(
                padding: const EdgeInsets.only(bottom: NrSpace.xl),
                itemCount: _results.length,
                separatorBuilder: (_, _) => Divider(height: 1, indent: 76, color: nr.border),
                itemBuilder: (_, i) {
                  final it = _results[i];
                  return NrListRow(
                    leading: NrThumb(name: '${it['name']}', url: it['image_url'] as String?, size: 44),
                    title: '${it['name']}',
                    subtitle: '${it['code']}',
                    trailing: Icon(Icons.add_circle_rounded, color: nr.accent, size: 26),
                    onTap: () {
                      NrHaptics.tap();
                      Navigator.of(context).pop(it);
                    },
                  );
                },
              ),
      ),
    ]);
  }
}

/// Elige un cliente de la base local (o del servidor si no está guardado).
Future<Map<String, dynamic>?> pickCustomer(BuildContext context) => showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const FractionallySizedBox(heightFactor: 0.9, child: _CustomerSearch()),
    );

class _CustomerSearch extends ConsumerStatefulWidget {
  const _CustomerSearch();

  @override
  ConsumerState<_CustomerSearch> createState() => _CustomerSearchState();
}

class _CustomerSearchState extends ConsumerState<_CustomerSearch> {
  List<Map<String, dynamic>> _results = [];

  @override
  void initState() {
    super.initState();
    _search('');
  }

  Future<void> _search(String q) async {
    var rows = await ref.read(localDbProvider).search('customers', q, limit: 60);
    if (rows.isEmpty && q.trim().length >= 2) {
      try {
        rows = asList(unwrap(await ref.read(apiProvider).get('/customers', query: {'search': q, 'per_page': 30})));
      } on ApiException catch (_) {}
    }
    if (mounted) setState(() => _results = rows);
  }

  @override
  Widget build(BuildContext context) {
    final nr = context.nr;
    return Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(NrSpace.lg, 0, NrSpace.lg, NrSpace.sm),
        child: NrSearchField(autofocus: true, hint: 'Nombre, código, RFC o teléfono', onChanged: _search),
      ),
      Expanded(
        child: _results.isEmpty
            ? const NrEmpty(icon: Icons.people_alt_rounded, title: 'Sin resultados', message: 'Prueba con otro texto o sincroniza tu cartera.')
            : ListView.separated(
                padding: const EdgeInsets.only(bottom: NrSpace.xl),
                itemCount: _results.length,
                separatorBuilder: (_, _) => Divider(height: 1, indent: 72, color: nr.border),
                itemBuilder: (_, i) {
                  final c = _results[i];
                  final name = '${c['trade_name'] ?? c['name']}';
                  final balance = Dec.parse(c['balance']);
                  return NrListRow(
                    leading: NrAvatar(name),
                    title: name,
                    subtitle: '${c['code']}',
                    trailing: balance > Dec.zero ? Text(moneyCompact(balance), style: NrText.money(context, size: 14, weight: FontWeight.w700)) : null,
                    onTap: () {
                      NrHaptics.tap();
                      Navigator.of(context).pop(c);
                    },
                  );
                },
              ),
      ),
    ]);
  }
}

/// Comparte la liga firmada del PDF (WhatsApp, correo, lo que tenga el teléfono)
/// o lo envía por correo desde el servidor.
Future<void> shareDocument(BuildContext context, WidgetRef ref, {required String kind, required int id, String? title}) async {
  final path = kind == 'payment' ? '/payments/$id' : '/documents/$id';
  final choice = await showNrSheet<String>(
    context,
    title: 'Enviar ${title ?? 'documento'}',
    builder: (ctx) => Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      NrButton(label: 'Compartir liga (WhatsApp…)', icon: Icons.ios_share_rounded, onPressed: () => Navigator.pop(ctx, 'share')),
      const SizedBox(height: NrSpace.sm),
      NrButton(label: 'Enviar por correo al cliente', icon: Icons.mail_rounded, variant: NrButtonVariant.secondary, onPressed: () => Navigator.pop(ctx, 'email')),
    ]),
  );
  if (choice == null || !context.mounted) return;
  try {
    if (choice == 'share') {
      final doc = asMap(unwrap(await ref.read(apiProvider).get(path)));
      final url = doc['pdf_url'] as String?;
      if (url == null) throw ApiException(code: 'no_pdf', message: 'El documento aún no tiene PDF.');
      await Share.share('${title ?? doc['folio'] ?? 'Documento'}\n$url', subject: title);
    } else {
      final op = OutboxOp.create('POST', '$path/email', body: {}, label: 'Correo ${title ?? ''}');
      final r = await ref.read(writerProvider).send(op);
      if (context.mounted) showSnack(context, r.queued ? 'Se enviará al recuperar señal.' : 'Correo enviado.', tone: r.queued ? NrTone.warning : NrTone.success);
    }
  } on ApiException catch (e) {
    if (context.mounted) showSnack(context, e.userMessage, tone: NrTone.danger);
  }
}
