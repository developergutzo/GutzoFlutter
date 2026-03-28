class Product {
  final String id;
  final String vendorId;
  final String name;
  final String description;
  final double price;
  final String category;
  final String image;
  final String? imageUrl;
  final bool isAvailable;
  final bool isVeg;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final double? rating;
  final int? ratingCount;
  final List<String>? dietTags;
  final List<String>? tags;
  final Map<String, dynamic>? variants; // For future customization
  final Map<String, dynamic>? addons;   // For future customization

  Product({
    required this.id,
    required this.vendorId,
    required this.name,
    required this.description,
    required this.price,
    required this.category,
    required this.image,
    this.imageUrl,
    required this.isAvailable,
    required this.isVeg,
    required this.createdAt,
    this.updatedAt,
    this.rating,
    this.ratingCount,
    this.dietTags,
    this.tags,
    this.variants,
    this.addons,
  });

  factory Product.fromJson(Map<String, dynamic> json) {
    return Product(
      id: json['id'] as String? ?? '',
      vendorId: (json['vendor_id'] ?? json['vendorId']) as String? ?? '',
      name: json['name'] as String? ?? '',
      description: json['description'] as String? ?? '',
      price: (json['price'] as num?)?.toDouble() ?? 0.0,
      category: json['category'] as String? ?? '',
      image: json['image'] as String? ?? '',
      imageUrl: (json['imageUrl'] ?? json['image_url']) as String?,
      isAvailable: json['isAvailable'] ?? json['is_available'] ?? json['available'] as bool? ?? true,
      isVeg: json['isVeg'] ?? json['is_veg'] as bool? ?? false,
      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at'] as String) : DateTime.now(),
      updatedAt: json['updated_at'] != null ? DateTime.parse(json['updated_at'] as String) : null,
      rating: (json['rating'] as num?)?.toDouble(),
      ratingCount: (json['ratingCount'] ?? json['rating_count'] as num?)?.toInt(),
      dietTags: (json['diet_tags'] ?? json['dietTags'] as List<dynamic>?)?.cast<String>(),
      tags: (json['tags'] as List<dynamic>?)?.cast<String>(),
      variants: json['variants'] as Map<String, dynamic>?,
      addons: json['addons'] as Map<String, dynamic>?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'vendor_id': vendorId,
      'name': name,
      'description': description,
      'price': price,
      'category': category,
      'image': image,
      'image_url': imageUrl,
      'is_available': isAvailable,
      'is_veg': isVeg,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
      'rating': rating,
      'rating_count': ratingCount,
      'diet_tags': dietTags,
      'tags': tags,
      'variants': variants,
      'addons': addons,
    };
  }
}
