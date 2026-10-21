class SavingsPocket {
  final String id;
  final String name;
  final double targetAmount;
  double currentAmount;
  final int colorValue;
  final String icon;
  final DateTime? targetDate;
  final String? notes;
  final DateTime createdAt;

  SavingsPocket({
    required this.id,
    required this.name,
    required this.targetAmount,
    required this.currentAmount,
    required this.colorValue,
    required this.icon,
    this.targetDate,
    this.notes,
    required this.createdAt,
  });

  double get progressRatio {
    if (targetAmount <= 0) return 0.0;
    return (currentAmount / targetAmount).clamp(0.0, 1.0);
  }

  int get progressPercent {
    if (targetAmount <= 0) return 0;
    return ((currentAmount / targetAmount) * 100).toInt();
  }

  double get remainingAmount {
    final remaining = targetAmount - currentAmount;
    return remaining > 0 ? remaining : 0.0;
  }

  bool get isAchieved => targetAmount > 0 && currentAmount >= targetAmount;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'targetAmount': targetAmount,
      'currentAmount': currentAmount,
      'colorValue': colorValue,
      'icon': icon,
      'targetDate': targetDate?.toIso8601String(),
      'notes': notes,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory SavingsPocket.fromJson(Map<String, dynamic> json) {
    return SavingsPocket(
      id: json['id'] as String,
      name: json['name'] as String,
      targetAmount: (json['targetAmount'] as num).toDouble(),
      currentAmount: (json['currentAmount'] as num).toDouble(),
      colorValue: json['colorValue'] as int? ?? 0xFF10B981,
      icon: json['icon'] as String? ?? 'savings',
      targetDate: json['targetDate'] != null ? DateTime.parse(json['targetDate'] as String) : null,
      notes: json['notes'] as String?,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String)
          : DateTime.now(),
    );
  }
}
