import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_core/models/order.dart';
import 'package:shared_core/theme/app_colors.dart';
import 'package:intl/intl.dart';
import '../../common/widgets/loading_overlay.dart';
import '../../common/widgets/skeletons.dart';
import 'order_provider.dart';
import 'today_habits_banner.dart';

class OrdersScreen extends ConsumerStatefulWidget {
  final String? initialOrderId;
  const OrdersScreen({super.key, this.initialOrderId});

  @override
  ConsumerState<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends ConsumerState<OrdersScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  Order? _selectedOrder;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    
    // Select initial order if provided
    if (widget.initialOrderId != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _selectInitialOrder();
      });
    }
  }

  void _selectInitialOrder() {
    final orders = ref.read(orderListProvider).value;
    if (orders != null && widget.initialOrderId != null) {
      final order = orders.where((o) => o.id == widget.initialOrderId).firstOrNull;
      if (order != null) {
        setState(() => _selectedOrder = order);
        
        // Switch tab if needed
        if (order.status == 'preparing' || order.status == 'ready' || order.status == 'dispatched') {
          _tabController.animateTo(0);
        } else if (order.status == 'received' || order.status == 'placed') {
          _tabController.animateTo(1);
        } else {
          _tabController.animateTo(2);
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width > 900;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: isDesktop ? _buildWebOrders(context) : _buildMobileOrders(context),
    );
  }

  Widget _buildWebOrders(BuildContext context) {
    final isOpen = _selectedOrder != null;

    return Stack(
      children: [
        // Base Layer: Centered Order List
        Positioned.fill(
          child: Column(
            children: [
              Expanded(
                child: Center(
                  child: Container(
                    constraints: const BoxConstraints(maxWidth: 900),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border.symmetric(vertical: BorderSide(color: Colors.grey[100]!)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(48, 64, 48, 32),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Order Management',
                                style: GoogleFonts.inter(fontSize: 40, fontWeight: FontWeight.w900, color: AppColors.textMain, letterSpacing: -1.5),
                              ),
                              const SizedBox(height: 24),
                              TabBar(
                                controller: _tabController,
                                indicatorColor: AppColors.brandGreen,
                                indicatorWeight: 4,
                                indicatorSize: TabBarIndicatorSize.label,
                                labelColor: AppColors.textMain,
                                labelPadding: const EdgeInsets.symmetric(horizontal: 24),
                                labelStyle: GoogleFonts.inter(fontWeight: FontWeight.w900, fontSize: 13, letterSpacing: 0.5),
                                unselectedLabelColor: AppColors.textDisabled,
                                unselectedLabelStyle: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 13),
                                tabs: const [
                                  Tab(text: 'ACTIVE'),
                                  Tab(text: 'PENDING'),
                                  Tab(text: 'HISTORY'),
                                ],
                              ),
                            ],
                          ),
                        ),
                        Expanded(
                          child: TabBarView(
                            controller: _tabController,
                            children: [
                              _OrderList(
                                statusFilter: 'preparing,ready,dispatched', 
                                onSelect: (o) => setState(() => _selectedOrder = o),
                                selectedId: _selectedOrder?.id,
                              ),
                              _OrderList(
                                statusFilter: 'received,placed', 
                                onSelect: (o) => setState(() => _selectedOrder = o),
                                selectedId: _selectedOrder?.id,
                              ),
                              _OrderList(
                                statusFilter: 'delivered,completed,cancelled', 
                                onSelect: (o) => setState(() => _selectedOrder = o),
                                selectedId: _selectedOrder?.id,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),

        // Scrim Overlay
        if (isOpen)
          GestureDetector(
            onTap: () => setState(() => _selectedOrder = null),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              color: Colors.black.withOpacity(0.3),
            ),
          ),

        // Right Side Sheet (Detail View)
        AnimatedPositioned(
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeOutQuart,
          right: isOpen ? 0 : -600,
          top: 0,
          bottom: 0,
          child: Container(
            width: 550,
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 40, offset: const Offset(-10, 0)),
              ],
            ),
            child: _selectedOrder == null 
                ? const SizedBox.shrink() 
                : Column(
                    children: [
                      // Header with Close Button
                      Container(
                        padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
                        alignment: Alignment.centerRight,
                        child: IconButton(
                          onPressed: () => setState(() => _selectedOrder = null),
                          icon: const Icon(CupertinoIcons.multiply_circle_fill, color: Color(0xFFE2E8F0), size: 32),
                        ),
                      ),
                      Expanded(child: _WebOrderDetailsView(order: _selectedOrder!)),
                    ],
                  ),
          ),
        ),
      ],
    );
  }

  Widget _buildMobileOrders(BuildContext context) {
    return NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) => [
          SliverAppBar(
            expandedHeight: 80,
            floating: true,
            pinned: true,
            elevation: 0,
            title: Text(
              'ORDER MANAGER',
              style: GoogleFonts.inter(
                fontWeight: FontWeight.w900,
                fontSize: 14,
                letterSpacing: 1.2,
                color: AppColors.textMain,
              ),
            ),
            centerTitle: Theme.of(context).platform == TargetPlatform.iOS,
            backgroundColor: Colors.white,
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border(bottom: BorderSide(color: Colors.grey[100]!, width: 0.5)),
                ),
              ),
            ),
          ),
          SliverPersistentHeader(
            pinned: true,
            delegate: _TabHeaderDelegate(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border(bottom: BorderSide(color: Colors.grey[100]!, width: 0.5)),
                ),
                child: TabBar(
                      controller: _tabController,
                      indicatorColor: AppColors.brandGreen,
                      indicatorWeight: 3,
                      labelColor: AppColors.textMain,
                      labelStyle: GoogleFonts.inter(fontWeight: FontWeight.w900, fontSize: 13, letterSpacing: 0.5),
                      unselectedLabelColor: AppColors.textSub,
                      unselectedLabelStyle: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 13),
                      tabs: const [
                        Tab(text: 'ACTIVE'),
                        Tab(text: 'PENDING'),
                        Tab(text: 'HISTORY'),
                      ],
                    ),
                  ),
                ),
              ),
            ],
            body: TabBarView(
          controller: _tabController,
          children: const [
            _OrderList(statusFilter: 'preparing,ready,dispatched'),
            _OrderList(statusFilter: 'received,placed'),
            _OrderList(statusFilter: 'delivered,completed,cancelled'),
          ],
        ),
      );
  }
}

