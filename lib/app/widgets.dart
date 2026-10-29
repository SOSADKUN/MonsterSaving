import '../core/localization/context.dart';
import 'package:flutter/material.dart';
import '../core/models/ledger.dart';

Future<bool> confirm(BuildContext context, String message) async =>
    await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(context.tr('widgets.001')),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: Text(context.tr('widgets.002')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(c, true),
            child: Text(context.tr('widgets.003')),
          ),
        ],
      ),
    ) ??
    false;
void notice(BuildContext context, Object text) {
  if (context.mounted) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(errorMessage(text))));
  }
}

class MoneyField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  const MoneyField(this.controller, this.label, {super.key});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: TextFormField(
      controller: controller,
      decoration: InputDecoration(labelText: label, prefixText: 'RM '),
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      validator: (v) {
        try {
          cents(v ?? '');
          return null;
        } catch (_) {
          return context.tr('widgets.004');
        }
      },
    ),
  );
}

class DateField extends StatelessWidget {
  final DateTime value;
  final ValueChanged<DateTime> onChanged;
  final String label;
  const DateField({
    super.key,
    required this.value,
    required this.onChanged,
    required this.label,
  });
  @override
  Widget build(BuildContext context) => ListTile(
    contentPadding: EdgeInsets.zero,
    title: Text(label),
    subtitle: Text(dateKey(value)),
    trailing: const Icon(Icons.calendar_month),
    onTap: () async {
      final d = await showDatePicker(
        context: context,
        initialDate: value,
        firstDate: DateTime(2000),
        lastDate: DateTime.now(),
      );
      if (d != null) {
        onChanged(d);
      }
    },
  );
}
