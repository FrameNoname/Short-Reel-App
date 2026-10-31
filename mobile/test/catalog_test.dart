import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shortreel/controllers/catalog_controller.dart';
import 'package:shortreel/data/film_filter.dart';
import 'package:shortreel/data/mock_repository.dart';
import 'package:shortreel/main.dart';
import 'package:shortreel/models/catalog.dart';
import 'package:shortreel/services/api_client.dart';
import 'package:shortreel/services/catalog_service.dart';

import 'api_client_test.dart';

CatalogService serviceFor(FakeAdapter adapter) {
  final dio = Dio(BaseOptions(baseUrl: 'http://api.test/api'))
    ..httpClientAdapter = adapter;
  return CatalogService(ApiClient(tokens: MemoryTokenStore('t'), dio: dio));
}

const _dramas = '''
{"platform":{"id":19,"name":"FreeReels"},"page":1,"page_size":20,"total":1,
 "total_pages":2,"items":[{"id":123,"title":"Sample","description":"d",
 "episode_count":34,"genres":["a","b"],"thai_dub":false,"thai_sub":true,
 "poster":"https://p/1.jpg"}]}''';

const _episodes = '''
{"episodes":[{"episode":2,"parts":[
 {"part":1,"of":2,"url":"https://v/1.mp4","subtitles":[
   {"language":"en","url":"https://s/en.vtt","forced":false},
   {"language":"th","url":"https://s/forced.vtt","forced":true},
   {"language":"th","url":"https://s/th.vtt","forced":false}]},
 {"part":2,"of":2,"url":"https://v/2.mp4"}]}]}''';

void main() {
  catalogFeedTests();
  test('reads a page of dramas', () async {
    final page = await serviceFor(FakeAdapter(200, _dramas)).dramas(19);
    expect(page.hasMore, isTrue);
    expect(page.items.single.title, 'Sample');
    expect(page.items.single.genres, ['a', 'b']);
    expect(page.items.single.thaiSub, isTrue);
  });

  test('asks for a single episode and keeps part order', () async {
    final adapter = FakeAdapter(200, _episodes);
    final parts = await serviceFor(adapter).episodeParts(123, 2);
    expect(adapter.lastRequest!.path, '/catalog/dramas/123/episodes');
    expect(adapter.lastRequest!.queryParameters['ep'], 2);
    expect(parts.map((p) => p.url), ['https://v/1.mp4', 'https://v/2.mp4']);
  });

  test('picks the full Thai subtitle, not the forced one', () async {
    final parts = await serviceFor(
      FakeAdapter(200, _episodes),
    ).episodeParts(1, 2);
    expect(parts.first.thaiSubtitleUrl, 'https://s/th.vtt');
    expect(parts.last.thaiSubtitleUrl, isNull);
  });

  test('lists only platforms the account can use', () async {
    final adapter = FakeAdapter(
      200,
      '{"page":1,"total_pages":1,"items":['
      '{"id":1,"name":"A","title":"t","has_access":true},'
      '{"id":2,"name":"B","title":"u","has_access":false}]}',
    );
    // One reply serves both calls: the platform list, then the first page.
    final controller = CatalogController(serviceFor(adapter));
    await controller.load();
    expect(controller.platforms.map((p) => p.name), ['A']);
    expect(controller.platform?.id, 1);
  });

  test('shows the backend message when a call fails', () async {
    final adapter = FakeAdapter(
      403,
      '{"error":{"code":"CATALOG_NO_ACCESS","message":"No access"}}',
    );
    final controller = CatalogController(serviceFor(adapter));
    await controller.load();
    expect(controller.error, 'No access');
    expect(controller.isLoading, isFalse);
  });

  test('fetches a subtitle file as plain text', () async {
    const vtt = 'WEBVTT 00:00.000 --> 00:01.000 สวัสดี';
    final dio = Dio()
      ..httpClientAdapter = FakeAdapter(200, vtt, contentType: 'text/vtt');
    final service = CatalogService(
      ApiClient(tokens: MemoryTokenStore()),
      subtitleClient: dio,
    );
    expect(await service.fetchSubtitle('https://vtt.test/a.vtt'), vtt);
  });

  test('a subtitle that cannot be fetched is just missing', () async {
    final dio = Dio()..httpClientAdapter = FakeAdapter(404, 'nope');
    final service = CatalogService(
      ApiClient(tokens: MemoryTokenStore()),
      subtitleClient: dio,
    );
    expect(await service.fetchSubtitle('https://vtt.test/a.vtt'), isNull);
  });

  test('episode parts of an empty reply are empty', () {
    expect(episodePartsFromJson({'episodes': []}), isEmpty);
    expect(
      const CatalogPage(items: [], page: 2, totalPages: 2).hasMore,
      isFalse,
    );
  });
}

