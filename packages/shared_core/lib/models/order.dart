import 'vendor.dart';
import 'product.dart';

class Order {
  final String id;
  final String orderNumber;
  final String status;
  final double totalAmount;
  final double subtotal;
  final double deliveryFee;
  final double packagingFee;
  final double platformFee;
  final double taxes;
  final double discountAmount;
  final String? paymentStatus;
  final String? paymentMethod;
  final DateTime createdAt;
  final List<OrderItem> items;
  final Vendor? vendor;
  final String? deliveryAddress;
  final String? riderId;

  Order({
    required this.id,
    required this.orderNumber,
    required this.status,
    required this.totalAmount,
    required this.subtotal,
    required this.deliveryFee,
    required this.packagingFee,
    required this.platformFee,
    required this.taxes,
    required this.discountAmount,
    this.paymentStatus,
    this.paymentMethod,
    required this.createdAt,
    this.items = const [],
    this.vendor,
    this.deliveryAddress,
    this.riderId,
  });

  factory Order.fromJson(Map<String, dynamic> json) {
    return Order(
      id: json['id'] ?? '',
      orderNumber: json['order_number'] ?? '',
      status: json['status'] ?? 'unknown',
      totalAmount: (json['total_amount'] ?? 0).toDouble(),
      subtotal: (json['subtotal'] ?? 0).toDouble(),
      deliveryFee: (json['delivery_fee'] ?? 0).toDouble(),
      packagingFee: (json['packaging_fee'] ?? 0).toDouble(),
      platformFee: (json['platform_fee'] ?? 0).toDouble(),
      taxes: (json['taxes'] ?? 0).toDouble(),
      discountAmount: (json['discount_amount'] ?? 0).toDouble(),
      paymentStatus: json['payment_status'],
      paymentMethod: json['payment_method'],
      createdAt: DateTime.parse(json['created_at']),
      items: (json['items'] as List? ?? [])
          .map((i) => OrderItem.fromJson(i))
          .toList(),
      vendor: json['vendor'] != null ? Vendor.fromJson(json['vendor']) : null,
      deliveryAddress: json['delivery_address'],
      riderId: json['rider_id'],
    );
  }
}

class OrderItem {
  final String id;
  final String productName;
  final int quantity;
  final double unitPrice;
  final double totalPrice;
  final String? customizations;

  OrderItem({
    required this.id,
    required this.productName,
    required this.quantity,
    required this.unitPrice,
    required this.totalPrice,
    this.customizations,
  });

  factory OrderItem.fromJson(Map<String, dynamic> json) {
    return OrderItem(
      id: json['id'] ?? '',
      productName: json['product_name'] ?? '',
      quantity: json['quantity'] ?? 0,
      unitPrice: (json['unit_price'] ?? 0).toDouble(),
      totalPrice: (json['total_price'] ?? 0).toDouble(),
      customizations: json['customizations'],
    );
  }
}

class OrderTrackingData {
  final String orderNumber;
  final String currentStatus;
  final List<StatusStep> statusFlow;
  final Map<String, dynamic>? rider;
  final Map<String, dynamic>? vendorLocation;

  OrderTrackingData({
    required this.orderNumber,
    required this.currentStatus,
    required this.statusFlow,
    this.rider,
    this.vendorLocation,
  });

  factory OrderTrackingData.fromJson(Map<String, dynamic> json) {
    return OrderTrackingData(
      orderNumber: json['order_number'] ?? '',
      currentStatus: json['current_status'] ?? '',
      statusFlow: (json['status_flow'] as List? ?? [])
          .map((s) => StatusStep.fromJson(s))
          .toList(),
      rider: json['rider'],
      vendorLocation: json['vendor_location'],
    );
  }
}

class StatusStep {
  final String status;
  final String label;
  final String icon;
  final bool completed;
  final bool current;

  StatusStep({
    required this.status,
    required this.label,
    required this.icon,
    required this.completed,
    required this.current,
  });

  factory StatusStep.fromJson(Map<String, dynamic> json) {
    return StatusStep(
      status: json['status'] ?? '',
      label: json['label'] ?? '',
      icon: json['icon'] ?? '',
      completed: json['completed'] ?? false,
      current: json['current'] ?? false,
    );
  }
}
