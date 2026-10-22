import 'package:flutter/material.dart';

import '../../core/design/design.dart';

class TenderChoice {
  const TenderChoice({required this.tenders, this.onCredit = false});

  /// [{tender_type_id, amount, reference?}] como los pide la API.
  final List<Map<String, dynamic>> tenders;
  final bool onCredit;
}

/// Forma de cobro y monto. [tenderTypes] = `{id, name, gives_change, requires_reference}`.
Future<TenderChoice?> showTenderSheet(BuildContext context,
    {required List<Map<String, dynamic>> tenderTypes, required Dec total, bool allowCredit = false, String title = 'Cobrar'}) {
  return showModalBottomSheet<TenderChoice>(
    context: context,
    isScrollControlled: true,
    builder: (_) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: _TenderSheet(tenderTypes: tenderTypes.where((t) => t['is_credit_document'] != true).toList(), total: total, allowCredit: allowCredit, title: title),
    ),
  );
}

class _TenderSheet extends StatefulWidget {
  const _TenderSheet({required this.tenderTypes, required this.total, required this.allowCredit, required this.title});

  final List<Map<String, dynamic>> tenderTypes;
  final Dec total;
  final bool allowCredit;
  final String title;

  @override
  State<_TenderSheet> createState() => _TenderSheetState();
}

class _TenderSheetState extends State<_TenderSheet> {
  Map<String, dynamic>? selected;
  late final amount = TextEditingController(text: widget.total.toFixed(2));
  final reference = TextEditingController();

  @override
  void initState() {
    super.initState();
    selected = widget.tenderTypes.firstOrNull;
  }

  /// Ícono según el nombre de la forma de pago.
  static IconData iconFor(Map<String, dynamic> t) {
    final n = '${t['name'] ?? ''}'.toLowerCase();
    if (n.contains('efectivo') || t['gives_change'] == true) return Icons.payments_rounded;
    if (n.contains('transfer') || n.contains('spei') || n.contains('depósito')) return Icons.account_balance_rounded;
    if (n.contains('tarjeta') || n.contains('crédito') || n.contains('débito')) return Icons.credit_card_rounded;
    if (n.contains('cheque')) return Icons.request_page_rounded;
    if (n.contains('vale')) return Icons.confirmation_number_rounded;
    return Icons.account_balance_wallet_rounded;
  }

  /// Billetes con los que suelen pagar: el total exacto y redondeos hacia arriba.
  List<Dec> _suggestions() {
    final total = widget.total.toDouble();
    final out = <double>{total};
    for (final step in [50, 100, 200, 500, 1000]) {
      final up = (total / step).ceil() * step.toDouble();
      if (up > total && out.length < 4) out.add(up);
    }
    return out.map((v) => Dec.parse(v.toStringAsFixed(2))).toList();
  }

  @override
  Widget build(BuildContext context) {
    final nr = context.nr;
    final paid = Dec.tryParse(amount.text) ?? Dec.zero;
    final change = paid - widget.total;
    final givesChange = selected?['gives_change'] == true;
    final short = paid < widget.total && paid > Dec.zero;
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(NrSpace.xl, 0, NrSpace.xl, NrSpace.lg),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text(widget.title.toUpperCase(), style: NrText.eyebrow(context), textAlign: TextAlign.center),
          const SizedBox(height: NrSpace.xs),
          Center(child: NrAmount(widget.total, size: 44, animate: true)),
          Text('por cobrar', textAlign: TextAlign.center, style: NrText.bodySm(context)),
          const SizedBox(height: NrSpace.xl),
          SizedBox(
            height: 76,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: widget.tenderTypes.length,
              separatorBuilder: (_, _) => const SizedBox(width: NrSpace.sm),
              itemBuilder: (_, i) {
                final t = widget.tenderTypes[i];
                final on = selected?['id'] == t['id'];
                return SizedBox(
                  width: 112,
                  child: NrCard(
                    depth: NrDepth.flat,
                    padding: const EdgeInsets.all(NrSpace.md),
                    color: on ? nr.accentSoft : null,
                    borderColor: on ? nr.accent : null,
                    onTap: () {
                      NrHaptics.tap();
                      setState(() => selected = t);
                    },
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Icon(iconFor(t), size: 22, color: on ? (nr.night ? nr.link : nr.accent) : nr.secondary),
                      const Spacer(),
                      Text('${t['name']}', maxLines: 1, overflow: TextOverflow.ellipsis, style: NrText.label(context).copyWith(fontWeight: FontWeight.w600, color: on ? nr.headline : nr.body)),
                    ]),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: NrSpace.lg),
          TextField(
            controller: amount,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            style: NrText.money(context, size: 28, weight: FontWeight.w700),
            decoration: const InputDecoration(labelText: 'Recibido', prefixText: r'$ '),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: NrSpace.sm),
          Wrap(spacing: NrSpace.sm, runSpacing: NrSpace.sm, children: [
            for (final (i, v) in _suggestions().indexed)
              ChoiceChip(
                label: Text(i == 0 ? 'Exacto' : money(v).replaceAll('.00', '')),
                selected: paid == v,
                onSelected: (_) {
                  NrHaptics.tap();
                  setState(() => amount.text = v.toFixed(2));
                },
              ),
          ]),
          if (selected?['requires_reference'] == true) ...[
            const SizedBox(height: NrSpace.md),
            TextField(controller: reference, decoration: const InputDecoration(labelText: 'Referencia', prefixIcon: Icon(Icons.tag_rounded))),
          ],
          AnimatedSize(
            duration: NrMotion.base,
            curve: NrMotion.ease,
            child: (givesChange && change > Dec.zero) || short
                ? Padding(
                    padding: const EdgeInsets.only(top: NrSpace.md),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: NrSpace.lg, vertical: NrSpace.md),
                      decoration: BoxDecoration(color: short ? nr.warningBg : nr.successBg, borderRadius: BorderRadius.circular(NrRadius.lg)),
                      child: Row(children: [
                        Icon(short ? Icons.pie_chart_outline_rounded : Icons.savings_rounded, color: short ? nr.warning : nr.success),
                        const SizedBox(width: NrSpace.sm),
                        Expanded(child: Text(short ? 'Falta por cubrir' : 'Cambio', style: NrText.headline(context).copyWith(color: short ? nr.warning : nr.success))),
                        NrAmount(short ? widget.total - paid : change, size: 22, animate: true, color: short ? nr.warning : nr.success),
                      ]),
                    ),
                  )
                : const SizedBox(width: double.infinity),
          ),
          const SizedBox(height: NrSpace.xl),
          NrButton(
            label: paid > Dec.zero ? 'Cobrar ${money(paid)}' : 'Cobrar',
            icon: Icons.check_rounded,
            onPressed: selected == null || paid <= Dec.zero
                ? null
                : () {
                    NrHaptics.action();
                    Navigator.pop(
                      context,
                      TenderChoice(tenders: [
                        {
                          'tender_type_id': selected!['id'],
                          'amount': paid.toJson(2),
                          if (reference.text.trim().isNotEmpty) 'reference': reference.text.trim(),
                        }
                      ]),
                    );
                  },
          ),
          if (widget.allowCredit) ...[
            const SizedBox(height: NrSpace.sm),
            NrButton(
              label: 'Dejar a crédito',
              icon: Icons.schedule_rounded,
              variant: NrButtonVariant.secondary,
              onPressed: () => Navigator.pop(context, const TenderChoice(tenders: [], onCredit: true)),
            ),
          ],
        ]),
      ),
    );
  }
}
