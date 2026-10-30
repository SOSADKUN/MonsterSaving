import 'hatch_screen.dart';
import 'dart:math';
import 'account_setup.dart';
import '../../core/localization/context.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../import/import_panel.dart';
import '../import/tng_phone_setup.dart';
import '../import/other_payment_review.dart';
import '../../core/services/nightly_reminder.dart';
import '../settings/language_setting.dart';
import '../../app/state.dart';
import '../../app/widgets.dart';
import '../../core/models/ledger.dart';

class Onboarding extends ConsumerStatefulWidget {
  const Onboarding({super.key});
  @override
  ConsumerState<Onboarding> createState() => _OnboardingState();
}

class _OnboardingState extends ConsumerState<Onboarding> {
  int step = 0;
  late final String _starterCompanion;
  bool busy = false;
  final form = GlobalKey<FormState>();
  final opening = TextEditingController(text: '0.00'),
      salary = TextEditingController(text: '0.00'),
      target = TextEditingController(text: '0.00'),
      goal = TextEditingController(text: '0.00');
  final DateTime openingDate = day(DateTime.now());
  DateTime paydayDate = DateTime(DateTime.now().year, DateTime.now().month, 25);
  bool _salaryReceived = false;
  DateTime _salaryReceivedDate = day(DateTime.now());
  final initialAmount = TextEditingController(text: '0.00');
  final initialDescription = TextEditingController();
  final initialEntries = <Entry>[];
  final _recordsScroll = ScrollController();
  DateTime? _otherPaymentDate;
  DateTime? _otherPaymentEndDate;
  DateTime initialDate = day(DateTime.now());
  String initialMethod = 'Cash';
  bool showPdf = false;
  bool reminder = true;
  int reminderMinute = 21 * 60;
  @override
  void initState() {
    super.initState();
    final ledger = ref.read(ledgerProvider).requireValue;
    step = ledger.hasHatched ? 1 : 0;
    // Choose once for this hatch, including retries and language changes.
    _starterCompanion = ledger.hasHatched
        ? ledger.activeCompanion
        : (Random().nextBool() ? 'dinosaur' : 'hamster');
  }

