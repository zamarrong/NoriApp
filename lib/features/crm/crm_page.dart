import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/api_client.dart';
import '../../core/design/design.dart';
import '../../core/providers.dart';
import '../../core/widgets/sync_indicator.dart';
import '../route/route_repo.dart' show Cached;
import 'crm_repo.dart';
import 'crm_sheets.dart';
import 'crm_widgets.dart';

/// "Mis oportunidades": el embudo como tablero (una columna por etapa, se
/// desliza de lado) o como lista, con totales por etapa, filtros y búsqueda.
/// Sin `crm_deals.view_all` solo se ven las propias (lo decide el servidor).
class CrmPage extends ConsumerStatefulWidget {
  const CrmPage({super.key});

  @override
  ConsumerState<CrmPage> createState() => _CrmPageState();
}

class _CrmPageState extends ConsumerState<CrmPage> {
  final _page = PageController(viewportFraction: 0.88);
  final _search = TextEditingController();
  int _index = 0;
  bool _searching = false;

  @override
  void dispose() {
    _page.dispose();
    _search.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    ref.invalidate(crmPipelinesProvider);
    ref.invalidate(crmDealsProvider);
    ref.invalidate(crmAgendaProvider);
    await ref.read(crmDealsProvider.future).catchError((_) => const Cached<List<Map<String, dynamic>>>([]));
  }

  void _goTo(int i) {
    NrHaptics.tap();
    _page.animateToPage(i, duration: NrMotion.base, curve: NrMotion.emphasized);
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(sessionProvider);
    final pipelinesAsync = ref.watch(crmPipelinesProvider);
    final dealsAsync = ref.watch(crmDealsProvider);
    final view = ref.watch(crmViewProvider);
    final filter = ref.watch(crmFilterProvider);
    final pipelineId = ref.watch(crmPipelineIdProvider);
    final agenda = ref.watch(crmAgendaProvider).valueOrNull?.value;
    final overdue = (asMap(asMap(agenda?['meta'])['counts'])['overdue'] as num?)?.toInt() ?? 0;
    final pipelines = pipelinesAsync.valueOrNull?.value ?? const [];
    final pipeline = pipelines.where((p) => p['id'] == pipelineId).firstOrNull ?? pipelines.firstOrNull;
    final offline = (pipelinesAsync.valueOrNull?.offline ?? false) || (dealsAsync.valueOrNull?.offline ?? false);

    return Scaffold(
      appBar: AppBar(
        title: _searching
            ? TextField(
                controller: _search,
                autofocus: true,
                style: NrText.body(context),
                decoration: const InputDecoration(hintText: 'Buscar oportunidad o cliente', border: InputBorder.none, filled: false, contentPadding: EdgeInsets.zero),
                onChanged: (v) => ref.read(crmFilterProvider.notifier).state = filter.copyWith(search: v.trim()),
              )
            : Text(s?.canCrmAll ?? false ? 'Oportunidades' : 'Mis oportunidades'),
        actions: [
          IconButton(
            tooltip: _searching ? 'Cerrar búsqueda' : 'Buscar',
            icon: Icon(_searching ? Icons.close_rounded : Icons.search_rounded),
            onPressed: () => setState(() {
              _searching = !_searching;
              if (!_searching) {
                _search.clear();
                ref.read(crmFilterProvider.notifier).state = filter.copyWith(search: '');
              }
            }),
          ),
          IconButton(
            tooltip: 'Mi agenda',
            onPressed: () => context.push('/crm/agenda'),
            icon: Badge(isLabelVisible: overdue > 0, label: Text('$overdue'), child: const Icon(Icons.event_note_rounded)),
          ),
          if (!_searching) const SyncIndicator(),
        ],
      ),
      floatingActionButton: (s?.canCrmCreate ?? false)
          ? FloatingActionButton.extended(
              heroTag: 'crm-new',
              onPressed: () {
                final stages = asList(pipeline?['stages']);
                final current = view == CrmView.board && _index < stages.length ? stages[_index] : null;
                showNewDealSheet(context, ref, pipelineId: pipeline?['id'] as int?, stageId: current?['outcome'] == 'open' ? current!['id'] as int? : null);
              },
              icon: const Icon(Icons.add_rounded),
              label: const Text('Nueva'),
            )
          : null,
      body: pipelinesAsync.when(
        skipLoadingOnReload: true,
        loading: () => const NrSkeletonList(header: true),
        error: (e, _) => NrErrorView(e, onRetry: _refresh),
        data: (_) => dealsAsync.when(
          skipLoadingOnReload: true,
          loading: () => const NrSkeletonList(header: true),
          error: (e, _) => NrErrorView(e, onRetry: _refresh),
          data: (c) {
            if (pipeline == null) return const NrEmpty(icon: Icons.view_kanban_rounded, title: 'Sin embudos', message: 'Pide a tu administrador que configure el CRM.');
            final userId = s?.userId ?? 0;
            final mine = c.value.where((d) => d['pipeline_id'] == pipeline['id'] && matchesFilter(d, filter, userId)).toList();
            return Column(children: [
              if (offline) const Padding(padding: EdgeInsets.fromLTRB(NrSpace.gutter, 0, NrSpace.gutter, NrSpace.sm), child: NrBanner(message: 'Sin señal: estás viendo lo guardado.')),
              _Kpis(deals: mine),
              _Toolbar(pipelines: pipelines, pipeline: pipeline, canSeeAll: s?.canCrmAll ?? false),
              Expanded(
                child: NrSwitcher(
                  child: view == CrmView.board
                      ? _Board(key: const ValueKey('board'), pipeline: pipeline, deals: mine, controller: _page, index: _index, onPage: (i) => setState(() => _index = i), onTab: _goTo, onRefresh: _refresh)
                      : _DealList(key: const ValueKey('list'), deals: mine, status: filter.status, onRefresh: _refresh),
                ),
              ),
            ]);
          },
        ),
      ),
    );
  }
}

