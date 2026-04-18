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
  final String dietaryType; // 'veg', 'non-veg', 'egg', 'vegan'
  final DateTime createdAt;
  final DateTime? updatedAt;
  final double? rating;
  final int? ratingCount;
  final List<String>? dietTags;
  final List<String>? tags;
  final Map<String, dynamic>? variants; // For future customization
  final Map<String, dynamic>? addons;   // For future customization
  final Map<String, dynamic>? nutritionalInfo; // Nutritional facts (calories, protein, carbs, fat, fiber, sugar)
  final String? nutritionalInfoText; // Description of nutritional value

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
    this.dietaryType = 'veg',
    required this.createdAt,
    this.updatedAt,
    this.rating,
    this.ratingCount,
    this.dietTags,
    this.tags,
    this.variants,
    this.addons,
    this.nutritionalInfo,
    this.nutritionalInfoText,
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
      isAvailable: _parseBool(json['isAvailable'] ?? json['is_available'] ?? json['available']) ?? true,
      isVeg: json['isVeg'] ?? json['is_veg'] as bool? ?? false,
      dietaryType: (json['dietary_type'] ?? json['dietaryType'])?.toString() ?? (json['is_veg'] == false ? 'non-veg' : 'veg'),
      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at'] as String) : DateTime.now(),
      updatedAt: json['updated_at'] != null ? DateTime.parse(json['updated_at'] as String) : null,
      rating: (json['rating'] as num?)?.toDouble(),
      ratingCount: (json['ratingCount'] ?? json['rating_count'] as num?)?.toInt(),
      dietTags: parsedTags.isNotEmpty ? parsedTags : (json['diet_tags'] as List? ?? json['dietTags'] as List?)?.cast<String>(),
      tags: (json['tags'] as List?)?.cast<String>(),
      variants: json['variants'] is Map ? json['variants'] as Map<String, dynamic> : null,
      addons: json['addons'] is Map ? json['addons'] as Map<String, dynamic> : null,
      nutritionalInfo: (json['nutritional_info'] ?? json['nutritionalInfo'] ?? json['nutrition']) is Map 
          ? (json['nutritional_info'] ?? json['nutritionalInfo'] ?? json['nutrition']) as Map<String, dynamic> 
          : null,
      nutritionalInfoText: json['nutritional_info_text'] ?? json['nutritionalInfoText'] as String?,
    );
  }

  static bool? _parseBool(dynamic value) {
    if (value == null) return null;
    if (value is bool) return value;
    if (value is int) return value == 1;
    if (value is String) return value.toLowerCase() == 'true' || value == '1';
    return null;
  }

  String get displayImage => (imageUrl != null && imageUrl!.isNotEmpty) 
    ? imageUrl! 
    : (image.isNotEmpty ? image : 'https://images.unsplash.com/photo-1546069901-ba9599a7e63c');

  /// Returns the matching Health Missions for this product
  List<String> get healthGoals {
    final List<String> goals = [];
    final String c = category.toLowerCase();
    final List<String> allTags = [
      ...(dietTags ?? []),
      ...(tags ?? []),
      name.toLowerCase(),
      description.toLowerCase(),
    ];

    bool hasTag(String term) => allTags.any((t) => t.contains(term.toLowerCase()));

    // --- MACRO-INTELLIGENCE (Verifiable Data) ---
    final macros = nutritionalInfo ?? {};
    final calories = (macros['calories'] as num?)?.toDouble() ?? (macros['kcal'] as num?)?.toDouble() ?? 1000.0;
    final protein = (macros['protein'] as num?)?.toDouble() ?? 0.0;
    final fiber = (macros['fiber'] as num?)?.toDouble() ?? (macros['fibre'] as num?)?.toDouble() ?? 0.0;
    final sugar = (macros['sugar'] as num?)?.toDouble() ?? 100.0;

    // 1. Flat Tummy (Low Calorie / Weight Loss)
    if (calories <= 400 || c.contains('low calorie') || hasTag('low calorie')) {
      goals.add('Flat Tummy');
    }

    // 2. Muscle Gain (High Protein)
    if (protein >= 15.0 || c.contains('high protein') || hasTag('high protein')) {
      goals.add('Muscle Gain');
    }

    // 3. Skin Glow (High Fiber / Antioxidants)
    if (fiber >= 5.0 || c.contains('high fiber') || hasTag('high fiber')) {
      goals.add('Skin Glow');
    }

    // 4. Clinical/Sugar (Sugar Free / Diabetic Friendly)
    if (sugar <= 2.0 || c.contains('sugar free') || hasTag('sugar free')) {
      goals.add('Clinical/Sugar');
    }

    return goals;
  }

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
    String? dietaryType,
    DateTime? createdAt,
    DateTime? updatedAt,
    double? rating,
    int? ratingCount,
    List<String>? dietTags,
    List<String>? tags,
    Map<String, dynamic>? variants,
    Map<String, dynamic>? addons,
    Map<String, dynamic>? nutritionalInfo,
    String? nutritionalInfoText,
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
      dietaryType: dietaryType ?? this.dietaryType,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      rating: rating ?? this.rating,
      ratingCount: ratingCount ?? this.ratingCount,
      dietTags: dietTags ?? this.dietTags,
      tags: tags ?? this.tags,
      variants: variants ?? this.variants,
      addons: addons ?? this.addons,
      nutritionalInfo: nutritionalInfo ?? this.nutritionalInfo,
      nutritionalInfoText: nutritionalInfoText ?? this.nutritionalInfoText,
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
      'dietary_type': dietaryType,
      'diet_tags': dietTags,
      'tags': tags,
      'variants': variants,
      'addons': addons,
      'nutritional_info': nutritionalInfo,
      'nutritional_info_text': nutritionalInfoText,
      'created_at': createdAt.toIso8601String(),
    };
  }

  /// Specialized mapping for Node.js Backend expectations
  Map<String, dynamic> toApiJson() {
    final data = toJson();
    // Map nutritional_info to 'nutrition' as expected by backend POST/PUT handlers
    if (data.containsKey('nutritional_info')) {
      data['nutrition'] = data.remove('nutritional_info');
    }
    return data;
  }
}
