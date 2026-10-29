import 'dart:async';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import '../../core/localization/context.dart';
import '../monster/monster_game.dart';
import '../monster/monster_scene.dart';
import '../settings/language_setting.dart';

enum HatchPhase { loading, hatching, reveal }

class HatchScreen extends StatefulWidget {
  const HatchScreen({
    super.key,
    required this.onHatched,
    required this.onContinue,
  });
  final Future<void> Function() onHatched;
  final VoidCallback onContinue;
  @override
  State<HatchScreen> createState() => _HatchScreenState();
}

class _HatchScreenState extends State<HatchScreen> with WidgetsBindingObserver {
  VideoPlayerController? _loading, _intro;
  late final MonsterGame _baby;
  HatchPhase phase = HatchPhase.loading;
  bool ready = false,
      blocked = false,
      failed = false,
      saving = false,
      saved = false,
      saveFailed = false;
  bool _resumePlayback = false, _disposed = false;
  int _generation = 0;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _baby = MonsterGame(transparentBackground: true, onReady: _recordHatch);
    _initialize();
  }

  Future<void> _initialize() async {
    final generation = ++_generation;
    setState(() {
      ready = false;
      failed = false;
      blocked = false;
    });
    final loading = VideoPlayerController.asset('assets/videos/loading.mp4');
    final intro = VideoPlayerController.asset('assets/videos/intro.mp4');
    _loading = loading;
    _intro = intro;
    try {
      await Future.wait([loading.initialize(), intro.initialize()]);
      if (_disposed || generation != _generation) return;
      await Future.wait([
        loading.setVolume(0),
        intro.setVolume(0),
        loading.setLooping(true),
        intro.setLooping(false),
      ]);
      // Play the supplied intro at its original speed until media completion.
      final duration = intro.value.duration.inMilliseconds;
      if (duration <= 0) throw StateError('Invalid intro duration');
      await intro.setPlaybackSpeed(1.0);
      loading.addListener(_videoChanged);
      intro.addListener(_videoChanged);
      if (!mounted) return;
      setState(() => ready = true);
      await _play(loading);
    } catch (_) {
      if (mounted && generation == _generation) setState(() => failed = true);
    }
  }

  void _videoChanged() {
    if (!mounted) return;
    final active = phase == HatchPhase.loading ? _loading : _intro;
    if (phase != HatchPhase.reveal && active?.value.hasError == true) {
      setState(() => failed = true);
      return;
    }
    if (phase == HatchPhase.hatching && _intro!.value.isCompleted) {
      _reveal();
    }
  }

  Future<void> _play(VideoPlayerController controller) async {
    try {
      await controller.play();
      if (mounted) setState(() => blocked = false);
    } catch (_) {
      if (mounted) setState(() => blocked = true);
    }
  }

  Future<void> _hatch() async {
    if (!ready || phase != HatchPhase.loading || failed) return;
    setState(() {
      phase = HatchPhase.hatching;
      blocked = false;
    });
    unawaited(_loading!.pause());
    await _play(_intro!);
  }

  void _reveal() {
    if (!mounted || phase == HatchPhase.reveal) return;
    unawaited(_loading?.pause() ?? Future<void>.value());
    unawaited(_intro?.pause() ?? Future<void>.value());
    setState(() {
      phase = HatchPhase.reveal;
      blocked = false;
      failed = false;
    });
  }

  Future<void> _recordHatch() async {
    if (!mounted || saving || saved) return;
    setState(() {
      saving = true;
      saveFailed = false;
    });
    try {
      await widget.onHatched();
      if (mounted) setState(() => saved = true);
    } catch (_) {
      if (mounted) setState(() => saveFailed = true);
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  Future<void> _retry() async {
    _generation++;
    final previousLoading = _loading, previousIntro = _intro;
    _loading = null;
    _intro = null;
    previousLoading?.removeListener(_videoChanged);
    previousIntro?.removeListener(_videoChanged);
    if (previousLoading != null) unawaited(previousLoading.dispose());
    if (previousIntro != null) unawaited(previousIntro.dispose());
    if (!mounted) return;
    setState(() => phase = HatchPhase.loading);
    await _initialize();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (phase == HatchPhase.reveal) {
      if (state == AppLifecycleState.resumed) {
        _baby.resumeEngine();
      } else {
        _baby.pauseEngine();
      }
      return;
    }
    final player = phase == HatchPhase.loading ? _loading : _intro;
    if (player == null || !ready) return;
    if (state == AppLifecycleState.resumed) {
      final resume = _resumePlayback;
      _resumePlayback = false;
      if (resume) unawaited(_play(player));
    } else {
      _resumePlayback = _resumePlayback || player.value.isPlaying;
      unawaited(player.pause());
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _generation++;
    WidgetsBinding.instance.removeObserver(this);
    for (final player in [_loading, _intro]) {
      player?.removeListener(_videoChanged);
      if (player != null) unawaited(player.dispose());
    }
    super.dispose();
  }

  Widget _video(VideoPlayerController player) => SizedBox.expand(
    child: FittedBox(
      fit: BoxFit.cover,
      child: SizedBox(
        width: player.value.size.width,
        height: player.value.size.height,
        child: VideoPlayer(player),
      ),
    ),
  );
  Widget _title(BuildContext context, String text, double fontSize) =>
      FittedBox(
        fit: BoxFit.scaleDown,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Text(
              text,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: fontSize,
                fontWeight: FontWeight.w900,
                letterSpacing: 2,
                foreground: Paint()
                  ..style = PaintingStyle.stroke
                  ..strokeWidth = 6
                  ..color = const Color(0xff46765b),
                shadows: const [
                  Shadow(
                    color: Color(0x33406a36),
                    offset: Offset(0, 5),
                    blurRadius: 8,
                  ),
                ],
              ),
            ),
            Text(
              text,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: fontSize,
                fontWeight: FontWeight.w900,
                letterSpacing: 2,
                color: const Color(0xfffff8da),
              ),
            ),
          ],
        ),
      );
  @override
  Widget build(BuildContext context) {
    final reveal = phase == HatchPhase.reveal;
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Stack(
            fit: StackFit.expand,
            children: [
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0xffcbe8e0), Color(0xfff1f6d7)],
                  ),
                ),
              ),
              if (ready && !failed)
                AnimatedOpacity(
                  opacity: reveal ? 0 : 1,
                  duration: const Duration(milliseconds: 450),
                  child: _video(
                    phase == HatchPhase.loading ? _loading! : _intro!,
                  ),
                ),
              if (!reveal)
                const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Color(0x22517642),
                        Color(0x00000000),
                        Color(0x66354922),
                      ],
                      stops: [0, .45, 1],
                    ),
                  ),
                ),
              SafeArea(
                child: LayoutBuilder(
                  builder: (context, space) => Stack(
                    children: [
                      Positioned(
                        top: 32,
                        left: 30,
                        right: 30,
                        child: Column(
                          children: [
                            _title(context, context.tr('hatch.titleTop'), 30),
                            _title(
                              context,
                              context.tr('hatch.titleBottom'),
                              minTitleSize(space.maxWidth),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              context.tr('hatch.tagline'),
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: Color(0xff365641),
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Positioned(
                        top: 4,
                        right: 4,
                        child: IconButton(
                          tooltip: context.tr('language.label'),
                          icon: const Icon(
                            Icons.language,
                            color: Color(0xff365641),
                          ),
                          onPressed: () => showModalBottomSheet<void>(
                            context: context,
                            showDragHandle: true,
                            builder: (_) => const SafeArea(
                              child: Padding(
                                padding: EdgeInsets.all(16),
                                child: LanguageSetting(),
                              ),
                            ),
                          ),
                        ),
                      ),
                      if (!ready && !failed)
                        const Center(child: CircularProgressIndicator()),
                      if (!reveal &&
                          !failed &&
                          ready &&
                          phase == HatchPhase.loading)
                        Positioned(
                          top: space.maxHeight * .28,
                          bottom: space.maxHeight * .20,
                          left: space.maxWidth * .12,
                          right: space.maxWidth * .12,
                          child: Semantics(
                            label: context.tr('hatch.tapEgg'),
                            button: true,
                            child: GestureDetector(
                              key: const Key('hatch_egg'),
                              behavior: HitTestBehavior.opaque,
                              onTap: _hatch,
                              child: const SizedBox.expand(),
                            ),
                          ),
                        ),
                      if (reveal)
                        Positioned(
                          top: space.maxHeight * .27,
                          bottom: space.maxHeight * .19,
                          left: 0,
                          right: 0,
                          child: AnimatedOpacity(
                            opacity: 1,
                            duration: const Duration(milliseconds: 500),
                            child: MonsterScene(game: _baby),
                          ),
                        ),
                      Positioned(
                        left: 24,
                        right: 24,
                        bottom: 24,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (failed) ...[
                              Text(
                                context.tr('hatch.videoError'),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 12),
                              FilledButton(
                                onPressed: _retry,
                                child: Text(context.tr('shell.006')),
                              ),
                              TextButton(
                                onPressed: _reveal,
                                child: Text(context.tr('hatch.skipVideo')),
                              ),
                            ] else if (reveal) ...[
                              Text(
                                context.tr('hatch.welcome'),
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xff365641),
                                ),
                              ),
                              const SizedBox(height: 12),
                              if (saveFailed) ...[
                                Text(
                                  context.tr('hatch.saveError'),
                                  textAlign: TextAlign.center,
                                ),
                                TextButton(
                                  onPressed: _recordHatch,
                                  child: Text(context.tr('shell.006')),
                                ),
                              ],
                              FilledButton(
                                onPressed: saved ? widget.onContinue : null,
                                child: Text(
                                  saving
                                      ? context.tr('onboarding.043')
                                      : context.tr('hatch.continue'),
                                ),
                              ),
                            ] else if (blocked)
                              FilledButton.icon(
                                onPressed: () => _play(
                                  phase == HatchPhase.loading
                                      ? _loading!
                                      : _intro!,
                                ),
                                icon: const Icon(Icons.play_arrow),
                                label: Text(context.tr('hatch.play')),
                              )
                            else
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 24,
                                  vertical: 14,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xeefff9e7),
                                  borderRadius: BorderRadius.circular(30),
                                  boxShadow: const [
                                    BoxShadow(
                                      color: Color(0x22476a34),
                                      blurRadius: 18,
                                      offset: Offset(0, 5),
                                    ),
                                  ],
                                ),
                                child: Text(
                                  context.tr(
                                    phase == HatchPhase.loading
                                        ? 'hatch.tapEgg'
                                        : 'hatch.hatching',
                                  ),
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xff365641),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  double minTitleSize(double width) => width < 350 ? 42 : 48;
}
