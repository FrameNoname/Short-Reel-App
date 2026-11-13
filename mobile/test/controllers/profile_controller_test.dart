// Person 1: ProfileController (saved and unlocked films).
import 'package:flutter_test/flutter_test.dart';
import 'package:shortreel/controllers/profile_controller.dart';

import '../support/fake_repository.dart';
import '../support/helpers.dart';

void main() {
  late FakeRepository repo;

  setUp(() => repo = FakeRepository());

  group('ProfileController', () {
    test('load refreshes the library and shows both lists', () async {
      repo.watchlist = [testFilm(1, 'Saved')];
      repo.unlockedFilms = [testFilm(2, 'Bought')];
      final profile = ProfileController(repo);
      var notified = 0;
      profile.addListener(() => notified++);

      await profile.load(2);

      expect(repo.calls, contains('refreshLibrary 2'));
      expect(profile.watchlistOf(2).single.title, 'Saved');
      expect(profile.unlockedFilmsOf(2).single.title, 'Bought');
      expect(notified, 1);
    });

    test('a failed refresh still opens the profile', () async {
      repo.libraryError = serverDown;
      final profile = ProfileController(repo);
      var notified = 0;
      profile.addListener(() => notified++);
      await profile.load(2);
      expect(notified, 1);
      expect(profile.watchlistOf(2), isEmpty);
    });
  });
}
