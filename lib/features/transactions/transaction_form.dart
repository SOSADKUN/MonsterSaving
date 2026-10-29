import '../../core/localization/context.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../app/state.dart';
import '../../app/widgets.dart';
import '../../core/models/ledger.dart';

class TransactionForm extends ConsumerStatefulWidget {
  final String type;
  final Entry? entry;
  final VoidCallback onDone;
  final DateTime? initialDate;
  const TransactionForm({
    super.key,
    required this.type,
    this.entry,
    required this.onDone,
    this.initialDate,
  });
  @override
  ConsumerState<TransactionForm> createState() => _TransactionFormState();
}

class _TransactionFormState extends ConsumerState<TransactionForm> {
  final form = GlobalKey<FormState>();
  late TextEditingController amount, description;
  late DateTime date;
  String method = 'Cash';
  bool busy = false;
  @override
  void initState() {
    super.initState();
    final e = widget.entry;
    amount = TextEditingController(
      text: e == null
          ? ''
          : '${e.amount ~/ 100}.${(e.amount % 100).toString().padLeft(2, '0')}',
    );
    description = TextEditingController(text: e?.description ?? '');
    date = e == null
        ? (widget.initialDate ?? day(DateTime.now()))
        : DateTime.parse(e.date);
    if (e == null && widget.type == 'salary') {
      final salary =
          ref.read(ledgerProvider).requireValue.profile!['salary'] as int;
      amount.text =
          '${salary ~/ 100}.${(salary % 100).toString().padLeft(2, '0')}';
    }
    method = e?.method ?? 'Cash';
  }

  @override
  void dispose() {
    amount.dispose();
    description.dispose();
    super.dispose();
  }

  Future<void> save() async {
    if (!form.currentState!.validate()) {
      return;
    }
    final n = cents(amount.text);
    if (n == 0) {
      notice(context, context.tr('transaction_form.001'));
      return;
    }
    final profile = ref.read(ledgerProvider).requireValue.profile!;
    if (date.isBefore(DateTime.parse(profile['openingDate']))) {
      if (!await confirm(context, context.tr('transaction_form.002'))) {
        return;
      }
      if (!mounted) return;
    }
    setState(() => busy = true);
    try {
      await ref.read(ledgerProvider.notifier).change((l) {
        final e = widget.entry;
        final key = dateKey(date);
        if (widget.type == 'salary' &&
            l.entries.any(
              (t) => t.type == 'salary' && t.date == key && t.id != e?.id,
            )) {
          throw FormatException(context.tr('transaction_form.003'));
        }
        final item = Entry(
          id: e?.id ?? const Uuid().v4(),
          date: key,
          type: widget.type,
          amount: n,
          method: method,
          description: description.text.trim(),
          source: e?.source ?? 'manual',
          fingerprint: e?.fingerprint ?? '',
          importData: e?.importData,
        );
        l.entries.removeWhere((t) => t.id == item.id);
        l.entries.add(item);
        if (e == null) {
          l.achievements.add('record:$key');
        }
      });
      widget.onDone();
    } catch (e) {
      if (mounted) {
        notice(context, e);
      }
    } finally {
      if (mounted) {
        setState(() => busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(20),
      child: Form(
        key: form,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              widget.entry == null
                  ? context.tr('transaction_form.004', {
                      'p0': typeLabel(widget.type),
                    })
                  : context.tr('transaction_form.005'),
              style: Theme.of(context).textTheme.titleLarge,
            ),
            MoneyField(amount, context.tr('transaction_form.006')),
            DropdownButtonFormField<String>(
              initialValue: method,
              decoration: InputDecoration(
                labelText: context.tr('transaction_form.007'),
              ),
              items:
                  ['TNG', 'Public Bank', 'Cash', 'Card', 'Other Bank', 'Other']
                      .map(
                        (m) => DropdownMenuItem(
                          value: m,
                          child: Text(paymentLabel(m)),
                        ),
                      )
                      .toList(),
              onChanged: (v) => method = v!,
            ),
            DateField(
              value: date,
              onChanged: (d) => setState(() => date = d),
              label: context.tr('transaction_form.008'),
            ),
            TextFormField(
              controller: description,
              validator: (v) =>
                  widget.type == 'income' && (v == null || v.trim().isEmpty)
                  ? context.tr('transaction_form.009')
                  : null,
              decoration: InputDecoration(
                labelText: widget.type == 'income'
                    ? context.tr('transaction_form.010')
                    : context.tr('transaction_form.011'),
              ),
              maxLength: 300,
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: busy ? null : save,
              child: Text(
                busy
                    ? context.tr('transaction_form.012')
                    : widget.type == 'salary'
                    ? context.tr('transaction_form.013')
                    : context.tr('transaction_form.014'),
              ),
            ),
            TextButton(
              onPressed: busy ? null : widget.onDone,
              child: Text(context.tr('transaction_form.015')),
            ),
          ],
        ),
      ),
    ),
  );
}
