import '../../core/localization/context.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../app/state.dart';
import '../../app/widgets.dart';
import '../../core/models/ledger.dart';
import '../../core/services/finance.dart';

class HistoryPanel extends ConsumerStatefulWidget {
  final ValueChanged<Entry> onEdit;
  const HistoryPanel({super.key, required this.onEdit});
  @override
  ConsumerState<HistoryPanel> createState() => _HistoryPanelState();
}

class _HistoryPanelState extends ConsumerState<HistoryPanel> {
  int offset = 0;
  bool all = false;
  @override
  Widget build(BuildContext context) {
    final l = ref.watch(ledgerProvider).requireValue;
    final now = DateTime.now();
    final anchor = Finance.calculate(l, now).start;
    final cycle = Finance.calculate(
      l,
      Finance.payday(anchor.year, anchor.month + offset, l.profile!['payday']),
    );
    final current = offset == 0 ? Finance.calculate(l, now) : cycle;
    final items =
        l.entries
            .where(
              (e) =>
                  all ||
                  (e.date.compareTo(dateKey(current.start)) >= 0 &&
                      e.date.compareTo(dateKey(current.end)) < 0),
            )
            .toList()
          ..sort((a, b) => b.date.compareTo(a.date));
    return Column(
      children: [
        SwitchListTile(
          title: Text(context.tr('history.001')),
          value: all,
          onChanged: (v) => setState(() => all = v),
        ),
        if (!all)
          Row(
            children: [
              IconButton(
                onPressed: () => setState(() => offset--),
                icon: const Icon(Icons.chevron_left),
              ),
              Expanded(
                child: Text(
                  '${dateKey(current.start)} → ${dateKey(current.end.subtract(const Duration(days: 1)))}',
                ),
              ),
              IconButton(
                onPressed: () => setState(() => offset++),
                icon: const Icon(Icons.chevron_right),
              ),
            ],
          ),
        if (items.isEmpty)
          Padding(
            padding: EdgeInsets.all(32),
            child: Text(context.tr('history.002')),
          ),
        for (final e in items)
          Card(
            child: ListTile(
              title: Text(
                '${e.type == 'expense' ? '-' : '+'}${money(e.amount)} · ${typeLabel(e.type)}',
              ),
              subtitle: Text(
                '${e.date} · ${paymentLabel(e.method)} · ${sourceLabel(e.source)}\n${e.description}',
              ),
              isThreeLine: true,
              onTap: () => widget.onEdit(e),
              trailing: IconButton(
                tooltip: context.tr('history.003'),
                icon: const Icon(Icons.delete_outline),
                onPressed: () async {
                  if (await confirm(
                    context,
                    context.tr(
                      e.includedInOpeningBalance
                          ? 'history.deleteIncluded'
                          : 'history.004',
                    ),
                  )) {
                    try {
                      await ref
                          .read(ledgerProvider.notifier)
                          .change(
                            (l) => l.entries.removeWhere((t) => t.id == e.id),
                          );
                    } catch (error) {
                      if (context.mounted) {
                        notice(context, error);
                      }
                    }
                  }
                },
              ),
            ),
          ),
      ],
    );
  }
}
