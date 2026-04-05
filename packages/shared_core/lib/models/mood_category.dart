class MoodCategory {
  final String id;
  final String name;
  final String imageUrl;
  final int? sortOrder;
  final bool? isActive;

  MoodCategory({
    required this.id,
    required this.name,
    required this.imageUrl,
    this.sortOrder,
    this.isActive,
  });

  factory MoodCategory.fromJson(Map<String, dynamic> json) {
    return MoodCategory(
      id: json['id'] as String,
      name: json['name'] as String,
      imageUrl: json['image_url'] as String,
      sortOrder: json['sort_order'] as int?,
      isActive: json['is_active'] as bool?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'image_url': imageUrl,
      'sort_order': sortOrder,
      'is_active': isActive,
    };
  }
}
