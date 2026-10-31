import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shortreel/theme/app_theme.dart';
import 'package:shortreel/views/profile/creator_profile_view.dart';

import 'app_shell_test.dart' show logIn, enterAsGuest;

void main() {
  testWidgets('double tap likes the film and shows a heart', (tester) async {
    await logIn(tester, 'viewer01');
    Color railHeart() =>
        tester.widget<Icon>(find.byIcon(Icons.favorite_rounded)).color!;
    expect(railHeart(), AppColors.text);

    final spot = tester.getCenter(find.textContaining('VIDEO ·'));
    await tester.tapAt(spot);
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tapAt(spot);
    await tester.pump(const Duration(milliseconds: 100));

    // The rail heart is filled and the big burst heart is on screen.
    expect(find.byIcon(Icons.favorite_rounded), findsNWidgets(2));
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.favorite_rounded), findsOneWidget);
    expect(railHeart(), AppColors.danger);
  });

  testWidgets('a single tap pauses and resumes', (tester) async {
    await enterAsGuest(tester);
    final spot = tester.getCenter(find.textContaining('VIDEO ·'));

    await tester.tapAt(spot);
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
    final paused = tester.widget<AnimatedOpacity>(
      find.ancestor(
        of: find.byIcon(Icons.play_arrow_rounded),
        matching: find.byType(AnimatedOpacity),
      ),
    );
    expect(paused.opacity, greaterThan(0));

    await tester.tapAt(spot);
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
    final resumed = tester.widget<AnimatedOpacity>(
      find.ancestor(
        of: find.byIcon(Icons.play_arrow_rounded),
        matching: find.byType(AnimatedOpacity),
      ),
    );
    expect(resumed.opacity, 0);
  });

  testWidgets('the share button offers speed, share and report', (
    tester,
  ) async {
    await enterAsGuest(tester);
    await tester.tap(find.text('Share'));
    await tester.pumpAndSettle();
    expect(find.text('Playback speed'), findsOneWidget);
    expect(find.text('Report'), findsOneWidget);

    await tester.tap(find.text('1.5x'));
    await tester.pumpAndSettle();
    expect(find.text('1.5x speed'), findsOneWidget);
  });

  testWidgets('holding the right edge plays at 2x until release', (
    tester,
  ) async {
    await enterAsGuest(tester);
    // Right edge, between the rail buttons.
    final gesture = await tester.startGesture(const Offset(370, 120));
    await tester.pump(const Duration(milliseconds: 700));
    expect(find.text('2x speed'), findsOneWidget);

    await gesture.up();
    await tester.pumpAndSettle();
    final pill = tester.widget<AnimatedOpacity>(
      find.ancestor(
        of: find.text('1x speed'),
        matching: find.byType(AnimatedOpacity),
      ),
    );
    expect(pill.opacity, 0);
  });

  testWidgets('holding the left side does not speed up', (tester) async {
    await enterAsGuest(tester);
    final gesture = await tester.startGesture(const Offset(60, 400));
    await tester.pump(const Duration(milliseconds: 700));
    expect(find.text('2x speed'), findsNothing);
    await gesture.up();
    await tester.pumpAndSettle();
  });

  testWidgets('a quick swipe left opens the creator channel', (tester) async {
    await enterAsGuest(tester);
    await tester.fling(
      find.textContaining('VIDEO ·'),
      const Offset(-300, 0),
      1500,
    );
    await tester.pumpAndSettle();
    expect(find.byType(CreatorProfileView), findsOneWidget);
  });

  testWidgets('a slow drag to the left does not open the channel', (
    tester,
  ) async {
    await enterAsGuest(tester);
    await tester.drag(find.textContaining('VIDEO ·'), const Offset(-80, 0));
    await tester.pumpAndSettle();
    expect(find.byType(CreatorProfileView), findsNothing);
  });

  testWidgets('an empty Following tab points back to For you', (tester) async {
    await logIn(tester, 'admin');
    await tester.tap(find.text('Following'));
    await tester.pumpAndSettle();
    expect(
      find.text('Follow a creator to see their films here.'),
      findsOneWidget,
    );

    await tester.tap(find.text('Find films for you'));
    await tester.pumpAndSettle();
    expect(find.textContaining('VIDEO ·'), findsOneWidget);
  });
}
