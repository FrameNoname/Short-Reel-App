import 'package:flutter_test/flutter_test.dart';
import 'package:shortreel/data/app_repository.dart';
import 'package:shortreel/data/film_filter.dart';
import 'package:shortreel/data/mock_repository.dart';
import 'package:shortreel/models/user.dart';
import 'package:shortreel/services/api_client.dart';

Matcher apiError(String code) =>
    throwsA(isA<ApiException>().having((e) => e.code, 'code', code));

void main() {
  late MockRepository repo;

  setUp(() => repo = MockRepository());

  Future<User> loginAs(String username, String password) =>
      repo.login(username, password);

  group('auth', () {
    test('logs in with a demo account', () async {
      final user = await loginAs('mira.lens', '4444');
      expect(user.role, UserRole.creator);
      expect(user.coinBalance, 142);
    });

    test('rejects a wrong password', () {
      expect(loginAs('mira.lens', 'nope'), apiError('UNAUTHENTICATED'));
    });

    test('rejects a taken username', () {
      expect(
        repo.register('mira.lens', 'abcd1234', UserRole.viewer),
        apiError('CONFLICT'),
      );
    });

    test('registers a new viewer who can log in', () async {
      await repo.register('new.user', 'abcd1234', UserRole.viewer);
      final user = await loginAs('new.user', 'abcd1234');
      expect(user.role, UserRole.viewer);
      expect(user.coinBalance, 0);
    });
  });

  group('films', () {
    test('lists only approved films', () async {
      final films = await repo.films();
      expect(films.map((f) => f.title), [
        'Salt & Signal',
        'Paper Moons',
        'Ember Protocol',
        'ShortReel Intro',
      ]);
    });

    test('filters by genre', () async {
      final films = await repo.films(const FilmFilter(genres: {'Sci-Fi'}));
      expect(films.single.title, 'Ember Protocol');
    });

    test('filters by AI tool', () async {
      final films = await repo.films(
        const FilmFilter(aiTools: {'Image-to-video'}),
      );
      expect(films.single.title, 'Paper Moons');
    });

    test('searches title, creator and prompt', () async {
      expect(
        (await repo.films(const FilmFilter(query: 'noor'))).single.title,
        'Paper Moons',
      );
      expect(
        (await repo.films(const FilmFilter(query: 'lighthouse'))).single.title,
        'Salt & Signal',
      );
    });

    test('an empty search result is empty, not an error', () async {
      expect(await repo.films(const FilmFilter(query: 'zzz')), isEmpty);
    });

    test('length filter uses episode duration', () async {
      final short = await repo.films(
        const FilmFilter(length: LengthFilter.under5),
      );
      expect(short, hasLength(4));
      final long = await repo.films(
        const FilmFilter(length: LengthFilter.from15to30),
      );
      expect(long, isEmpty);
    });
  });

  group('unlock', () {
    test('charges coins and keeps the episode available', () async {
      final user = await loginAs('viewer01', '6666');
      final episode = (await repo.episodes(1))[4];
      expect(repo.accessOf(user.id, episode), EpisodeAccess.locked);

      final updated = await repo.unlock(user.id, episode.id);

      expect(updated.coinBalance, 60);
      expect(repo.accessOf(user.id, episode), EpisodeAccess.unlocked);
    });

    test('a repeated unlock never charges twice', () async {
      final user = await loginAs('viewer01', '6666');
      final episode = (await repo.episodes(1))[4];
      await repo.unlock(user.id, episode.id);
      final again = await repo.unlock(user.id, episode.id);
      expect(again.coinBalance, 60);
      expect(
        repo.transactionsOf(user.id).where((t) => t.type == 'unlock'),
        hasLength(2),
      );
    });

    test('owners watch their own paid episodes', () async {
      final owner = await loginAs('kestrel_studio', '2222');
      final episode = (await repo.episodes(1))[7];
      expect(repo.accessOf(owner.id, episode), EpisodeAccess.unlocked);
    });

    test('refuses when the balance is too low', () async {
      final user = await loginAs('kestrel_studio', '2222');
      final episode = (await repo.episodes(2))[4];
      await expectLater(
        repo.unlock(user.id, episode.id),
        apiError('INSUFFICIENT_COINS'),
      );
    });

    test('splits a creator film 70/30', () async {
      final viewer = await loginAs('viewer01', '6666');
      final before = repo.earningsOf(3).coins;
      await repo.unlock(viewer.id, (await repo.episodes(2))[4].id);
      expect(repo.earningsOf(3).coins, before + 14);
    });

    test('gives an admin film entirely to the admin', () async {
      final viewer = await loginAs('viewer01', '6666');
      final before = repo.adminSales().adminCoins;
      await repo.unlock(viewer.id, (await repo.episodes(5))[4].id);
      expect(repo.adminSales().adminCoins, before + 20);
    });

    test('uses the admin revenue share setting', () async {
      repo.setAdminSharePercent(40);
      final viewer = await loginAs('viewer01', '6666');
      final before = repo.earningsOf(3).coins;
      await repo.unlock(viewer.id, (await repo.episodes(2))[4].id);
      expect(repo.earningsOf(3).coins, before + 12);
    });
  });

  group('wallet and Plus', () {
    test('demo top-up adds coins and history', () async {
      final user = await loginAs('viewer01', '6666');
      final updated = await repo.topUp(user.id, coins: 100);
      expect(updated.coinBalance, 180);
      expect(repo.transactionsOf(user.id).first.amount, 100);
    });

    test('Plus plays every episode without coins', () async {
      final user = await loginAs('viewer01', '6666');
      final episode = (await repo.episodes(1))[7];
      expect(repo.accessOf(user.id, episode), EpisodeAccess.locked);
      await repo.subscribe(user.id);
      expect(repo.accessOf(user.id, episode), EpisodeAccess.plus);
      expect(repo.subscriptionOf(user.id), isNotNull);
    });

    test('free episodes are open to guests', () async {
      final episode = (await repo.episodes(1)).first;
      expect(repo.accessOf(null, episode), EpisodeAccess.free);
    });

    test('paid episodes are locked for guests', () async {
      final episode = (await repo.episodes(1))[2];
      expect(repo.accessOf(null, episode), EpisodeAccess.locked);
    });
  });

  group('upload and review', () {
    test('a new film waits for review and stays out of the feed', () async {
      final creator = await loginAs('noor.frames', '3333');
      final film = await repo.upload(
        creatorId: creator.id,
        title: 'Night Bus',
        genre: 'Drama',
        aiTool: 'Mixed',
        promptCredit: 'Prompt: night bus',
        episodePrices: const [0, 20],
      );
      expect(film.status, 'pending');
      expect(
        (await repo.films()).map((f) => f.title),
        isNot(contains('Night Bus')),
      );
      expect(repo.reviewQueue().map((f) => f.title), contains('Night Bus'));
    });

    test('approving makes a film visible', () async {
      final queued = repo.reviewQueue().first;
      repo.review(queued.id, 'approved');
      expect((await repo.films()).map((f) => f.id), contains(queued.id));
      expect(repo.reviewQueue().map((f) => f.id), isNot(contains(queued.id)));
    });

    test('taking a film down hides it', () async {
      repo.review(1, 'taken_down');
      expect((await repo.films()).map((f) => f.id), isNot(contains(1)));
    });
  });

  group('social', () {
    test('like toggles the count', () async {
      final user = await loginAs('viewer01', '6666');
      final before = (await repo.films()).first.likeCount;
      repo.toggleLike(user.id, 1);
      expect((await repo.films()).first.likeCount, before + 1);
      repo.toggleLike(user.id, 1);
      expect((await repo.films()).first.likeCount, before);
    });
  });
}
