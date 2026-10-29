import '../../core/localization/context.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../app/state.dart';
import '../../app/widgets.dart';
import '../../core/services/nightly_reminder.dart';

class ReminderSettings extends ConsumerStatefulWidget {
  const ReminderSettings({super.key});
  @override
  ConsumerState<ReminderSettings> createState() => _ReminderSettingsState();
}

class _ReminderSettingsState extends ConsumerState<ReminderSettings> {
  bool busy = false;
  String? status;
  Future<void> save(bool enabled, int minute) async {
    setState(() => busy = true);
    try {
      final scheduled = await NightlyReminder.instance.configure(
        enabled: enabled,
        minute: minute,
        requestPermission: enabled,
      );
      await ref
          .read(ledgerProvider.notifier)
          .change(
            (l) => l.profile!.addAll({
              'reminderEnabled': enabled,
              'reminderMinute': minute,
              'nativeReminderScheduled': scheduled,
            }),
          );
      if (mounted) {
        setState(
          () => status = !enabled
              ? 'reminder_settings.001'
              : scheduled
              ? 'reminder_settings.002'
              : NightlyReminder.instance.supported
              ? 'reminder_settings.003'
              : 'reminder_settings.004',
        );
      }
    } catch (_) {
      if (mounted) notice(context, context.tr('reminder_settings.005'));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = ref.watch(ledgerProvider).requireValue.profile!;
    final enabled = p['reminderEnabled'] == true;
    final minute = p['reminderMinute'] as int? ?? 1260;
    return Card(
      child: Column(
        children: [
          SwitchListTile(
            title: Text(context.tr('reminder_settings.006')),
            subtitle: Text(
              status != null
                  ? context.tr(status!)
                  : (NightlyReminder.instance.supported
                        ? context.tr('reminder_settings.007')
                        : context.tr('reminder_settings.008')),
            ),
            value: enabled,
            onChanged: busy ? null : (v) => save(v, minute),
          ),
          ListTile(
            title: Text(context.tr('reminder_settings.009')),
            trailing: Text(
              '${(minute ~/ 60).toString().padLeft(2, '0')}:${(minute % 60).toString().padLeft(2, '0')}',
            ),
            onTap: busy
                ? null
                : () async {
                    final t = await showTimePicker(
                      context: context,
                      initialTime: TimeOfDay(
                        hour: minute ~/ 60,
                        minute: minute % 60,
                      ),
                    );
                    if (t != null) await save(enabled, t.hour * 60 + t.minute);
                  },
          ),
          if (busy) const LinearProgressIndicator(),
        ],
      ),
    );
  }
}
