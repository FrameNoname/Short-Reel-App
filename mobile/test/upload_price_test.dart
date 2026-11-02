import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shortreel/data/app_repository.dart';
import 'support/mock_repository.dart';

import 'app_shell_test.dart' show logIn;

Future<void> openUpload(WidgetTester tester) async {
  await logIn(tester, 'kestrel_studio');
  await tester.tap(find.byTooltip('Upload'));
  await tester.pumpAndSettle();
}

Future<void> reveal(WidgetTester tester, Finder finder) async {
  await tester.scrollUntilVisible(
    finder,
    200,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.pumpAndSettle();
}

Future<void> fillDetails(WidgetTester tester) async {
  await tester.tap(find.text('Choose episode videos'));
  await tester.enterText(find.byKey(const Key('upload-title')), 'Night Bus');
  await tester.enterText(find.byKey(const Key('upload-prompt')), 'A night bus');
  await tester.pumpAndSettle();
  await reveal(tester, find.byType(CheckboxListTile));
  await tester.tap(find.byType(CheckboxListTile));
  await tester.pumpAndSettle();
}

void main() {
  test('a film keeps the price the creator set for each episode', () async {
    final repo = MockRepository();
    final film = await repo.upload(
      creatorId: 3,
      title: 'Night Bus',
      genre: 'Drama',
      aiTool: 'Mixed',
      promptCredit: 'Prompt',
      episodes: const [
        EpisodeDraft(fileName: 'a.mp4', priceCoins: 0),
        EpisodeDraft(fileName: 'b.mp4', priceCoins: 35),
        EpisodeDraft(fileName: 'c.mp4', priceCoins: 120),
      ],
    );
    final prices = (await repo.episodes(
      film.id,
    )).map((e) => e.priceCoins).toList();
    expect(prices, [0, 35, 120]);

    final pricing = await repo.pricingOf(film.id);
    expect(pricing.freeCount, 1);
    expect(pricing.paidCount, 2);
    expect(pricing.priceCoins, 35);
    expect(pricing.maxPriceCoins, 120);
    expect(pricing.hasMixedPrices, isTrue);
  });

  testWidgets('a creator can price a paid episode with any amount', (
    tester,
  ) async {
    await openUpload(tester);
    await fillDetails(tester);

    // Episode 2 is paid by default and starts at 20 coins.
    final price = find.byKey(const Key('episode-2-price'));
    await reveal(tester, price);
    await tester.enterText(price, '35');
    await tester.pumpAndSettle();

    final submit = find.widgetWithText(FilledButton, 'Submit for review');
    expect(tester.widget<FilledButton>(submit).onPressed, isNotNull);
    await tester.tap(submit);
    await tester.pumpAndSettle();
    expect(find.text('Submitted. Waiting for admin review.'), findsOneWidget);
  });

  testWidgets('an empty or zero price blocks the submit', (tester) async {
    await openUpload(tester);
    await fillDetails(tester);

    final price = find.byKey(const Key('episode-2-price'));
    await reveal(tester, price);
    await tester.enterText(price, '0');
    await tester.pumpAndSettle();

    expect(find.text('Enter 1 to 500 coins.'), findsOneWidget);
    final submit = find.widgetWithText(
      FilledButton,
      'Set a price for every paid episode',
    );
    expect(tester.widget<FilledButton>(submit).onPressed, isNull);
  });

  testWidgets('a quick price chip fills the field', (tester) async {
    await openUpload(tester);
    await tester.tap(find.text('Choose episode videos'));
    await tester.pumpAndSettle();

    final price = find.byKey(const Key('episode-2-price'));
    await reveal(tester, price);
    await tester.tap(find.widgetWithText(ActionChip, '50'));
    await tester.pumpAndSettle();
    expect(tester.widget<TextField>(price).controller!.text, '50');
  });

  testWidgets('a free episode hides the price field', (tester) async {
    await openUpload(tester);
    await tester.tap(find.text('Choose episode videos'));
    await tester.pumpAndSettle();
    await reveal(tester, find.byKey(const Key('episode-2-price')));
    expect(find.byKey(const Key('episode-1-price')), findsNothing);
    expect(find.byKey(const Key('episode-2-price')), findsOneWidget);
  });
}
