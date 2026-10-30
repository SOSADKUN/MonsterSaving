import 'package:flutter/material.dart';
import '../../core/localization/context.dart';
import '../../core/models/ledger.dart';

class OtherPaymentReview extends StatelessWidget {
  const OtherPaymentReview({
    super.key,
    required this.date,
    this.endDate,
    required this.onYes,
    required this.onNo,
    this.enabled = true,
  });
  final DateTime date;
  final DateTime? endDate;
  final VoidCallback onYes, onNo;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final range = endDate != null && !DateUtils.isSameDay(date, endDate);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              range ? '${dateKey(date)} – ${dateKey(endDate!)}' : dateKey(date),
              style: Theme.of(context).textTheme.labelLarge,
            ),
            const SizedBox(height: 8),
            Text(
              context.tr(
                range ? 'import_panel.otherRange' : 'import_panel.014',
              ),
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(context.tr('import_panel.015')),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: enabled ? onYes : null,
              child: Text(context.tr('import_panel.016')),
            ),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: enabled ? onNo : null,
              child: Text(
                context.tr(
                  range ? 'import_panel.finishRange' : 'import_panel.017',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