/// Abierto, ponderado y ganado este mes (con los filtros).
class _Kpis extends StatelessWidget {
  const _Kpis({required this.deals});
  final List<Map<String, dynamic>> deals;

  @override
  Widget build(BuildContext context) {
    final nr = context.nr;
    final open = stageTotals(deals.where((d) => d['status'] == 'open'));
    final won = stageTotals(deals.where((d) => d['status'] == 'won' && closedThisMonth(d)));
    Widget stat(String label, Widget value, String caption, Color dot) => Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Container(width: 7, height: 7, decoration: BoxDecoration(color: dot, shape: BoxShape.circle)),
              const SizedBox(width: 5),
              Flexible(child: Text(label.toUpperCase(), style: NrText.eyebrow(context), maxLines: 1, overflow: TextOverflow.ellipsis)),
            ]),
            const SizedBox(height: 4),
            value,
            Text(caption, style: NrText.caption(context), maxLines: 1, overflow: TextOverflow.ellipsis),
          ]),
        );
    return Padding(
      padding: const EdgeInsets.fromLTRB(NrSpace.gutter, NrSpace.xs, NrSpace.gutter, NrSpace.sm),
      child: NrCard(
        padding: const EdgeInsets.fromLTRB(NrSpace.lg, NrSpace.md, NrSpace.lg, NrSpace.md),
        child: IntrinsicHeight(
          child: Row(children: [
            stat('Abierto', NrAmount(open.amount, size: 19, showCents: false, animate: true), '${open.count} oportunidades', nr.accent),
            VerticalDivider(color: nr.border, width: NrSpace.xl),
            stat('Ponderado', NrAmount(open.weighted, size: 19, showCents: false, animate: true), 'por probabilidad', NrColors.hues[2]),
            VerticalDivider(color: nr.border, width: NrSpace.xl),
            stat('Ganado', NrAmount(won.amount, size: 19, showCents: false, animate: true, color: won.count > 0 ? nr.success : null), 'este mes', nr.success),
          ]),
        ),
      ),
    );
  }
}

class _Toolbar extends ConsumerWidget {
  const _Toolbar({required this.pipelines, required this.pipeline, required this.canSeeAll});

