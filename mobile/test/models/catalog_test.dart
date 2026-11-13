// Person 5: the Series Jeen catalog models.
import 'package:flutter_test/flutter_test.dart';
import 'package:shortreel/models/catalog.dart';

void main() {
  group('Catalog models', () {
    test('CatalogDrama reads the API shape with defaults', () {
      final drama = CatalogDrama.fromJson({
        'id': 7,
        'title': 'Drama',
        'poster': 'https://img/cover.jpg',
        'thai_dub': true,
      });
      expect(drama.posterUrl, 'https://img/cover.jpg');
      expect(drama.episodeCount, 0);
      expect(drama.genres, isEmpty);
      expect(drama.thaiDub, isTrue);
      expect(drama.thaiSub, isFalse);
    });

    test('CatalogPlatform has access only when the API says true', () {
      final p = CatalogPlatform.fromJson({'id': 19, 'name': 'FreeReels'});
      expect(p.hasAccess, isFalse);
      expect(p.dramaCount, 0);
    });

    test('CatalogPage has more until the last page', () {
      CatalogPage page(int n) =>
          CatalogPage.fromJson({'items': [], 'page': n, 'total_pages': 3});
      expect(page(1).hasMore, isTrue);
      expect(page(3).hasMore, isFalse);
    });

    test(
      'an episode part keeps the first Thai subtitle that is not forced',
      () {
        final part = EpisodePart.fromJson({
          'url': 'https://v/1.m3u8',
          'subtitles': [
            {'language': 'en', 'url': 'en.vtt'},
            {'language': 'th', 'url': 'forced.vtt', 'forced': true},
            {'language': 'th', 'url': 'th.vtt'},
            {'language': 'th', 'url': 'th2.vtt'},
          ],
        });
        expect(part.thaiSubtitleUrl, 'th.vtt');
        expect(EpisodePart.fromJson({'url': 'x'}).thaiSubtitleUrl, isNull);
      },
    );

    test('episode parts come from the first episode, or none', () {
      final parts = episodePartsFromJson({
        'episodes': [
          {
            'parts': [
              {'url': 'a'},
              {'url': 'b'},
            ],
          },
        ],
      });
      expect(parts.map((p) => p.url), ['a', 'b']);
      expect(episodePartsFromJson({'episodes': []}), isEmpty);
    });
  });
}
