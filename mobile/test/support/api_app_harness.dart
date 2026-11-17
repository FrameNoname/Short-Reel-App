import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shortreel/data/api_repository.dart';
import 'package:shortreel/l10n/thai.dart';
import 'package:shortreel/main.dart';
import 'package:shortreel/services/api_client.dart';
import 'package:shortreel/services/catalog_service.dart';
import 'package:video_player_platform_interface/video_player_platform_interface.dart';

import 'fake_dio.dart' show MemoryTokens;

/// Where backend/scripts/widget-test-server.js listens. Override with
/// --dart-define=WIDGET_TEST_API=http://host:port
const testServer = String.fromEnvironment(
  'WIDGET_TEST_API',
  defaultValue: 'http://127.0.0.1:3100',
);

/// The seed accounts in backend/db/shortreel.sql.
const passwords = {'viewer01': '6666', 'mira.lens': '4444', 'admin': '1111'};

/// Runs the widget tests in real time with real HTTP, so the app talks to the
/// real API. The normal test binding answers every HTTP request with 400.
class ApiTestBinding extends LiveTestWidgetsFlutterBinding {
  @override
  bool get overrideHttpClient => false;

  static void ensureInitialized() {
    ApiTestBinding();
    // A tap that misses its widget fails the test instead of only warning.
    WidgetController.hitTestWarningShouldBeFatal = true;
    // Frames run when the test pumps, as in the usual widget tests.
    (WidgetsBinding.instance as LiveTestWidgetsFlutterBinding).framePolicy =
        LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;
  }
}

/// The app is shown in Thai only, so finders look for the Thai of the English
/// wording written in the views.
String th(String english) => thaiOf(english);

Finder text(String english) => find.text(th(english));

/// Rebuilds the test database from the seed.
Future<void> resetServer() async {
  final client = HttpClient();
  try {
    final request = await client.postUrl(Uri.parse('$testServer/__test/reset'));
    final response = await request.close();
    final body = await response.transform(utf8.decoder).join();
    if (response.statusCode != 200) {
      throw StateError('Resetting the test database failed: $body');
    }
  } on SocketException {
    throw StateError(
      'The widget test API is not running. Start it with\n'
      '  node backend/scripts/widget-test-server.js',
    );
  } finally {
    client.close();
  }
}

/// Reads [path] from the test API, as [username] when given, so a test can
/// check what the server stored and not only what the screen shows.
Future<Map<String, dynamic>> serverGet(String path, {String? username}) async {
  final client = HttpClient();
  try {
    String? token;
    if (username != null) {
      final login = await client.postUrl(
        Uri.parse('$testServer/api/auth/login'),
      );
      login.headers.contentType = ContentType.json;
      login.write(
        jsonEncode({'username': username, 'password': passwords[username]}),
      );
      final answer = await login.close();
      final json =
          jsonDecode(await answer.transform(utf8.decoder).join())
              as Map<String, dynamic>;
      token = json['token'] as String;
    }
    final request = await client.getUrl(Uri.parse('$testServer/api$path'));
    if (token != null) {
      request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $token');
    }
    final response = await request.close();
    return jsonDecode(await response.transform(utf8.decoder).join())
        as Map<String, dynamic>;
  } finally {
    client.close();
  }
}

/// Whether the API accepts this username and password.
Future<bool> serverLogIn(String username, String password) async {
  final client = HttpClient();
  try {
    final login = await client.postUrl(Uri.parse('$testServer/api/auth/login'));
    login.headers.contentType = ContentType.json;
    login.write(jsonEncode({'username': username, 'password': password}));
    final answer = await login.close();
    await answer.drain<void>();
    return answer.statusCode == 200;
  } finally {
    client.close();
  }
}

/// A platform video player that never decodes anything; the API still decides
/// which episodes get a stream link. It counts players and which are playing.
class FakeVideoPlatform extends VideoPlayerPlatform {
  int created = 0;
  int disposed = 0;
  final Set<int> playing = {};
  final List<String> urls = [];
  final List<double> speeds = [];
  final Map<int, StreamController<VideoEvent>> _events = {};

  int get live => created - disposed;

  @override
  Future<void> init() async {}

