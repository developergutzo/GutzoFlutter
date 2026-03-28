class Category {
  final String id;
  final String name;
  final String? imageUrl;
  final bool? isActive;

  Category({
    required this.id,
    required this.name,
    this.imageUrl,
    this.isActive,
  });

  factory Category.fromJson(Map<String, dynamic> json) {
    return Category(
      id: json['id'] as String,
      name: json['name'] as String,
      imageUrl: json['image_url'] as String?,
      isActive: json['is_active'] as bool?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'image_url': imageUrl,
      'is_active': isActive,
    };
  }
}
