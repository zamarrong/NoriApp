import 'dart:async';

import 'package:flutter/material.dart';
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
      appBar: AppBar(title: const Text('Escanear'), backgroundColor: Colors.black, foregroundColor: Colors.white),
      body: MobileScanner(
        onDetect: (capture) {
          final code = capture.barcodes.map((b) => b.rawValue).whereType<String>().firstOrNull;
          if (code == null || _done) return;
          _done = true;
          Navigator.of(context).pop(code);
        },
      ),
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
    return Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(NrSpace.lg, 0, NrSpace.lg, NrSpace.sm),
        child: TextField(
          controller: _text,
          autofocus: true,
          decoration: InputDecoration(
            hintText: 'Código, nombre o código de barras',
            prefixIcon: const Icon(Icons.search),
            suffixIcon: IconButton(icon: const Icon(Icons.qr_code_scanner), tooltip: 'Escanear', onPressed: _scan),
          ),
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
            ? const NrEmpty(icon: Icons.inventory_2_outlined, title: 'Sin artículos', message: 'Sincroniza o busca con otro texto.')
            : ListView.separated(
                itemCount: _results.length,
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (_, i) {
                  final it = _results[i];
                  return NrListRow(
                    title: '${it['name']}',
                    subtitle: '${it['code']}',
                    onTap: () => Navigator.of(context).pop(it),
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
    return Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(NrSpace.lg, 0, NrSpace.lg, NrSpace.sm),
        child: TextField(
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Buscar cliente', prefixIcon: Icon(Icons.search)),
          onChanged: _search,
        ),
      ),
      Expanded(
        child: ListView.separated(
          itemCount: _results.length,
          separatorBuilder: (_, _) => const Divider(height: 1),
          itemBuilder: (_, i) {
            final c = _results[i];
            final name = '${c['trade_name'] ?? c['name']}';
            return NrListRow(
              leading: NrAvatar(name),
              title: name,
              subtitle: '${c['code']}',
              onTap: () => Navigator.of(context).pop(c),
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
  final choice = await showModalBottomSheet<String>(
    context: context,
    builder: (_) => SafeArea(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        ListTile(leading: const Icon(Icons.share_outlined), title: const Text('Compartir liga del PDF (WhatsApp…)'), onTap: () => Navigator.pop(context, 'share')),
        ListTile(leading: const Icon(Icons.email_outlined), title: const Text('Enviar por correo al cliente'), onTap: () => Navigator.pop(context, 'email')),
      ]),
    ),
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
      if (context.mounted) showSnack(context, r.queued ? 'Se enviará al recuperar señal.' : 'Correo enviado.');
    }
  } on ApiException catch (e) {
    if (context.mounted) showSnack(context, e.userMessage);
  }
}
