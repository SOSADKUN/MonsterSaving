import '../core/localization/context.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'state.dart';
import 'widgets.dart';
import '../core/models/ledger.dart';
import '../core/services/finance.dart';
import '../core/services/nightly_reminder.dart';
import '../features/onboarding/onboarding.dart';
import '../features/startup/startup_screen.dart';
import '../features/monster/monster_habitat.dart';
import '../features/transactions/transaction_form.dart';
import '../features/transactions/salary_receipt_sheet.dart';
import '../features/transactions/history.dart';
import '../features/import/import_panel.dart';
import '../features/settings/settings.dart';
import '../features/shop/shop.dart';

class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key});
  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell>
    with WidgetsBindingObserver {
  String tab = 'home';
  String? form;
  Entry? editing;
  bool daily = true;
  Timer? timer;
  DateTime? recordingDate;
  bool otherQuestion = false;
  bool _dismissingCoverage = false;

  Future<void> _dismissCoverage(DateTime cycle) async {
    if (_dismissingCoverage) return;
    setState(() => _dismissingCoverage = true);
    try {
      await ref.read(ledgerProvider.notifier).change((ledger) {
        ledger.profile!['coverageNoticeDismissedFor'] = dateKey(cycle);
      });
    } catch (error) {
      if (mounted) notice(context, error);
    } finally {
      if (mounted) setState(() => _dismissingCoverage = false);
    }
  }

  void notificationOpened() {
    if (mounted) {
      setState(() {
        tab = 'home';
        form = 'pdf';
        otherQuestion = false;
      });
    }
  }

  void otherSpending(DateTime date) => setState(() {
    tab = 'home';
    form = 'expense';
    recordingDate = date;
    editing = null;
    otherQuestion = false;
  });
  Future<void> finishRecording() async {
    try {
      await ref.read(ledgerProvider.notifier).change((l) {
        final dates = Set<String>.from(l.profile!['recordedDays'] ?? []);
        dates.add(dateKey(recordingDate!));
        l.profile!['recordedDays'] = dates.toList();
      });
      done();
    } catch (_) {
      if (mounted) notice(context, context.tr('shell.001'));
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    NightlyReminder.instance.opened.addListener(notificationOpened);
    timer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    NightlyReminder.instance.opened.removeListener(notificationOpened);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      setState(() {});
    }
  }

  void done() => setState(() {
    form = null;
    editing = null;
    recordingDate = null;
    otherQuestion = false;
  });
  Future<void> add() async {
    final value = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (c) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final item in [
              ('expense', context.tr('shell.002'), Icons.receipt_long),
              ('pdf', context.tr('common.tngPdf'), Icons.picture_as_pdf),
              ('income', context.tr('shell.003'), Icons.add_card),
              ('refund', context.tr('shell.004'), Icons.undo),
            ])
              ListTile(
                leading: Icon(item.$3),
                title: Text(item.$2),
                onTap: () => Navigator.pop(c, item.$1),
              ),
          ],
        ),
      ),
    );
    if (value != null) {
      setState(() {
        tab = 'home';
        form = value;
        editing = null;
        recordingDate = null;
        otherQuestion = false;
      });
    }
  }

  Widget tile(String title, int value) => Expanded(
    child: Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title),
            const SizedBox(height: 8),
            FittedBox(
              child: Text(
                money(value),
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 23,
                  color: value < 0
                      ? Colors.red.shade800
                      : const Color(0xff293a22),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
  @override
  Widget build(BuildContext context) {
    ref.listen(ledgerProvider, (previous, next) {
      final p = next.asData?.value.profile;
      if (p != null) {
        final before = previous?.asData?.value.profile;
        if ((before == null && p['reminderEnabled'] == true) ||
            (before != null &&
                (before['reminderEnabled'] != p['reminderEnabled'] ||
                    before['reminderMinute'] != p['reminderMinute']))) {
          NightlyReminder.instance
              .configure(
                enabled: p['reminderEnabled'] == true,
                minute: p['reminderMinute'] as int? ?? 1260,
              )
              .catchError((_) => false);
        }
      }
    });
    final state = ref.watch(ledgerProvider);
    return state.when(
      loading: () => const StartupScreen(),
      error: (e, st) => Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(context.tr('shell.005')),
                FilledButton(
                  onPressed: () => ref.invalidate(ledgerProvider),
                  child: Text(context.tr('shell.006')),
                ),
              ],
            ),
          ),
        ),
      ),
      data: (l) {
        if (l.profile == null) {
          return const Onboarding();
        }
        final f = Finance.calculate(l, DateTime.now());
        final p = l.profile!;
        final coverage = p['coverage'] as String?;
        final salaryDue =
            (p['salary'] as int) > 0 &&
            (p['lastSalary'] == null ||
                (p['lastSalary'] as String).compareTo(dateKey(f.start)) < 0 ||
                (p['lastSalary'] as String).compareTo(dateKey(f.end)) >= 0) &&
            !l.entries.any(
              (e) =>
                  e.type == 'salary' &&
                  e.date.compareTo(dateKey(f.start)) >= 0 &&
                  e.date.compareTo(dateKey(f.end)) < 0,
            );
        Widget content;
        if (tab == 'settings') {
          content = SettingsPanel(
            salaryPending: salaryDue,
            onHistory: () => setState(() => tab = 'history'),
            onSalary: () => showSalaryReceiptSheet(context),
          );
        } else if (tab == 'shop') {
          content = const ShopPanel();
        } else if (tab == 'history') {
          content = HistoryPanel(
            onEdit: (e) => setState(() {
              tab = 'home';
              form = e.type;
              editing = e;
            }),
          );
        } else {
          content = Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      dateKey(DateTime.now()),
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  IconButton(
                    tooltip: context.tr('shell.007'),
                    onPressed: () => setState(() => tab = 'history'),
                    icon: const Icon(Icons.history),
                  ),
                  IconButton(
                    tooltip: salaryDue
                        ? '${context.tr('shell.008')} · ${context.tr('salary.pending')}'
                        : context.tr('shell.008'),
                    onPressed: () => setState(() => tab = 'settings'),
                    icon: Badge(
                      isLabelVisible: salaryDue,
                      backgroundColor: Colors.red,
                      child: const Icon(Icons.settings_outlined),
                    ),
                  ),
                ],
              ),
              Text(
                context.tr('shell.009'),
                style: TextStyle(fontSize: 23, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              if ((p['reminderEnabled'] ?? true) == true &&
                  DateTime.now().hour * 60 + DateTime.now().minute >=
                      (p['reminderMinute'] as int? ?? 1260) &&
                  !List<String>.from(
                    p['recordedDays'] ?? [],
                  ).contains(dateKey(DateTime.now())))
                Card(
                  color: const Color(0xffffefcc),
                  child: ListTile(
                    leading: const Icon(Icons.nightlight_round),
                    title: Text(context.tr('shell.010')),
                    subtitle: Text(context.tr('shell.011')),
                    trailing: TextButton(
                      onPressed: notificationOpened,
                      child: Text(context.tr('shell.012')),
                    ),
                  ),
                ),
              ClipRRect(
                borderRadius: BorderRadius.circular(30),
                child: SizedBox(
                  height: 300,
                  child: MonsterHabitat(
                    key: ValueKey(l.activeCompanion),
                    companion: l.activeCompanion,
                    stage: l.stage,
                    equipped: l.equipped,
                    worried: f.available < 0,
                    background: l.background,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(10),
                child: Text(
                  f.available < 0
                      ? context.tr('shell.013')
                      : context.tr('shell.014'),
                  textAlign: TextAlign.center,
                ),
              ),
              Row(
                children: [
                  Flexible(
                    flex: 2,
                    child: Text(
                      context.tr('shell.015', {
                        'p0': [
                          context.tr('shell.016'),
                          context.tr('shell.017'),
                          context.tr('shell.018'),
                          context.tr('shell.019'),
                        ][l.stage],
                        'p1': l.level,
                      }),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: LinearProgressIndicator(value: (l.exp % 100) / 100),
                  ),
                  Flexible(
                    child: Text(
                      context.tr('common.exp', {'value': l.exp % 100}),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (otherQuestion)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        Text(
                          context.tr('shell.026', {
                            'p0': dateKey(recordingDate!),
                          }),
                        ),
                        FilledButton(
                          onPressed: () => otherSpending(recordingDate!),
                          child: Text(context.tr('shell.027')),
                        ),
                        OutlinedButton(
                          onPressed: finishRecording,
                          child: Text(context.tr('shell.028')),
                        ),
                      ],
                    ),
                  ),
                )
              else if (form == 'pdf')
                ImportPanel(
                  onManual: () => otherSpending(day(DateTime.now())),
                  onOtherSpending: otherSpending,
                  onCancel: done,
                )
              else if (form != null)
                TransactionForm(
                  key: ValueKey('${form}_${editing?.id}'),
                  type: form!,
                  entry: editing,
                  initialDate: recordingDate,
                  onDone: recordingDate == null
                      ? done
                      : () => setState(() {
                          form = null;
                          otherQuestion = true;
                        }),
                )
              else ...[
                Row(
                  children: [
                    tile(context.tr('shell.029'), f.balance),
                    tile(context.tr('shell.030'), f.income),
                  ],
                ),
                Row(
                  children: [
                    tile(context.tr('shell.031'), f.spending),
                    tile(context.tr('shell.032'), p['target']),
                  ],
                ),
                Card(
                  color: const Color(0xffd5eabf),
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        Text(
                          context.tr('common.availableToSpend'),
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 8),
                        SegmentedButton<bool>(
                          segments: [
                            ButtonSegment(
                              value: true,
                              label: Text(context.tr('shell.033')),
                            ),
                            ButtonSegment(
                              value: false,
                              label: Text(context.tr('shell.034')),
                            ),
                          ],
                          selected: {daily},
                          onSelectionChanged: (v) =>
                              setState(() => daily = v.first),
                        ),
                        const SizedBox(height: 14),
                        Text(
                          money(daily ? f.daily : f.available),
                          style: TextStyle(
                            fontSize: 36,
                            fontWeight: FontWeight.bold,
                            color: f.available < 0
                                ? Colors.red.shade800
                                : const Color(0xff293a22),
                          ),
                        ),
                        Text(
                          context.tr('shell.035', {
                            'p0': dateKey(f.start),
                            'p1': dateKey(
                              f.end.subtract(const Duration(days: 1)),
                            ),
                            'p2': f.remainingDays,
                          }),
                        ),
                        Text(
                          context.tr('shell.036', {'p0': money(f.reserve)}),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.savings_outlined),
                    title: Text(
                      context.tr('shell.037', {'p0': money(p['saved'])}),
                    ),
                    subtitle: Text(
                      (p['goal'] as int) > 0
                          ? context.tr('shell.038', {'p0': money(p['goal'])})
                          : context.tr('shell.039'),
                    ),
                  ),
                ),
              ],
              if (form == null &&
                  !otherQuestion &&
                  (coverage == null ||
                      coverage.compareTo(dateKey(DateTime.now())) < 0) &&
                  p['coverageNoticeDismissedFor'] != dateKey(f.start))
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Card(
                    color: const Color(0xffffefcc),
                    child: ListTile(
                      leading: const Icon(Icons.info_outline),
                      title: Text(context.tr('shell.023')),
                      subtitle: Text(context.tr('shell.024')),
                      trailing: IconButton(
                        tooltip: context.tr('common.dismiss'),
                        icon: const Icon(Icons.close),
                        onPressed: _dismissingCoverage
                            ? null
                            : () => _dismissCoverage(f.start),
                      ),
                    ),
                  ),
                ),
            ],
          );
        }
        return Scaffold(
          appBar: tab == 'home'
              ? null
              : AppBar(
                  title: Text(
                    {
                      'shop': context.tr('shell.040'),
                      'settings': context.tr('shell.041'),
                      'history': context.tr('shell.042'),
                    }[tab]!,
                  ),
                  leading: IconButton(
                    onPressed: () => setState(() => tab = 'home'),
                    icon: const Icon(Icons.arrow_back),
                  ),
                ),
          body: SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 620),
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [content],
                ),
              ),
            ),
          ),
          bottomNavigationBar: SafeArea(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                TextButton.icon(
                  onPressed: () => setState(() => tab = 'home'),
                  icon: const Icon(Icons.home_rounded),
                  label: Text(context.tr('shell.043')),
                ),
                Padding(
                  padding: const EdgeInsets.all(8),
                  child: FloatingActionButton(
                    onPressed: add,
                    tooltip: context.tr('shell.044'),
                    child: const Icon(Icons.add, size: 32),
                  ),
                ),
                TextButton.icon(
                  onPressed: () => setState(() => tab = 'shop'),
                  icon: const Icon(Icons.storefront),
                  label: Text(context.tr('shell.045')),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
