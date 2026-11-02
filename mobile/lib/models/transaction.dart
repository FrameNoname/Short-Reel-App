class Transaction {
  const Transaction({
    required this.id,
    required this.type,
    required this.amount,
    required this.balanceAfter,
    required this.createdAt,
    this.label = '',
    this.priceUsd,
  });

  final int id;
  final String type;
  final int amount;
  final int balanceAfter;
  final DateTime createdAt;
  final String label;

  /// What the simulated payment charged; null for unlocks and demo coins.
  final double? priceUsd;

  factory Transaction.fromJson(Map<String, dynamic> json) => Transaction(
    id: json['id'] as int,
    type: json['type'] as String,
    amount: json['amount'] as int,
    balanceAfter: json['balance_after'] as int,
    createdAt: DateTime.parse(json['created_at'] as String),
    label: _label(json),
    priceUsd: json['price_usd'] == null
        ? null
        : double.parse(json['price_usd'].toString()),
  );

  static String _label(Map<String, dynamic> json) {
    if (json['type'] == 'unlock') {
      final title = json['film_title'] as String?;
      return title == null
          ? 'Unlocked episode'
          : '$title, Episode ${json['episode_no']}';
    }
    if (json['pack_name'] != null) return '${json['pack_name']} pack';
    return 'Demo top-up';
  }
}