  final List<Map<String, dynamic>> pipelines;
  final Map<String, dynamic> pipeline;
  final bool canSeeAll;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final nr = context.nr;
    final view = ref.watch(crmViewProvider);
    final filter = ref.watch(crmFilterProvider);
    void set(CrmFilter f) => ref.read(crmFilterProvider.notifier).state = f;
    Widget chip(String label, IconData icon, bool on, VoidCallback onTap) => Padding(
          padding: const EdgeInsets.only(right: NrSpace.sm),
          child: FilterChip(
            avatar: Icon(icon, size: 16, color: on ? nr.onInk : nr.secondary),
            label: Text(label),
            selected: on,
            showCheckmark: false,
            onSelected: (_) {
              NrHaptics.tap();
              onTap();
            },
          ),
        );
    return Column(children: [
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: NrSpace.gutter),
        child: Row(children: [
          Expanded(
            child: NrSegmented<CrmView>(
              values: const [CrmView.board, CrmView.list],
              labels: const ['Tablero', 'Lista'],
              icons: const [Icons.view_kanban_rounded, Icons.view_agenda_rounded],
              selected: view,
              onChanged: (v) => ref.read(crmViewProvider.notifier).set(v),
            ),
          ),
          if (pipelines.length > 1) ...[
            const SizedBox(width: NrSpace.sm),
            PopupMenuButton<int>(
              tooltip: 'Embudo',
              onSelected: (id) => ref.read(crmPipelineIdProvider.notifier).state = id,
              itemBuilder: (_) => [for (final p in pipelines) PopupMenuItem(value: p['id'] as int, child: Text('${p['name']}'))],
              child: Container(
                height: 44,
                padding: const EdgeInsets.symmetric(horizontal: NrSpace.md),
                decoration: BoxDecoration(color: nr.night ? nr.raised : nr.sunken, borderRadius: BorderRadius.circular(NrRadius.lg)),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  ConstrainedBox(constraints: const BoxConstraints(maxWidth: 96), child: Text('${pipeline['name']}', style: NrText.label(context).copyWith(fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis)),
                  Icon(Icons.expand_more_rounded, size: 18, color: nr.secondary),
                ]),
              ),
            ),
          ],
        ]),
      ),
      SizedBox(
        height: 52,
        child: ListView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.fromLTRB(NrSpace.gutter, NrSpace.sm, NrSpace.gutter, 0), children: [
          if (view == CrmView.list)
            for (final (st, label) in [(CrmStatus.open, 'Abiertas'), (CrmStatus.won, 'Ganadas'), (CrmStatus.lost, 'Perdidas')])
              Padding(
                padding: const EdgeInsets.only(right: NrSpace.sm),
                child: ChoiceChip(
                  label: Text(label),
                  selected: filter.status == st,
                  onSelected: (_) {
                    NrHaptics.tap();
                    set(filter.copyWith(status: st));
                  },
                ),
              ),
          if (canSeeAll) chip('Mías', Icons.person_rounded, filter.mineOnly, () => set(filter.copyWith(mineOnly: !filter.mineOnly))),
          chip('Con vencidos', Icons.schedule_rounded, filter.overdue, () => set(filter.copyWith(overdue: !filter.overdue))),
          chip('Inactivas', Icons.hourglass_bottom_rounded, filter.idle, () => set(filter.copyWith(idle: !filter.idle))),
        ]),
      ),
      const SizedBox(height: NrSpace.sm),
    ]);
  }
}

// ───────────────────────── Tablero ─────────────────────────

class _Board extends ConsumerWidget {
  const _Board({super.key, required this.pipeline, required this.deals, required this.controller, required this.index, required this.onPage, required this.onTab, required this.onRefresh});

