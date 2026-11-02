import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'support/mock_repository.dart';
import 'package:shortreel/main.dart';
import 'package:shortreel/views/auth/login_view.dart';
import 'package:shortreel/views/onboarding/onboarding_view.dart';

Future<void> pumpFirstRun(WidgetTester tester) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ShortReelApp(repository: MockRepository(), showOnboarding: true),
  );
  await tester.pumpAndSettle();
}

Future<void> toLastSlide(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('onboarding-next')));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const Key('onboarding-next')));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('a first run opens on the slides, not the login', (tester) async {
    await pumpFirstRun(tester);
    expect(find.byType(OnboardingView), findsOneWidget);
    expect(find.byType(LoginView), findsNothing);
    expect(find.text('Watch AI short films'), findsOneWidget);
  });

  testWidgets('the app still opens on login when onboarding is off', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(ShortReelApp(repository: MockRepository()));
    await tester.pumpAndSettle();
    expect(find.byType(LoginView), findsOneWidget);
  });

  testWidgets('Next walks through the three slides', (tester) async {
    await pumpFirstRun(tester);
    await tester.tap(find.byKey(const Key('onboarding-next')));
    await tester.pumpAndSettle();
    expect(find.text('Unlock with coins or Plus'), findsOneWidget);

    await tester.tap(find.byKey(const Key('onboarding-next')));
    await tester.pumpAndSettle();
    expect(find.text('Pick what you like'), findsOneWidget);
    expect(find.byKey(const Key('onboarding-start')), findsOneWidget);
    expect(find.byKey(const Key('onboarding-skip')), findsNothing);
  });

  testWidgets('Skip goes straight to the login screen', (tester) async {
    await pumpFirstRun(tester);
    await tester.tap(find.byKey(const Key('onboarding-skip')));
    await tester.pumpAndSettle();
    expect(find.byType(LoginView), findsOneWidget);
  });

  testWidgets('Get started without picking anything also continues', (
    tester,
  ) async {
    await pumpFirstRun(tester);
    await toLastSlide(tester);
    await tester.tap(find.byKey(const Key('onboarding-start')));
    await tester.pumpAndSettle();
    expect(find.byType(LoginView), findsOneWidget);
  });

  testWidgets('genres can be picked and unpicked', (tester) async {
    await pumpFirstRun(tester);
    await toLastSlide(tester);

    Color? fill(String genre) {
      final box = tester.widget<AnimatedContainer>(
        find.descendant(
          of: find.byKey(Key('genre-$genre')),
          matching: find.byType(AnimatedContainer),
        ),
      );
      return (box.decoration as BoxDecoration).color;
    }

    final before = fill('Sci-Fi');
    await tester.tap(find.byKey(const Key('genre-Sci-Fi')));
    await tester.pumpAndSettle();
    expect(fill('Sci-Fi'), isNot(before));
    await tester.tap(find.byKey(const Key('genre-Sci-Fi')));
    await tester.pumpAndSettle();
    expect(fill('Sci-Fi'), before);
  });

  testWidgets('picked genres lead the feed', (tester) async {
    await pumpFirstRun(tester);
    await toLastSlide(tester);
    await tester.tap(find.byKey(const Key('genre-Sci-Fi')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('onboarding-start')));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Watch free episodes without an account'));
    await tester.pumpAndSettle();
    // Ember Protocol is the Sci-Fi film; without a choice Salt & Signal leads.
    expect(find.textContaining('EMBER PROTOCOL'), findsOneWidget);
  });

  testWidgets('without a choice the feed keeps its usual order', (
    tester,
  ) async {
    await pumpFirstRun(tester);
    await tester.tap(find.byKey(const Key('onboarding-skip')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Watch free episodes without an account'));
    await tester.pumpAndSettle();
    expect(find.textContaining('SALT & SIGNAL'), findsOneWidget);
  });
}