  @override
  void dispose() {
    _recordsScroll.dispose();
    for (final c in [
      opening,
      salary,
      target,
      goal,
      initialAmount,
      initialDescription,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> next() async {
    if (!(form.currentState?.validate() ?? true)) {
      return;
    }
    if (step == 2 && _salaryReceived && cents(salary.text) == 0) {
      notice(context, context.tr('salary.enterAmount'));
      return;
    }
    if (step < 5) {
      setState(() => step++);
      return;
    }
    setState(() => busy = true);
    try {
      bool scheduled = false;
      try {
        scheduled = await NightlyReminder.instance.configure(
          enabled: reminder,
          minute: reminderMinute,
          requestPermission: reminder,
        );
      } catch (_) {
        if (mounted) notice(context, context.tr('onboarding.001'));
      }

      await ref.read(ledgerProvider.notifier).change((l) {
        l.profile = {
          'opening': cents(opening.text),
          'openingDate': dateKey(openingDate),
          'salary': cents(salary.text),
          'payday': paydayDate.day,
          'lastSalary': _salaryReceived ? dateKey(_salaryReceivedDate) : null,
          'target': cents(target.text),
          'goal': cents(goal.text),
          'saved': 0,
          'coverage': null,
          'reminderEnabled': reminder,
          'reminderMinute': reminderMinute,
          'nativeReminderScheduled': scheduled,
        };
        // The supplied current balance already includes all setup transactions,
        // including today's manual records and staged TNG statement imports.
        l.entries.addAll(
          initialEntries.map(
            (entry) => entry.copyWith(includedInOpeningBalance: true),
          ),
        );
        if (_salaryReceived) {
          l.entries.add(
            Entry(
              id: const Uuid().v4(),
              date: dateKey(_salaryReceivedDate),
              type: 'salary',
              amount: cents(salary.text),
              method: 'Other',
              includedInOpeningBalance: true,
            ),
          );
          l.achievements.add('record:${dateKey(_salaryReceivedDate)}');
        }
        for (final e in initialEntries) {
          l.achievements.add('record:${e.date}');
          if (e.fingerprint.isNotEmpty) l.fingerprints.add(e.fingerprint);
        }
      });
    } catch (e) {
      if (mounted) {
        notice(context, context.tr('onboarding.002', {'p0': e}));
      }
    } finally {
      if (mounted) {
        setState(() => busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (step == 0) {
      return HatchScreen(
        companion: _starterCompanion,
        onHatched: () => ref.read(ledgerProvider.notifier).change((ledger) {
          ledger.hasHatched = true;
          ledger.companions = {_starterCompanion};
          ledger.activeCompanion = _starterCompanion;
        }),
        onContinue: () => setState(() => step = 1),
      );
    }

    final titles = [
      context.tr('onboarding.003'),
      context.tr('onboarding.004'),
      context.tr('onboarding.005'),
      context.tr('onboarding.006'),
      context.tr('onboarding.007'),
      context.tr('onboarding.008'),
    ];
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        elevation: 0,
        titleSpacing: 24,
        scrolledUnderElevation: 0,
        title: Text(
          context.tr('main.001'),
          style: Theme.of(context).textTheme.labelLarge,
        ),
        actions: const [
          Padding(
            padding: EdgeInsets.only(right: 12),
            child: LanguageIconButton(),
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: ListView(
              padding: const EdgeInsets.all(24),
              children: [
                LinearProgressIndicator(value: (step + 1) / 6),
                const SizedBox(height: 24),
                Text(
                  titles[step],
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 20),
                Form(
                  key: form,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (step == 1) AccountSetup(onContinueAsGuest: next),
                      if (step == 2) ...[
                        const TngPhoneSetup(),
                        MoneyField(opening, context.tr('onboarding.015')),
                        Row(
                          children: [
                            Expanded(
                              child: MoneyField(
                                salary,
                                context.tr('onboarding.018'),
                              ),
                            ),
                            const SizedBox(width: 12),
                            DecoratedBox(
                              decoration: BoxDecoration(
                                color: _salaryReceived
                                    ? Theme.of(
                                        context,
                                      ).colorScheme.primaryContainer
                                    : Theme.of(
                                        context,
                                      ).colorScheme.surfaceContainerHighest,
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.only(right: 10),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Checkbox(
                                      value: _salaryReceived,
                                      visualDensity: VisualDensity.compact,
                                      materialTapTargetSize:
                                          MaterialTapTargetSize.shrinkWrap,
                                      onChanged: (value) => setState(
                                        () => _salaryReceived = value ?? false,
                                      ),
                                    ),
                                    InkWell(
                                      onTap: () => setState(
                                        () =>
                                            _salaryReceived = !_salaryReceived,
                                      ),
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 12,
                                        ),
                                        child: Text(
                                          context.tr('salary.received'),
                                          style: Theme.of(
                                            context,
                                          ).textTheme.labelMedium,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                        if (_salaryReceived)
                          DateField(
                            value: _salaryReceivedDate,
                            onChanged: (date) =>
                                setState(() => _salaryReceivedDate = date),
                            label: context.tr('salary.receivedDate'),
                          ),
                        DateField(
                          value: paydayDate,
                          onChanged: (d) => setState(() => paydayDate = d),
                          label: context.tr('onboarding.019'),
                          lastDate: DateTime(DateTime.now().year + 10, 12, 31),
                        ),
                      ],
                      if (step == 3) ...[
                        MoneyField(target, context.tr('onboarding.023')),
                        MoneyField(goal, context.tr('onboarding.024')),
                        Text(context.tr('onboarding.025')),
                      ],
                      if (step == 4) ...[
                        const Icon(Icons.receipt_long, size: 72),
                        Text(context.tr('onboarding.026')),
                        const SizedBox(height: 16),
                        if (showPdf)
                          ImportPanel(
                            pendingEntries: initialEntries,
                            openingDate: openingDate,
                            showFollowUp: false,
                            onImportedRange: (start, end) => setState(() {
                              _otherPaymentDate = start;
                              _otherPaymentEndDate = end;
                            }),
                            onNewImport: () => setState(() {
                              _otherPaymentDate = null;
                              _otherPaymentEndDate = null;
                            }),
                            onStagedImport: (entries) =>
                                setState(() => initialEntries.addAll(entries)),
                            onOtherSpending: (date) => setState(() {
                              showPdf = false;
                              initialDate = date;
                            }),
                            onManual: () => setState(() => showPdf = false),
                            onCancel: () => setState(() => showPdf = false),
                          ),
                        if (!showPdf) ...[
                          DateField(
                            value: initialDate,
                            onChanged: (d) => setState(() => initialDate = d),
                            label: context.tr('onboarding.029'),
                          ),
                          MoneyField(
                            initialAmount,
                            context.tr('onboarding.028'),
                          ),
                          DropdownButtonFormField<String>(
                            initialValue: initialMethod,
                            isExpanded: true,
                            decoration: InputDecoration(
                              labelText: context.tr('onboarding.method'),
                            ),
                            items:
                                [
                                      'Cash',
                                      'TNG',
                                      'Card',
                                      'Public Bank',
                                      'Other Bank',
                                      'Other',
                                    ]
                                    .map(
                                      (s) => DropdownMenuItem(
                                        value: s,
                                        child: Text(paymentLabel(s)),
                                      ),
                                    )
                                    .toList(),
                            onChanged: (s) {
                              if (s != null) setState(() => initialMethod = s);
                            },
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: initialDescription,
                            decoration: InputDecoration(
                              labelText: context.tr('onboarding.030'),
                            ),
                          ),
                          const SizedBox(height: 16),
                          OutlinedButton(
                            onPressed: () {
                              try {
                                final amount = cents(initialAmount.text);
                                if (amount <= 0) {
                                  throw FormatException(
                                    context.tr('onboarding.031'),
                                  );
                                }
                                setState(() {
                                  initialEntries.add(
                                    Entry(
                                      id: const Uuid().v4(),
                                      date: dateKey(initialDate),
                                      type: 'expense',
                                      amount: amount,
                                      method: initialMethod,
                                      description: initialDescription.text
                                          .trim(),
                                    ),
                                  );
                                  initialAmount.text = '0.00';
                                  initialDescription.clear();
                                });
                              } catch (e) {
                                notice(context, e);
                              }
                            },
                            child: Text(context.tr('onboarding.032')),
                          ),
                        ],
                        if (initialEntries.isNotEmpty) ...[
                          const SizedBox(height: 20),
                          Text(
                            context.tr('onboarding.records'),
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 8),
                          _recordsTable(),
                        ],
                        if (!showPdf) ...[
                          const SizedBox(height: 16),
                          OutlinedButton.icon(
                            onPressed: () => setState(() => showPdf = true),
                            icon: const Icon(Icons.upload_file),
                            label: Text(context.tr('onboarding.027')),
                          ),
                        ],
                        if (!showPdf && initialEntries.isEmpty) ...[
                          const SizedBox(height: 12),
                          Text(
                            context.tr('onboarding.033'),
                            style: const TextStyle(color: Colors.deepOrange),
                          ),
                        ],
                      ],
                      if (step == 5) ...[
                        SwitchListTile(
                          title: Text(context.tr('onboarding.034')),
                          subtitle: Text(context.tr('onboarding.035')),
                          value: reminder,
                          onChanged: (v) => setState(() => reminder = v),
                        ),
                        ListTile(
                          title: Text(context.tr('onboarding.036')),
                          trailing: Text(
                            TimeOfDay(
                              hour: reminderMinute ~/ 60,
                              minute: reminderMinute % 60,
                            ).format(context),
                          ),
                          onTap: () async {
                            final time = await showTimePicker(
                              context: context,
                              initialTime: TimeOfDay(
                                hour: reminderMinute ~/ 60,
                                minute: reminderMinute % 60,
                              ),
                            );
                            if (time != null) {
                              setState(
                                () => reminderMinute =
                                    time.hour * 60 + time.minute,
                              );
                            }
                          },
                        ),
                        for (final text in [
                          context.tr('onboarding.037'),
                          context.tr('onboarding.038'),
                          context.tr('onboarding.039'),
                          context.tr('onboarding.040'),
                          context.tr('onboarding.041'),
                          context.tr('onboarding.042'),
                        ])
                          ListTile(
                            leading: const Icon(Icons.check_circle_outline),
                            title: Text(text),
                          ),
                      ],
                    ],
                  ),
                ),
                if (step == 4 && _otherPaymentDate != null) ...[
                  const SizedBox(height: 16),
                  OtherPaymentReview(
                    date: _otherPaymentDate!,
                    endDate: _otherPaymentEndDate,
                    onYes: () => setState(() {
                      initialDate = _otherPaymentEndDate ?? _otherPaymentDate!;
                      _otherPaymentDate = null;
                      _otherPaymentEndDate = null;
                      showPdf = false;
                    }),
                    onNo: () => setState(() {
                      _otherPaymentDate = null;
                      _otherPaymentEndDate = null;
                    }),
                  ),
                ],
                const SizedBox(height: 24),
                if (step != 1)
                  FilledButton(
                    onPressed: busy ? null : next,
                    child: Text(
                      busy
                          ? context.tr('onboarding.043')
                          : step == 5
                          ? context.tr('onboarding.044')
                          : step == 4 && initialEntries.isEmpty
                          ? context.tr('onboarding.045')
                          : context.tr('onboarding.047'),
                    ),
                  ),
                if (step > 1)
                  TextButton(
                    onPressed: busy ? null : () => setState(() => step--),
                    child: Text(context.tr('onboarding.048')),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static const _recordColumns = <int, TableColumnWidth>{
    0: FixedColumnWidth(60),
    1: FlexColumnWidth(),
    2: FixedColumnWidth(84),
    3: FixedColumnWidth(40),
  };

  Widget _recordCell(Widget child) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
    child: child,
  );

  Widget _recordsTable() => Card(
    margin: EdgeInsets.zero,
    clipBehavior: Clip.antiAlias,
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ColoredBox(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          child: Table(
            columnWidths: _recordColumns,
            children: [
              TableRow(
                children: [
                  _recordCell(
                    Text(
                      context.tr('records.date'),
                      style: Theme.of(context).textTheme.labelMedium,
                    ),
                  ),
                  _recordCell(
                    Text(
                      context.tr('records.details'),
                      style: Theme.of(context).textTheme.labelMedium,
                    ),
                  ),
                  _recordCell(
                    Text(
                      context.tr('transaction_form.006'),
                      textAlign: TextAlign.right,
                      style: Theme.of(context).textTheme.labelMedium,
                    ),
                  ),
                  const SizedBox.shrink(),
                ],
              ),
            ],
          ),
        ),
        ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 340),
          child: Scrollbar(
            controller: _recordsScroll,
            thumbVisibility: true,
            child: SingleChildScrollView(
              controller: _recordsScroll,
              primary: false,
              scrollDirection: Axis.vertical,
              child: Table(
                columnWidths: _recordColumns,
                defaultVerticalAlignment: TableCellVerticalAlignment.middle,
                border: TableBorder(
                  horizontalInside: BorderSide(
                    color: Theme.of(context).dividerColor.withValues(alpha: .3),
                  ),
                ),
                children: initialEntries.map((entry) {
                  final date = DateTime.parse(entry.date);
                  final shortDate =
                      '${date.day.toString().padLeft(2, '0')}/'
                      '${date.month.toString().padLeft(2, '0')}\n${date.year}';
                  return TableRow(
                    key: ValueKey(entry.id),
                    children: [
                      _recordCell(
                        Tooltip(
                          message: entry.date,
                          child: Text(
                            shortDate,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ),
                      ),
                      _recordCell(
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              paymentLabel(entry.method),
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 12,
                              ),
                            ),
                            if (entry.description.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text(
                                entry.description,
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ],
                          ],
                        ),
                      ),
                      _recordCell(
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerRight,
                          child: Text(
                            money(entry.amount),
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: context.tr('history.003'),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints.tightFor(
                          width: 40,
                          height: 48,
                        ),
                        style: IconButton.styleFrom(
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        icon: const Icon(Icons.delete_outline, size: 18),
                        onPressed: () =>
                            setState(() => initialEntries.remove(entry)),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ),
          ),
        ),
      ],
    ),
  );
}