  final Map<String, dynamic> pipeline;
  final List<Map<String, dynamic>> deals;
  final PageController controller;
  final int index;
  final ValueChanged<int> onPage;
  final ValueChanged<int> onTab;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final nr = context.nr;
    final stages = asList(pipeline['stages']);
    List<Map<String, dynamic>> inStage(Map<String, dynamic> st) {
      final closing = st['outcome'] != 'open';
      final rows = deals.where((d) => d['stage_id'] == st['id'] && (closing ? closedThisMonth(d) || d['local'] == true : d['status'] == 'open')).toList();
      rows.sort((a, b) {
        // Lo vencido arriba, luego el siguiente seguimiento más cercano
        final oa = ((a['overdue_count'] as num?) ?? 0) > 0 ? 0 : 1;
        final ob = ((b['overdue_count'] as num?) ?? 0) > 0 ? 0 : 1;
        if (oa != ob) return oa - ob;
        final da = '${asMap(a['next_activity'])['due_at'] ?? '~'}';
        final db = '${asMap(b['next_activity'])['due_at'] ?? '~'}';
        return da.compareTo(db);
      });
      return rows;
    }

    final columns = [for (final st in stages) inStage(st)];
    return Column(children: [
      // Etapas como pestañas: la activa sigue al deslizar
      SizedBox(
        height: 38,
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: NrSpace.gutter),
          itemCount: stages.length,
          itemBuilder: (_, i) {
            final c = stageColor(context, stages[i]);
            final on = i == index;
            return Padding(
              padding: const EdgeInsets.only(right: 6),
              child: InkWell(
                borderRadius: BorderRadius.circular(NrRadius.pill),
                onTap: () => onTab(i),
                child: AnimatedContainer(
                  duration: NrMotion.fast,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: on ? nr.tint(c, 0.16) : Colors.transparent,
                    borderRadius: BorderRadius.circular(NrRadius.pill),
                    border: Border.all(color: on ? c.withValues(alpha: 0.6) : nr.border),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Container(width: 7, height: 7, decoration: BoxDecoration(color: c, shape: BoxShape.circle)),
                    const SizedBox(width: 6),
                    Text('${stages[i]['name']}', style: NrText.label(context).copyWith(color: on ? nr.headline : nr.secondary, fontWeight: on ? FontWeight.w700 : FontWeight.w500)),
                    const SizedBox(width: 5),
                    Text('${columns[i].length}', style: NrText.caption(context).copyWith(fontWeight: FontWeight.w700, color: on ? nr.tone(c) : nr.muted)),
                  ]),
                ),
              ),
            );
          },
        ),
      ),
      const SizedBox(height: NrSpace.sm),
      Expanded(
        child: PageView.builder(
          controller: controller,
          padEnds: false,
          itemCount: stages.length,
          onPageChanged: onPage,
          itemBuilder: (_, i) => Padding(
            padding: EdgeInsets.only(left: i == 0 ? NrSpace.gutter : 6, right: i == stages.length - 1 ? NrSpace.gutter : 6),
            child: _Column(stage: stages[i], deals: columns[i], pipelineId: pipeline['id'] as int, onRefresh: onRefresh),
          ),
        ),
      ),
    ]);
  }
}

class _Column extends ConsumerWidget {
  const _Column({required this.stage, required this.deals, required this.pipelineId, required this.onRefresh});

