import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_client.dart';
import '../../core/authorizations/authorization_flow.dart';
import '../../core/design/design.dart';
import '../../core/providers.dart';
import '../../core/sync/outbox.dart';
import '../../core/widgets/pickers.dart';

/// Conteos en curso del almacén.
class CountsPage extends ConsumerStatefulWidget {
  const CountsPage({super.key});

  @override
  ConsumerState<CountsPage> createState() => _CountsPageState();
}

class _CountsPageState extends ConsumerState<CountsPage> {
  late Future<List<Map<String, dynamic>>> future = _load();

  Future<List<Map<String, dynamic>>> _load() async =>
      asList(unwrap(await ref.read(apiProvider).get('/inventory/counts', query: {'status': 'counting'})));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Conteos')),
      body: FutureBuilder(
        future: future,
        builder: (context, snap) {
          if (snap.hasError) return NrErrorView(snap.error!, onRetry: () => setState(() => future = _load()));
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());
          final rows = snap.data!;
          if (rows.isEmpty) return const NrEmpty(icon: Icons.fact_check_outlined, title: 'Sin conteos abiertos');
          return ListView(padding: const EdgeInsets.all(NrSpace.gutter), children: [
            NrGroup(children: [
              for (final c in rows)
                NrListRow(
                  title: '${c['title'] ?? 'Conteo ${c['number']}'}',
                  subtitle: '${asMap(c['warehouse'])['name'] ?? ''}${c['is_blind'] == true ? ' · a ciegas' : ''}',
                  trailing: NrPill('${asMap(c['progress'])['progress'] ?? 0} %', tone: NrTone.accent),
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => CountPage(count: c))),
                ),
            ]),
          ]);
        },
      ),
    );
  }
}

/// Unirse a un conteo y escanear: la cifra grande es lo contado del último
/// artículo; deshacer quita la última captura de esa línea.
class CountPage extends ConsumerStatefulWidget {
  const CountPage({super.key, required this.count});

  final Map<String, dynamic> count;

  @override
  ConsumerState<CountPage> createState() => _CountPageState();
}

class _CountPageState extends ConsumerState<CountPage> {
  Map<String, dynamic> progress = {};
  Map<String, dynamic>? last;
  final history = <Map<String, dynamic>>[];
  final scan = TextEditingController();
  final focus = FocusNode();
  bool busy = false;
  bool setMode = false;

  int get countId => (widget.count['id'] as num).toInt();

  @override
  void initState() {
    super.initState();
    progress = asMap(widget.count['progress']);
  }

  @override
  void dispose() {
    scan.dispose();
    focus.dispose();
    super.dispose();
  }

  Future<void> _record(Map<String, dynamic> body) async {
    setState(() => busy = true);
    final r = await sendWithAuthorization(context, ref, OutboxOp.create('POST', '/inventory/counts/$countId/entries', body: body, label: 'Conteo'));
    if (!mounted) return;
    setState(() => busy = false);
    focus.requestFocus();
    if (r == null) {
      HapticFeedback.heavyImpact();
      return;
    }
    if (r.queued) {
      showSnack(context, 'Captura en cola (sin señal).');
      return;
    }
    final data = asMap(unwrap(r.response));
    HapticFeedback.selectionClick();
    setState(() {
      last = asMap(data['line']);
      progress = asMap(data['progress']);
      history.insert(0, last!);
      if (history.length > 30) history.removeLast();
    });
  }

  Future<void> _onScan(String text) async {
    scan.clear();
    if (text.trim().isEmpty) return;
    if (setMode) {
      final q = await _askQty('Cantidad total de $text');
      if (q != null) await _record({'text': text.trim(), 'quantity': q.toJson(4), 'mode': 'set'});
    } else {
      await _record({'text': text.trim()});
    }
  }