class _WebOrderDetailsView extends StatelessWidget {
  final Order order;
  const _WebOrderDetailsView({required this.order});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(40, 20, 40, 64),
      child: Center(
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(32),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 40, offset: const Offset(0, 10))],
            border: Border.all(color: Colors.grey[100]!),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Receipt Header
              Container(
                padding: const EdgeInsets.all(40),
                decoration: const BoxDecoration(
                  color: Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.only(topLeft: Radius.circular(32), topRight: Radius.circular(32)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('ORDER DETAIL', style: GoogleFonts.inter(fontWeight: FontWeight.w900, fontSize: 11, color: AppColors.brandGreen, letterSpacing: 1.5)),
                          const SizedBox(height: 12),
                          Text('#${order.orderNumber}', style: GoogleFonts.inter(fontWeight: FontWeight.w900, fontSize: 28, letterSpacing: -1.5, color: AppColors.textMain)),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              const Icon(Icons.calendar_today_rounded, size: 14, color: AppColors.textSub),
                              const SizedBox(width: 8),
                              Expanded(child: Text(DateFormat('MMMM d, yyyy • hh:mm a').format(order.createdAt), style: GoogleFonts.inter(color: AppColors.textSub, fontWeight: FontWeight.w600, fontSize: 12), overflow: TextOverflow.ellipsis)),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    _StatusBadge(status: order.status, isLarge: true),
                  ],
                ),
              ),
              
              Padding(
                padding: const EdgeInsets.all(40),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('ITEMS SUMMARY', style: GoogleFonts.inter(fontWeight: FontWeight.w900, fontSize: 12, color: AppColors.textDisabled, letterSpacing: 1)),
                    const SizedBox(height: 32),
                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: order.items.length,
                      separatorBuilder: (c, i) => const SizedBox(height: 20),
                      itemBuilder: (context, idx) {
                        final item = order.items[idx];
                        return Row(
                          children: [
                            Container(
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(color: AppColors.brandGreen.withOpacity(0.08), borderRadius: BorderRadius.circular(8)),
                              alignment: Alignment.center,
                              child: Text('${item.quantity}', style: GoogleFonts.inter(fontWeight: FontWeight.w900, color: AppColors.brandGreen, fontSize: 14)),
                            ),
                            const SizedBox(width: 16),
                            Expanded(child: Text(item.productName, style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 16, color: AppColors.textMain))),
                            Text('₹${item.totalPrice.toStringAsFixed(0)}', style: GoogleFonts.inter(fontWeight: FontWeight.w900, fontSize: 16, color: AppColors.textMain)),
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 40),
                    Container(height: 1, color: Colors.grey[100]),
                    const SizedBox(height: 32),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Total Bill', style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 14, color: AppColors.textSub)),
                        Text('₹${order.totalAmount.toStringAsFixed(0)}', style: GoogleFonts.inter(fontWeight: FontWeight.w900, fontSize: 32, color: AppColors.brandGreen, letterSpacing: -1.5)),
                      ],
                    ),
                    const SizedBox(height: 48),
                    Row(
                      children: [
                        Expanded(child: SizedBox(height: 60, child: _ActionButton(order: order))),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OrderList extends ConsumerWidget {
  final String statusFilter;
  final Function(Order)? onSelect;
  final String? selectedId;

  const _OrderList({
    required this.statusFilter, 
    this.onSelect, 
    this.selectedId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final orderAsync = ref.watch(orderListProvider);

    return orderAsync.when(
      loading: () => ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 24, 16, 16),
        itemCount: 5,
        itemBuilder: (context, index) => const OrderCardSkeleton(),
      ),
      error: (err, st) => Center(child: Text('Error: $err')),
      data: (orders) {
        final filtered = orders.where((o) => statusFilter.contains(o.status)).toList();
        
        if (filtered.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(color: Colors.grey[50], shape: BoxShape.circle),
                  child: Icon(Icons.receipt_long_outlined, size: 48, color: Colors.grey[300]),
                ),
                const SizedBox(height: 16),
                Text('NO ORDERS FOUND', style: GoogleFonts.inter(color: AppColors.textDisabled, fontWeight: FontWeight.w900, fontSize: 13, letterSpacing: 1)),
              ],
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: () => ref.read(orderListProvider.notifier).fetchOrders(),
          color: AppColors.brandGreen,
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
            itemCount: filtered.length + (statusFilter.contains('preparing') ? 1 : 0),
            itemBuilder: (context, index) {
              // Insert habit banner as first item in ACTIVE tab
              if (statusFilter.contains('preparing') && index == 0) {
                return const TodayHabitsBanner();
              }
              final orderIndex = statusFilter.contains('preparing') ? index - 1 : index;
              return _OrderCard(
                order: filtered[orderIndex],
                onTap: onSelect,
                isSelected: selectedId == filtered[orderIndex].id,
              );
            },
          ),
        );
      },
    );
  }
}

