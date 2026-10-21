class TransactionItem {
  final String id;
  final String walletId;
  final String? destinationWalletId; // Digunakan jika type == 'transfer'
  final String categoryId;
  final String type; // 'expense', 'income', 'transfer'
  final double amount;
  final String note;
  final DateTime date;

  TransactionItem({
    required this.id,
    required this.walletId,
    this.destinationWalletId,
    required this.categoryId,
    required this.type,
    required this.amount,
    required this.note,
    required this.date,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'walletId': walletId,
      'destinationWalletId': destinationWalletId,
      'categoryId': categoryId,
      'type': type,
      'amount': amount,
      'note': note,
      'date': date.toIso8601String(),
    };
  }

  factory TransactionItem.fromJson(Map<String, dynamic> json) {
    return TransactionItem(
      id: json['id'] as String,
      walletId: json['walletId'] as String,
      destinationWalletId: json['destinationWalletId'] as String?,
      categoryId: json['categoryId'] as String? ?? 'general',
      type: json['type'] as String,
      amount: (json['amount'] as num).toDouble(),
      note: json['note'] as String? ?? '',
      date: DateTime.parse(json['date'] as String),
    );
  }
}