  Future<Dec?> _askQty(String title) async {
    final ctrl = TextEditingController();
    final v = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: TextField(controller: ctrl, autofocus: true, keyboardType: const TextInputType.numberWithOptions(decimal: true), style: NrText.money(ctx, size: 28)),
        actions: [FilledButton(onPressed: () => Navigator.pop(ctx, ctrl.text), child: const Text('Guardar'))],
      ),
    );
    return Dec.tryParse(v);
  }

  Future<void> _undo() async {
    final lineId = last?['id'];
    if (lineId == null) return;
    setState(() => busy = true);
    final r = await sendWithAuthorization(context, ref, OutboxOp.create('DELETE', '/inventory/counts/$countId/lines/$lineId/last-entry', label: 'Deshacer conteo'), offline: false);
    if (!mounted) return;
    setState(() => busy = false);
    if (r == null || r.queued) return;
    final data = asMap(unwrap(r.response));
    setState(() {
      last = asMap(data['line']);
      progress = asMap(data['progress']);
    });
    showSnack(context, 'Se deshizo la última captura.');
  }

  @override
  Widget build(BuildContext context) {
    final pct = (progress['progress'] as num?) ?? 0;
    final nr = context.nr;
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.count['title'] ?? 'Conteo'}'),
        actions: [
          IconButton(
            tooltip: setMode ? 'Modo: reemplazar total' : 'Modo: sumar',
            icon: Icon(setMode ? Icons.edit_note : Icons.exposure_plus_1),
            onPressed: () => setState(() => setMode = !setMode),
          ),
        ],
      ),
      body: ListView(padding: const EdgeInsets.all(NrSpace.gutter), children: [
        Row(children: [
          Expanded(child: ClipRRect(borderRadius: BorderRadius.circular(NrRadius.pill), child: LinearProgressIndicator(value: pct / 100, minHeight: 8))),
          const SizedBox(width: NrSpace.md),
          Text('${progress['counted'] ?? 0}/${progress['lines'] ?? 0} · $pct %', style: NrText.label(context)),
        ]),
        const SizedBox(height: NrSpace.lg),
        TextField(
          controller: scan,
          focusNode: focus,
          autofocus: true,
          enabled: !busy,
          style: NrText.headline(context),
          decoration: InputDecoration(
            hintText: setMode ? 'Escanea para capturar el total' : 'Escanea (suma 1) o 3*CÓDIGO',
            prefixIcon: const Icon(Icons.qr_code),
            suffixIcon: Row(mainAxisSize: MainAxisSize.min, children: [
              IconButton(icon: const Icon(Icons.search), onPressed: () async {
                final item = await pickItem(context);
                if (item == null) return;
                final q = await _askQty('${item['name']}');
                if (q != null) await _record({'item_id': item['id'], 'quantity': q.toJson(4), 'mode': setMode ? 'set' : 'add'});
              }),
              IconButton(icon: const Icon(Icons.photo_camera_outlined), onPressed: () async {
                final code = await scanBarcode(context);
                if (code != null) _onScan(code);
              }),
            ]),
          ),
          onSubmitted: _onScan,
        ),
        const SizedBox(height: NrSpace.xl),
        NrCard(
          child: last == null
              ? SizedBox(height: 160, child: Center(child: Text('Escanea un artículo', style: NrText.bodySm(context))))
              : Column(children: [
                  Text('${last!['name']}', style: NrText.title(context), textAlign: TextAlign.center),
                  Text('${last!['code']} ${last!['uom'] ?? ''}', style: NrText.bodySm(context)),
                  const SizedBox(height: NrSpace.md),
                  Text(Dec.parse(last!['counted']).toQty(), style: NrText.huge(context)),
                  if (last!['system'] != null)
                    Text('Sistema: ${Dec.parse(last!['system']).toQty()}',
                        style: NrText.label(context).copyWith(color: Dec.parse(last!['system']) == Dec.parse(last!['counted']) ? nr.success : nr.warning)),
                  const SizedBox(height: NrSpace.md),
                  OutlinedButton.icon(onPressed: busy ? null : _undo, icon: const Icon(Icons.undo), label: const Text('Deshacer última')),
                ]),
        ),
        if (history.length > 1) ...[
          NrSectionHeader('Recientes'),
          NrGroup(children: [
            for (final h in history.skip(1).take(10))
              NrListRow(title: '${h['name']}', subtitle: '${h['code']}', trailing: Text(Dec.parse(h['counted']).toQty(), style: NrText.money(context))),
          ]),
        ],
      ]),
    );
  }
}
