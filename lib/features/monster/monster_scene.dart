import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import '../../core/localization/context.dart';
import 'monster_game.dart';

class MonsterScene extends StatelessWidget {
  const MonsterScene({super.key, required this.game});
  final MonsterGame game;
  @override
  Widget build(BuildContext context) => Semantics(
    label: context.tr('monster.tap'),
    button: true,
    onTap: game.react,
    child: GameWidget(
      game: game,
      loadingBuilder: (_) => const Center(child: CircularProgressIndicator()),
      errorBuilder: (context, _) => Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Text(
            context.tr('monster.loadError'),
            textAlign: TextAlign.center,
          ),
        ),
      ),
    ),
  );
}