  @override
  Future<int?> createWithOptions(VideoCreationOptions options) async {
    final id = ++created;
    urls.add(options.dataSource.uri ?? '');
    final events = StreamController<VideoEvent>();
    _events[id] = events;
    events.add(
      VideoEvent(
        eventType: VideoEventType.initialized,
        duration: const Duration(seconds: 60),
        size: const Size(100, 200),
      ),
    );
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
  Future<void> play(int playerId) async => playing.add(playerId);

  @override
  Future<void> pause(int playerId) async => playing.remove(playerId);

  @override
  Future<void> setLooping(int playerId, bool looping) async {}

  @override
  Future<void> setVolume(int playerId, double volume) async {}

  @override
  Future<void> setPlaybackSpeed(int playerId, double speed) async =>
      speeds.add(speed);

  @override
  Future<void> seekTo(int playerId, Duration position) async {}

  @override
  Future<Duration> getPosition(int playerId) async => Duration.zero;

  @override
  Widget buildView(int playerId) => const SizedBox();

  @override
  Future<void> setMixWithOthers(bool mixWithOthers) async {}
}

/// Starts the whole app, wired to the test API exactly as main() wires it to
/// the real one, except that the login token is kept in memory.
Future<void> pumpApp(
  WidgetTester tester, {
  bool allowTestFontOverflow = false,
}) async {
  await tester.binding.setSurfaceSize(const Size(390, 844));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  if (allowTestFontOverflow) _ignoreTestFontOverflow();

  final tokens = MemoryTokens();
  final api = ApiClient(
    tokens: tokens,
    dio: Dio(
      BaseOptions(
        baseUrl: '$testServer/api',
        connectTimeout: ApiClient.connectTimeout,
        receiveTimeout: ApiClient.receiveTimeout,
      ),
    ),
  );
  final catalog = CatalogService(api);
  final repository = ApiRepository(client: api, tokens: tokens)
    ..useCatalog(catalog);
  await tester.pumpWidget(
    ShortReelApp(repository: repository, catalog: catalog, api: api),
  );
  await tester.pumpAndSettle();
}

/// Tests draw text in Flutter's square test font, where every glyph is as wide
/// as the font is tall, far wider than Thai in a real font. A few tight rows
/// then report an overflow that does not happen on a phone, so only that error
/// is ignored, and only by the tests that ask for it.
void _ignoreTestFontOverflow() {
  final original = FlutterError.onError;
  FlutterError.onError = (details) {
    if (details.exceptionAsString().contains('A RenderFlex overflowed')) {
      return;
    }
    original?.call(details);
  };
  addTearDown(() => FlutterError.onError = original);
}

/// Pumps until [finder] matches, while the API answers in real time.
Future<void> waitFor(
  WidgetTester tester,
  Finder finder, {
  Duration timeout = const Duration(seconds: 15),
}) async {
  final end = DateTime.now().add(timeout);
  while (finder.evaluate().isEmpty) {
    if (DateTime.now().isAfter(end)) {
      throw TestFailure('Timed out waiting for $finder');
    }
    await tester.pump(const Duration(milliseconds: 100));
  }
  await tester.pump();
}

/// Pumps until [condition] holds.
Future<void> waitUntil(
  WidgetTester tester,
  bool Function() condition, {
  String reason = 'a condition',
  Duration timeout = const Duration(seconds: 15),
}) async {
  final end = DateTime.now().add(timeout);
  while (!condition()) {
    if (DateTime.now().isAfter(end)) {
      throw TestFailure('Timed out waiting for $reason');
    }
    await tester.pump(const Duration(milliseconds: 100));
  }
  await tester.pump();
}

/// Lets requests that need no visible change finish.
Future<void> settle(WidgetTester tester) async {
  await tester.pump(const Duration(milliseconds: 800));
  await tester.pumpAndSettle();
}

Future<void> logIn(
  WidgetTester tester,
  String username, {
  bool allowTestFontOverflow = false,
}) async {
  await pumpApp(tester, allowTestFontOverflow: allowTestFontOverflow);
  await tester.enterText(find.byKey(const Key('login-username')), username);
  await tester.enterText(
    find.byKey(const Key('login-password')),
    passwords[username] ?? 'wrong',
  );
  await tester.tap(find.widgetWithText(FilledButton, th('Log in')));
  await waitFor(tester, find.byType(NavigationBar));
}

Future<void> enterAsGuest(WidgetTester tester) async {
  await pumpApp(tester);
  await tester.tap(text('Watch free episodes without an account'));
  await waitFor(tester, find.byType(NavigationBar));
}

Finder navTab(String english) => find.descendant(
  of: find.byType(NavigationBar),
  matching: find.text(th(english)),
);

Future<void> openTab(WidgetTester tester, String english) async {
  await tester.tap(navTab(english));
  await settle(tester);
}

/// Takes the app down so every video player is disposed before the test ends.
/// Requests still in flight (the feed loads on every tab) are let finish
/// first, so none of them answers a controller that is gone.
Future<void> closeApp(WidgetTester tester) async {
  await settle(tester);
  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(milliseconds: 300));
}