void catalogFeedTests() {
  group('catalog films in the feed', () {
    CatalogService service() => serviceFor(
      FakeAdapter(
        200,
        '{"page":1,"total_pages":1,"items":[{"id":7,"name":"A","has_access":true,'
        '"title":"Series Seven","description":"d","episode_count":3,'
        '"genres":["Drama"],"poster":"https://p/7.jpg"}]}',
      ),
    );

    test('are owned by the admin and listed first', () async {
      final repo = MockRepository()..useCatalog(service());
      final films = await repo.films();
      final film = films.first;
      expect(film.title, 'Series Seven');
      expect(film.catalogDramaId, 7);
      expect(film.creatorId, 1);
      expect(film.isAiGenerated, isFalse);
      expect(film.episodeCount, 3);
      expect(films.length, greaterThan(1));
      expect(repo.filmsOf(1).map((f) => f.id), contains(film.id));
    });

    test('have free episodes and survive a like', () async {
      final repo = MockRepository()..useCatalog(service());
      final film = (await repo.films()).first;
      final episodes = await repo.episodes(film.id);
      expect(episodes.map((e) => e.isFree), everyElement(isTrue));
      expect(episodes, hasLength(3));
      repo.toggleLike(6, film.id);
      expect(repo.filmById(film.id)!.catalogDramaId, 7);
    });

    testWidgets('a long series fits in the episodes sheet', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final adapter = FakeAdapter(
        200,
        '{"page":1,"total_pages":1,"items":[{"id":7,"name":"A","has_access":true,'
        '"title":"Long Series","episode_count":60,"genres":[],'
        '"poster":"https://p/long.jpg"}]}',
      );
      final catalog = serviceFor(adapter);
      final repo = MockRepository()..useCatalog(catalog);
      await tester.pumpWidget(ShortReelApp(repository: repo, catalog: catalog));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('login-username')),
        'viewer01',
      );
      await tester.enterText(find.byKey(const Key('login-password')), '6666');
      await tester.tap(find.widgetWithText(FilledButton, 'Log in'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Eps').first);
      await tester.pumpAndSettle();
      expect(find.text('60 episodes · @admin'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    test('any catalog series can be opened as an admin film', () {
      final repo = MockRepository();
      const drama = CatalogDrama(
        id: 99,
        title: 'Elsewhere',
        description: null,
        episodeCount: 2,
        genres: [],
        posterUrl: null,
        thaiDub: false,
        thaiSub: false,
      );
      final film = repo.catalogFilm(drama);
      expect(repo.catalogFilm(drama), same(film));
      expect(film.creatorId, 1);
      expect(repo.filmById(film.id), film);
    });

    test(
      'their genres can be filtered and length does not rule them out',
      () async {
        final repo = MockRepository()..useCatalog(service());
        expect(await repo.films(), isNotEmpty);
        // The test reply has genre "Drama" on its one series.
        expect(repo.catalogGenres(), ['Drama']);
        final byGenre = await repo.films(const FilmFilter(genres: {'Drama'}));
        expect(byGenre.any((f) => f.catalogDramaId == 7), isTrue);
        final short = await repo.films(
          const FilmFilter(length: LengthFilter.from15to30),
        );
        expect(short.any((f) => f.catalogDramaId == 7), isTrue);
      },
    );

    test('a series is listed under every one of its genres', () async {
      final adapter = FakeAdapter(
        200,
        '{"page":1,"total_pages":1,"items":[{"id":9,"name":"A","has_access":true,'
        '"title":"Two Genres","episode_count":2,"genres":["Revenge","Rebirth"],'
        '"poster":"https://p/9.jpg"}]}',
      );
      final repo = MockRepository()..useCatalog(serviceFor(adapter));
      await repo.films();
      expect(repo.catalogGenres(), containsAll(['Revenge', 'Rebirth']));
      final second = await repo.films(const FilmFilter(genres: {'Rebirth'}));
      expect(second.any((f) => f.catalogDramaId == 9), isTrue);
    });

    test('series without artwork stay out of the feed', () async {
      final adapter = FakeAdapter(
        200,
        '{"page":1,"total_pages":1,"items":[{"id":8,"name":"A","has_access":true,'
        '"title":"No Poster","episode_count":2,"genres":[]}]}',
      );
      final repo = MockRepository()..useCatalog(serviceFor(adapter));
      final films = await repo.films();
      expect(films.any((f) => f.catalogDramaId == 8), isFalse);
    });

    test('a failing catalog leaves the demo films', () async {
      final adapter = FakeAdapter(500, '{}');
      final repo = MockRepository()..useCatalog(serviceFor(adapter));
      final films = await repo.films();
      expect(films.any((f) => f.catalogDramaId != null), isFalse);
      expect(films, isNotEmpty);
    });
  });
}
