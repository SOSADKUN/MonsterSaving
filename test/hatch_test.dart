import 'package:saving_monster/core/localization/strings.dart';
import 'dart:async';
import 'dart:convert';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:video_player_platform_interface/video_player_platform_interface.dart';
import 'package:saving_monster/core/models/ledger.dart';
import 'package:saving_monster/features/monster/monster_game.dart';
import 'package:saving_monster/features/monster/monster_scene.dart';
import 'package:saving_monster/features/onboarding/hatch_screen.dart';
import 'support/localization.dart';

class FakeVideoPlayer extends VideoPlayerPlatform {
  FakeVideoPlayer({this.deferIntro = false});
  final bool deferIntro;
  final sources = <int, DataSource>{},
      events = <int, StreamController<VideoEvent>>{};
  final loops = <int, bool>{},
      playing = <int, bool>{},
      speeds = <int, double>{};
  final disposed = <int>[];
  @override
  Future<void> init() async {}
  @override
  Future<int> createWithOptions(VideoCreationOptions options) async {
    final id = sources.length + 1;
    sources[id] = options.dataSource;
    events[id] = StreamController<VideoEvent>.broadcast(
      onListen: () {
        scheduleMicrotask(() {
          if (!deferIntro || !options.dataSource.asset!.endsWith('intro.mp4')) {
            initializePlayer(id);
          }
        });
      },
    );
    return id;
  }

  void initializePlayer(int id) => events[id]!.add(
    VideoEvent(
      eventType: VideoEventType.initialized,
      duration: const Duration(milliseconds: 3042),
      size: const Size(720, 1280),
    ),
  );

  @override
  Stream<VideoEvent> videoEventsFor(int playerId) => events[playerId]!.stream;
  @override
  Future<void> dispose(int playerId) async {
    disposed.add(playerId);
    await events[playerId]!.close();
  }

  @override
  Future<void> setLooping(int playerId, bool looping) async {
    loops[playerId] = looping;
  }

  @override
  Future<void> play(int playerId) async {
    if (playing.entries.any((e) => e.key != playerId && e.value)) {
      throw StateError('Only one video should play at a time');
    }
    playing[playerId] = true;
  }

  @override
  Future<void> pause(int playerId) async {
    playing[playerId] = false;
  }

  @override
  Future<void> setVolume(int playerId, double volume) async {}
  @override
  Future<void> setPlaybackSpeed(int playerId, double speed) async {
    speeds[playerId] = speed;
  }

  @override
  Future<void> seekTo(int playerId, Duration position) async {}
  @override
  Future<Duration> getPosition(int playerId) async => Duration.zero;
  @override
  Widget buildViewWithOptions(VideoViewOptions options) =>
      const ColoredBox(color: Color(0xffe4f3da));
}

