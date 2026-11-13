// Person 5: CatalogService (the Series Jeen API calls).
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shortreel/services/api_client.dart';
import 'package:shortreel/services/catalog_service.dart';

import '../support/fake_dio.dart';

void main() {
  group('CatalogService', () {
    late List<RequestOptions> sent;
    late CatalogService real;

    setUp(() {
      sent = [];
      real = CatalogService(
        ApiClient(tokens: MemoryTokens(), dio: fakeDio(sent, _answer)),
        subtitleClient: fakeDio(sent, _answer),
      );
    });

    test('platforms reads the list', () async {
      final list = await real.platforms();
      expect(list.single.name, 'FreeReels');
      expect(sent.single.path, '/catalog/platforms');
    });

    test('dramas sends the page, size and word', () async {
      final page = await real.dramas(19, query: 'love', page: 2);
      expect(page.items.single.title, 'Drama');
      expect(sent.single.path, '/catalog/platforms/19/dramas');
      expect(sent.single.queryParameters, {
        'page': 2,
        'page_size': 20,
        'q': 'love',
      });
      await real.dramas(19);
      expect(sent.last.queryParameters.containsKey('q'), isFalse);
    });

    test('episodeParts asks for one episode', () async {
      final parts = await real.episodeParts(21, 6);
      expect(parts.single.url, 'https://v/6.m3u8');
      expect(sent.single.queryParameters, {'ep': 6});
    });

    test('a subtitle is text, or null when it cannot be fetched', () async {
      expect(await real.fetchSubtitle('https://sub/th.vtt'), 'WEBVTT');
      expect(await real.fetchSubtitle('https://sub/missing.vtt'), isNull);
    });
  });
}

/// The backend and subtitle host as CatalogService sees them.
(int, Object?) _answer(RequestOptions request) => switch (request.path) {
  '/catalog/platforms' => (
    200,
    {
      'items': [
        {'id': 19, 'name': 'FreeReels', 'has_access': true},
      ],
    },
  ),
  '/catalog/platforms/19/dramas' => (
    200,
    {
      'items': [
        {'id': 1, 'title': 'Drama'},
      ],
      'page': request.queryParameters['page'],
      'total_pages': 3,
    },
  ),
  '/catalog/dramas/21/episodes' => (
    200,
    {
      'episodes': [
        {
          'parts': [
            {'url': 'https://v/6.m3u8'},
          ],
        },
      ],
    },
  ),
  'https://sub/th.vtt' => (200, 'WEBVTT'),
  _ => (404, {'error': 'not found'}),
};
