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
