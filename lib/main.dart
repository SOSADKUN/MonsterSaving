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
import 'features/startup/startup_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppStrings.load(rootBundle.loadString);
  final database = AppDatabase();
  runApp(_Startup(database: database));
}

class _Startup extends StatefulWidget {
  const _Startup({required this.database});
  final AppDatabase database;

  @override
  State<_Startup> createState() => _StartupState();
}

class _StartupState extends State<_Startup> {
  bool ready = false;

  @override
  void initState() {
    super.initState();
    _prepare();
  }

  Future<void> _prepare() async {
    final minimumDisplay = Future<void>.delayed(const Duration(milliseconds: 900));
    try {
      AppStrings.language = (await widget.database.load()).language;
    } catch (_) {
      // The app's storage error screen offers retry without resetting data.
    }
    if (!mounted) return;
    setState(() {});
    await minimumDisplay;
    if (mounted) setState(() => ready = true);
  }

  @override
  Widget build(BuildContext context) {
    if (ready) {
      return ProviderScope(
        overrides: [databaseProvider.overrideWithValue(widget.database)],
        child: const SavingMonster(),
      );
    }
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: monsterTheme(),
      home: StartupScreen(key: ValueKey(AppStrings.language)),
    );
  }
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