  final Map<String, dynamic> stage;
  final List<Map<String, dynamic>> deals;
  final int pipelineId;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final nr = context.nr;
    final closing = stage['outcome'] != 'open';
    final canCreate = ref.watch(sessionProvider)?.canCrmCreate ?? false;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      StageHeader(stage: stage, totals: stageTotals(deals), closing: closing),
      const SizedBox(height: NrSpace.sm),
      Expanded(
        child: RefreshIndicator(
          color: nr.accent,
          onRefresh: onRefresh,
          child: deals.isEmpty
              ? ListView(physics: const AlwaysScrollableScrollPhysics(), padding: const EdgeInsets.only(bottom: 96), children: [
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: NrSpace.xxl, horizontal: NrSpace.lg),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(NrRadius.xl),
                      border: Border.all(color: nr.borderStrong.withValues(alpha: 0.6)),
                      color: nr.night ? nr.surface.withValues(alpha: 0.4) : nr.sunken.withValues(alpha: 0.35),
                    ),
                    child: Column(children: [
                      Icon(closing ? Icons.inbox_rounded : Icons.view_kanban_outlined, color: nr.muted),
                      const SizedBox(height: NrSpace.sm),
                      Text(closing ? 'Nada cerrado este mes' : 'Sin oportunidades aquí', style: NrText.label(context).copyWith(color: nr.secondary)),
                      if (!closing && canCreate) ...[
                        const SizedBox(height: NrSpace.sm),
                        TextButton.icon(
                          onPressed: () => showNewDealSheet(context, ref, pipelineId: pipelineId, stageId: stage['id'] as int?),
                          icon: const Icon(Icons.add_rounded, size: 18),
                          label: const Text('Agregar aquí'),
                        ),
                      ],
                    ]),
                  ),
                ])
              : ListView.separated(
                  physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                  padding: const EdgeInsets.only(bottom: 96),
                  itemCount: deals.length,
                  separatorBuilder: (_, _) => const SizedBox(height: NrSpace.sm),
                  itemBuilder: (_, i) {
                    final d = deals[i];
                    final card = DealCard(deal: d, onTap: () => context.push('/crm/deals/${d['id']}'));
                    final open = d['status'] == 'open' && d['local'] != true;
                    final child = open
                        ? GestureDetector(
                            onLongPress: () async {
                              NrHaptics.action();
                              // El detalle trae las etapas del embudo para moverla
                              final detail = await ref.read(crmDealProvider((d['id'] as num).toInt()).future);
                              if (context.mounted) await showMoveSheet(context, ref, detail.value);
                            },
                            child: card,
                          )
                        : card;
                    return i < 8 ? NrEntrance(index: i, child: child) : child;
                  },
                ),
        ),
      ),
    ]);
  }
}

// ───────────────────────── Lista ─────────────────────────

class _DealList extends StatelessWidget {
  const _DealList({super.key, required this.deals, required this.status, required this.onRefresh});

  final List<Map<String, dynamic>> deals;
  final CrmStatus status;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    final rows = deals.where((d) => d['status'] == status.name).toList();
    if (status == CrmStatus.open) {
      rows.sort((a, b) => '${asMap(a['next_activity'])['due_at'] ?? '~'}'.compareTo('${asMap(b['next_activity'])['due_at'] ?? '~'}'));
    } else {
      rows.sort((a, b) => '${b['closed_at'] ?? ''}'.compareTo('${a['closed_at'] ?? ''}'));
    }
    final totals = stageTotals(rows);
    return RefreshIndicator(
      color: context.nr.accent,
      onRefresh: onRefresh,
      child: rows.isEmpty
          ? ListView(physics: const AlwaysScrollableScrollPhysics(), children: [
              NrEmpty(
                icon: status == CrmStatus.open ? Icons.view_kanban_rounded : (status == CrmStatus.won ? Icons.emoji_events_rounded : Icons.inbox_rounded),
                title: switch (status) { CrmStatus.open => 'Sin oportunidades abiertas', CrmStatus.won => 'Aún no hay ganadas', CrmStatus.lost => 'Sin perdidas' },
                message: status == CrmStatus.open ? 'Crea una desde aquí o desde la ficha de un cliente.' : null,
              ),
            ])
          : ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
              padding: const EdgeInsets.fromLTRB(NrSpace.gutter, 0, NrSpace.gutter, 96),
              itemCount: rows.length + 1,
              separatorBuilder: (_, _) => const SizedBox(height: NrSpace.sm),
              itemBuilder: (_, i) {
                if (i == 0) {
                  return Padding(
                    padding: const EdgeInsets.fromLTRB(NrSpace.xs, 0, NrSpace.xs, 0),
                    child: Row(children: [
                      Text('${rows.length} ${rows.length == 1 ? 'oportunidad' : 'oportunidades'}'.toUpperCase(), style: NrText.eyebrow(context)),
                      const Spacer(),
                      Text(money(totals.amount), style: NrText.money(context, size: 14, weight: FontWeight.w700)),
                    ]),
                  );
                }
                final d = rows[i - 1];
                final card = DealCard(deal: d, showStage: true, onTap: () => context.push('/crm/deals/${d['id']}'));
                return i < 10 ? NrEntrance(index: i, child: card) : card;
              },
            ),
    );
  }
}