class _OrderCard extends ConsumerWidget {
  final Order order;
  final Function(Order)? onTap;
  final bool isSelected;

  const _OrderCard({
    required this.order, 
    this.onTap, 
    this.isSelected = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final timeStr = DateFormat('hh:mm a').format(order.createdAt);

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: Colors.grey[100]!),
        boxShadow: [
          BoxShadow(
            color: isSelected ? AppColors.brandGreen.withOpacity(0.1) : Colors.black.withOpacity(0.02), 
            blurRadius: 20, 
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(28),
          onTap: () {
            if (onTap != null) {
              onTap!(order);
            } else {
              _showOrderDetails(context, ref, order);
            }
          },
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '#${order.orderNumber}',
                      style: GoogleFonts.inter(fontWeight: FontWeight.w900, fontSize: 17, color: AppColors.textMain, letterSpacing: -0.5),
                    ),
                    _StatusBadge(status: order.status),
                  ],
                ),
                if (order.isHabitPack) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.brandGreen.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.auto_awesome, color: AppColors.brandGreen, size: 14),
                        const SizedBox(width: 4),
                        Text(
                          "DAY ${order.currentFulfillmentDay} / ${order.totalFulfillmentDays} ${order.selectedGoal?.toUpperCase() ?? 'HABIT'} PACK",
                          style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w900, color: AppColors.brandGreen),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 10),
                Row(
                  children: [
                    const Icon(Icons.access_time_filled_rounded, size: 14, color: AppColors.textSub),
                    const SizedBox(width: 6),
                    Text(timeStr, style: GoogleFonts.inter(color: AppColors.textSub, fontSize: 13, fontWeight: FontWeight.w600)),
                    const SizedBox(width: 20),
                    const Icon(Icons.shopping_bag_rounded, size: 14, color: AppColors.textSub),
                    const SizedBox(width: 6),
                    Text('${order.items.length} Items', style: GoogleFonts.inter(color: AppColors.textSub, fontSize: 13, fontWeight: FontWeight.w600)),
                  ],
                ),
                const SizedBox(height: 20),
                Container(height: 1, color: const Color(0xFFF5F5F5)),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '₹${order.totalAmount.toStringAsFixed(0)}',
                      style: GoogleFonts.inter(fontWeight: FontWeight.w900, fontSize: 20, color: AppColors.brandGreen),
                    ),
                    _ActionButton(order: order),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showOrderDetails(BuildContext context, WidgetRef ref, Order order) {
    if (Theme.of(context).platform == TargetPlatform.iOS) {
      showCupertinoModalPopup(
        context: context,
        builder: (context) => _OrderDetailsSheet(order: order),
      );
    } else {
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (context) => _OrderDetailsSheet(order: order),
      );
    }
  }
}

