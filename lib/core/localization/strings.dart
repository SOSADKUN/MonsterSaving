import 'dart:convert';

/// Editable messages live in assets/i18n/en.json and zh_CN.json.
/// Kept independent of Flutter so ledger/parser errors can also be localized.
class AppStrings {
  static const supported = ['en', 'zh_CN'];
  static String language = 'en';
  static final Map<String, Map<String, String>> catalogs = {};
  static Future<void> load(Future<String> Function(String path) loader) async {
    for (final code in supported) {
      final data =
          jsonDecode(await loader('assets/i18n/$code.json'))
              as Map<String, dynamic>;
      catalogs[code] = data.map((key, value) => MapEntry(key, value as String));
    }
  }

  static String text(String key, [Map<String, Object?> args = const {}]) {
    final template = catalogs[language]?[key] ?? catalogs['en']?[key] ?? key;
    return template.replaceAllMapped(
      RegExp(r'\{([A-Za-z0-9_]+)\}'),
      (match) =>
          args.containsKey(match[1]) ? _value(args[match[1]]) : match[0]!,
    );
  }

  static String _value(Object? value) {
    if (value is FormatException) return value.message;
    if (value is StateError) return value.message;
    if (value is Error || value is Exception) {
      return text('common.unexpectedError');
    }
    return '$value';
  }
}

String tr(String key, [Map<String, Object?> args = const {}]) =>
    AppStrings.text(key, args);
String paymentLabel(String method) =>
    AppStrings.catalogs[AppStrings.language]?.containsKey('payment.$method') ==
        true
    ? tr('payment.$method')
    : method;
String typeLabel(String type) =>
    AppStrings.catalogs[AppStrings.language]?.containsKey('type.$type') == true
    ? tr('type.$type')
    : type;
String sourceLabel(String source) =>
    AppStrings.catalogs[AppStrings.language]?.containsKey('source.$source') ==
        true
    ? tr('source.$source')
    : source;
String tngLabel(String value) =>
    AppStrings.catalogs[AppStrings.language]?.containsKey('tng.$value') == true
    ? tr('tng.$value')
    : value;
String errorMessage(Object value) => AppStrings._value(value);
