class HabitPack {
  final String id;
  final String vendorId;
  final String productId;
  final String productName;
  final String? productImage;
  final String? healthGoal;
  final int daysTotal;
  final int daysDone;
  final String status; // active | completed | cancelled | paused
  final List<String> skipDates;
  final DateTime startDate;
  final DateTime endDate;
  final double perDayPrice;
  final double totalPaid;
  final DateTime? cancelledAt;
  final String? cancellationReason;
  final DateTime? completedAt;
  final Map<String, dynamic>? vendor;
  final Map<String, dynamic>? product;
  final List<Map<String, dynamic>> dayOrders;

  const HabitPack({
    required this.id,
    required this.vendorId,
    required this.productId,
    required this.productName,
    this.productImage,
    this.healthGoal,
    required this.daysTotal,
    required this.daysDone,
    required this.status,
    required this.skipDates,
    required this.startDate,
    required this.endDate,
    required this.perDayPrice,
    required this.totalPaid,
    this.cancelledAt,
    this.cancellationReason,
    this.completedAt,
    this.vendor,
    this.product,
    this.dayOrders = const [],
  });

  factory HabitPack.fromJson(Map<String, dynamic> json) {
    return HabitPack(
      id: json['id'] as String,
      vendorId: json['vendor_id'] as String,
      productId: json['product_id'] as String,
      productName: json['product_name'] as String? ?? 'Habit Meal',
      productImage: json['product_image'] as String?,
      healthGoal: json['health_goal'] as String?,
      daysTotal: json['days_total'] as int? ?? 5,
      daysDone: json['days_done'] as int? ?? 0,
      status: json['status'] as String? ?? 'active',
      skipDates: (json['skip_dates'] as List<dynamic>?)?.cast<String>() ?? [],
      startDate: DateTime.tryParse(json['start_date'] as String? ?? '') ?? DateTime.now(),
      endDate: DateTime.tryParse(json['end_date'] as String? ?? '') ?? DateTime.now(),
      perDayPrice: (json['per_day_price'] as num?)?.toDouble() ?? 0,
      totalPaid: (json['total_paid'] as num?)?.toDouble() ?? 0,
      cancelledAt: json['cancelled_at'] != null ? DateTime.tryParse(json['cancelled_at'] as String) : null,
      cancellationReason: json['cancellation_reason'] as String?,
      completedAt: json['completed_at'] != null ? DateTime.tryParse(json['completed_at'] as String) : null,
      vendor: json['vendor'] as Map<String, dynamic>?,
      product: json['product'] as Map<String, dynamic>?,
      dayOrders: (json['day_orders'] as List<dynamic>?)
              ?.map((e) => e as Map<String, dynamic>)
              .toList() ??
          [],
    );
  }

  bool get isActive => status == 'active';
  bool get isCompleted => status == 'completed';
  bool get isCancelled => status == 'cancelled';
  double get progressPercent => daysTotal > 0 ? daysDone / daysTotal : 0;
  int get daysRemaining => daysTotal - daysDone;
  String get vendorName => vendor?['name'] as String? ?? 'Kitchen';

  bool isTodaySkipped() {
    final today = DateTime.now().toIso8601String().substring(0, 10);
    return skipDates.contains(today);
  }

  Map<String, dynamic>? get todayOrder {
    final today = daysDone + 1;
    return dayOrders
        .where((o) => (o['habit_day'] as int?) == today)
        .firstOrNull;
  }
}