class _StatusBadge extends StatelessWidget {
  final String status;
  final bool isLarge;
  const _StatusBadge({required this.status, this.isLarge = false});

  @override
  Widget build(BuildContext context) {
    Color color = Colors.grey;
    String label = status.toUpperCase();

    switch (status) {
      case 'received': color = Colors.blue; break;
      case 'preparing': color = Colors.orange; break;
      case 'ready': color = Colors.indigo; break;
      case 'dispatched': color = AppColors.brandGreen; break;
      case 'delivered': color = AppColors.brandGreen; break;
      case 'cancelled': color = AppColors.errorRed; break;
    }

    return Container(
      padding: EdgeInsets.symmetric(horizontal: isLarge ? 16 : 10, vertical: isLarge ? 8 : 4),
      decoration: BoxDecoration(color: color.withOpacity(0.08), borderRadius: BorderRadius.circular(10)),
      child: Text(
        label, 
        style: GoogleFonts.inter(
          color: color, 
          fontSize: isLarge ? 12 : 10, 
          fontWeight: FontWeight.w900, 
          letterSpacing: 0.5
        )
      ),
    );
  }
}

class _ActionButton extends ConsumerWidget {
  final Order order;
  const _ActionButton({required this.order});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isIOS = Theme.of(context).platform == TargetPlatform.iOS;
    String label = '';
    String nextStatus = '';

