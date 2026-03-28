class CartItem {
  final String productId;
  final String vendorId;
  final String name;
  final double price;
  final int quantity;
  final String image;
  final bool isVeg;
  final Map<String, dynamic>? metadata;

  CartItem({
    required this.productId,
    required this.vendorId,
    required this.name,
    required this.price,
    required this.quantity,
    required this.image,
    required this.isVeg,
    this.metadata,
  });

  factory CartItem.fromJson(Map<String, dynamic> json) {
    return CartItem(
      productId: json['productId'] as String,
      vendorId: json['vendorId'] as String,
      name: json['name'] as String,
      price: (json['price'] as num).toDouble(),
      quantity: json['quantity'] as int,
      image: json['image'] as String,
      isVeg: json['isVeg'] as bool? ?? false,
      metadata: json['metadata'] as Map<String, dynamic>?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'productId': productId,
      'vendorId': vendorId,
      'name': name,
      'price': price,
      'quantity': quantity,
      'image': image,
      'isVeg': isVeg,
      'metadata': metadata,
    };
  }

  CartItem copyWith({
    String? productId,
    String? vendorId,
    String? name,
    double? price,
    int? quantity,
    String? image,
    bool? isVeg,
    Map<String, dynamic>? metadata,
  }) {
    return CartItem(
      productId: productId ?? this.productId,
      vendorId: vendorId ?? this.vendorId,
      name: name ?? this.name,
      price: price ?? this.price,
      quantity: quantity ?? this.quantity,
      image: image ?? this.image,
      isVeg: isVeg ?? this.isVeg,
      metadata: metadata ?? this.metadata,
    );
  }
}
