import 'core/localization/strings.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:go_router/go_router.dart';
import 'app/shell.dart';
import 'core/theme/theme.dart';
import 'package:flutter/services.dart';
import 'app/state.dart';
import 'core/database/database.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppStrings.load(rootBundle.loadString);
  final database = AppDatabase();
  try {
    AppStrings.language = (await database.load()).language;
  } catch (_) {
    // The app's existing storage error screen offers retry without resetting data.
  }
  runApp(
    ProviderScope(
      overrides: [databaseProvider.overrideWithValue(database)],
      child: const SavingMonster(),
    ),
  );
}

final router = GoRouter(
  routes: [GoRoute(path: '/', builder: (_, state) => const AppShell())],
);

class SavingMonster extends ConsumerWidget {
  const SavingMonster({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final language = ref.watch(languageProvider);
    return MaterialApp.router(
      title: tr('main.001'),
      theme: monsterTheme(),
      routerConfig: router,
      locale: language == 'en' ? const Locale('en') : const Locale('zh', 'CN'),
      supportedLocales: const [Locale('en'), Locale('zh', 'CN')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
    );
  }
}
