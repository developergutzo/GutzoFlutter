class HomeBanner {
  final String id;
  final String imageUrl;
  final String? targetType; // e.g., 'vendor', 'category', 'product'
  final String? targetId;
  final bool isActive;
  final int? priority;

  HomeBanner({
    required this.id,
    required this.imageUrl,
    this.targetType,
    this.targetId,
    required this.isActive,
    this.priority,
  });

  factory HomeBanner.fromJson(Map<String, dynamic> json) {
    return HomeBanner(
      id: json['id'] as String,
      imageUrl: json['image_url'] as String,
      targetType: json['target_type'] as String?,
      targetId: json['target_id'] as String?,
      isActive: json['is_active'] as bool? ?? true,
      priority: json['priority'] as int?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'image_url': imageUrl,
      'target_type': targetType,
      'target_id': targetId,
      'is_active': isActive,
      'priority': priority,
    };
  }
}
