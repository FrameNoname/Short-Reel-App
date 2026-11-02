import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show PlatformException;
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shortreel/controllers/auth_controller.dart';
import 'package:shortreel/controllers/feed_controller.dart';
import 'package:shortreel/controllers/settings_controller.dart';
import 'package:shortreel/data/app_repository.dart';
import 'support/mock_repository.dart';
import 'package:shortreel/models/episode.dart';
import 'package:shortreel/models/film.dart';
import 'package:shortreel/views/feed/episode_video.dart';
import 'package:video_player_platform_interface/video_player_platform_interface.dart';

/// A platform player that only counts what it is asked to do.
class _FakePlatform extends VideoPlayerPlatform {
  int created = 0;
  int disposed = 0;
  bool failInitialize = false;
  Completer<void>? holdInitialize;
  final Set<int> playing = {};
  int maxPlaying = 0;
  final Map<int, StreamController<VideoEvent>> _events = {};

  int get live => created - disposed;

  @override
  Future<void> init() async {}

  @override
  Future<int?> createWithOptions(VideoCreationOptions options) async {
    final id = ++created;
    final events = StreamController<VideoEvent>();
    _events[id] = events;
    () async {
      if (holdInitialize != null) await holdInitialize!.future;
      if (events.isClosed) return;
      if (failInitialize) {
        events.addError(
          PlatformException(code: 'fail', message: 'cannot open'),
        );
      } else {
        events.add(
          VideoEvent(
            eventType: VideoEventType.initialized,
            duration: const Duration(seconds: 5),
            size: const Size(100, 200),
          ),
        );
      }
    }();
    return id;
  }

  @override
  Stream<VideoEvent> videoEventsFor(int playerId) => _events[playerId]!.stream;

  @override
  Future<void> dispose(int playerId) async {
    disposed++;
    playing.remove(playerId);
    await _events[playerId]?.close();
  }

  @override
  Future<void> play(int playerId) async {
    playing.add(playerId);
    if (playing.length > maxPlaying) maxPlaying = playing.length;
  }

  @override
  Future<void> pause(int playerId) async => playing.remove(playerId);

  @override
  Future<void> setLooping(int playerId, bool looping) async {}

  @override
  Future<void> setVolume(int playerId, double volume) async {}

  @override
  Future<void> setPlaybackSpeed(int playerId, double speed) async {}

  @override
  Future<void> seekTo(int playerId, Duration position) async {}

  @override
  Future<Duration> getPosition(int playerId) async => Duration.zero;

  @override
  Widget buildView(int playerId) => const SizedBox();

  @override
  Future<void> setMixWithOthers(bool mixWithOthers) async {}
}

class _Repo extends MockRepository {
  _Repo(this.numbers);

  final List<int> numbers;

  @override
  bool get playsVideo => true;

  @override
  Future<List<Episode>> episodes(int filmId) async => [
    for (final n in numbers)
      Episode(
        id: n,
        filmId: filmId,
        episodeNo: n,
        title: 'Episode $n',
        durationSec: 5,
        isFree: true,
        priceCoins: 0,
      ),
  ];

  @override
  Future<Playback> playback(int episodeId) async => Playback(
    episode: (await episodes(1)).firstWhere((e) => e.id == episodeId),
    streamUrl: 'http://api.test/api/episodes/$episodeId/stream?t=x',
  );
}

Future<(_Repo, Film)> _pump(
  WidgetTester tester,
  ValueNotifier<bool> active,
  List<int> numbers, {
  int episodeNo = 1,
  void Function(int)? onResolved,
  void Function(List<int>)? onEpisodes,
}) async {
  final repo = _Repo(numbers);
  final film = repo.filmById(1)!;
  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => FeedController(repo)),
        ChangeNotifierProvider(create: (_) => AuthController(repo)),
        ChangeNotifierProvider(create: (_) => SettingsController()),
      ],
      child: MaterialApp(
        home: ValueListenableBuilder<bool>(
          valueListenable: active,
          builder: (_, isActive, _) => EpisodeVideo(
            film: film,
            episodeNo: episodeNo,
            paused: false,
            speed: 1,
            active: isActive,
            onEnded: () {},
            onLocked: () async {},
            onResolved: onResolved,
            onEpisodes: onEpisodes,
            overlay: const SizedBox.expand(),
          ),
        ),
      ),
    ),
  );
  return (repo, film);
}

/// Lets the real-async parts of the player (event streams) finish.
Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  await tester.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 30)),
  );
  await tester.pump();
}

void main() {
  late _FakePlatform platform;
  setUp(() {
    platform = _FakePlatform();
    VideoPlayerPlatform.instance = platform;
  });

  testWidgets('a controller whose initialize fails is disposed', (
    tester,
  ) async {
    platform.failInitialize = true;
    await _pump(tester, ValueNotifier(true), [1, 2]);
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));
    expect(platform.created, 1);
    await _settle(tester);
    expect(platform.live, 0, reason: 'the failed controller must not leak');
    expect(find.text('Try again'), findsOneWidget);

    // Retrying creates a new one and disposes that too when it fails again.
    await tester.tap(find.text('Try again'));
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));
    expect(platform.created, 2);
    await _settle(tester);
    expect(platform.live, 0);
  });

  testWidgets(
    'leaving the page while a controller is still opening disposes it',
    (tester) async {
      platform.holdInitialize = Completer<void>();
      await _pump(tester, ValueNotifier(true), [1, 2]);
      await tester.pump(const Duration(seconds: 1));
      expect(platform.created, 1);
      await tester.pumpWidget(const SizedBox());
      platform.holdInitialize!.complete();
      await tester.pump(const Duration(seconds: 1));
      await _settle(tester);
      expect(platform.live, 0);
    },
  );

  testWidgets(
    'an inactive page loads and plays nothing; the active one plays alone',
    (tester) async {
      final active = ValueNotifier(false);
      await _pump(tester, active, [1, 2]);
      await tester.pump(const Duration(seconds: 2));
      expect(
        platform.created,
        0,
        reason: 'a page the feed is not on must not load',
      );

      active.value = true;
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 1));
      expect(platform.live, 1);
      expect(platform.playing.length, 1);

      active.value = false; // swiped away
      await _settle(tester);
      expect(platform.live, 0, reason: 'the page it left holds no player');
      expect(platform.playing, isEmpty);
      expect(platform.maxPlaying, 1);
    },
  );

  testWidgets('a deleted first episode falls forward to the next real number', (
    tester,
  ) async {
    final resolved = <int>[];
    final known = <List<int>>[];
    await _pump(
      tester,
      ValueNotifier(true),
      [3, 5, 8],
      episodeNo: 1,
      onResolved: resolved.add,
      onEpisodes: known.add,
    );
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));
    expect(known.single, [3, 5, 8]);
    expect(resolved, [3]);
    expect(platform.live, 1);
  });

  test(
    'the next episode follows the real list, not episode number plus one',
    () {
      final feed = FeedController(MockRepository());
      feed.learnEpisodes(7, [1, 3, 8]);
      expect(feed.episodeAfter(7, 1, fallbackCount: 8), 3);
      expect(feed.episodeAfter(7, 3, fallbackCount: 8), 8);
      expect(feed.episodeAfter(7, 8, fallbackCount: 8), isNull);
      expect(
        feed.episodeAfter(9, 2, fallbackCount: 3),
        3,
        reason: 'list not known yet',
      );
    },
  );
}
