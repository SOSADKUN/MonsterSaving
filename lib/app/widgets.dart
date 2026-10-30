import '../core/localization/context.dart';
import 'package:flutter/material.dart';
import '../core/models/ledger.dart';
import '../core/input/cents_input_formatter.dart';

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
      decoration: InputDecoration(
        labelText: label,
        prefixText: 'RM ',
        hintText: '0.00',
      ),
      keyboardType: TextInputType.number,
      inputFormatters: const [CentsInputFormatter()],
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

class DateField extends StatefulWidget {
  final DateTime value;
  final ValueChanged<DateTime> onChanged;
  final String label;
  final DateTime? lastDate;
  const DateField({
    super.key,
    required this.value,
    required this.onChanged,
    required this.label,
    this.lastDate,
  });
  @override
  State<DateField> createState() => _DateFieldState();
}

class _DateFieldState extends State<DateField> {
  bool _open = false;

  Future<void> _pick() async {
    if (_open) return;
    FocusScope.of(context).unfocus();
    setState(() => _open = true);
    try {
      final chosen = await showModalBottomSheet<DateTime>(
        context: context,
        showDragHandle: true,
        useSafeArea: true,
        isScrollControlled: true,
        constraints: const BoxConstraints(maxWidth: 560),
        sheetAnimationStyle: MediaQuery.disableAnimationsOf(context)
            ? AnimationStyle.noAnimation
            : const AnimationStyle(
                duration: Duration(milliseconds: 160),
                reverseDuration: Duration(milliseconds: 120),
              ),
        builder: (sheetContext) => SafeArea(
          top: false,
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    widget.label,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  CalendarDatePicker(
                    initialDate: widget.value,
                    firstDate: DateTime(2000),
                    lastDate: DateUtils.dateOnly(
                      widget.lastDate ?? DateTime.now(),
                    ),
                    onDateChanged: (date) => Navigator.pop(sheetContext, date),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(sheetContext),
                    child: Text(context.tr('widgets.002')),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      if (mounted && chosen != null) widget.onChanged(chosen);
    } finally {
      if (mounted) setState(() => _open = false);
    }
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: InkWell(
      borderRadius: BorderRadius.circular(18),
      child: InputDecorator(
        isFocused: _open,
        decoration: InputDecoration(
          labelText: widget.label,
          suffixIcon: Icon(
            Icons.calendar_month,
            color: _open ? Theme.of(context).colorScheme.primary : null,
          ),
        ),
        child: Text(
          MaterialLocalizations.of(context).formatMediumDate(widget.value),
        ),
      ),
      onTap: _pick,
    ),
  );
}
