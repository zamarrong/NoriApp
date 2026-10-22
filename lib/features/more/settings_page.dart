import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/design/design.dart';
import '../../core/providers.dart';
import '../../core/widgets/pickers.dart';
import '../sales/quick_capture.dart';

final _favoriteItemsProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final ids = ref.watch(quickCaptureProvider).favorites;
  final db = ref.watch(localDbProvider);
  return [for (final id in ids) await db.find('items', id) ?? {'id': id, 'name': 'Artículo $id', 'code': ''}];
});

/// Más › Configuración: preferencias de este equipo.
class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final qc = ref.watch(quickCaptureProvider);
    final favorites = ref.watch(_favoriteItemsProvider).valueOrNull ?? [];
    final notifier = ref.read(quickCaptureProvider.notifier);
    return Scaffold(
      appBar: AppBar(title: const Text('Configuración')),
      body: ListView(padding: const EdgeInsets.all(NrSpace.gutter), children: [
        NrSectionHeader('Venta'),
        NrCard(padding: const EdgeInsets.symmetric(horizontal: NrSpace.xs, vertical: NrSpace.xs), child: Column(children: [
          SwitchListTile(
            title: const Text('Modo de captura rápida'),
            subtitle: const Text('La venta abre la lista de artículos de la ruta (o tus favoritos) para teclear cantidades como en una libreta de pedidos.'),
            value: qc.enabled,
            onChanged: (v) {
              NrHaptics.tap();
              notifier.setEnabled(v);
            },
          ),
        ])),
        NrSectionHeader('Favoritos para vender sin ruta', count: favorites.length),
        Text(
          'Con ruta se usa lo cargado en el camión. Sin ruta, estos artículos; si no eliges ninguno, los que más vendiste en los últimos 30 días.',
          style: NrText.caption(context),
        ),
        const SizedBox(height: NrSpace.sm),
        if (favorites.isNotEmpty)
          ReorderableListView(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            onReorder: (from, to) {
              final ids = [...qc.favorites];
              final id = ids.removeAt(from);
              ids.insert(to > from ? to - 1 : to, id);
              notifier.setFavorites(ids);
            },
            children: [
              for (final f in favorites)
                Padding(
                  key: ValueKey(f['id']),
                  padding: const EdgeInsets.only(bottom: NrSpace.sm),
                  child: NrCard(
                    padding: const EdgeInsets.fromLTRB(NrSpace.md, NrSpace.sm, NrSpace.xs, NrSpace.sm),
                    child: Row(children: [
                      NrThumb(name: '${f['name']}', url: f['image_url'] as String?, size: 40),
                      const SizedBox(width: NrSpace.md),
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text('${f['name']}', style: NrText.headline(context).copyWith(fontSize: 15), maxLines: 1, overflow: TextOverflow.ellipsis),
                          Text('${f['code'] ?? ''}', style: NrText.caption(context)),
                        ]),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded),
                        tooltip: 'Quitar',
                        onPressed: () => notifier.setFavorites([...qc.favorites]..remove((f['id'] as num).toInt())),
                      ),
                      const Icon(Icons.drag_indicator_rounded),
                    ]),
                  ),
                ),
            ],
          ),
        if (favorites.isEmpty) const NrCard(depth: NrDepth.flat, child: NrEmpty(compact: true, icon: Icons.star_rounded, title: 'Sin favoritos', message: 'Se usará lo que más vendiste en 30 días.')),
        const SizedBox(height: NrSpace.sm),
        NrButton(
          icon: Icons.add_rounded,
          label: 'Agregar artículo',
          variant: NrButtonVariant.secondary,
          height: NrTouch.min,
          onPressed: () async {
            final item = await pickItem(context);
            if (item == null) return;
            final id = (item['id'] as num).toInt();
            if (!qc.favorites.contains(id)) notifier.setFavorites([...ref.read(quickCaptureProvider).favorites, id]);
          },
        ),
      ]),
    );
  }
}
