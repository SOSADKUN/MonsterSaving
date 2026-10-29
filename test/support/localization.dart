import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saving_monster/core/localization/strings.dart';

Future<void> loadTestTranslations() async {
  TestWidgetsFlutterBinding.ensureInitialized();
  await AppStrings.load(rootBundle.loadString);
  AppStrings.language = 'en';
}
