import '../../core/localization/context.dart';
import 'package:flutter/material.dart';
import '../../app/widgets.dart';
import '../../core/services/tng_phone.dart';

class TngPhoneSetup extends StatefulWidget {
  final VoidCallback? onSaved;
  const TngPhoneSetup({super.key, this.onSaved});
  @override
  State<TngPhoneSetup> createState() => _TngPhoneSetupState();
}

class _TngPhoneSetupState extends State<TngPhoneSetup> {
  final phone = TextEditingController();
  bool busy = false, configured = false, editing = false;
  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    try {
      final n = await TngPhone().read();
      if (mounted) setState(() => configured = n != null);
    } catch (_) {
      if (mounted) notice(context, context.tr('tng_phone_setup.001'));
    }
  }

  @override
  void dispose() {
    phone.dispose();
    super.dispose();
  }

  Future<void> save() async {
    setState(() => busy = true);
    try {
      await TngPhone().save(phone.text);
      phone.clear();
      if (mounted) {
        setState(() {
          configured = true;
          editing = false;
        });
        widget.onSaved?.call();
        notice(context, context.tr('tng_phone_setup.002'));
      }
    } catch (e) {
      if (mounted) notice(context, e);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            context.tr('tng_phone_setup.003'),
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          Text(context.tr('tng_phone_setup.004')),
          if (!configured || editing) ...[
            const SizedBox(height: 12),
            TextField(
              controller: phone,
              keyboardType: TextInputType.phone,
              obscureText: true,
              autocorrect: false,
              enableSuggestions: false,
              decoration: InputDecoration(
                labelText: context.tr('tng_phone_setup.005'),
              ),
            ),
            FilledButton(
              onPressed: busy ? null : save,
              child: Text(context.tr('tng_phone_setup.006')),
            ),
          ] else
            Row(
              children: [
                Expanded(child: Text(context.tr('tng_phone_setup.007'))),
                TextButton(
                  onPressed: () => setState(() => editing = true),
                  child: Text(context.tr('tng_phone_setup.008')),
                ),
                TextButton(
                  onPressed: busy
                      ? null
                      : () async {
                          try {
                            await TngPhone().clear();
                            if (mounted) setState(() => configured = false);
                          } catch (e) {
                            if (context.mounted) notice(context, e);
                          }
                        },
                  child: Text(context.tr('tng_phone_setup.009')),
                ),
              ],
            ),
        ],
      ),
    ),
  );
}
