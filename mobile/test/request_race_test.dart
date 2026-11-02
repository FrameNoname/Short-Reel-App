import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:shortreel/controllers/feed_controller.dart';
import 'package:shortreel/controllers/film_search_controller.dart';
import 'package:shortreel/data/film_filter.dart';
import 'support/mock_repository.dart';
import 'package:shortreel/models/film.dart';
import 'package:shortreel/services/video_picker.dart';
import 'package:shortreel/services/api_client.dart';

/// Answers `films` from a completer per call so the test decides the order.
class _SlowRepo extends MockRepository {
  final List<Completer<List<Film>>> pending = [];
  final List<FilmFilter> asked = [];

  @override
  Future<List<Film>> films([FilmFilter filter = const FilmFilter()]) {
    asked.add(filter);
    final c = Completer<List<Film>>();
    pending.add(c);
    return c.future;
  }
}

void main() {
  late List<Film> all;
  setUp(() async => all = await MockRepository().films());

  test(
    'an older search answer that arrives last does not replace the newer one',
    () async {
      final repo = _SlowRepo();
      final search = FilmSearchController(repo);
      final first = search.apply(const FilmFilter(query: 'salt'));
      final second = search.apply(const FilmFilter(query: 'ember'));
      repo.pending[1].complete([all[1]]); // the newer answer comes first
      await second;
      expect(search.results.map((f) => f.id), [all[1].id]);
      repo.pending[0].complete([all[0], all[2]]); // the old one limps in
      await first;
      expect(search.results.map((f) => f.id), [
        all[1].id,
      ], reason: 'stale answer is dropped');
      expect(search.filter.query, 'ember');
    },
  );

  test(
    'an old failed search cannot show an error over a newer good answer',
    () async {
      final repo = _SlowRepo();
      final search = FilmSearchController(repo);
      final first = search.apply(const FilmFilter(query: 'a'));
      final second = search.apply(const FilmFilter(query: 'b'));
      repo.pending[1].complete([all[0]]);
      await second;
      repo.pending[0].completeError(
        const ApiException(code: 'NETWORK_ERROR', message: 'down'),
      );
      await first;
      expect(search.error, isNull);
      expect(search.results, isNotEmpty);
    },
  );

  test(
    'the feed keeps the tab that was chosen last, whatever order answers arrive in',
    () async {
      final repo = _SlowRepo();
      final feed = FeedController(repo);
      final forYou = feed.load(null); // slow
      final second = feed.load(null); // the newer load
      repo.pending[1].complete([all[1]]);
      await second;
      repo.pending[0].complete([all[0]]);
      await forYou;
      expect(feed.films.map((f) => f.id), [all[1].id]);
      expect(feed.isLoading, isFalse);
    },
  );

  test(
    'videos over 200 MB, or over 600 MB together, are refused before any byte is read',
    () {
      const mb = 1024 * 1024;
      expect(() => checkVideoSizes([10 * mb, 150 * mb]), returnsNormally);
      expect(() => checkVideoSizes([201 * mb]), throwsA(isA<ApiException>()));
      expect(
        () => checkVideoSizes([200 * mb, 200 * mb, 201 * mb]),
        throwsA(isA<ApiException>()),
      );
      expect(
        () => checkVideoSizes([200 * mb, 200 * mb, 200 * mb, 1]),
        throwsA(isA<ApiException>()),
      );
    },
  );
}
