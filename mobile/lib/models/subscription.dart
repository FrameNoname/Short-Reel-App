class Subscription {
  const Subscription({
    required this.id,
    required this.priceUsd,
    required this.startDate,
    required this.endDate,
    this.isCancelled = false,
  });

  final int id;
  final double priceUsd;
  final DateTime startDate;
  final DateTime endDate;
  final bool isCancelled;

  factory Subscription.fromJson(Map<String, dynamic> json) => Subscription(
    id: json['id'] as int,
    // mysql2 returns DECIMAL columns as strings.
    priceUsd: double.parse(json['price_usd'].toString()),
    startDate: DateTime.parse(json['start_date'] as String),
    endDate: DateTime.parse(json['end_date'] as String),
  );
}
