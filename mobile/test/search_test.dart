// Person 3: search.
import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:shortreel/controllers/film_search_controller.dart';
import 'package:shortreel/models/film.dart';

import 'support/fake_repository.dart';
import 'support/helpers.dart';

void main() {
  late FakeRepository repo;

  setUp(() => repo = FakeRepository());

  group('FilmSearchController', () {
    test('apply finds films by title', () async {
      repo.filmList = [
        testFilm(1, 'Salt & Signal'),
        testFilm(2, 'Paper Moons'),
      ];
      final search = FilmSearchController(repo);
      await search.apply('paper');
      expect(search.results.map((f) => f.title), ['Paper Moons']);
      expect(search.error, isNull);
    });

    test(
      'a slow answer for an old word does not replace the newer one',
      () async {
        repo.filmList = [
          testFilm(1, 'Salt & Signal'),
          testFilm(2, 'Paper Moons'),
        ];
        repo.filmGates['s'] = Completer<List<Film>>();
        final search = FilmSearchController(repo);

        final old = search.apply('s');
        await search.apply('paper');
        repo.filmGates['s']!.complete([testFilm(1, 'Salt & Signal')]);
        await old;

        expect(search.query, 'paper');
        expect(search.results.map((f) => f.title), ['Paper Moons']);
      },
    );

    test('a failed search clears the results and shows why', () async {
      repo.filmsError = serverDown;
      final search = FilmSearchController(repo);
      await search.apply('x');
      expect(search.results, isEmpty);
      expect(search.error, 'Cannot reach the server');
    });

    test('typing searches once, after the pause, for the last word', () async {
      repo.filmList = [
        testFilm(1, 'Salt & Signal'),
        testFilm(2, 'Paper Moons'),
      ];
      final search = FilmSearchController(repo);
      Iterable<String> filmCalls() =>
          repo.calls.where((c) => c.startsWith('films'));
      for (final word in ['p', 'pa', 'pap', 'paper']) {
        search.type(word);
        await Future<void>.delayed(const Duration(milliseconds: 50));
      }
      expect(filmCalls(), isEmpty);
      await Future<void>.delayed(
        FilmSearchController.typingPause + const Duration(milliseconds: 100),
      );
      expect(filmCalls(), ['films paper']);
      expect(search.results.map((f) => f.title), ['Paper Moons']);
      search.dispose();
    });

    test('trending is the five most liked films', () async {
      repo.filmList = [
        for (var i = 1; i <= 7; i++) testFilm(i, 'Film $i', likes: i),
      ];
      final search = FilmSearchController(repo);
      await search.loadTrending();
      expect(search.trending.map((f) => f.id), [7, 6, 5, 4, 3]);
    });

    test('recent searches stay unique, newest first, at most eight', () {
      final search = FilmSearchController(repo);
      for (var i = 0; i < 10; i++) {
        search.remember('word $i');
      }
      search.remember('WORD 5');
      search.remember('   ');
      expect(search.recent.length, 8);
      expect(search.recent.first, 'WORD 5');
      expect(search.recent.where((t) => t.toLowerCase() == 'word 5').length, 1);

      search.forget('WORD 5');
      expect(search.recent, isNot(contains('WORD 5')));
      search.clearRecent();
      expect(search.recent, isEmpty);
    });
  });
}
