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
        NrGroup(children: [
          SwitchListTile(
            title: const Text('Modo de captura rápida'),
            subtitle: const Text('La venta abre la lista de artículos de la ruta (o tus favoritos) para teclear cantidades como en una libreta de pedidos.'),
            value: qc.enabled,
            onChanged: notifier.setEnabled,
          ),
        ]),
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
                ListTile(
                  key: ValueKey(f['id']),
                  title: Text('${f['name']}'),
                  subtitle: Text('${f['code'] ?? ''}'),
                  trailing: IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => notifier.setFavorites([...qc.favorites]..remove((f['id'] as num).toInt())),
                  ),
                ),
            ],
          ),
        OutlinedButton.icon(
          icon: const Icon(Icons.add),
          label: const Text('Agregar artículo'),
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
