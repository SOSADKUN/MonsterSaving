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
  bool hidden = true;
  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    try {
      final n = await TngPhone().read();
      if (mounted) {
        if (!editing) phone.text = n ?? '';
        setState(() => configured = n != null);
      }
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
      final normalized = TngPhone.normalize(phone.text);
      await TngPhone().save(normalized);
      if (mounted) {
        phone.text = normalized;
        setState(() {
          configured = true;
          editing = false;
          hidden = true;
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
          const SizedBox(height: 16),
          TextField(
            controller: phone,
            keyboardType: TextInputType.phone,
            obscureText: hidden,
            readOnly: busy || (configured && !editing),
            autocorrect: false,
            enableSuggestions: false,
            onChanged: (_) {
              if (!editing) setState(() => editing = true);
            },
            decoration: InputDecoration(
              labelText: context.tr('tng_phone_setup.005'),
              hintText: context.tr('tng_phone_setup.005'),
              suffixIcon: IconButton(
                tooltip: context.tr(
                  hidden ? 'common.showValue' : 'common.hideValue',
                ),
                icon: Icon(
                  hidden
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                ),
                onPressed: () => setState(() => hidden = !hidden),
              ),
            ),
          ),
          const SizedBox(height: 12),
          if (!configured || editing)
            FilledButton(
              onPressed: busy ? null : save,
              child: Text(context.tr('tng_phone_setup.006')),
            )
          else
            Row(
              children: [
                Expanded(child: Text(context.tr('tng_phone_setup.007'))),
                TextButton(
                  onPressed: busy
                      ? null
                      : () => setState(() {
                          editing = true;
                          hidden = true;
                        }),
                  child: Text(context.tr('tng_phone_setup.008')),
                ),
                TextButton(
                  onPressed: busy
                      ? null
                      : () async {
                          try {
                            await TngPhone().clear();
                            if (mounted) {
                              phone.clear();
                              setState(() {
                                configured = false;
                                editing = false;
                                hidden = true;
                              });
                            }
                          } catch (e) {
                            if (context.mounted) notice(context, e);
                          }
                        },
                  child: Text(context.tr('tng_phone_setup.009')),
                ),
              ],
            ),
          const SizedBox(height: 8),
          Text(
            context.tr('tng_phone_setup.privacy'),
            style: const TextStyle(color: Colors.black, fontSize: 12),
          ),
        ],
      ),
    ),
  );
}