void main() {
  setUpAll(loadTestTranslations);
  test('Hatch progress survives restart and migrates existing profiles', () {
    expect(Ledger(hasHatched: true).copy().hasHatched, isTrue);
    final oldEmpty = Ledger().toJson()..remove('hasHatched');
    expect(Ledger.decode(jsonEncode(oldEmpty)).hasHatched, isFalse);
    final oldProfile = Ledger(
      profile: {
        'opening': 0,
        'openingDate': '2026-10-01',
        'salary': 0,
        'payday': 25,
        'target': 0,
        'goal': 0,
        'saved': 0,
        'coverage': null,
      },
    ).toJson()..remove('hasHatched');
    expect(Ledger.decode(jsonEncode(oldProfile)).hasHatched, isTrue);
  });
  testWidgets(
    'Loop → tap → original-speed hatch → reference sprite, with pause/resume and disposal',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final previous = VideoPlayerPlatform.instance;
      final fake = FakeVideoPlayer();
      VideoPlayerPlatform.instance = fake;
      addTearDown(() => VideoPlayerPlatform.instance = previous);
      var saved = 0, continued = false;
      await tester.pumpWidget(
        MaterialApp(
          home: HatchScreen(
            onHatched: () async {
              saved++;
            },
            onContinue: () => continued = true,
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 100));
      final loading = fake.sources.entries
          .singleWhere((e) => e.value.asset!.endsWith('loading.mp4'))
          .key;
      expect(fake.sources, hasLength(2));
      expect(fake.loops[loading], isTrue);
      expect(find.byKey(const Key('hatch_egg')), findsOneWidget);
      expect(saved, 0);
      final intro = fake.sources.entries
          .singleWhere((e) => e.value.asset!.endsWith('intro.mp4'))
          .key;
      for (var i = 0; i < 3; i++) {
        await tester.pump(const Duration(milliseconds: 20));
      }
      expect(fake.playing[intro], isFalse);
      expect(
        find.byKey(const Key('hatch_video_corner_badge')),
        findsNWidgets(2),
      );
      await tester.tap(find.byKey(const Key('hatch_egg')));
      await tester.pump();
      expect(fake.sources, hasLength(2));
      expect(fake.disposed, isEmpty);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(fake.playing[loading], isFalse);
      expect(fake.playing[intro], isTrue);
      expect(fake.speeds[intro], 1.0);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      await tester.pump();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump();
      expect(fake.playing[intro], isFalse);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      expect(fake.playing[intro], isTrue);
      await tester.pump(const Duration(seconds: 3));
      expect(saved, 0);
      fake.events[intro]!.add(VideoEvent(eventType: VideoEventType.completed));
      await tester.pump();
      await tester.pump();
      final game = tester.widget<MonsterScene>(find.byType(MonsterScene)).game;
      for (var i = 0; i < 40 && !game.spriteReady; i++) {
        await tester.runAsync(() async {
          await Future<void>.delayed(const Duration(milliseconds: 50));
        });
        await tester.pump(const Duration(milliseconds: 16));
      }
      await tester.pump(const Duration(milliseconds: 100));
      expect(game.spriteReady, isTrue);
      expect(saved, 1);
      final body = game.children
          .expand((c) => c.children)
          .whereType<SpriteComponent>()
          .single;
      expect(body.sprite!.srcSize.x, lessThan(body.sprite!.image.width / 2));
      game.react();
      game.update(.1);
      expect(game.mood, BabyMood.happy);
      game.worried = true;
      game.update(2);
      expect(game.mood, BabyMood.sad);
      await tester.tap(find.text(tr('hatch.continue')));
      expect(continued, isTrue);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      for (var i = 0; i < 10 && fake.disposed.length < 2; i++) {
        await tester.pump(const Duration(milliseconds: 50));
        await tester.runAsync(() async {
          await Future<void>.delayed(const Duration(milliseconds: 20));
        });
      }
      expect(fake.disposed.toSet(), {loading, intro});
    },
  );
  testWidgets('An early tap keeps the egg visible while the intro preloads', (
    tester,
  ) async {
    final previous = VideoPlayerPlatform.instance;
    final fake = FakeVideoPlayer(deferIntro: true);
    VideoPlayerPlatform.instance = fake;
    addTearDown(() => VideoPlayerPlatform.instance = previous);
    await tester.pumpWidget(
      MaterialApp(
        home: HatchScreen(onHatched: () async {}, onContinue: () {}),
      ),
    );
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 20));
    }
    final loading = fake.sources.entries
        .singleWhere((e) => e.value.asset!.endsWith('loading.mp4'))
        .key;
    final intro = fake.sources.entries
        .singleWhere((e) => e.value.asset!.endsWith('intro.mp4'))
        .key;
    await tester.tap(find.byKey(const Key('hatch_egg')));
    await tester.pump();
    expect(fake.playing[loading], isTrue);
    expect(fake.playing[intro], isNot(isTrue));
    expect(find.byType(CircularProgressIndicator), findsNothing);
    fake.initializePlayer(intro);
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 20));
    }
    expect(fake.playing[loading], isFalse);
    expect(fake.playing[intro], isTrue);
    expect(fake.sources, hasLength(2));
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 50));
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 20));
    });
  });
}
