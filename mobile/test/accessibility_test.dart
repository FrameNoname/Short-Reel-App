import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shortreel/data/mock_repository.dart';
import 'package:shortreel/main.dart';
import 'package:shortreel/theme/app_theme.dart';
import 'package:shortreel/widgets/common.dart';

double contrast(Color a, Color b) {
  final x = a.computeLuminance();
  final y = b.computeLuminance();
  final hi = x > y ? x : y;
  final lo = x > y ? y : x;
  return (hi + 0.05) / (lo + 0.05);
}

Future<void> pumpApp(WidgetTester tester) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(ShortReelApp(repository: MockRepository()));
  await tester.pumpAndSettle();
}

void main() {
  test('button text meets 4.5:1 on the primary colour', () {
    expect(
      contrast(Colors.white, AppColors.primary),
      greaterThanOrEqualTo(4.5),
    );
  });

  test('link text meets 4.5:1 on every surface', () {
    for (final surface in [
      AppColors.background,
      AppColors.surface,
      AppColors.surfaceHigh,
      AppColors.primarySoft,
    ]) {
      expect(contrast(AppColors.link, surface), greaterThanOrEqualTo(4.5));
    }
  });

  testWidgets('Forgot password is at least 44 tall', (tester) async {
    await pumpApp(tester);
    final size = tester.getSize(find.byKey(const Key('forgot-password')));
    expect(size.height, greaterThanOrEqualTo(44));
  });

  testWidgets('Follow is at least 44 tall', (tester) async {
    await pumpApp(tester);
    await tester.tap(find.text('Watch free episodes without an account'));
    await tester.pumpAndSettle();
    final size = tester.getSize(find.byKey(const Key('follow-button')));
    expect(size.height, greaterThanOrEqualTo(44));
  });

  testWidgets('feed actions have spoken labels', (tester) async {
    final semantics = tester.ensureSemantics();
    await pumpApp(tester);
    await tester.tap(find.text('Watch free episodes without an account'));
    await tester.pumpAndSettle();
    expect(find.bySemanticsLabel(RegExp('^Like')), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp('^Comments')), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp('^Report')), findsOneWidget);
    semantics.dispose();
  });

  testWidgets('posters are described for screen readers', (tester) async {
    final semantics = tester.ensureSemantics();
    final film = (await MockRepository().films()).first;
    await tester.pumpWidget(MaterialApp(home: FilmPoster(film: film)));
    expect(find.bySemanticsLabel('Poster of ${film.title}'), findsOneWidget);
    semantics.dispose();
  });
}
