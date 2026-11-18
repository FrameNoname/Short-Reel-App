// Person 4: the Transaction model.
import 'package:flutter_test/flutter_test.dart';
import 'package:shortreel/models/transaction.dart';

void main() {
  group('Transaction labels', () {
    Transaction read(Map<String, dynamic> extra) => Transaction.fromJson({
      'id': 1,
      'amount': 10,
      'balance_after': 10,
      'created_at': '2026-11-08T10:00:00Z',
      ...extra,
    });

    test('an unlock names the film and episode', () {
      final t = read({
        'type': 'unlock',
        'film_title': 'Ember',
        'episode_no': 3,
        'price_usd': null,
      });
      expect(t.label, 'Ember, Episode 3');
      expect(t.priceUsd, isNull);
    });

    test('a pack top-up names the pack and keeps its price', () {
      final t = read({
        'type': 'topup',
        'pack_name': 'Starter',
        'price_usd': '0.99',
      });
      expect(t.label, 'Starter pack');
      expect(t.priceUsd, 0.99);
    });

    test('a top-up without a pack is the demo one', () {
      expect(read({'type': 'topup'}).label, 'Demo top-up');
    });
  });
}
