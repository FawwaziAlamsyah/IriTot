class SavingsRecord {
  final String id;
  final String pocketId;
  final String pocketName;
  final String walletId;
  final String walletName;
  final String type; // 'in' (masuk/deposit) atau 'out' (keluar/withdraw)
  final double amount;
  final String note;
  final DateTime date;

  SavingsRecord({
    required this.id,
    required this.pocketId,
    required this.pocketName,
    required this.walletId,
    required this.walletName,
    required this.type,
    required this.amount,
    required this.note,
    required this.date,
  });

  bool get isIn => type == 'in';
  bool get isOut => type == 'out';

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'pocketId': pocketId,
      'pocketName': pocketName,
      'walletId': walletId,
      'walletName': walletName,
      'type': type,
      'amount': amount,
      'note': note,
      'date': date.toIso8601String(),
    };
  }

  factory SavingsRecord.fromJson(Map<String, dynamic> json) {
    return SavingsRecord(
      id: json['id'] as String,
      pocketId: json['pocketId'] as String,
      pocketName: json['pocketName'] as String? ?? 'Tabungan',
      walletId: json['walletId'] as String,
      walletName: json['walletName'] as String? ?? 'Dompet',
      type: json['type'] as String,
      amount: (json['amount'] as num).toDouble(),
      note: json['note'] as String? ?? '',
      date: DateTime.parse(json['date'] as String),
    );
  }
}
