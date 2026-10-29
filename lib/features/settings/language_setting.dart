import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../app/state.dart';
import '../../app/widgets.dart';
import '../../core/localization/context.dart';

class LanguageSetting extends ConsumerStatefulWidget {
  const LanguageSetting({super.key});
  @override
  ConsumerState<LanguageSetting> createState() => _LanguageSettingState();
}

class _LanguageSettingState extends ConsumerState<LanguageSetting> {
  bool busy = false;
  int revision = 0;
  @override
  Widget build(BuildContext context) {
    final language = ref.watch(languageProvider);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: DropdownButtonFormField<String>(
          key: ValueKey((language, revision)),
          initialValue: language,
          isExpanded: true,
          decoration: InputDecoration(
            labelText: context.tr('language.label'),
            prefixIcon: const Icon(Icons.language),
          ),
          items: [
            DropdownMenuItem(
              value: 'en',
              child: Text(context.tr('language.english')),
            ),
            DropdownMenuItem(
              value: 'zh_CN',
              child: Text(context.tr('language.chinese')),
            ),
          ],
          onChanged: busy
              ? null
              : (code) async {
                  if (code == null || code == language) return;
                  setState(() => busy = true);
                  try {
                    await ref.read(languageProvider.notifier).select(code);
                  } catch (_) {
                    if (context.mounted) {
                      setState(() => revision++);
                      notice(context, context.tr('language.saveError'));
                    }
                  } finally {
                    if (mounted) setState(() => busy = false);
                  }
                },
        ),
      ),
    );
  }
}
