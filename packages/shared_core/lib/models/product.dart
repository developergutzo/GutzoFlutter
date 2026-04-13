class Product {
  final String id;
  final String vendorId;
  final String name;
  final String description;
  final double price;
  final double? originalPrice;
  final double? discountPct;
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
    this.originalPrice,
    this.discountPct,
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
    final rawDescription = json['description'] as String? ?? '';
    final tagRegex = RegExp(r'\[TAGS:(.*?)\]\s*$');
    final match = tagRegex.firstMatch(rawDescription);
    
    String cleanDescription = rawDescription;
    List<String> parsedTags = [];
    
    if (match != null) {
      final tagsString = match.group(1);
      if (tagsString != null) {
        parsedTags = tagsString.split(',').map((t) => t.trim()).where((t) => t.isNotEmpty).toList();
      }
      cleanDescription = rawDescription.replaceFirst(tagRegex, '').trim();
    }

    return Product(
      id: json['id']?.toString() ?? '',
      vendorId: (json['vendor_id'] ?? json['vendorId'])?.toString() ?? '',
      name: json['name'] as String? ?? '',
      description: cleanDescription,
      price: (json['price'] as num?)?.toDouble() ?? 0.0,
      originalPrice: (json['original_price'] ?? json['originalPrice'] as num?)?.toDouble(),
      discountPct: (json['discount_pct'] ?? json['discountPct'] as num?)?.toDouble(),
      category: json['category'] as String? ?? '',
      image: json['image'] as String? ?? '',
      imageUrl: (json['imageUrl'] ?? json['image_url']) as String?,
      isAvailable: json['isAvailable'] ?? json['is_available'] ?? json['available'] as bool? ?? true,
      isVeg: json['isVeg'] ?? json['is_veg'] as bool? ?? false,
      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at'] as String) : DateTime.now(),
      updatedAt: json['updated_at'] != null ? DateTime.parse(json['updated_at'] as String) : null,
      rating: (json['rating'] as num?)?.toDouble(),
      ratingCount: (json['ratingCount'] ?? json['rating_count'] as num?)?.toInt(),
      dietTags: parsedTags.isNotEmpty ? parsedTags : (json['diet_tags'] as List? ?? json['dietTags'] as List?)?.cast<String>(),
      tags: (json['tags'] as List?)?.cast<String>(),
      variants: json['variants'] is Map ? json['variants'] as Map<String, dynamic> : null,
      addons: json['addons'] is Map ? json['addons'] as Map<String, dynamic> : null,
    );
  }

  String get displayImage => (imageUrl != null && imageUrl!.isNotEmpty) 
    ? imageUrl! 
    : (image.isNotEmpty ? image : 'https://images.unsplash.com/photo-1546069901-ba9599a7e63c');

  Product copyWith({
    String? id,
    String? vendorId,
    String? name,
    String? description,
    double? price,
    double? originalPrice,
    double? discountPct,
    String? category,
    String? image,
    String? imageUrl,
    bool? isAvailable,
    bool? isVeg,
    DateTime? createdAt,
    DateTime? updatedAt,
    double? rating,
    int? ratingCount,
    List<String>? dietTags,
    List<String>? tags,
    Map<String, dynamic>? variants,
    Map<String, dynamic>? addons,
  }) {
    return Product(
      id: id ?? this.id,
      vendorId: vendorId ?? this.vendorId,
      name: name ?? this.name,
      description: description ?? this.description,
      price: price ?? this.price,
      originalPrice: originalPrice ?? this.originalPrice,
      discountPct: discountPct ?? this.discountPct,
      category: category ?? this.category,
      image: image ?? this.image,
      imageUrl: imageUrl ?? this.imageUrl,
      isAvailable: isAvailable ?? this.isAvailable,
      isVeg: isVeg ?? this.isVeg,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      rating: rating ?? this.rating,
      ratingCount: ratingCount ?? this.ratingCount,
      dietTags: dietTags ?? this.dietTags,
      tags: tags ?? this.tags,
      variants: variants ?? this.variants,
      addons: addons ?? this.addons,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'vendor_id': vendorId,
      'name': name,
      'description': description,
      'price': price,
      'original_price': originalPrice,
      'discount_pct': discountPct,
      'category': category,
      'image_url': imageUrl ?? image,
      'is_available': isAvailable,
      'is_veg': isVeg,
      'created_at': createdAt.toIso8601String(),
    };
  }
}
