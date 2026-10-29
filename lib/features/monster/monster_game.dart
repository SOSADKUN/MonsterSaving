import 'dart:convert';
import 'dart:math';
import 'dart:ui';
import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame/game.dart';

enum BabyMood { idle, happy, sad }

/// All character artwork comes from the transparent official-reference atlas.
/// Primitive components below are only scenery, evolution accents and shop props.
class MonsterGame extends FlameGame with TapCallbacks {
  MonsterGame({this.transparentBackground = false, this.onReady});
  final bool transparentBackground;
  final void Function()? onReady;
  int stage = 0;
  String equipped = '';
  bool worried = false;
  double clock = 0, reaction = 0;
  late final PositionComponent _character;
  late final SpriteComponent _body;
  late final CircleComponent _shadow, _aura;
  late final List<Sprite> _poses;
  final Map<String, PositionComponent> _equipment = {};
  final List<PolygonComponent> _stars = [];
  bool _ready = false;
  BabyMood get mood => reaction > 0
      ? BabyMood.happy
      : worried
      ? BabyMood.sad
      : BabyMood.idle;
  bool get spriteReady => _ready;

  @override
  Color backgroundColor() =>
      transparentBackground ? const Color(0x00000000) : const Color(0xffe9f4df);

  @override
  Future<void> onLoad() async {
    final manifest =
        jsonDecode(
              await images.bundle.loadString(
                'assets/images/monster/baby_atlas.json',
              ),
            )
            as Map<String, dynamic>;
    final atlas = await images.load('monster/${manifest['image']}');
    if (atlas.width != manifest['width'] ||
        atlas.height != manifest['height']) {
      throw StateError('Sprite dimensions do not match their manifest.');
    }
    // Measured alpha bounds keep the entire tail, horns and sprout intact.
    final frames = manifest['frames'] as Map<String, dynamic>;
    _poses = BabyMood.values.map((mood) {
      final frame = frames[mood.name] as Map<String, dynamic>;
      final x = (frame['x'] as num).toDouble(),
          y = (frame['y'] as num).toDouble();
      final w = (frame['width'] as num).toDouble(),
          h = (frame['height'] as num).toDouble();
      if (x < 0 ||
          y < 0 ||
          w <= 0 ||
          h <= 0 ||
          x + w > atlas.width ||
          y + h > atlas.height) {
        throw StateError('Invalid sprite frame bounds.');
      }
      return Sprite(atlas, srcPosition: Vector2(x, y), srcSize: Vector2(w, h));
    }).toList();
    _shadow = CircleComponent(
      radius: 85,
      anchor: Anchor.center,
      paint: Paint()..color = const Color(0x18608a55),
    )..scale = Vector2(1, .12);
    _aura = CircleComponent(
      radius: 118,
      anchor: Anchor.center,
      paint: Paint()
        ..color = const Color(0x00000000)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3,
    );
    _character = PositionComponent(
      anchor: Anchor.center,
      size: Vector2.all(256),
    );
    _body = SpriteComponent(
      sprite: _poses[0],
      size: Vector2.all(256),
      paint: Paint()..filterQuality = FilterQuality.medium,
    );
    _setPose(BabyMood.idle);
    await addAll([_shadow, _aura, _character]);
    await _character.add(_body);
    await _createEquipment();
    for (var i = 0; i < 6; i++) {
      final star = PolygonComponent(
        _starPoints(6, 2.6),
        anchor: Anchor.center,
        paint: Paint()..color = const Color(0x00ffd66d),
      );
      _stars.add(star);
      await add(star);
    }
    _ready = true;
    _layout();
    onReady?.call();
  }

  int _poseIndex = -1;
  void _setPose(BabyMood mood) {
    if (_poseIndex == mood.index) return;
    _poseIndex = mood.index;
    final sprite = _poses[mood.index];
    _body.sprite = sprite;
    final width = 256 * sprite.srcSize.x / sprite.srcSize.y;
    _body.size = Vector2(width, 256);
    _body.position = Vector2((256 - width) / 2, 0);
  }

  List<Vector2> _starPoints(double outer, double inner) => List.generate(8, (
    i,
  ) {
    final angle = -pi / 2 + i * pi / 4;
    final radius = i.isEven ? outer : inner;
    return Vector2(cos(angle) * radius + outer, sin(angle) * radius + outer);
  });

