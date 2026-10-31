import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shortreel/l10n/app_language.dart';
import 'package:shortreel/l10n/thai.dart';

import 'app_shell_test.dart' show enterAsGuest, logIn, openTab;

Future<void> chooseLanguage(WidgetTester tester, String key) async {
  await tester.tap(find.byTooltip('Settings').first);
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(Key(key)));
  await tester.pumpAndSettle();
}

void main() {
  group('thaiOf', () {
    test('translates fixed wording', () {
      expect(thaiOf('Wallet'), 'กระเป๋าเงิน');
      expect(thaiOf('Log in'), 'เข้าสู่ระบบ');
      expect(thaiOf('Drama'), 'ดราม่า');
    });

    test('translates wording that carries a number', () {
      expect(thaiOf('Unlock Episode 3'), 'ปลดล็อกตอนที่ 3');
      expect(thaiOf('20 coins'), '20 เหรียญ');
      expect(thaiOf('8 eps'), '8 ตอน');
      expect(thaiOf('Show 4 films'), 'ดู 4 เรื่อง');
      expect(thaiOf('Enough for 4 episodes'), 'ดูได้ประมาณ 4 ตอน');
      expect(thaiOf('Buy 330 coins for \$4.99'), 'ซื้อ 330 เหรียญ ราคา \$4.99');
    });

    test('translates dates', () {
      expect(thaiOf('Oct 29'), '29 ต.ค.');
      expect(
        thaiOf('Oct 31 to Nov 30, cancel anytime'),
        '31 ต.ค. ถึง 30 พ.ย. ยกเลิกได้ทุกเมื่อ',
      );
    });

    test('translates each part of a dotted line', () {
      expect(thaiOf('@kestrel_studio · Mystery'), '@kestrel_studio · ลึกลับ');
      expect(thaiOf('8 episodes · @noor.frames'), '8 ตอน · @noor.frames');
    });

    test('keeps surrounding spaces', () {
      expect(thaiOf('Added '), 'เติมเข้า ');
      expect(thaiOf(' /mo'), ' /เดือน');
    });

    test('leaves content written by people alone', () {
      expect(thaiOf('Salt & Signal'), 'Salt & Signal');
      expect(thaiOf('The ending of episode 2 was great!'), isNotEmpty);
      expect(thaiOf('@viewer01'), '@viewer01');
      expect(thaiOf('2.3K'), '2.3K');
      expect(thaiOf(''), '');
    });

    test('an unknown sentence stays in English', () {
      expect(
        thaiOf('Something nobody translated'),
        'Something nobody translated',
      );
    });

    test('translate follows the language chosen', () {
      expect(translate('Home', AppLanguage.english), 'Home');
      expect(translate('Home', AppLanguage.thai), 'หน้าแรก');
    });
  });

  group('screens', () {
    testWidgets('the app starts in English', (tester) async {
      await enterAsGuest(tester);
      expect(find.text('Home'), findsOneWidget);
      expect(find.text('หน้าแรก'), findsNothing);
    });

    testWidgets('choosing Thai changes the navigation and the page', (
      tester,
    ) async {
      await enterAsGuest(tester);
      await openTab(tester, 'Profile');
      await chooseLanguage(tester, 'language-thai');

      // The settings page itself switches...
      expect(find.text('การตั้งค่า'), findsOneWidget);
      expect(find.text('ภาษา'), findsWidgets);

      // ...and so does everything behind it, including the const labels.
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.text('หน้าแรก'), findsOneWidget);
      expect(find.text('ค้นหา'), findsOneWidget);
      expect(find.text('กระเป๋าเงิน'), findsOneWidget);
      expect(find.text('Home'), findsNothing);
    });

    testWidgets('Thai reaches the feed, search and wallet', (tester) async {
      await logIn(tester, 'viewer01');
      await openTab(tester, 'Profile');
      await chooseLanguage(tester, 'language-thai');
      await tester.pageBack();
      await tester.pumpAndSettle();

      await openTab(tester, 'หน้าแรก');
      expect(find.text('สำหรับคุณ'), findsOneWidget);
      expect(find.text('แชร์'), findsOneWidget);

      await openTab(tester, 'ค้นหา');
      expect(find.text('ค้นพบ'), findsOneWidget);
      expect(find.text('4 เรื่อง'), findsOneWidget);

      await openTab(tester, 'กระเป๋าเงิน');
      expect(find.text('เติมเหรียญ'), findsWidgets);
      expect(find.text('ประวัติ'), findsOneWidget);
    });

    testWidgets('film titles and comments stay as written', (tester) async {
      await logIn(tester, 'viewer01');
      await openTab(tester, 'Profile');
      await chooseLanguage(tester, 'language-thai');
      await tester.pageBack();
      await tester.pumpAndSettle();

      await openTab(tester, 'หน้าแรก');
      expect(find.text('Salt & Signal'), findsOneWidget);
    });

    testWidgets('switching back to English restores the wording', (
      tester,
    ) async {
      await enterAsGuest(tester);
      await openTab(tester, 'Profile');
      await chooseLanguage(tester, 'language-thai');
      await tester.tap(find.byKey(const Key('language-english')));
      await tester.pumpAndSettle();
      expect(find.text('Settings'), findsOneWidget);
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.text('Home'), findsOneWidget);
    });

    testWidgets('a sheet opened after the change is in Thai', (tester) async {
      await logIn(tester, 'viewer01');
      await openTab(tester, 'Profile');
      await chooseLanguage(tester, 'language-thai');
      await tester.pageBack();
      await tester.pumpAndSettle();
      await openTab(tester, 'หน้าแรก');

      await tester.tap(find.text('ตอน').first);
      await tester.pumpAndSettle();
      expect(find.text('8 ตอน · @kestrel_studio'), findsOneWidget);
      expect(find.text('ดูได้ทุกตอน'), findsOneWidget);
    });
  });
}
