import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';

import '../../core/api/api_client.dart';
import '../../core/api/api_error.dart';
import '../../core/authorizations/authorization_flow.dart';
import '../../core/design/design.dart';
import '../../core/sync/outbox.dart';
import '../../core/providers.dart';
import '../collections/tender_sheet.dart';
import 'route_repo.dart';
import 'visit_page.dart';

/// Entrega de pedidos desde el camión (parcial permitido), cobrando o a crédito.
class DeliveryPage extends ConsumerStatefulWidget {
  const DeliveryPage({super.key, required this.visit});

  final Map<String, dynamic> visit;

  @override
  ConsumerState<DeliveryPage> createState() => _DeliveryPageState();
}

class _DeliveryPageState extends ConsumerState<DeliveryPage> {
  final Map<int, Dec> qty = {};
  final Map<int, Dec> prices = {};
  bool busy = false;

  @override
  void initState() {
    super.initState();
    for (final o in asList(widget.visit['orders'])) {
      for (final l in asList(o['lines'])) {
        final id = (l['base_line_id'] as num).toInt();
        qty[id] = Dec.parse(l['open']);
        prices[id] = Dec.parse(l['price']);
      }
    }
  }

  Dec get total => qty.entries.fold(Dec.zero, (s, e) => s + (e.value * (prices[e.key] ?? Dec.zero)));

  Future<void> _submit() async {
    final lines = [for (final e in qty.entries) if (e.value > Dec.zero) {'base_line_id': e.key, 'quantity': e.value.toJson(4)}];
    if (lines.isEmpty) return;
    final tenders = asList(asMap(await ref.read(localDbProvider).getJson(RouteRepo.todayKey))['tenders']);
    if (!mounted) return;
    final choice = await showTenderSheet(context, tenderTypes: tenders, total: total.round(2), allowCredit: true, title: 'Entrega');
    if (choice == null || !mounted) return;
    setState(() => busy = true);
    final r = await sendWithAuthorization(
      context,
      ref,
      OutboxOp.create('POST', '/route/visits/${widget.visit['id']}/delivery', body: {'lines': lines, 'tenders': choice.tenders}, label: 'Entrega'),
    );
    if (!mounted) return;
    setState(() => busy = false);
    if (r == null) return;
    if (!r.queued) {
      final body = asMap(r.response);
      await ref.read(routeRepoProvider).saveVisit(asMap(body['visit']));
      final docs = asList(body['documents']);
      if (docs.isNotEmpty && mounted) await showDoneDialog(context, ref, '${body['message'] ?? 'Entregado'}', docs.first);
    } else {
      showSnack(context, 'Entrega guardada sin señal.');
    }
    if (mounted) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Entregar pedidos')),
      body: ListView(padding: const EdgeInsets.all(NrSpace.gutter), children: [
        for (final o in asList(widget.visit['orders'])) ...[
          NrSectionHeader('Pedido ${o['folio']} · ${o['date'] ?? ''}'),
          NrGroup(children: [
            for (final l in asList(o['lines']))
              NrListRow(
                title: '${l['name']}',
                subtitle: '${l['code']} · pendiente ${Dec.parse(l['open']).toQty()} · ${money(l['price'])}',
                trailing: SizedBox(
                  width: 80,
                  child: TextFormField(
                    initialValue: qty[(l['base_line_id'] as num).toInt()]!.toQty(),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    textAlign: TextAlign.end,
                    onChanged: (v) => setState(() {
                      final id = (l['base_line_id'] as num).toInt();
                      qty[id] = (Dec.tryParse(v) ?? Dec.zero).min(Dec.parse(l['open']));
                    }),
                  ),
                ),
              ),
          ]),
        ],
      ]),
      bottomNavigationBar: NrBottomAction(label: 'Entregar ${money(total)}', busy: busy, onPressed: _submit),
    );
  }
}

/// Servicio a enfriador/exhibidor con fotos. Requiere señal (multipart).
class AssetServicePage extends ConsumerStatefulWidget {
  const AssetServicePage({super.key, required this.visit});

  final Map<String, dynamic> visit;

  @override
  ConsumerState<AssetServicePage> createState() => _AssetServicePageState();
}

