class Subscription {
  const Subscription({
    required this.id,
    required this.priceUsd,
    required this.startDate,
    required this.endDate,
    this.isCancelled = false,
    this.paidThrough,
    this.today,
  });

  final int id;
  final double priceUsd;
  final DateTime startDate;
  final DateTime endDate;
  final bool isCancelled;

  /// Last paid day across every plan bought ahead (inclusive), from the server.
  final DateTime? paidThrough;

  /// The server's calendar day when this was read.
  final DateTime? today;

  /// Both ends of a plan are inclusive, so the last day still counts as a day.
  DateTime get lastDay => paidThrough ?? endDate;

  int get daysLeft {
    final from = today ?? DateTime.now();
    final day = DateTime(from.year, from.month, from.day);
    final last = DateTime(lastDay.year, lastDay.month, lastDay.day);
    final left = last.difference(day).inDays + 1;
    return left < 0 ? 0 : left;
  }

  factory Subscription.fromJson(
    Map<String, dynamic> json, {
    String? paidThrough,
    String? today,
  }) => Subscription(
    id: json['id'] as int,
    // mysql2 returns DECIMAL columns as strings.
    priceUsd: double.parse(json['price_usd'].toString()),
    startDate: DateTime.parse(json['start_date'] as String),
    endDate: DateTime.parse(json['end_date'] as String),
    isCancelled: json['is_cancelled'] == true,
    paidThrough: paidThrough == null ? null : DateTime.parse(paidThrough),
    today: today == null ? null : DateTime.parse(today),
  );
}
