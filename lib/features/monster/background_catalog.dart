import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/localization/strings.dart';

class HabitatBackground {
  const HabitatBackground({
    required this.id,
    required this.names,
    required this.price,
    this.asset,
    this.colors = const [Color(0xffdcefe3), Color(0xfff2f6da)],
  });

  final String id;
  final Map<String, String> names;
  final int price;
  final String? asset;
  final List<Color> colors;
  String get name =>
      names[AppStrings.language] ??
      names['en'] ??
      tr(id == 'meadow' ? 'background.meadow' : 'background.untitled');

  static const defaultAsset = 'assets/videos/background.png';
  static const meadow = HabitatBackground(
    id: 'meadow',
    names: {},
    price: 0,
    asset: defaultAsset,
  );
}

class BackgroundCatalog {
  static Future<List<HabitatBackground>>? _pending;
  static Future<List<HabitatBackground>> load() => _pending ??= _load();

  static Future<List<HabitatBackground>> _load() async {
    final data =
        jsonDecode(
              await rootBundle.loadString('assets/backgrounds/catalog.json'),
            )
            as Map<String, dynamic>;
    final result = <HabitatBackground>[];
    final ids = <String>{};
    final bundledAssets = (await AssetManifest.loadFromAssetBundle(
      rootBundle,
    )).listAssets().toSet();
    for (final raw in data['items'] as List) {
      final item = raw as Map<String, dynamic>;
      final id = item['id'] as String;
      final price = item['price'] as int;
      final asset = item['asset'] as String?;
      if (!RegExp(r'^[a-z][a-z0-9_-]{0,63}$').hasMatch(id) ||
          !ids.add(id) ||
          price < 0 ||
          price > 999999 ||
          (id == 'meadow' && price != 0) ||
          (asset != null &&
              ((!asset.startsWith('assets/backgrounds/') &&
                      asset != HabitatBackground.defaultAsset) ||
                  asset.contains('..')))) {
        throw const FormatException('Invalid background catalog entry');
      }
      // Do not sell an image that has not been bundled with the app yet.
      if (asset != null && !bundledAssets.contains(asset)) continue;
      final colors = (item['colors'] as List?)
          ?.map(
            (hex) => Color(0xff000000 | int.parse(hex as String, radix: 16)),
          )
          .toList();
      result.add(
        HabitatBackground(
          id: id,
          names: Map<String, String>.from(item['name'] as Map),
          price: price,
          asset: asset,
          colors: colors != null && colors.length >= 2
              ? colors
              : HabitatBackground.meadow.colors,
        ),
      );
    }
    if (!result.any((item) => item.id == 'meadow')) {
      result.insert(0, HabitatBackground.meadow);
    }
    return List.unmodifiable(result);
  }
}

class HabitatBackdrop extends StatelessWidget {
  const HabitatBackdrop({super.key, required this.background});
  final HabitatBackground background;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: background.colors,
      ),
    ),
    child: background.asset == null
        ? const SizedBox.expand()
        : Image.asset(
            background.asset!,
            fit: BoxFit.cover,
            width: double.infinity,
            height: double.infinity,
            errorBuilder: (_, _, _) => const SizedBox.expand(),
          ),
  );
}
