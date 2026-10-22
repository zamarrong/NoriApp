import 'package:flutter/material.dart';
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
          if (!snap.hasData) return const NrSkeletonList(count: 4);
          final rows = snap.data!;
          if (rows.isEmpty) return const NrEmpty(icon: Icons.fact_check_rounded, title: 'Sin conteos abiertos', message: 'Cuando se abra un conteo físico en tu almacén, podrás unirte desde aquí.');
          return ListView(padding: const EdgeInsets.all(NrSpace.gutter), children: [
            NrGroup(children: [
              for (final c in rows)
                NrListRow(
                  title: '${c['title'] ?? 'Conteo ${c['number']}'}',
                  subtitle: '${asMap(c['warehouse'])['name'] ?? ''}${c['is_blind'] == true ? ' · a ciegas' : ''}',
                  leading: NrRing(value: (((asMap(c['progress'])['progress'] as num?) ?? 0) / 100).toDouble(), size: 40, stroke: 5),
                  trailing: Text('${asMap(c['progress'])['progress'] ?? 0} %', style: NrText.money(context, size: 15, weight: FontWeight.w700)),
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
      NrHaptics.warning();
      return;
    }
    if (r.queued) {
      showSnack(context, 'Captura en cola (sin señal).', tone: NrTone.warning);
      return;
    }
    final data = asMap(unwrap(r.response));
    NrHaptics.tap();
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
    final v = await showNrSheet<String>(
      context,
      title: title,
      builder: (ctx) => Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        TextField(
          controller: ctrl,
          autofocus: true,
          textAlign: TextAlign.center,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          style: NrText.huge(ctx).copyWith(fontSize: 48),
          decoration: const InputDecoration(hintText: '0'),
          onSubmitted: (t) => Navigator.pop(ctx, t),
        ),
        const SizedBox(height: NrSpace.lg),
        NrButton(label: 'Guardar', onPressed: () => Navigator.pop(ctx, ctrl.text)),
      ]),
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
    final counted = last == null ? null : Dec.parse(last!['counted']);
    final system = last?['system'] == null ? null : Dec.parse(last!['system']);
    final matches = system != null && system == counted;
    return Scaffold(
      appBar: AppBar(title: Text('${widget.count['title'] ?? 'Conteo'}')),
      body: ListView(padding: const EdgeInsets.fromLTRB(NrSpace.gutter, NrSpace.xs, NrSpace.gutter, NrSpace.xxxl), children: [
        NrCard(
          child: Row(children: [
            NrRing(
              value: pct / 100,
              size: 64,
              stroke: 7,
              color: nr.success,
              child: Text('$pct %', style: NrText.label(context).copyWith(fontWeight: FontWeight.w700)),
            ),
            const SizedBox(width: NrSpace.lg),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('AVANCE', style: NrText.eyebrow(context)),
                const SizedBox(height: 4),
                Text('${progress['counted'] ?? 0} de ${progress['lines'] ?? 0} renglones', style: NrText.headline(context)),
                Text('${asMap(widget.count['warehouse'])['name'] ?? ''}${widget.count['is_blind'] == true ? ' · a ciegas' : ''}', style: NrText.caption(context)),
              ]),
            ),
          ]),
        ),
        const SizedBox(height: NrSpace.md),
        NrSegmented<bool>(
          values: const [false, true],
          labels: const ['Sumar', 'Capturar total'],
          icons: const [Icons.exposure_plus_1_rounded, Icons.edit_note_rounded],
          selected: setMode,
          onChanged: (v) => setState(() => setMode = v),
        ),
        const SizedBox(height: NrSpace.md),
        TextField(
          controller: scan,
          focusNode: focus,
          autofocus: true,
          enabled: !busy,
          style: NrText.body(context).copyWith(fontSize: 18, fontWeight: FontWeight.w500),
          decoration: InputDecoration(
            hintText: setMode ? 'Escanea para capturar el total' : 'Escanea (suma 1) o 3*CÓDIGO',
            prefixIcon: Icon(Icons.qr_code_2_rounded, color: nr.night ? nr.link : nr.accent),
            contentPadding: const EdgeInsets.symmetric(vertical: 20),
            suffixIcon: Row(mainAxisSize: MainAxisSize.min, children: [
              IconButton(icon: const Icon(Icons.search_rounded), tooltip: 'Buscar', onPressed: () async {
                final item = await pickItem(context);
                if (item == null) return;
                final q = await _askQty('${item['name']}');
                if (q != null) await _record({'item_id': item['id'], 'quantity': q.toJson(4), 'mode': setMode ? 'set' : 'add'});
              }),
              IconButton(icon: const Icon(Icons.photo_camera_outlined), tooltip: 'Cámara', onPressed: () async {
                final code = await scanBarcode(context);
                if (code != null) _onScan(code);
              }),
            ]),
          ),
          onSubmitted: _onScan,
        ),
        const SizedBox(height: NrSpace.lg),
        NrCard(
          depth: NrDepth.floating,
          radius: NrRadius.hero,
          padding: const EdgeInsets.all(NrSpace.xl),
          child: NrSwitcher(
            child: last == null
                ? const NrEmpty(key: ValueKey('none'), compact: true, icon: Icons.qr_code_scanner_rounded, title: 'Escanea un artículo', message: 'La cifra grande es lo contado del último artículo.')
                : Column(key: ValueKey('${last!['id']}-${last!['counted']}'), children: [
                    Text('${last!['name']}', style: NrText.title(context), textAlign: TextAlign.center),
                    Text('${last!['code']} ${last!['uom'] ?? ''}', style: NrText.bodySm(context)),
                    const SizedBox(height: NrSpace.md),
                    TweenAnimationBuilder<double>(
                      tween: Tween(begin: 1.15, end: 1),
                      duration: nrReduceMotion(context) ? Duration.zero : const Duration(milliseconds: 380),
                      curve: Curves.easeOutBack,
                      builder: (context, sc, child) => Transform.scale(scale: sc, child: child),
                      child: Text(counted!.toQty(), style: NrText.huge(context).copyWith(fontSize: 88)),
                    ),
                    if (system != null) ...[
                      const SizedBox(height: NrSpace.xs),
                      NrPill(matches ? 'Cuadra con el sistema' : 'Sistema: ${system.toQty()}', tone: matches ? NrTone.success : NrTone.warning, large: true, dot: true),
                    ],
                    const SizedBox(height: NrSpace.lg),
                    NrButton(label: 'Deshacer última', icon: Icons.undo_rounded, variant: NrButtonVariant.secondary, expand: false, height: NrTouch.min, onPressed: busy ? null : _undo),
                  ]),
          ),
        ),
        if (history.length > 1) ...[
          NrSectionHeader('Recientes'),
          NrGroup(children: [
            for (final h in history.skip(1).take(10))
              NrListRow(dense: true, title: '${h['name']}', subtitle: '${h['code']}', trailing: Text(Dec.parse(h['counted']).toQty(), style: NrText.money(context, size: 18, weight: FontWeight.w700))),
          ]),
        ],
      ]),
    );
  }
}
