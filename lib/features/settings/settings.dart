import '../../core/localization/context.dart';
import 'dart:convert';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../app/state.dart';
import '../../app/widgets.dart';
import '../../core/models/ledger.dart';
import '../../core/services/finance.dart';
import '../../core/services/tng_phone.dart';
import '../../core/services/nightly_reminder.dart';
import '../import/tng_phone_setup.dart';
import 'reminder_settings.dart';
import 'language_setting.dart';

class SettingsPanel extends ConsumerStatefulWidget {
  final VoidCallback onHistory, onSalary;
  const SettingsPanel({
    super.key,
    required this.onHistory,
    required this.onSalary,
  });
  @override
  ConsumerState<SettingsPanel> createState() => _SettingsPanelState();
}

class _SettingsPanelState extends ConsumerState<SettingsPanel> {
  final form = GlobalKey<FormState>();
  late TextEditingController salary, payday, target, goal, saved;
  bool busy = false;
  @override
  void initState() {
    super.initState();
    final p = ref.read(ledgerProvider).requireValue.profile!;
    String number(int n) =>
        '${n ~/ 100}.${(n % 100).toString().padLeft(2, '0')}';
    salary = TextEditingController(text: number(p['salary']));
    payday = TextEditingController(text: '${p['payday']}');
    target = TextEditingController(text: number(p['target']));
    goal = TextEditingController(text: number(p['goal']));
    saved = TextEditingController(text: number(p['saved']));
  }

  @override
  void dispose() {
    for (final c in [salary, payday, target, goal, saved]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> run(Future<void> Function() action) async {
    setState(() => busy = true);
    try {
      await action();
    } catch (e) {
      if (mounted) {
        notice(context, context.tr('settings.001', {'p0': e}));
      }
    } finally {
      if (mounted) {
        setState(() => busy = false);
      }
    }
  }

  Future<void> save() async {
    if (!form.currentState!.validate()) {
      return;
    }
    final old = ref.read(ledgerProvider).requireValue;
    final next = cents(target.text);
    if (next != old.profile!['target']) {
      if (!await confirm(
        context,
        next < (old.profile!['target'] as int)
            ? context.tr('settings.002')
            : context.tr('settings.003'),
      )) {
        return;
      }
    }
    if (!mounted) {
      return;
    }
    if (cents(saved.text) != old.profile!['saved']) {
      if (!await confirm(context, context.tr('settings.004'))) {
        return;
      }
    }
    await run(() async {
      await ref.read(ledgerProvider.notifier).change((l) {
        final value = cents(saved.text);
        final balance = Finance.calculate(l, DateTime.now()).balance;
        if (value > 0 && value > balance) {
          throw FormatException(context.tr('settings.005'));
        }
        l.profile!.addAll({
          'salary': cents(salary.text),
          'payday': int.parse(payday.text),
          'target': next,
          'goal': cents(goal.text),
          'saved': value,
          'savedConfirmedAt': dateKey(DateTime.now()),
        });
      });
      if (mounted) {
        notice(context, context.tr('settings.006'));
      }
    });
  }

  Future<void> export() async => run(() async {
    final data = utf8.encode(
      jsonEncode(ref.read(ledgerProvider).requireValue.toJson()),
    );
    await FilePicker.platform.saveFile(
      dialogTitle: context.tr('settings.007'),
      fileName: 'saving-monster-${dateKey(DateTime.now())}.json',
      type: FileType.custom,
      allowedExtensions: ['json'],
      bytes: Uint8List.fromList(data),
    );
  });
  Future<void> restore() async => run(() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json'],
      withData: true,
    );
    if (result == null) {
      return;
    }
    final file = result.files.single;
    if (file.size > 10 * 1024 * 1024 || file.bytes == null) {
      throw FormatException(tr('settings.008'));
    }
    final restored = Ledger.decode(utf8.decode(file.bytes!));
    if (!mounted) {
      return;
    }
    if (!await confirm(
      context,
      context.tr('settings.009', {
        'p0': restored.entries.length,
        'p1': restored.exp,
      }),
    )) {
      return;
    }
    await ref.read(ledgerProvider.notifier).change((l) {
      l.profile = restored.profile;
      l.language = restored.language;
      l.hasHatched = restored.hasHatched;
      l.entries = restored.entries;
      l.achievements = restored.achievements;
      l.fingerprints = restored.fingerprints;
      l.inventory = restored.inventory;
      l.equipped = restored.equipped;
    });
    if (mounted) {
      final p = restored.profile;
      if (p != null) {
        String number(int n) =>
            '${n ~/ 100}.${(n % 100).toString().padLeft(2, '0')}';
        salary.text = number(p['salary']);
        payday.text = '${p['payday']}';
        target.text = number(p['target']);
        goal.text = number(p['goal']);
        saved.text = number(p['saved']);
      }
      notice(context, context.tr('settings.010'));
    }
  });
  @override
  Widget build(BuildContext context) => Form(
    key: form,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const LanguageSetting(),
        const TngPhoneSetup(),
        const ReminderSettings(),
        Text(
          context.tr('settings.011'),
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
        MoneyField(salary, context.tr('settings.012')),
        TextFormField(
          controller: payday,
          decoration: InputDecoration(labelText: context.tr('settings.013')),
          keyboardType: TextInputType.number,
          validator: (v) {
            final n = int.tryParse(v ?? '');
            return n == null || n < 1 || n > 31
                ? context.tr('settings.014')
                : null;
          },
        ),
        MoneyField(target, context.tr('settings.015')),
        MoneyField(goal, context.tr('settings.016')),
        MoneyField(saved, context.tr('settings.017')),
        Text(context.tr('settings.018')),
        FilledButton(
          onPressed: busy ? null : save,
          child: Text(context.tr('settings.019')),
        ),
        OutlinedButton(
          onPressed: busy ? null : widget.onSalary,
          child: Text(context.tr('settings.020')),
        ),
        OutlinedButton(
          onPressed: busy ? null : widget.onHistory,
          child: Text(context.tr('settings.021')),
        ),
        const Divider(),
        Text(context.tr('settings.022')),
        OutlinedButton.icon(
          onPressed: busy ? null : export,
          icon: const Icon(Icons.download),
          label: Text(context.tr('settings.023')),
        ),
        OutlinedButton.icon(
          onPressed: busy ? null : restore,
          icon: const Icon(Icons.upload),
          label: Text(context.tr('settings.024')),
        ),
        TextButton(
          onPressed: busy
              ? null
              : () async {
                  if (await confirm(context, context.tr('settings.025'))) {
                    await run(() async {
                      await TngPhone().clear();
                      await NightlyReminder.instance.configure(
                        enabled: false,
                        minute: 1260,
                      );
                      await ref.read(ledgerProvider.notifier).change((l) {
                        l.profile = null;
                        l.hasHatched = false;
                        l.entries.clear();
                        l.achievements.clear();
                        l.fingerprints.clear();
                        l.inventory.clear();
                        l.equipped = '';
                      });
                    });
                  }
                },
          child: Text(
            context.tr('settings.026'),
            style: TextStyle(color: Colors.red),
          ),
        ),
        ListTile(
          title: Text(context.tr('settings.027')),
          subtitle: Text(context.tr('settings.028')),
        ),
        if (busy) const LinearProgressIndicator(),
      ],
    ),
  );
}