class _AssetServicePageState extends ConsumerState<AssetServicePage> {
  static const kinds = {'preventive': 'Preventivo', 'corrective': 'Correctivo', 'installation': 'Instalación', 'removal': 'Retiro', 'inspection': 'Inspección'};
  static const conditions = {'working': 'Funciona', 'needs_repair': 'Requiere reparación', 'out_of_service': 'Fuera de servicio'};

  Map<String, dynamic>? asset;
  String kind = 'preventive';
  String condition = 'working';
  final temperature = TextEditingController();
  final notes = TextEditingController();
  final photos = <XFile>[];
  bool busy = false;
  // Misma llave en cada reintento de este servicio.
  final key = const Uuid().v4();

  @override
  void initState() {
    super.initState();
    asset = asList(widget.visit['assets']).firstOrNull;
  }

  Future<void> _photo() async {
    final f = await ImagePicker().pickImage(source: ImageSource.camera, maxWidth: 1600, imageQuality: 80);
    if (f != null) setState(() => photos.add(f));
  }

  Future<void> _submit() async {
    if (asset == null) return;
    setState(() => busy = true);
    try {
      final form = FormData.fromMap({
        'customer_asset_id': asset!['id'],
        'kind': kind,
        'condition': condition,
        if (temperature.text.trim().isNotEmpty) 'temperature': temperature.text.trim(),
        if (notes.text.trim().isNotEmpty) 'notes': notes.text.trim(),
        'performed_at': DateTime.now().toIso8601String(),
        'photos[]': [for (final p in photos) await MultipartFile.fromFile(p.path, filename: p.name)],
      });
      final r = asMap(await ref.read(apiProvider).post('/route/visits/${widget.visit['id']}/asset-service', body: form, key: key));
      await ref.read(routeRepoProvider).saveVisit(asMap(r['visit']));
      if (mounted) {
        showSnack(context, 'Servicio registrado.');
        Navigator.of(context).pop(true);
      }
    } on ApiException catch (e) {
      if (mounted) showSnack(context, e.isNetwork ? 'Necesitas señal para subir las fotos. Intenta de nuevo al tener conexión.' : e.userMessage);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final assets = asList(widget.visit['assets']);
    return Scaffold(
      appBar: AppBar(title: const Text('Mantenimiento')),
      body: ListView(padding: const EdgeInsets.all(NrSpace.gutter), children: [
        DropdownButtonFormField<int>(
          initialValue: (asset?['id'] as num?)?.toInt(),
          decoration: const InputDecoration(labelText: 'Equipo'),
          items: [
            for (final a in assets)
              DropdownMenuItem(value: (a['id'] as num).toInt(), child: Text('${a['type_label'] ?? ''} ${a['name']} ${a['serial_number'] ?? ''}')),
          ],
          onChanged: (id) => setState(() => asset = assets.firstWhere((a) => a['id'] == id)),
        ),
        const SizedBox(height: NrSpace.md),
        DropdownButtonFormField<String>(
          initialValue: kind,
          decoration: const InputDecoration(labelText: 'Tipo de servicio'),
          items: [for (final e in kinds.entries) DropdownMenuItem(value: e.key, child: Text(e.value))],
          onChanged: (v) => setState(() => kind = v!),
        ),
        const SizedBox(height: NrSpace.md),
        DropdownButtonFormField<String>(
          initialValue: condition,
          decoration: const InputDecoration(labelText: 'Estado del equipo'),
          items: [for (final e in conditions.entries) DropdownMenuItem(value: e.key, child: Text(e.value))],
          onChanged: (v) => setState(() => condition = v!),
        ),
        const SizedBox(height: NrSpace.md),
        TextField(controller: temperature, keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true), decoration: const InputDecoration(labelText: 'Temperatura °C')),
        const SizedBox(height: NrSpace.md),
        TextField(controller: notes, maxLines: 3, decoration: const InputDecoration(labelText: 'Notas')),
        NrSectionHeader('Fotos', count: photos.length, action: photos.length < 6 ? 'Tomar foto' : null, onAction: _photo),
        Wrap(spacing: NrSpace.sm, children: [
          for (final p in photos) Chip(label: Text(p.name), onDeleted: () => setState(() => photos.remove(p))),
        ]),
      ]),
      bottomNavigationBar: NrBottomAction(label: 'Registrar servicio', busy: busy, onPressed: asset == null ? null : _submit),
    );
  }
}
