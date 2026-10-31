class Transaction {
  const Transaction({
    required this.id,
    required this.type,
    required this.amount,
    required this.balanceAfter,
    required this.createdAt,
    this.label = '',
  });

  final int id;
  final String type;
  final int amount;
  final int balanceAfter;
  final DateTime createdAt;
  final String label;

  factory Transaction.fromJson(Map<String, dynamic> json) => Transaction(
    id: json['id'] as int,
    type: json['type'] as String,
    amount: json['amount'] as int,
    balanceAfter: json['balance_after'] as int,
    createdAt: DateTime.parse(json['created_at'] as String),
  );
}
