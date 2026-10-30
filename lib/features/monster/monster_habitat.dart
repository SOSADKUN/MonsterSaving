import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import '../../core/localization/context.dart';
import 'background_catalog.dart';
import 'companion_catalog.dart';

enum MonsterActivity { idle, walking, eating, sleeping, playing }

/// The homepage pet uses Flutter tickers and image frames, with no Flame game.
class MonsterHabitat extends StatefulWidget {
  const MonsterHabitat({
    super.key,
    this.stage = 0,
    this.equipped = '',
    this.worried = false,
    this.background = 'meadow',
    this.companion = 'dinosaur',
  });

  final int stage;
  final String equipped, background, companion;
  final bool worried;

  @override
  State<MonsterHabitat> createState() => _MonsterHabitatState();
}

class _MonsterHabitatState extends State<MonsterHabitat>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  final _random = math.Random();
  late final Ticker _ticker;
  _MonsterArtwork? _art;
  List<HabitatBackground> _backgrounds = const [HabitatBackground.meadow];
  MonsterActivity _activity = MonsterActivity.idle;
  Duration _lastTick = Duration.zero;
  double _clock = 0, _elapsed = 0, _duration = 3;
  double _x = .5, _walkStart = .5, _walkTarget = .5;
  bool _left = false, _failed = false, _reduceMotion = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _ticker = createTicker(_tick);
    _load();
  }

  Future<void> _load() async {
    // An unavailable optional background never blocks the character itself.
    BackgroundCatalog.load()
        .then((items) {
          if (mounted) setState(() => _backgrounds = items);
        })
        .catchError((Object _) {});
    try {
      final art = await _MonsterArtwork.load(widget.companion);
      if (!mounted) {
        art.dispose();
        return;
      }
      setState(() => _art = art);
      final lifecycle = WidgetsBinding.instance.lifecycleState;
      if (lifecycle == null || lifecycle == AppLifecycleState.resumed) {
        _ticker.start();
      }
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduceMotion = MediaQuery.disableAnimationsOf(context);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      if (_art != null && !_ticker.isActive) {
        _lastTick = Duration.zero;
        _ticker.start();
      }
    } else {
      _ticker.stop();
      _lastTick = Duration.zero;
    }
  }

  void _tick(Duration elapsed) {
    final dt = ((elapsed - _lastTick).inMicroseconds / 1000000)
        .clamp(0.0, .05)
        .toDouble();
    _lastTick = elapsed;
    _clock += dt;
    _elapsed += dt;
    if (_reduceMotion) {
      if (_elapsed >= _duration) setState(_chooseActivity);
      return;
    }
    setState(() {
      if (_activity == MonsterActivity.walking) {
        final t = Curves.easeInOut.transform(
          (_elapsed / _duration).clamp(0.0, 1.0).toDouble(),
        );
        _x = _walkStart + (_walkTarget - _walkStart) * t;
      }
      if (_elapsed >= _duration) _chooseActivity();
    });
  }

  void _chooseActivity() {
    const weighted = [
      MonsterActivity.idle,
      MonsterActivity.idle,
      MonsterActivity.walking,
      MonsterActivity.walking,
      MonsterActivity.walking,
      MonsterActivity.eating,
      MonsterActivity.eating,
      MonsterActivity.sleeping,
      MonsterActivity.playing,
    ];
    final choices = weighted.where((item) => item != _activity).toList();
    _startActivity(choices[_random.nextInt(choices.length)]);
  }

  void _startActivity(MonsterActivity activity) {
    _activity = activity;
    _elapsed = 0;
    _duration = switch (activity) {
      MonsterActivity.idle => 4 + _random.nextDouble() * 4,
      MonsterActivity.walking => 4 + _random.nextDouble() * 3,
      MonsterActivity.eating => 4 + _random.nextDouble() * 3,
      MonsterActivity.sleeping => 10 + _random.nextDouble() * 7,
      MonsterActivity.playing => 2.5 + _random.nextDouble() * 2,
    };
    if (activity == MonsterActivity.walking) {
      _walkStart = _x;
      // Pick the other side of the available floor, without clipping the sprite.
      _walkTarget = _x < .5
          ? .65 + _random.nextDouble() * .3
          : .05 + _random.nextDouble() * .3;
      _left = _walkTarget < _walkStart;
    }
  }

  void _react() {
    if (_art == null) return;
    setState(() => _startActivity(MonsterActivity.playing));
  }

  String get _frame => switch (_activity) {
    MonsterActivity.walking =>
      !_reduceMotion && (_elapsed * 5).floor().isOdd ? 'walk2' : 'walk1',
    MonsterActivity.eating => 'eat',
    MonsterActivity.sleeping => 'sleep',
    MonsterActivity.playing => 'happy',
    MonsterActivity.idle =>
      widget.worried
          ? 'sad'
          : (!_reduceMotion &&
                    _art?.frames.containsKey('blink') == true &&
                    _clock % 5.8 > 5.65
                ? 'blink'
                : 'idle'),
  };

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _ticker.dispose();
    _art?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final backdrop = _backgrounds.firstWhere(
      (item) => item.id == widget.background,
      orElse: () => HabitatBackground.meadow,
    );
    return RepaintBoundary(
      child: Semantics(
        label:
            '${context.tr('monster.tap')} ${context.tr('monster.activity.${_activity.name}')}',
        button: true,
        onTap: _react,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: _react,
          child: LayoutBuilder(
            builder: (context, space) {
              final side = math.min(
                space.maxHeight * .66,
                space.maxWidth * .60,
              );
              final characterHeight =
                  side * (1 + widget.stage.clamp(0, 3) * .012);
              final frame = _art?.frames[_frame];
              final height = characterHeight * (frame?.heightFactor ?? 1);
              final width =
                  height *
                  (frame == null ? 1 : frame.rect.width / frame.rect.height);
              final position = _reduceMotion ? .5 : _x;
              final left =
                  16.0 + math.max(0.0, space.maxWidth - width - 32) * position;
              final breathing = _reduceMotion
                  ? 0.0
                  : math.sin(
                          _clock *
                              (_activity == MonsterActivity.sleeping
                                  ? 1.2
                                  : 2.1),
                        ) *
                        .012;
              final bob = _reduceMotion
                  ? 0.0
                  : switch (_activity) {
                      MonsterActivity.walking =>
                        math.sin(_elapsed * 10).abs() * 4,
                      MonsterActivity.playing =>
                        math.max(0.0, math.sin(_elapsed * 6)) * 14,
                      MonsterActivity.eating =>
                        math.sin(_elapsed * 11).abs() * 1.5,
                      _ => 0.0,
                    };
              return Stack(
                clipBehavior: Clip.hardEdge,
                children: [
                  Positioned.fill(child: HabitatBackdrop(background: backdrop)),
                  if (_art != null) ...[
                    Positioned(
                      left: left + width * .12,
                      bottom: 30,
                      width: width * .76,
                      height: 12,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: const Color(0x18608a55),
                          borderRadius: BorderRadius.circular(100),
                        ),
                      ),
                    ),
                    Positioned(
                      left: left,
                      bottom: 34 + bob,
                      width: width,
                      height: height,
                      child: Transform.scale(
                        alignment: Alignment.bottomCenter,
                        scaleX: 1 - breathing,
                        scaleY:
                            1 +
                            breathing +
                            (_activity == MonsterActivity.eating &&
                                    !_reduceMotion
                                ? math.sin(_elapsed * 11) * .008
                                : 0),
                        child: Transform(
                          alignment: Alignment.center,
                          transform: Matrix4.diagonal3Values(
                            _activity == MonsterActivity.walking && _left
                                ? -1
                                : 1,
                            1,
                            1,
                          ),
                          child: CustomPaint(
                            painter: _MonsterFramePainter(frame!),
                          ),
                        ),
                      ),
                    ),
                    if (widget.equipped.isNotEmpty)
                      Positioned(
                        left:
                            left +
                            width * (widget.equipped == 'bow' ? .38 : .34),
                        bottom:
                            34 +
                            bob +
                            height * (widget.equipped == 'bow' ? .22 : .79),
                        child: IgnorePointer(
                          child: switch (widget.equipped) {
                            'flower' => Icon(
                              Icons.local_florist,
                              color: const Color(0xffee8bad),
                              size: side * .17,
                            ),
                            'crown' => Text(
                              '👑',
                              style: TextStyle(fontSize: side * .20),
                            ),
                            'bow' => Text(
                              '🎀',
                              style: TextStyle(fontSize: side * .17),
                            ),
                            _ => const SizedBox.shrink(),
                          },
                        ),
                      ),
                    if (_activity == MonsterActivity.sleeping)
                      for (var i = 0; i < 3; i++)
                        Positioned(
                          left: (left + width * .75 + i * 10)
                              .clamp(8.0, math.max(8.0, space.maxWidth - 25))
                              .toDouble(),
                          bottom:
                              34 +
                              height * .67 +
                              i * 15 +
                              (_reduceMotion ? 0 : (_clock * 6 + i * 8) % 18),
                          child: Text(
                            i == 2 ? 'Z' : 'z',
                            style: TextStyle(
                              color: const Color(0xff65828c),
                              fontWeight: FontWeight.bold,
                              fontSize: 13.0 + i * 3,
                            ),
                          ),
                        ),
                    if (_activity == MonsterActivity.playing ||
                        widget.stage > 0)
                      Positioned(
                        left: left + width * .85,
                        bottom: 40 + height * .65 + bob,
                        child: const Icon(
                          Icons.auto_awesome,
                          size: 22,
                          color: Color(0xffe5b64d),
                        ),
                      ),
                  ],
                  Positioned(
                    top: 12,
                    left: 12,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: const Color(0xddfffdf4),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        child: Text(
                          context.tr('monster.activity.${_activity.name}'),
                          style: const TextStyle(
                            color: Color(0xff46765b),
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ),
                  ),
                  if (_failed)
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Text(
                          context.tr('monster.loadError'),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _MonsterFrame {
  const _MonsterFrame(this.image, this.rect, this.heightFactor, this.flipX);
  final ui.Image image;
  final Rect rect;
  final double heightFactor;
  final bool flipX;
}

class _MonsterArtwork {
  _MonsterArtwork(this.images, this.frames);
  final List<ui.Image> images;
  final Map<String, _MonsterFrame> frames;

  static Future<_MonsterArtwork> load(String companion) async {
    final images = <ui.Image>[];
    final frames = <String, _MonsterFrame>{};
    try {
      for (final file in CompanionCatalog.manifests(companion)) {
        final data =
            jsonDecode(
                  await rootBundle.loadString(
                    'assets/images/monster/$file.json',
                  ),
                )
                as Map<String, dynamic>;
        final bytes = await rootBundle.load(
          'assets/images/monster/${data['image']}',
        );
        final codec = await ui.instantiateImageCodec(
          bytes.buffer.asUint8List(bytes.offsetInBytes, bytes.lengthInBytes),
        );
        late final ui.Image image;
        try {
          image = (await codec.getNextFrame()).image;
        } finally {
          codec.dispose();
        }
        images.add(image);
        if (image.width != data['width'] || image.height != data['height']) {
          throw const FormatException(
            'Monster image dimensions do not match manifest',
          );
        }
        for (final entry in (data['frames'] as Map<String, dynamic>).entries) {
          final frame = entry.value as Map<String, dynamic>;
          final rect = Rect.fromLTWH(
            (frame['x'] as num).toDouble(),
            (frame['y'] as num).toDouble(),
            (frame['width'] as num).toDouble(),
            (frame['height'] as num).toDouble(),
          );
          if (rect.left < 0 ||
              rect.top < 0 ||
              rect.width <= 0 ||
              rect.height <= 0 ||
              rect.right > image.width ||
              rect.bottom > image.height) {
            throw const FormatException('Invalid monster frame bounds');
          }
          frames[entry.key] = _MonsterFrame(
            image,
            rect,
            (frame['heightFactor'] as num?)?.toDouble() ?? 1,
            frame['flipX'] as bool? ?? false,
          );
        }
      }
      return _MonsterArtwork(images, frames);
    } catch (_) {
      for (final image in images) {
        image.dispose();
      }
      rethrow;
    }
  }

  void dispose() {
    for (final image in images) {
      image.dispose();
    }
  }
}

/// Paints a crop of supplied raster art; it never draws the character as shapes.
class _MonsterFramePainter extends CustomPainter {
  _MonsterFramePainter(this.frame);
  final _MonsterFrame frame;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    if (frame.flipX) {
      canvas.translate(size.width, 0);
      canvas.scale(-1, 1);
    }
    canvas.drawImageRect(
      frame.image,
      frame.rect,
      Offset.zero & size,
      Paint()..filterQuality = FilterQuality.medium,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_MonsterFramePainter oldDelegate) =>
      oldDelegate.frame != frame;
}
