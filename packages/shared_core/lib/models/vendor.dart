import 'product.dart';

class Vendor {
  final String id;
  final String name;
  final String description;
  final String location;
  final double rating;
  final String image;
  final String deliveryTime;
  final double minimumOrder;
  final double deliveryFee;
  final String cuisineType;
  final String phone;
  final bool isActive;
  final bool isFeatured;
  final DateTime createdAt;
  final List<String>? tags;
  final String? logoUrl;
  final String? contactWhatsapp;
  final List<Product>? products;
  final double? latitude;
  final double? longitude;
  final bool? isBlacklisted;
  final bool? isOpen;
  final String? nextOpenTime;
  final bool? isServiceable;

  Vendor({
    required this.id,
    required this.name,
    required this.description,
    required this.location,
    required this.rating,
    required this.image,
    required this.deliveryTime,
    required this.minimumOrder,
    required this.deliveryFee,
    required this.cuisineType,
    required this.phone,
    required this.isActive,
    required this.isFeatured,
    required this.createdAt,
    this.tags,
    this.logoUrl,
    this.contactWhatsapp,
    this.products,
    this.latitude,
    this.longitude,
    this.isBlacklisted,
    this.isOpen,
    this.nextOpenTime,
    this.isServiceable,
  });

  factory Vendor.fromJson(Map<String, dynamic> json) {
    return Vendor(
      id: json['id']?.toString() ?? '',
      name: json['name'] as String? ?? '',
      description: json['description'] as String? ?? '',
      location: json['location'] as String? ?? '',
      rating: (json['rating'] as num?)?.toDouble() ?? 4.5,
      image: json['image'] as String? ?? '',
      deliveryTime: (json['deliveryTime'] ?? json['delivery_time']) as String? ?? '',
      minimumOrder: (json['minimumOrder'] ?? json['minimum_order'] as num?)?.toDouble() ?? 0.0,
      deliveryFee: (json['deliveryFee'] ?? json['delivery_fee'] as num?)?.toDouble() ?? 0.0,
      cuisineType: (json['cuisineType'] ?? json['cuisine_type']) as String? ?? '',
      phone: json['phone'] as String? ?? '',
      isActive: json['isActive'] ?? json['is_active'] as bool? ?? false,
      isFeatured: json['isFeatured'] ?? json['is_featured'] as bool? ?? false,
      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at'] as String) : DateTime.now(),
      tags: (json['tags'] as List<dynamic>?)?.cast<String>(),
      logoUrl: json['logo_url'] as String?,
      contactWhatsapp: json['contact_whatsapp'] as String?,
      products: (json['products'] as List<dynamic>?)
          ?.map((e) => Product.fromJson(e as Map<String, dynamic>))
          .toList(),
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      isBlacklisted: json['isBlacklisted'] ?? json['is_blacklisted'] as bool?,
      isOpen: json['isOpen'] ?? json['is_open'] as bool?,
      nextOpenTime: json['nextOpenTime'] ?? json['next_open_time'] as String?,
      isServiceable: json['isServiceable'] ?? json['is_serviceable'] as bool?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'location': location,
      'rating': rating,
      'image': image,
      'delivery_time': deliveryTime,
      'minimum_order': minimumOrder,
      'delivery_fee': deliveryFee,
      'cuisine_type': cuisineType,
      'phone': phone,
      'is_active': isActive,
      'is_featured': isFeatured,
      'created_at': createdAt.toIso8601String(),
      'tags': tags,
      'logo_url': logoUrl,
      'contact_whatsapp': contactWhatsapp,
      'products': products?.map((e) => e.toJson()).toList(),
      'latitude': latitude,
      'longitude': longitude,
      'is_blacklisted': isBlacklisted,
      'is_open': isOpen,
      'next_open_time': nextOpenTime,
      'is_serviceable': isServiceable,
    };
  }
}
