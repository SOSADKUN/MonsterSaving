import 'package:flutter/material.dart';
import 'strings.dart';
export 'strings.dart';

extension TranslatedContext on BuildContext {
  String tr(String key, [Map<String, Object?> args = const {}]) {
    // Register a locale dependency while preserving widget and form state.
    Localizations.localeOf(this);
    return AppStrings.text(key, args);
  }
}
