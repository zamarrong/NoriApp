import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_client.dart';
import '../../core/api/api_error.dart';
import '../../core/design/design.dart';
import '../../core/providers.dart';

/// Unidades de medida de la empresa (`/catalogs`), guardadas para trabajar sin señal.
Future<Map<int, String>> uomNames(WidgetRef ref) async {
  final db = ref.read(localDbProvider);
  Map<String, dynamic> catalogs;
  try {
    catalogs = asMap(unwrap(await ref.read(apiProvider).get('/catalogs')));
    await db.putJson('catalogs', catalogs);
  } on ApiException catch (_) {
    catalogs = asMap(await db.getJson('catalogs'));
  }
  return {
    for (final u in asList(catalogs['units_of_measure'])) (u['id'] as num).toInt(): '${u['name'] ?? u['code']}',
  };
}

/// Artículo por código o código de barras: lo guardado primero y, con señal, el servidor.
Future<Map<String, dynamic>?> findItemByCode(WidgetRef ref, String code) async {
  final c = code.trim();
  if (c.isEmpty) return null;
  final local = await ref.read(localDbProvider).itemByCode(c);
  if (local != null) return local;
  try {
    final rows = asList(unwrap(await ref.read(apiProvider).get('/items', query: {'barcode': c, 'per_page': 1})));
    return rows.firstOrNull;
  } on ApiException catch (_) {
    return null;
  }
}

/// Unidades en que se vende un artículo: las de su grupo (en línea) o, sin
/// señal, las que tienen precio guardado. Cada una `{id, name}`; id nulo = la
/// unidad de venta.
Future<List<Map<String, dynamic>>> itemUnits(WidgetRef ref, Map<String, dynamic> item) async {
  final id = (item['id'] as num).toInt();
  try {
    final data = asMap(unwrap(await ref.read(apiProvider).get('/items/$id/price-check')));
    final units = asList(data['units']);
    if (units.isNotEmpty) {
      return [for (final u in units) {'id': u['id'], 'name': '${u['name'] ?? u['code']}', 'base_quantity': u['base_quantity']}];
    }
  } on ApiException catch (_) {}
  final names = await uomNames(ref);
  final prices = await ref.read(localDbProvider).byRefs('item_prices', ref1: id);
  final ids = <int?>{null, for (final p in prices) (p['uom_id'] as num?)?.toInt()};
  final salesUom = (item['sales_uom_id'] as num?)?.toInt();
  return [
    for (final u in ids)
      {'id': u, 'name': u == null ? (names[salesUom] ?? 'Unidad de venta') : (names[u] ?? 'Unidad $u')},
  ];
}

/// Para un paquete con opciones ("elige 3"), pide qué lleva cada unidad.
/// Regresa {} si no hay nada que elegir (kit fijo o artículo normal) y null si se cancela.
Future<Map<String, Map<String, int>>?> pickPackageChoices(BuildContext context, WidgetRef ref, Map<String, dynamic> item) async {
  if (item['is_package'] != true) return {};
  Map<String, dynamic> def;
  try {
    def = asMap(unwrap(await ref.read(apiProvider).get('/items/${item['id']}/package')));
  } on ApiException catch (_) {
    return {}; // sin señal: el servidor aplica lo predeterminado o rechaza al guardar
  }
  final groups = asList(def['groups']);
  if (groups.isEmpty || !context.mounted) return {};
  return showModalBottomSheet<Map<String, Map<String, int>>>(
    context: context,
    isScrollControlled: true,
    builder: (_) => FractionallySizedBox(heightFactor: 0.85, child: _PackageSheet(name: '${item['name']}', groups: groups)),
  );
}

class _PackageSheet extends StatefulWidget {
  const _PackageSheet({required this.name, required this.groups});

  final String name;
  final List<Map<String, dynamic>> groups;

  @override
  State<_PackageSheet> createState() => _PackageSheetState();
}

class _PackageSheetState extends State<_PackageSheet> {
  final Map<String, Map<String, int>> picked = {};

  @override
  void initState() {
    super.initState();
    for (final g in widget.groups) {
      final gid = '${g['id']}';
      picked[gid] = {
        for (final o in asList(g['options']))
          if (((o['min'] as num?) ?? 0) > 0) '${o['item_id']}': (o['min'] as num).toInt(),
      };
    }
  }

  int _sum(String gid) => picked[gid]!.values.fold(0, (a, b) => a + b);

  String? get _problem {
    for (final g in widget.groups) {
      final min = (g['min'] as num?)?.toInt() ?? 0;
      final max = (g['max'] as num?)?.toInt() ?? 0;
      final s = _sum('${g['id']}');
      if (s < min) return 'Elige al menos $min en ${g['name']}';
      if (max > 0 && s > max) return 'Máximo $max en ${g['name']}';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final problem = _problem;
    return Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(NrSpace.xl, 0, NrSpace.xl, NrSpace.sm),
        child: Text(widget.name, style: NrText.title(context)),
      ),
      Expanded(
        child: ListView(padding: const EdgeInsets.symmetric(horizontal: NrSpace.gutter), children: [
          for (final g in widget.groups) ...[
            NrSectionHeader(
              '${g['name']}${((g['max'] as num?) ?? 0) > 0 ? ' · elige ${g['max']}' : ''}',
              count: _sum('${g['id']}'),
            ),
            NrGroup(children: [
              for (final o in asList(g['options']))
                _optionRow(context, '${g['id']}', o, ((g['max'] as num?) ?? 0).toInt()),
            ]),
          ],
          const SizedBox(height: NrSpace.lg),
        ]),
      ),
      SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.all(NrSpace.lg),
          child: NrButton(
            icon: problem == null ? Icons.add_rounded : null,
            onPressed: problem != null ? null : () => Navigator.pop(context, {for (final e in picked.entries) if (e.value.isNotEmpty) e.key: e.value}),
            label: problem ?? 'Agregar',
          ),
        ),
      ),
    ]);
  }

  Widget _optionRow(BuildContext context, String gid, Map<String, dynamic> o, int groupMax) {
    final key = '${o['item_id']}';
    final n = picked[gid]![key] ?? 0;
    final min = (o['min'] as num?)?.toInt() ?? 0;
    final max = (o['max'] as num?)?.toInt() ?? 0;
    final full = groupMax > 0 && _sum(gid) >= groupMax;
    void set(int v) => setState(() {
          if (v <= 0) {
            picked[gid]!.remove(key);
          } else {
            picked[gid]![key] = v;
          }
        });
    return NrListRow(
      title: '${o['name']}',
      subtitle: o['on_hand'] == null ? '${o['code'] ?? ''}' : '${o['code'] ?? ''} · Existencia ${Dec.parse(o['on_hand']).toQty()}',
      trailing: Row(mainAxisSize: MainAxisSize.min, children: [
        IconButton(icon: const Icon(Icons.remove_circle_outline), onPressed: n <= min ? null : () => set(n - 1)),
        Text('$n', style: NrText.money(context, size: 17)),
        IconButton(icon: const Icon(Icons.add_circle_outline), onPressed: full || (max > 0 && n >= max) ? null : () => set(n + 1)),
      ]),
    );
  }
}
