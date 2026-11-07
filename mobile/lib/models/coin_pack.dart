class CoinPack {
  const CoinPack({
    required this.id,
    required this.name,
    required this.coins,
    required this.priceUsd,
  });

  final int id;
  final String name;
  final int coins;
  final double priceUsd;

  factory CoinPack.fromJson(Map<String, dynamic> json) => CoinPack(
    id: json['id'] as int,
    name: json['name'] as String,
    coins: json['coins'] as int,
    priceUsd: double.parse(json['price_usd'].toString()),
  );
}

/// What each pack offers compared with the others, worked out from the packs
/// themselves so any pack the admin adds or edits is described correctly.
class CoinPackOffers {
  CoinPackOffers(List<CoinPack> packs) : _packs = packs;

  final List<CoinPack> _packs;

  /// Coins per whole dollar in the cheapest pack, the rate the rest beat.
  late final double _baseRate = () {
    if (_packs.isEmpty) return 0.0;
    final cheapest = _packs.reduce((a, b) => a.priceUsd <= b.priceUsd ? a : b);
    final dollars = cheapest.priceUsd.round();
    return dollars <= 0 ? 0.0 : cheapest.coins / dollars;
  }();

  /// Extra coins over the cheapest pack's rate, or 0.
  int bonusOf(CoinPack pack) {
    final dollars = pack.priceUsd.round();
    if (_baseRate <= 0 || dollars <= 0) return 0;
    final bonus = pack.coins - (_baseRate * dollars).round();
    return bonus > 0 ? bonus : 0;
  }

  /// The pack with the most coins per dollar, when it beats the base rate.
  CoinPack? get bestValue {
    final priced = _packs.where((p) => p.priceUsd > 0).toList();
    if (priced.length < 2) return null;
    final best = priced.reduce(
      (a, b) => a.coins / a.priceUsd >= b.coins / b.priceUsd ? a : b,
    );
    return bonusOf(best) > 0 ? best : null;
  }
}
