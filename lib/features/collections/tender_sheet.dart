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

  @override
  Widget build(BuildContext context) {
    final paid = Dec.tryParse(amount.text) ?? Dec.zero;
    final change = paid - widget.total;
    final givesChange = selected?['gives_change'] == true;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(NrSpace.xl, 0, NrSpace.xl, NrSpace.xl),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text(widget.title, style: NrText.title(context)),
          const SizedBox(height: NrSpace.xs),
          Text('Total ${money(widget.total)}', style: NrText.bodySm(context)),
          const SizedBox(height: NrSpace.lg),
          Wrap(spacing: NrSpace.sm, runSpacing: NrSpace.sm, children: [
            for (final t in widget.tenderTypes)
              ChoiceChip(label: Text('${t['name']}'), selected: selected?['id'] == t['id'], onSelected: (_) => setState(() => selected = t)),
          ]),
          const SizedBox(height: NrSpace.lg),
          TextField(
            controller: amount,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            style: NrText.money(context, size: 22),
            decoration: const InputDecoration(labelText: 'Recibido', prefixText: r'$ '),
            onChanged: (_) => setState(() {}),
          ),
          if (selected?['requires_reference'] == true) ...[
            const SizedBox(height: NrSpace.md),
            TextField(controller: reference, decoration: const InputDecoration(labelText: 'Referencia')),
          ],
          if (givesChange && change > Dec.zero) ...[
            const SizedBox(height: NrSpace.sm),
            Text('Cambio ${money(change)}', style: NrText.headline(context).copyWith(color: context.nr.success)),
          ],
          const SizedBox(height: NrSpace.lg),
          FilledButton(
            onPressed: selected == null || paid <= Dec.zero
                ? null
                : () => Navigator.pop(
                      context,
                      TenderChoice(tenders: [
                        {
                          'tender_type_id': selected!['id'],
                          'amount': paid.toJson(2),
                          if (reference.text.trim().isNotEmpty) 'reference': reference.text.trim(),
                        }
                      ]),
                    ),
            child: const Text('Cobrar'),
          ),
          if (widget.allowCredit) ...[
            const SizedBox(height: NrSpace.sm),
            OutlinedButton(onPressed: () => Navigator.pop(context, const TenderChoice(tenders: [], onCredit: true)), child: const Text('Dejar a crédito')),
          ],
        ]),
      ),
    );
  }
}
