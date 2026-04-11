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
  final String? pincode;
  final String? companyType;
  final String? ownerName;
  final String? companyRegNo;
  final String? ownerAadharNo;
  final String? panCardNo;
  final String? fssaiLicense;
  final String? gstNumber;
  final String? bankAccountNo;
  final String? ifscCode;
  final String? bankName;
  final String? accountHolderName;

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
    this.pincode,
    this.companyType,
    this.ownerName,
    this.companyRegNo,
    this.ownerAadharNo,
    this.panCardNo,
    this.fssaiLicense,
    this.gstNumber,
    this.bankAccountNo,
    this.ifscCode,
    this.bankName,
    this.accountHolderName,
  });

  factory Vendor.fromJson(Map<String, dynamic> json) {
    return Vendor(
      id: json['id']?.toString() ?? '',
      name: json['name'] as String? ?? '',
      description: json['description'] as String? ?? '',
      location: (json['address'] ?? json['location']) as String? ?? '',
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
      pincode: json['pincode'] as String?,
      companyType: json['company_type'] as String?,
      ownerName: json['owner_name'] as String?,
      companyRegNo: json['company_reg_no'] as String?,
      ownerAadharNo: json['owner_aadhar_no'] as String?,
      panCardNo: json['pan_card_no'] as String?,
      fssaiLicense: json['fssai_license'] as String?,
      gstNumber: json['gst_number'] as String?,
      bankAccountNo: (json['bank_account_no'] ?? json['bank_account_number']) as String?,
      ifscCode: json['ifsc_code'] as String?,
      bankName: json['bank_name'] as String?,
      accountHolderName: json['account_holder_name'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'address': location,
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
      'pincode': pincode,
      'company_type': companyType,
      'owner_name': ownerName,
      'company_reg_no': companyRegNo,
      'owner_aadhar_no': ownerAadharNo,
      'pan_card_no': panCardNo,
      'fssai_license': fssaiLicense,
      'gst_number': gstNumber,
      'bank_account_no': bankAccountNo,
      'ifsc_code': ifscCode,
      'bank_name': bankName,
      'account_holder_name': accountHolderName,
    };
  }

  Map<String, dynamic> toProfileUpdateJson() {
    return {
      'name': name,
      'description': description,
      'cuisine_type': cuisineType,
      'address': location,
      'phone': phone,
      'image': image,
      'delivery_time': deliveryTime,
      'minimum_order': minimumOrder,
      'delivery_fee': deliveryFee,
      'pincode': pincode,
      'company_type': companyType,
      'owner_name': ownerName,
      'company_reg_no': companyRegNo,
      'owner_aadhar_no': ownerAadharNo,
      'pan_card_no': panCardNo,
      'fssai_license': fssaiLicense,
      'gst_number': gstNumber,
      'bank_account_no': bankAccountNo,
      'ifsc_code': ifscCode,
      'bank_name': bankName,
      'account_holder_name': accountHolderName,
    };
  }





  Vendor copyWith({
    String? id,
    String? name,
    String? description,
    String? location,
    double? rating,
    String? image,
    String? deliveryTime,
    double? minimumOrder,
    double? deliveryFee,
    String? cuisineType,
    String? phone,
    bool? isActive,
    bool? isFeatured,
    DateTime? createdAt,
    List<String>? tags,
    String? logoUrl,
    String? contactWhatsapp,
    List<Product>? products,
    double? latitude,
    double? longitude,
    bool? isBlacklisted,
    bool? isOpen,
    String? nextOpenTime,
    bool? isServiceable,
    String? pincode,
    String? companyType,
    String? ownerName,
    String? companyRegNo,
    String? ownerAadharNo,
    String? panCardNo,
    String? fssaiLicense,
    String? gstNumber,
    String? bankAccountNo,
    String? ifscCode,
    String? bankName,
    String? accountHolderName,
  }) {
    return Vendor(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      location: location ?? this.location,
      rating: rating ?? this.rating,
      image: image ?? this.image,
      deliveryTime: deliveryTime ?? this.deliveryTime,
      minimumOrder: minimumOrder ?? this.minimumOrder,
      deliveryFee: deliveryFee ?? this.deliveryFee,
      cuisineType: cuisineType ?? this.cuisineType,
      phone: phone ?? this.phone,
      isActive: isActive ?? this.isActive,
      isFeatured: isFeatured ?? this.isFeatured,
      createdAt: createdAt ?? this.createdAt,
      tags: tags ?? this.tags,
      logoUrl: logoUrl ?? this.logoUrl,
      contactWhatsapp: contactWhatsapp ?? this.contactWhatsapp,
      products: products ?? this.products,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      isBlacklisted: isBlacklisted ?? this.isBlacklisted,
      isOpen: isOpen ?? this.isOpen,
      nextOpenTime: nextOpenTime ?? this.nextOpenTime,
      isServiceable: isServiceable ?? this.isServiceable,
      pincode: pincode ?? this.pincode,
      companyType: companyType ?? this.companyType,
      ownerName: ownerName ?? this.ownerName,
      companyRegNo: companyRegNo ?? this.companyRegNo,
      ownerAadharNo: ownerAadharNo ?? this.ownerAadharNo,
      panCardNo: panCardNo ?? this.panCardNo,
      fssaiLicense: fssaiLicense ?? this.fssaiLicense,
      gstNumber: gstNumber ?? this.gstNumber,
      bankAccountNo: bankAccountNo ?? this.bankAccountNo,
      ifscCode: ifscCode ?? this.ifscCode,
      bankName: bankName ?? this.bankName,
      accountHolderName: accountHolderName ?? this.accountHolderName,
    );
  }
}
