import 'package:flutter_test/flutter_test.dart';
import 'package:shortreel/models/episode.dart';
import 'package:shortreel/models/film.dart';
import 'package:shortreel/models/subscription.dart';
import 'package:shortreel/models/transaction.dart';
import 'package:shortreel/models/user.dart';

void main() {
  test('Episode maps MySQL tinyint to bool', () {
    final e = Episode.fromJson({
      'id': 1,
      'film_id': 2,
      'episode_no': 3,
      'title': null,
      'duration_sec': 60,
      'is_free': 1,
      'price_coins': 0,
    });
    expect(e.isFree, isTrue);
    expect(e.title, isNull);
  });

  test('Subscription parses mysql2 DECIMAL strings', () {
    final s = Subscription.fromJson({
      'id': 1,
      'price_usd': '6.99',
      'start_date': '2026-10-01',
      'end_date': '2026-10-31',
    });
    expect(s.priceUsd, 6.99);
    expect(s.endDate, DateTime(2026, 10, 31));
  });

  test('User maps role and tolerates a null display_name', () {
    final u = User.fromJson({
      'id': 1,
      'username': 'a',
      'display_name': null,
      'role': 'creator',
      'coin_balance': 0,
    });
    expect(u.role, UserRole.creator);
    expect(u.displayName, isNull);
  });

  test('Film and Transaction keep their key fields', () {
    final f = Film.fromJson({
      'id': 1,
      'creator_id': 2,
      'title': 'T',
      'genre_id': 1,
      'ai_tool_id': 1,
      'is_ai_generated': 1,
      'status': 'approved',
    });
    expect(f.isAiGenerated, isTrue);
    final t = Transaction.fromJson({
      'id': 1,
      'type': 'unlock',
      'amount': -20,
      'balance_after': 80,
      'created_at': '2026-10-31T10:00:00',
    });
    expect(t.amount, -20);
  });
}
