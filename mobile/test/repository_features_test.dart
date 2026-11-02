import 'package:flutter_test/flutter_test.dart';
import 'package:shortreel/controllers/auth_controller.dart';
import 'package:shortreel/controllers/wallet_controller.dart';
import 'support/mock_repository.dart';
import 'package:shortreel/services/api_client.dart';

void main() {
  late MockRepository repo;

  setUp(() => repo = MockRepository());

  test('a report reaches the admin list', () async {
    await repo.reportFilm(6, 3, 'Misleading AI label');
    final report = (await repo.openReports()).last;
    expect(report.filmId, 3);
    expect(report.reason, 'Misleading AI label');
  });

  test('taking a film down closes its reports', () async {
    await repo.review(2, 'taken_down', note: 'Confirmed report');
    expect((await repo.openReports()).where((r) => r.filmId == 2), isEmpty);
  });

  test('a comment appears first and raises the count', () async {
    final before = (await repo.films()).first.commentCount;
    await repo.addComment(6, 1, '  Great twist  ');
    final comment = repo.commentsOf(1).first;
    expect(comment.body, 'Great twist');
    expect(comment.username, 'viewer01');
    expect((await repo.films()).first.commentCount, before + 1);
  });

  test('an empty comment is refused', () {
    expect(
      () => repo.addComment(6, 1, '   '),
      throwsA(
        isA<ApiException>().having((e) => e.code, 'code', 'VALIDATION_ERROR'),
      ),
    );
  });

  test('a comment can be removed', () {
    repo.addComment(6, 2, 'Remove me');
    repo.removeComment(repo.commentsOf(2).first.id);
    expect(repo.commentsOf(2).map((c) => c.body), isNot(contains('Remove me')));
  });

  test('editing a rejected film sends it back for review', () async {
    await repo.updateFilm(
      7,
      title: 'Night Tram',
      genre: 'Thriller',
      aiTool: 'Mixed',
      promptCredit: 'Prompt: last tram of the night',
    );
    final film = (await repo.filmsOf(4)).firstWhere((f) => f.id == 7);
    expect(film.status, 'pending');
    expect(film.reviewNote, isNull);
    expect(film.promptCredit, 'Prompt: last tram of the night');
  });

  test('editing an approved film keeps it live', () async {
    await repo.updateFilm(
      3,
      title: 'Ember Protocol 2',
      genre: 'Sci-Fi',
      aiTool: 'Mixed',
      promptCredit: 'Prompt: android',
    );
    final film = (await repo.filmsOf(4)).firstWhere((f) => f.id == 3);
    expect(film.status, 'approved');
    expect(film.title, 'Ember Protocol 2');
    expect(film.genreName, 'Sci-Fi');
  });

  test('a film with no sales can be deleted', () async {
    await repo.deleteFilm(7);
    expect((await repo.filmsOf(4)).map((f) => f.id), isNot(contains(7)));
  });

  test('a film with paid unlocks cannot be deleted', () async {
    await expectLater(
      repo.deleteFilm(1),
      throwsA(isA<ApiException>().having((e) => e.code, 'code', 'CONFLICT')),
    );
  });

  test('cancelling Plus keeps access until the end date', () async {
    await repo.cancelSubscription(4);
    final plan = await repo.subscriptionOf(4);
    expect(plan, isNotNull);
    expect(plan!.isCancelled, isTrue);
  });

  test('live films are the approved ones', () async {
    expect(await repo.liveFilms(), hasLength(4));
  });

  test('pricing summarises the episodes of a film', () async {
    final pricing = await repo.pricingOf(3);
    expect(pricing.freeCount, 2);
    expect(pricing.paidCount, 6);
    expect(pricing.priceCoins, 20);
  });

  test('the plan price is shown in dollars', () async {
    final auth = AuthController(repo);
    await auth.login('viewer01', '6666');
    expect(WalletController(repo, auth).planPrice, r'$6.99');
  });

  test('prices come from one place', () {
    expect(repo.episodePriceCoins, 20);
    expect(repo.subscriptionPriceUsd, 6.99);
  });
}
