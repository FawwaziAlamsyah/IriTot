class Budget {
  final String id;
  final String categoryId;
  final double monthlyLimit;
  final int month;
  final int year;

  Budget({
    required this.id,
    required this.categoryId,
    required this.monthlyLimit,
    required this.month,
    required this.year,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'categoryId': categoryId,
      'monthlyLimit': monthlyLimit,
      'month': month,
      'year': year,
    };
  }

  factory Budget.fromJson(Map<String, dynamic> json) {
    return Budget(
      id: json['id'] as String,
      categoryId: json['categoryId'] as String,
      monthlyLimit: (json['monthlyLimit'] as num).toDouble(),
      month: json['month'] as int,
      year: json['year'] as int,
    );
  }
}