    if (order.status == 'received') {
      label = 'Accept Order';
      nextStatus = 'preparing';
    } else if (order.status == 'preparing') {
      label = 'Mark Ready';
      nextStatus = 'ready';
    } else if (order.status == 'ready' || (order.isHabitPack && order.currentFulfillmentDay < order.totalFulfillmentDays)) {
      if (order.isHabitPack && order.status != 'ready') {
         label = 'Dispatch Day ${order.currentFulfillmentDay + 1}';
         return ElevatedButton(
            onPressed: () => ref.read(orderListProvider.notifier).dispatchHabitOrder(order.id),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.brandGreen,
              foregroundColor: Colors.white,
              minimumSize: const Size(100, 44),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              elevation: 0,
            ),
            child: Text(
              label.toUpperCase(),
              style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 0.5),
            ),
          );
      }
      label = 'Dispatch';
      nextStatus = 'dispatched';
    } else {
      return const SizedBox.shrink();
    }

    if (isIOS) {
      return CupertinoButton.filled(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        borderRadius: BorderRadius.circular(12),
        onPressed: () => ref.read(orderListProvider.notifier).updateOrderStatus(order.id, nextStatus),
        child: Text(
          label.toUpperCase(),
          style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 0.5),
        ),
      );
    }

    return ElevatedButton(
      onPressed: () => ref.read(orderListProvider.notifier).updateOrderStatus(order.id, nextStatus),
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.brandGreen,
        foregroundColor: Colors.white,
        minimumSize: const Size(100, 44),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        elevation: 0,
      ),
      child: Text(
        label.toUpperCase(),
        style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 0.5),
      ),
    );
  }
}

class _OrderDetailsSheet extends StatelessWidget {
  final Order order;
  const _OrderDetailsSheet({required this.order});

  @override
  Widget build(BuildContext context) {
    final isIOS = Theme.of(context).platform == TargetPlatform.iOS;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      decoration: isIOS 
        ? BoxDecoration(
            color: CupertinoColors.systemBackground.resolveFrom(context),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          )
        : null,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'ORDER DETAILS',
            style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w900, letterSpacing: 1, color: AppColors.textMain),
          ),
          if (order.isHabitPack) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.brandGreen.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  const Icon(Icons.auto_awesome, color: AppColors.brandGreen),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "5-Day ${order.selectedGoal ?? 'Health'} Commitment",
                          style: GoogleFonts.inter(fontWeight: FontWeight.w900, fontSize: 14, color: AppColors.brandGreen),
                        ),
                        Text(
                          "Day ${order.currentFulfillmentDay} / ${order.totalFulfillmentDays} • Dispatch Next Segment",
                          style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 12, color: AppColors.brandGreen.withValues(alpha: 0.7)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 24),
          ...order.items.map((item) => Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${item.quantity}x ${item.productName}',
                  style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 14, color: AppColors.textMain),
                ),
                Text(
                  '₹${item.totalPrice.toStringAsFixed(0)}',
                  style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 14, color: AppColors.textMain),
                ),
              ],
            ),
          )),
          const Divider(height: 48, color: Color(0xFFF1F5F9)),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'TOTAL AMOUNT',
                style: GoogleFonts.inter(fontWeight: FontWeight.w900, fontSize: 12, color: AppColors.textSub, letterSpacing: 0.5),
              ),
              Text(
                '₹${order.totalAmount.toStringAsFixed(0)}',
                style: GoogleFonts.inter(fontWeight: FontWeight.w900, fontSize: 24, color: AppColors.brandGreen, letterSpacing: -1),
              ),
            ],
          ),
          const SizedBox(height: 32),
          SizedBox(width: double.infinity, child: _ActionButton(order: order)),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

class _TabHeaderDelegate extends SliverPersistentHeaderDelegate {
  final Widget child;
  _TabHeaderDelegate({required this.child});

  @override
  double get minExtent => 48;
  @override
  double get maxExtent => 48;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) => child;

  @override
  bool shouldRebuild(covariant _TabHeaderDelegate oldDelegate) => false;
}
