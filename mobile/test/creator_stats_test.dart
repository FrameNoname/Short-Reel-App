import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shortreel/data/app_repository.dart';
import 'package:shortreel/data/mock_repository.dart';
import 'package:shortreel/l10n/thai.dart';
import 'package:shortreel/views/profile/creator_stats.dart';

import 'app_shell_test.dart' show logIn, openTab;

Future<void> openStudio(WidgetTester tester) async {
  await logIn(tester, 'kestrel_studio');
  await openTab(tester, 'Profile');
  await tester.tap(find.text('Creator studio'));
  await tester.pumpAndSettle();
}

String totalValue(WidgetTester tester) {
  final widget = tester.widget(find.byKey(const Key('stat-total')));
  // The app's own Text wraps Flutter's; read what it was given.
  return (widget as dynamic).data as String;
}

void main() {
  group('daily numbers', () {
    test('they add up to the channel totals', () {
      final repo = MockRepository();
      final totals = repo.earningsOf(2);
      final days = repo.dailyStatsOf(2);
      expect(days.length, 60);
      expect(days.fold(0, (s, d) => s + d.views), totals.views);
      expect(days.fold(0, (s, d) => s + d.likes), totals.likes);
      expect(days.fold(0, (s, d) => s + d.coins), totals.coins);
    });

    test('they run oldest to newest and end today', () {
      final days = MockRepository(
        now: DateTime(2026, 10, 31, 9),
      ).dailyStatsOf(2);
      expect(days.last.day, DateTime(2026, 10, 31));
      expect(days.first.day, DateTime(2026, 9, 2));
      for (var i = 1; i < days.length; i++) {
        expect(days[i].day.isAfter(days[i - 1].day), isTrue);
      }
    });

    test('they never go negative and are the same every time', () {
      final repo = MockRepository();
      final a = repo.dailyStatsOf(2);
      final b = repo.dailyStatsOf(2);
      expect(a.map((d) => d.views), b.map((d) => d.views));
      expect(
        a.every((d) => d.views >= 0 && d.likes >= 0 && d.coins >= 0),
        isTrue,
      );
    });

    test('a channel with nothing has flat zero days', () {
      final days = MockRepository().dailyStatsOf(5);
      expect(days.every((d) => d.views == 0 && d.coins == 0), isTrue);
    });

    test('other periods work too', () {
      expect(MockRepository().dailyStatsOf(2, days: 14).length, 14);
    });
  });

  group('chart scale', () {
    test('rounds up to 1, 2 or 5 times a power of ten', () {
      expect(niceChartMax(0), 1);
      expect(niceChartMax(1), 1);
      expect(niceChartMax(3), 5);
      expect(niceChartMax(7), 10);
      expect(niceChartMax(120), 200);
      expect(niceChartMax(480), 500);
      expect(niceChartMax(1300), 2000);
      expect(niceChartMax(41200), 50000);
    });
  });

  group('Thai', () {
    test('the stats wording is translated', () {
      expect(thaiOf('Performance'), 'ผลงาน');
      expect(thaiOf('7 days'), '7 วัน');
      expect(thaiOf('vs previous 30 days'), 'เทียบกับ 30 วันก่อนหน้า');
    });
  });

  group('studio', () {
    testWidgets('shows the performance card and top films', (tester) async {
      await openStudio(tester);
      expect(find.text('Performance'), findsOneWidget);
      expect(find.byKey(const Key('stat-chart')), findsOneWidget);
      expect(find.text('7 days'), findsOneWidget);
      expect(find.text('30 days'), findsOneWidget);
      expect(find.text('vs previous 7 days'), findsOneWidget);

      await tester.scrollUntilVisible(
        find.text('Top films'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.byKey(const Key('top-film-1')), findsOneWidget);
    });

    testWidgets('a longer period shows more', (tester) async {
      await openStudio(tester);
      final week = totalValue(tester);
      await tester.tap(find.byKey(const Key('period-30')));
      await tester.pumpAndSettle();
      expect(find.text('vs previous 30 days'), findsOneWidget);
      expect(totalValue(tester) != week, isTrue);
    });

    testWidgets('another metric changes the total', (tester) async {
      await openStudio(tester);
      final views = totalValue(tester);
      await tester.tap(find.byKey(const Key('metric-likes')));
      await tester.pumpAndSettle();
      expect(totalValue(tester) != views, isTrue);
    });

    testWidgets('tapping a bar shows that day', (tester) async {
      await openStudio(tester);
      String label() =>
          (tester.widget(find.byKey(const Key('stat-selected'))) as dynamic)
                  .data
              as String;
      expect(label(), startsWith('Today'));

      final chart = tester.getTopLeft(find.byKey(const Key('stat-chart')));
      await tester.tapAt(chart + const Offset(60, 80));
      await tester.pumpAndSettle();
      expect(label(), isNot(startsWith('Today')));
    });
  });

  group('card on its own', () {
    List<DailyStat> flat(int views) => [
      for (var i = 0; i < 60; i++)
        DailyStat(
          day: DateTime(2026, 9, 2).add(Duration(days: i)),
          views: views,
          likes: 0,
          coins: 0,
        ),
    ];

    Widget host(List<DailyStat> stats) => MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(child: PerformanceCard(stats: stats)),
      ),
    );

    testWidgets('an empty channel gets a message, not a chart', (tester) async {
      await tester.pumpWidget(host(flat(0)));
      expect(find.byKey(const Key('stat-chart')), findsNothing);
      expect(
        find.text('No data yet. Views, likes and coins show up here.'),
        findsOneWidget,
      );
    });

    testWidgets('a steady channel shows a flat comparison', (tester) async {
      await tester.pumpWidget(host(flat(10)));
      expect(find.byKey(const Key('stat-delta')), findsOneWidget);
      expect(find.text('0%'), findsOneWidget);
    });
  });
}
