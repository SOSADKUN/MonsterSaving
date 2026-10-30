import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Manifest names are shared by the hatch, habitat and shop previews.
abstract final class CompanionCatalog {
  static List<String> manifests(String id) => id == 'hamster'
      ? const ['hamster_atlas']
      : const ['baby_atlas', 'baby_activities'];

  static final _portraits = <String, Future<Map<String, dynamic>>>{};
  static Future<Map<String, dynamic>> portrait(String id) =>
      _portraits.putIfAbsent(
        id,
        () async =>
            jsonDecode(
                  await rootBundle.loadString(
                    'assets/images/monster/${manifests(id).first}.json',
                  ),
                )
                as Map<String, dynamic>,
      );
}

/// Shows just the idle character crop, never the full reference/pose sheet.
class CompanionPortrait extends StatelessWidget {
  const CompanionPortrait({super.key, required this.companion});
  final String companion;

  @override
  Widget build(BuildContext context) => FutureBuilder<Map<String, dynamic>>(
    future: CompanionCatalog.portrait(companion),
    builder: (context, snapshot) {
      if (!snapshot.hasData) return const SizedBox.shrink();
      final data = snapshot.data!;
      final frame = data['frames']['idle'] as Map<String, dynamic>;
      return FittedBox(
        fit: BoxFit.contain,
        child: SizedBox(
          width: (frame['width'] as num).toDouble(),
          height: (frame['height'] as num).toDouble(),
          child: ClipRect(
            child: Stack(
              children: [
                Positioned(
                  left: -(frame['x'] as num).toDouble(),
                  top: -(frame['y'] as num).toDouble(),
                  width: (data['width'] as num).toDouble(),
                  height: (data['height'] as num).toDouble(),
                  child: Image.asset(
                    'assets/images/monster/${data['image']}',
                    fit: BoxFit.fill,
                    excludeFromSemantics: true,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}
