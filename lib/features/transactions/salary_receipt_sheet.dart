import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../app/state.dart';
import '../../app/widgets.dart';
import '../../core/localization/context.dart';
import '../../core/models/ledger.dart';
import '../../core/services/finance.dart';

Future<void> showSalaryReceiptSheet(BuildContext context) async {
  await showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    useSafeArea: true,
    isScrollControlled: true,
    constraints: const BoxConstraints(maxWidth: 560),
    builder: (_) => const _SalaryReceiptSheet(),
  );
}

class _SalaryReceiptSheet extends ConsumerStatefulWidget {
  const _SalaryReceiptSheet();
  @override
  ConsumerState<_SalaryReceiptSheet> createState() =>
      _SalaryReceiptSheetState();
}

class _SalaryReceiptSheetState extends ConsumerState<_SalaryReceiptSheet> {
  DateTime _date = day(DateTime.now());
  bool _busy = false;

  Future<void> _confirm() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final current = ref.read(ledgerProvider).requireValue;
      final historical = _date.isBefore(
        DateTime.parse(current.profile!['openingDate']),
      );
      // A missed setup checkbox must never credit an already-spent salary again.
      // Historical receipts are always record-only; newer receipts need a choice.
      final bool? alreadyIncluded = historical
          ? true
          : await showDialog<bool>(
              context: context,
              builder: (dialogContext) {
                final balance = Finance.calculate(
                  current,
                  DateTime.now(),
                ).balance;
                final salary = current.profile!['salary'] as int;
                return AlertDialog(
                  title: Text(context.tr('salary.balanceChoiceTitle')),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        context.tr('salary.balanceChoiceBody', {
                          'balance': money(balance),
                          'salary': money(salary),
                        }),
                      ),
                      const SizedBox(height: 20),
                      FilledButton(
                        onPressed: () => Navigator.pop(dialogContext, true),
                        child: Text(
                          context.tr('salary.recordOnly', {
                            'balance': money(balance),
                          }),
                        ),
                      ),
                      const SizedBox(height: 8),
                      OutlinedButton(
                        onPressed: () => Navigator.pop(dialogContext, false),
                        child: Text(
                          context.tr('salary.addToBalance', {
                            'balance': money(balance + salary),
                          }),
                        ),
                      ),
                    ],
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(dialogContext),
                      child: Text(context.tr('transaction_form.015')),
                    ),
                  ],
                  scrollable: true,
                );
              },
            );
      if (alreadyIncluded == null || !mounted) return;
      await ref.read(ledgerProvider.notifier).change((ledger) {
        final profile = ledger.profile!;
        final amount = profile['salary'] as int;
        if (amount <= 0) {
          throw FormatException(context.tr('salary.enterAmount'));
        }
        final cycle = Finance.calculate(ledger, _date);
        final start = dateKey(cycle.start), end = dateKey(cycle.end);
        final previous = profile['lastSalary'] as String?;
        if ((previous != null &&
                previous.compareTo(start) >= 0 &&
                previous.compareTo(end) < 0) ||
            ledger.entries.any(
              (entry) =>
                  entry.type == 'salary' &&
                  entry.date.compareTo(start) >= 0 &&
                  entry.date.compareTo(end) < 0,
            )) {
          throw FormatException(context.tr('salary.alreadyConfirmed'));
        }
        ledger.entries.add(
          Entry(
            id: const Uuid().v4(),
            date: dateKey(_date),
            type: 'salary',
            amount: amount,
            method: 'Other',
            includedInOpeningBalance: alreadyIncluded,
          ),
        );
        ledger.achievements.add('record:${dateKey(_date)}');
      });
      if (mounted) Navigator.pop(context);
    } catch (error) {
      if (mounted) notice(context, error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(ledgerProvider).requireValue.profile!;
    final historical = _date.isBefore(DateTime.parse(profile['openingDate']));
    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            24,
            0,
            24,
            24 + MediaQuery.viewInsetsOf(context).bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                context.tr('settings.020'),
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 12),
              Text(
                money(profile['salary'] as int),
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 12),
              IgnorePointer(
                ignoring: _busy,
                child: DateField(
                  value: _date,
                  onChanged: (date) => setState(() => _date = date),
                  label: context.tr('salary.receivedDate'),
                ),
              ),
              if (historical)
                Text(context.tr('transaction_form.includedInBalance')),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: _busy ? null : _confirm,
                child: Text(
                  context.tr(
                    _busy ? 'transaction_form.012' : 'transaction_form.013',
                  ),
                ),
              ),
              TextButton(
                onPressed: _busy ? null : () => Navigator.pop(context),
                child: Text(context.tr('transaction_form.015')),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
