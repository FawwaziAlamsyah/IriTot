class Wallet {
  final String id;
  final String name;
  final String type; // 'cash', 'bank', 'ewallet'
  double balance;
  final String icon;
  final int colorValue;

  Wallet({
    required this.id,
    required this.name,
    required this.type,
    required this.balance,
    required this.icon,
    required this.colorValue,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'type': type,
      'balance': balance,
      'icon': icon,
      'colorValue': colorValue,
    };
  }

  factory Wallet.fromJson(Map<String, dynamic> json) {
    return Wallet(
      id: json['id'] as String,
      name: json['name'] as String,
      type: json['type'] as String,
      balance: (json['balance'] as num).toDouble(),
      icon: json['icon'] as String? ?? 'account_balance_wallet',
      colorValue: json['colorValue'] as int? ?? 0xFF10B981,
    );
  }
}
