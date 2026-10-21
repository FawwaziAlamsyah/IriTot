class CategoryItem {
  final String id;
  final String name;
  final String type; // 'expense', 'income'
  final String icon;
  final int colorValue;

  CategoryItem({
    required this.id,
    required this.name,
    required this.type,
    required this.icon,
    required this.colorValue,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'type': type,
      'icon': icon,
      'colorValue': colorValue,
    };
  }

  factory CategoryItem.fromJson(Map<String, dynamic> json) {
    return CategoryItem(
      id: json['id'] as String,
      name: json['name'] as String,
      type: json['type'] as String,
      icon: json['icon'] as String,
      colorValue: json['colorValue'] as int? ?? 0xFF38BDF8,
    );
  }
}
