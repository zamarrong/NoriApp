import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/api_client.dart';
import '../../core/design/design.dart';
import '../../core/widgets/sync_indicator.dart';
import 'crm_repo.dart';
import 'crm_sheets.dart';
import 'crm_widgets.dart';

/// "Mi agenda": los seguimientos de tus oportunidades abiertas, vencidos
/// primero, luego hoy y los próximos días. Se marcan hechos aquí mismo.
class AgendaPage extends ConsumerWidget {
  const AgendaPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(crmAgendaProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Mi agenda'), actions: const [SyncIndicator()]),
      body: async.when(
        skipLoadingOnReload: true,
        loading: () => const NrSkeletonList(count: 6),
        error: (e, _) => NrErrorView(e, onRetry: () => ref.invalidate(crmAgendaProvider)),
        data: (c) {
          final items = asList(c.value['data']);
          final groups = [
            ('overdue', 'Vencidos', NrTone.danger),
            ('today', 'Hoy', NrTone.accent),
            ('upcoming', 'Próximos días', NrTone.neutral),
          ];
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(crmAgendaProvider),
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
              padding: const EdgeInsets.fromLTRB(NrSpace.gutter, 0, NrSpace.gutter, NrSpace.xxxl),
              children: [
                if (c.offline) const Padding(padding: EdgeInsets.only(bottom: NrSpace.sm), child: NrBanner(message: 'Sin señal: estás viendo lo guardado.')),
                if (items.isEmpty)
                  const NrEmpty(icon: Icons.event_available_rounded, title: 'Agenda libre', message: 'No tienes seguimientos en los próximos 14 días. Programa uno desde una oportunidad.')
                else
                  for (final (key, label, tone) in groups)
                    if (items.any((a) => a['bucket'] == key)) ...[
                      NrSectionHeader(label, count: items.where((a) => a['bucket'] == key).length, trailing: tone == NrTone.danger ? Icon(Icons.warning_amber_rounded, size: 16, color: context.nr.danger) : null),
                      NrGroup(inset: 64, children: [
                        for (final a in items.where((a) => a['bucket'] == key))
                          ActivityTile(
                            activity: a,
                            subtitle: [asMap(asMap(a['deal'])['partner'])['name'], asMap(a['deal'])['title']].whereType<Object>().join(' · '),
                            onTap: () => context.push('/crm/deals/${asMap(a['deal'])['id']}'),
                            onToggle: () => toggleActivity(context, ref, a),
                          ),
                      ]),
                    ],
              ],
            ),
          );
        },
      ),
    );
  }
}
