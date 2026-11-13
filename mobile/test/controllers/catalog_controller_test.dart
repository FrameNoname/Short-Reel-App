// Person 5: CatalogController (Series Jeen list, paging, search).
import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:shortreel/controllers/catalog_controller.dart';
import 'package:shortreel/models/catalog.dart';
import 'package:shortreel/services/catalog_service.dart';

import '../support/helpers.dart';

CatalogDrama _drama(int id) => CatalogDrama(
  id: id,
  title: 'Drama $id',
  description: null,
  episodeCount: 10,
  genres: const [],
  posterUrl: null,
  thaiDub: false,
  thaiSub: false,
);

const _open = CatalogPlatform(
  id: 19,
  name: 'FreeReels',
  dramaCount: 0,
  hasAccess: true,
);
const _closed = CatalogPlatform(
  id: 3,
  name: 'Other',
  dramaCount: 0,
  hasAccess: false,
);

/// Answers the controller from lists set per test; [calls] records each ask.
class _FakeCatalog implements CatalogService {
  List<CatalogPlatform> platformList = const [_closed, _open];
  int totalPages = 2;
  Object? error;
  final List<String> calls = [];
  final Map<String, Completer<CatalogPage>> gates = {};

  @override
  Future<List<CatalogPlatform>> platforms() async {
    calls.add('platforms');
    if (error != null) throw error!;
    return platformList;
  }

  @override
  Future<CatalogPage> dramas(
    int platformId, {
    String? query,
    int page = 1,
  }) async {
    final word = query ?? '';
    calls.add('dramas $platformId [$word] $page');
    if (error != null) throw error!;
    final gate = gates[word];
    if (gate != null) return gate.future;
    return CatalogPage(
      items: [_drama(page * 10 + 1), _drama(page * 10 + 2)],
      page: page,
      totalPages: totalPages,
    );
  }

  @override
  Object? noSuchMethod(Invocation invocation) => throw UnimplementedError(
    '_FakeCatalog does not answer ${invocation.memberName}',
  );
}

void main() {
  late _FakeCatalog service;

  setUp(() => service = _FakeCatalog());

  group('CatalogController', () {
    test('load keeps only platforms with access and reads page 1', () async {
      final catalog = CatalogController(service);
      await catalog.load();
      expect(catalog.platforms.map((p) => p.id), [19]);
      expect(catalog.platform?.id, 19);
      expect(catalog.dramas.map((d) => d.id), [11, 12]);
      expect(catalog.hasMore, isTrue);
      expect(catalog.isLoading, isFalse);
    });

    test('load asks for the platforms only once', () async {
      final catalog = CatalogController(service);
      await catalog.load();
      await catalog.load();
      expect(service.calls.where((c) => c == 'platforms').length, 1);
    });

    test('with no platform bought, nothing is listed', () async {
      service.platformList = const [_closed];
      final catalog = CatalogController(service);
      await catalog.load();
      expect(catalog.platform, isNull);
      expect(catalog.dramas, isEmpty);
      expect(service.calls, ['platforms']);
    });

    test('loadMore adds the next page and stops at the last', () async {
      final catalog = CatalogController(service);
      await catalog.load();
      await catalog.loadMore();
      expect(catalog.dramas.map((d) => d.id), [11, 12, 21, 22]);
      expect(catalog.hasMore, isFalse);
      await catalog.loadMore();
      expect(service.calls.last, 'dramas 19 [] 2');
    });

    test('search starts again from page 1 with the trimmed word', () async {
      final catalog = CatalogController(service);
      await catalog.load();
      await catalog.loadMore();
      await catalog.search('  love ');
      expect(catalog.query, 'love');
      expect(service.calls.last, 'dramas 19 [love] 1');
      expect(catalog.dramas.map((d) => d.id), [11, 12]);
    });

    test(
      'a slow answer for an old word does not replace the newer one',
      () async {
        final catalog = CatalogController(service);
        await catalog.load();
        service.gates['old'] = Completer<CatalogPage>();
        final old = catalog.search('old');
        await catalog.search('new');
        service.gates['old']!.complete(
          CatalogPage(items: [_drama(99)], page: 1, totalPages: 1),
        );
        await old;
        expect(catalog.query, 'new');
        expect(catalog.dramas.map((d) => d.id), [11, 12]);
      },
    );

    test('a failed load shows why', () async {
      service.error = serverDown;
      final catalog = CatalogController(service);
      await catalog.load();
      expect(catalog.error, 'Cannot reach the server');
      expect(catalog.isLoading, isFalse);
    });

    test('choosing another platform lists it from page 1', () async {
      final catalog = CatalogController(service);
      await catalog.load();
      await catalog.loadMore();
      await catalog.selectPlatform(_closed);
      expect(catalog.platform?.id, 3);
      expect(service.calls.last, 'dramas 3 [] 1');
      expect(catalog.dramas.map((d) => d.id), [11, 12]);
    });
  });
}
