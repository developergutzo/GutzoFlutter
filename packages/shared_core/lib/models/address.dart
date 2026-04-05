class UserAddress {
  final String id;
  final String userId;
  final String type; // 'home', 'work', 'other'
  final String? label;
  final String? customLabel;
  final String street;
  final String? area;
  final String? landmark;
  final String fullAddress;
  final String city;
  final String state;
  final String country;
  final String? postalCode;
  final String? alternativePhone;
  final double? latitude;
  final double? longitude;
  final String? deliveryInstructions;
  final bool isDefault;
  final DateTime createdAt;
  final DateTime updatedAt;

  UserAddress({
    required this.id,
    required this.userId,
    required this.type,
    this.label,
    this.customLabel,
    required this.street,
    this.area,
    this.landmark,
    required this.fullAddress,
    required this.city,
    required this.state,
    required this.country,
    this.postalCode,
    this.alternativePhone,
    this.latitude,
    this.longitude,
    this.deliveryInstructions,
    required this.isDefault,
    required this.createdAt,
    required this.updatedAt,
  });

  factory UserAddress.fromJson(Map<String, dynamic> json) {
    return UserAddress(
      id: (json['id'] ?? '') as String,
      userId: (json['user_id'] ?? '') as String,
      type: (json['type'] ?? 'other') as String,
      label: json['label'] as String?,
      customLabel: json['custom_label'] as String?,
      street: (json['street'] ?? '') as String,
      area: json['area'] as String?,
      landmark: json['landmark'] as String?,
      fullAddress: (json['full_address'] ?? '') as String,
      city: (json['city'] ?? '') as String,
      state: (json['state'] ?? '') as String,
      country: (json['country'] ?? '') as String,
      postalCode: json['zipcode'] as String? ?? json['postal_code'] as String?,
      alternativePhone: json['alternative_phone'] as String?,
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      deliveryInstructions: json['delivery_instructions'] as String?,
      isDefault: json['is_default'] as bool? ?? false,
      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at'] as String) : DateTime.now(),
      updatedAt: json['updated_at'] != null ? DateTime.parse(json['updated_at'] as String) : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'type': type,
      'label': label,
      'custom_label': customLabel,
      'street': street,
      'area': area,
      'landmark': landmark,
      'full_address': fullAddress,
      'city': city,
      'state': state,
      'country': country,
      'postal_code': postalCode,
      'alternative_phone': alternativePhone,
      'latitude': latitude,
      'longitude': longitude,
      'delivery_instructions': deliveryInstructions,
      'is_default': isDefault,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }
}