  Future<void> _createEquipment() async {
    final crown = PolygonComponent(
      [
        Vector2(0, 24),
        Vector2(0, 0),
        Vector2(17, 13),
        Vector2(28, 0),
        Vector2(40, 13),
        Vector2(57, 0),
        Vector2(57, 24),
      ],
      position: Vector2(86, 43),
      paint: Paint()..color = const Color(0xffffd263),
    );
    final flower = PositionComponent(position: Vector2(196, 67));
    for (var i = 0; i < 6; i++) {
      await flower.add(
        CircleComponent(
          radius: 7,
          anchor: Anchor.center,
          position: Vector2(cos(i * pi / 3) * 8, sin(i * pi / 3) * 8),
          paint: Paint()..color = const Color(0xffffb5cd),
        ),
      );
    }
    await flower.add(
      CircleComponent(
        radius: 5,
        anchor: Anchor.center,
        paint: Paint()..color = const Color(0xffffdf7b),
      ),
    );
    final bow = PositionComponent(position: Vector2(128, 167));
    await bow.addAll([
      PolygonComponent([
        Vector2(-23, -11),
        Vector2(0, 0),
        Vector2(-23, 11),
      ], paint: Paint()..color = const Color(0xffee8bad)),
      PolygonComponent([
        Vector2(23, -11),
        Vector2(0, 0),
        Vector2(23, 11),
      ], paint: Paint()..color = const Color(0xffee8bad)),
      CircleComponent(
        radius: 5,
        anchor: Anchor.center,
        paint: Paint()..color = const Color(0xffd9769b),
      ),
    ]);
    _equipment.addAll({'crown': crown, 'flower': flower, 'bow': bow});
    await _character.addAll(_equipment.values);
  }

  @override
  void onGameResize(Vector2 size) {
    super.onGameResize(size);
    if (_ready) _layout();
  }

  void _layout() {
    final side = min(size.x * .78, size.y * .91);
    _character.size = Vector2.all(256);
    final scale = side / 256;
    _character.scale = Vector2.all(scale);
    _character.position = Vector2(size.x / 2, size.y * .52);
    _shadow.position = Vector2(size.x / 2, size.y * .52 + side * .48);
    _shadow.scale = Vector2(scale, scale * .12);
    _aura.position = Vector2(size.x / 2, size.y * .52);
    _aura.scale = Vector2.all(scale);
  }

  void react() {
    reaction = 1.05;
  }

  @override
  void onTapDown(TapDownEvent event) => react();
  @override
  void update(double dt) {
    super.update(dt);
    clock += dt;
    reaction = max(0, reaction - dt);
    if (!_ready) return;
    final side = min(size.x * .78, size.y * .91);
    final breathing = sin(clock * 2.0) * .008;
    final evolutionScale = 1 + stage.clamp(0, 3) * .018;
    _character.scale = Vector2(
      side / 256 * (1 - breathing) * evolutionScale,
      side / 256 * (1 + breathing) * evolutionScale,
    );
    _character.position = Vector2(
      size.x / 2,
      size.y * .52 + sin(clock * 2) * 2 - sin(reaction / 1.05 * pi) * 10,
    );
    _character.angle = reaction > 0 ? sin(clock * 15) * .025 : 0;
    final blink = !worried && clock % 5.8 > 5.65;
    _setPose(blink && reaction == 0 ? BabyMood.happy : mood);
    for (final entry in _equipment.entries) {
      entry.value.scale = Vector2.all(entry.key == equipped ? 1 : 0);
    }
    final colors = [0x00000000, 0x6678bfa8, 0x99a4a0df, 0xb3efc762];
    _aura.paint.color = Color(colors[stage.clamp(0, 3)]);
    for (var i = 0; i < _stars.length; i++) {
      final angle = clock * .22 + i * pi / 3;
      _stars[i].position = Vector2(
        size.x / 2 + cos(angle) * side * .46,
        size.y * .52 + sin(angle) * side * .43,
      );
      _stars[i].paint.color = Color(i < stage * 2 ? 0xbbefd17b : 0x00000000);
      _stars[i].angle = clock * .25;
    }
  }
}
