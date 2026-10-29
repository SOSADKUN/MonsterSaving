import 'hatch_screen.dart';
import '../../core/localization/context.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../import/import_panel.dart';
import '../import/tng_phone_setup.dart';
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
  bool busy = false;
  final form = GlobalKey<FormState>();
  final opening = TextEditingController(text: '0'),
      salary = TextEditingController(text: '0'),
      payday = TextEditingController(text: '25'),
      target = TextEditingController(text: '0'),
      goal = TextEditingController(text: '0');
  DateTime openingDate = day(DateTime.now()), lastSalary = day(DateTime.now());
  bool hasSalary = false;
  final initialAmount = TextEditingController(text: '0');
  final initialDescription = TextEditingController();
  final initialEntries = <Entry>[];
  DateTime initialDate = day(DateTime.now());
  String initialMethod = 'Cash';
  bool showPdf = false;
  bool reminder = true;
  int reminderMinute = 21 * 60;
  @override
  void initState() {
    super.initState();
    step = ref.read(ledgerProvider).requireValue.hasHatched ? 1 : 0;
  }

  @override
  void dispose() {
    for (final c in [
      opening,
      salary,
      payday,
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
          'payday': int.parse(payday.text),
          'lastSalary': hasSalary ? dateKey(lastSalary) : null,
          'target': cents(target.text),
          'goal': cents(goal.text),
          'saved': 0,
          'coverage': null,
          'reminderEnabled': reminder,
          'reminderMinute': reminderMinute,
          'nativeReminderScheduled': scheduled,
        };
        l.entries.addAll(initialEntries);
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
        onHatched: () => ref
            .read(ledgerProvider.notifier)
            .change((ledger) => ledger.hasHatched = true),
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
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: ListView(
              padding: const EdgeInsets.all(24),
              children: [
                const LanguageSetting(),
                Text(
                  'SAVING MONSTER',
                  style: Theme.of(context).textTheme.labelLarge,
                ),
                const SizedBox(height: 24),
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
                    children: [
                      if (step == 1) ...[
                        ListTile(
                          leading: Icon(Icons.person_outline),
                          title: Text(context.tr('onboarding.010')),
                          subtitle: Text(context.tr('onboarding.011')),
                        ),
                        FilledButton(
                          onPressed: null,
                          child: Text(context.tr('onboarding.012')),
                        ),
                        OutlinedButton(
                          onPressed: null,
                          child: Text(context.tr('onboarding.013')),
                        ),
                        Text(context.tr('onboarding.014')),
                      ],
                      if (step == 2) ...[
                        const TngPhoneSetup(),
                        MoneyField(opening, context.tr('onboarding.015')),
                        DateField(
                          value: openingDate,
                          onChanged: (d) => setState(() => openingDate = d),
                          label: context.tr('onboarding.016'),
                        ),
                        Text(context.tr('onboarding.017')),
                        MoneyField(salary, context.tr('onboarding.018')),
                        TextFormField(
                          controller: payday,
                          decoration: InputDecoration(
                            labelText: context.tr('onboarding.019'),
                          ),
                          keyboardType: TextInputType.number,
                          validator: (v) {
                            final p = int.tryParse(v ?? '');
                            return p == null || p < 1 || p > 31
                                ? context.tr('onboarding.020')
                                : null;
                          },
                        ),
                        SwitchListTile(
                          title: Text(context.tr('onboarding.021')),
                          value: hasSalary,
                          onChanged: (v) => setState(() => hasSalary = v),
                        ),
                        if (hasSalary)
                          DateField(
                            value: lastSalary,
                            onChanged: (d) => setState(() => lastSalary = d),
                            label: context.tr('onboarding.022'),
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
                        OutlinedButton(
                          onPressed: () => setState(() => showPdf = !showPdf),
                          child: Text(context.tr('onboarding.027')),
                        ),
                        if (showPdf)
                          ImportPanel(
                            pendingEntries: initialEntries,
                            openingDate: openingDate,
                            onStagedImport: (entries) =>
                                setState(() => initialEntries.addAll(entries)),
                            onOtherSpending: (date) => setState(() {
                              showPdf = false;
                              initialDate = date;
                            }),
                            onManual: () => setState(() => showPdf = false),
                            onCancel: () => setState(() => showPdf = false),
                          ),
                        MoneyField(initialAmount, context.tr('onboarding.028')),
                        DateField(
                          value: initialDate,
                          onChanged: (d) => setState(() => initialDate = d),
                          label: context.tr('onboarding.029'),
                        ),
                        DropdownButtonFormField<String>(
                          initialValue: initialMethod,
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
                          onChanged: (s) => initialMethod = s!,
                        ),
                        TextFormField(
                          controller: initialDescription,
                          decoration: InputDecoration(
                            labelText: context.tr('onboarding.030'),
                          ),
                        ),
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
                                    description: initialDescription.text.trim(),
                                  ),
                                );
                                initialAmount.text = '0';
                                initialDescription.clear();
                              });
                            } catch (e) {
                              notice(context, e);
                            }
                          },
                          child: Text(context.tr('onboarding.032')),
                        ),
                        for (final e in initialEntries)
                          ListTile(
                            title: Text('${e.date} · ${money(e.amount)}'),
                            trailing: IconButton(
                              onPressed: () =>
                                  setState(() => initialEntries.remove(e)),
                              icon: const Icon(Icons.close),
                            ),
                          ),
                        Text(
                          context.tr('onboarding.033'),
                          style: TextStyle(color: Colors.deepOrange),
                        ),
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
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: busy ? null : next,
                  child: Text(
                    busy
                        ? context.tr('onboarding.043')
                        : step == 5
                        ? context.tr('onboarding.044')
                        : step == 4
                        ? context.tr('onboarding.045')
                        : step == 1
                        ? context.tr('onboarding.046')
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
}
