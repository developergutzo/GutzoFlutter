import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_core/theme/app_colors.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'report_provider.dart';
import '../auth/vendor_provider.dart';
import '../../common/widgets/skeletons.dart';
import 'package:shared_core/services/node_api_service.dart';

class GSTReportScreen extends ConsumerStatefulWidget {
  const GSTReportScreen({super.key});

  @override
  ConsumerState<GSTReportScreen> createState() => _GSTReportScreenState();
}

class _GSTReportScreenState extends ConsumerState<GSTReportScreen> {
  String _selectedPeriod = 'this_month';
  DateTime? _customFrom;
  DateTime? _customTo;

  @override
  void initState() {
    super.initState();
    Future.microtask(() => _fetchReport());
  }

  void _fetchReport() {
    String? from;
    String? to;

    if (_selectedPeriod == 'custom') {
      if (_customFrom != null) from = _customFrom!.toIso8601String();
      if (_customTo != null) to = _customTo!.toIso8601String();
    } else {
      final now = DateTime.now();
      if (_selectedPeriod == 'this_month') {
        from = DateTime(now.year, now.month, 1).toIso8601String();
        to = now.toIso8601String();
      } else if (_selectedPeriod == 'last_month') {
        from = DateTime(now.year, now.month - 1, 1).toIso8601String();
        to = DateTime(now.year, now.month, 0, 23, 59, 59).toIso8601String();
      }
    }

    ref.read(gstReportProvider.notifier).fetchReport(from: from, to: to);
  }

  Future<void> _downloadReport(String format) async {
    final vendorId = ref.read(vendorProvider).value?.id;
    if (vendorId == null) return;

    final now = DateTime.now();
    late String from;
    late String to;

    if (_selectedPeriod == 'custom') {
      from = _customFrom?.toIso8601String() ?? DateTime(now.year, now.month, 1).toIso8601String();
      to = _customTo?.toIso8601String() ?? now.toIso8601String();
    } else if (_selectedPeriod == 'this_month') {
      from = DateTime(now.year, now.month, 1).toIso8601String();
      to = now.toIso8601String();
    } else {
      from = DateTime(now.year, now.month - 1, 1).toIso8601String();
      to = DateTime(now.year, now.month, 0, 23, 59, 59).toIso8601String();
    }

    final baseUrl = ref.read(nodeApiServiceProvider).baseUrl;
    final url = Uri.parse('$baseUrl/api/vendor-auth/$vendorId/gst-report?from=$from&to=$to&format=$format');

    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not launch download URL')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final reportAsync = ref.watch(gstReportProvider);
    final isIOS = Theme.of(context).platform == TargetPlatform.iOS;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) => [
          SliverAppBar(
            expandedHeight: 80, // Using the new professional compact height
            floating: true,
            pinned: true,
            elevation: 0,
            backgroundColor: Colors.white.withOpacity(0.1),
            centerTitle: isIOS,
            title: Text(
              'GST & TAX REPORTS',
              style: GoogleFonts.inter(
                fontWeight: FontWeight.w900,
                fontSize: 14,
                letterSpacing: 1.2,
                color: AppColors.textMain,
              ),
            ),
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.85),
                  border: Border(bottom: BorderSide(color: Colors.grey[200]!, width: 0.5)),
                ),
                child: ClipRRect(
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                    child: Container(color: Colors.transparent),
                  ),
                ),
              ),
            ),
            actions: [
              IconButton(
                onPressed: () => _showDownloadOptions(context),
                icon: Icon(
                  isIOS ? CupertinoIcons.square_arrow_down : Icons.file_download_rounded,
                  color: AppColors.brandGreen,
                  size: isIOS ? 22 : 28,
                ),
              ),
              const SizedBox(width: 8),
            ],
          ),
        ],
        body: RefreshIndicator.adaptive(
          onRefresh: () async => _fetchReport(),
          color: AppColors.brandGreen,
          child: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 24, 16, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'SELECT PERIOD',
                        style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w900, color: AppColors.brandGreen, letterSpacing: 1),
                      ),
                      const SizedBox(height: 12),
                      _buildPeriodSelector(),
                      if (_selectedPeriod == 'custom') ...[
                        const SizedBox(height: 20),
                        _buildCustomDatePickers(),
                      ],
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
              reportAsync.when(
                loading: () => const SliverFillRemaining(child: Center(child: CircularProgressIndicator(color: AppColors.brandGreen))),
                error: (err, st) => SliverFillRemaining(child: Center(child: Text('Error: $err'))),
                data: (data) => _buildReportContent(data),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPeriodSelector() {
    final options = [
      {'id': 'this_month', 'label': 'THIS MONTH'},
      {'id': 'last_month', 'label': 'LAST MONTH'},
      {'id': 'custom', 'label': 'CUSTOM RANGE'},
    ];

    return Wrap(
      spacing: 8,
      children: options.map((opt) {
        final isSelected = _selectedPeriod == opt['id'];
        return ChoiceChip(
          label: Text(opt['label']!),
          selected: isSelected,
          onSelected: (val) {
            if (val) {
              setState(() => _selectedPeriod = opt['id']!);
              if (_selectedPeriod != 'custom') _fetchReport();
            }
          },
          selectedColor: AppColors.brandGreen,
          labelStyle: GoogleFonts.inter(
            color: isSelected ? Colors.white : AppColors.textSub,
            fontWeight: FontWeight.w900,
            fontSize: 10,
            letterSpacing: 0.5,
          ),
          backgroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 4),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
            side: BorderSide(color: isSelected ? AppColors.brandGreen : Colors.grey[200]!),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildCustomDatePickers() {
    return Row(
      children: [
        Expanded(
          child: _buildDatePickerBox(
            label: 'FROM',
            date: _customFrom,
            onTap: () => _pickDate(context, true),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildDatePickerBox(
            label: 'TO',
            date: _customTo,
            onTap: () => _pickDate(context, false),
          ),
        ),
      ],
    );
  }

  Future<void> _pickDate(BuildContext context, bool isFrom) async {
    final isIOS = Theme.of(context).platform == TargetPlatform.iOS;
    if (isIOS) {
      DateTime tempDate = (isFrom ? _customFrom : _customTo) ?? DateTime.now();
      await showCupertinoModalPopup(
        context: context,
        builder: (context) => Container(
          height: 300,
          color: CupertinoColors.systemBackground.resolveFrom(context),
          child: Column(
            children: [
              Container(
                color: CupertinoColors.secondarySystemBackground.resolveFrom(context),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    CupertinoButton(
                      child: const Text('Cancel'),
                      onPressed: () => Navigator.pop(context),
                    ),
                    CupertinoButton(
                      child: const Text('Done'),
                      onPressed: () {
                        setState(() {
                          if (isFrom) _customFrom = tempDate; else _customTo = tempDate;
                        });
                        Navigator.pop(context);
                        if (_customFrom != null && _customTo != null) _fetchReport();
                      },
                    ),
                  ],
                ),
              ),
              Expanded(
                child: CupertinoDatePicker(
                  mode: CupertinoDatePickerMode.date,
                  initialDateTime: tempDate,
                  onDateTimeChanged: (d) => tempDate = d,
                ),
              ),
            ],
          ),
        ),
      );
    } else {
      final d = await showDatePicker(
        context: context,
        initialDate: DateTime.now(),
        firstDate: DateTime(2023),
        lastDate: DateTime.now(),
        builder: (context, child) => Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(primary: AppColors.brandGreen),
          ),
          child: child!,
        ),
      );
      if (d != null) {
        setState(() {
          if (isFrom) _customFrom = d; else _customTo = d;
        });
        if (_customFrom != null && _customTo != null) _fetchReport();
      }
    }
  }

  Widget _buildDatePickerBox({required String label, DateTime? date, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey[100]!),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4)),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: GoogleFonts.inter(fontSize: 10, color: AppColors.textSub, fontWeight: FontWeight.w900, letterSpacing: 0.5)),
            const SizedBox(height: 6),
            Text(
              date != null ? DateFormat('dd MMM yyyy').format(date).toUpperCase() : 'SELECT',
              style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w900, color: AppColors.textMain),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReportContent(Map<String, dynamic> data) {
    final summary = data['summary'] as Map<String, dynamic>;
    final orders = data['orders'] as List<dynamic>;

    return SliverList(
      delegate: SliverChildListDelegate([
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSummaryGrid(summary),
              const SizedBox(height: 32),
              Text(
                'ORDER-WISE BREAKDOWN',
                style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w900, color: AppColors.brandGreen, letterSpacing: 1),
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
        if (orders.isEmpty)
          Center(
            child: Padding(
              padding: const EdgeInsets.all(60), 
              child: Text(
                'NO TRANSACTIONS FOUND', 
                style: GoogleFonts.inter(color: AppColors.textDisabled, fontSize: 13, fontWeight: FontWeight.w900, letterSpacing: 1)
              )
            )
          )
        else
          ...orders.map((o) => _buildOrderTaxRow(o)).toList(),
        const SizedBox(height: 100),
      ]),
    );
  }

  Widget _buildSummaryGrid(Map<String, dynamic> summary) {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      childAspectRatio: 1.6,
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      children: [
        _buildStatCard('Total Sales', '₹${(summary['total_sales_value'] ?? 0).toStringAsFixed(0)}', Icons.currency_rupee, Colors.blue),
        _buildStatCard('Taxable Amount', '₹${((summary['total_sales_value'] ?? 0) - (summary['total_gst_collected_5_percent'] ?? 0)).toStringAsFixed(0)}', Icons.receipt_long, Colors.orange),
        _buildStatCard('CGST (2.5%)', '₹${((summary['total_gst_collected_5_percent'] ?? 0) / 2).toStringAsFixed(0)}', Icons.pie_chart_outline, AppColors.brandGreen),
        _buildStatCard('SGST (2.5%)', '₹${((summary['total_gst_collected_5_percent'] ?? 0) / 2).toStringAsFixed(0)}', Icons.pie_chart, AppColors.brandGreen),
      ],
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.grey[50]!),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02), 
            blurRadius: 20, 
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label.toUpperCase(), style: GoogleFonts.inter(fontSize: 10, color: AppColors.textSub, fontWeight: FontWeight.w900, letterSpacing: 0.5)),
              Icon(icon, size: 14, color: color.withOpacity(0.4)),
            ],
          ),
          Text(
            value, 
            style: GoogleFonts.inter(fontSize: 19, fontWeight: FontWeight.w900, color: AppColors.textMain),
          ),
        ],
      ),
    );
  }

  Widget _buildOrderTaxRow(Map<String, dynamic> order) {
    final date = DateTime.parse(order['date']);
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey[100]!),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('#${order['order_number']}', style: GoogleFonts.inter(fontWeight: FontWeight.w900, fontSize: 13, color: AppColors.textMain)),
                const SizedBox(height: 2),
                Text(DateFormat('dd MMM yy').format(date).toUpperCase(), style: GoogleFonts.inter(color: AppColors.textSub, fontSize: 10, fontWeight: FontWeight.w700)),
              ],
            ),
          ),
          Expanded(
            child: Column(
              children: [
                Text('TOTAL', style: GoogleFonts.inter(fontSize: 8, color: AppColors.textDisabled, fontWeight: FontWeight.w800)),
                Text('₹${(order['item_total'] ?? 0).toStringAsFixed(0)}', style: GoogleFonts.inter(fontWeight: FontWeight.w900, fontSize: 13)),
              ],
            ),
          ),
          Expanded(
            child: Column(
              children: [
                Text('CGST', style: GoogleFonts.inter(fontSize: 8, color: AppColors.textDisabled, fontWeight: FontWeight.w800)),
                Text('₹${((order['gst_on_items'] ?? 0) / 2).toStringAsFixed(0)}', style: GoogleFonts.inter(color: AppColors.textSub, fontWeight: FontWeight.w700, fontSize: 13)),
              ],
            ),
          ),
          Expanded(
            child: Column(
              children: [
                Text('SGST', style: GoogleFonts.inter(fontSize: 8, color: AppColors.textDisabled, fontWeight: FontWeight.w800)),
                Text('₹${((order['gst_on_items'] ?? 0) / 2).toStringAsFixed(0)}', style: GoogleFonts.inter(color: AppColors.textSub, fontWeight: FontWeight.w700, fontSize: 13)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showDownloadOptions(BuildContext context) {
    if (Theme.of(context).platform == TargetPlatform.iOS) {
      showCupertinoModalPopup(
        context: context,
        builder: (context) => CupertinoActionSheet(
          title: Text('DOWNLOAD REPORT', style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 13)),
          message: const Text('Choose your preferred file format'),
          actions: [
            CupertinoActionSheetAction(
              onPressed: () {
                Navigator.pop(context);
                _downloadReport('pdf');
              },
              child: Text('Download PDF', style: GoogleFonts.inter(fontWeight: FontWeight.w600, color: CupertinoColors.activeBlue)),
            ),
            CupertinoActionSheetAction(
              onPressed: () {
                Navigator.pop(context);
                _downloadReport('excel');
              },
              child: Text('Download Excel (.xlsx)', style: GoogleFonts.inter(fontWeight: FontWeight.w600, color: AppColors.brandGreen)),
            ),
          ],
          cancelButton: CupertinoActionSheetAction(
            isDefaultAction: true,
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ),
      );
    } else {
      showModalBottomSheet(
        context: context,
        backgroundColor: Colors.transparent,
        builder: (context) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 24),
                    decoration: BoxDecoration(color: Colors.grey[200], borderRadius: BorderRadius.circular(2)),
                  ),
                  Text('DOWNLOAD REPORT', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w900, letterSpacing: 1)),
                  const SizedBox(height: 24),
                  ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(color: Colors.red.withOpacity(0.1), shape: BoxShape.circle),
                      child: const Icon(Icons.picture_as_pdf_rounded, color: Colors.red, size: 20),
                    ),
                    title: Text('Download PDF', style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 14)),
                    subtitle: Text('Best for printing & records', style: GoogleFonts.inter(fontSize: 12, color: AppColors.textSub)),
                    onTap: () {
                      Navigator.pop(context);
                      _downloadReport('pdf');
                    },
                  ),
                  ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(color: AppColors.brandGreen.withOpacity(0.1), shape: BoxShape.circle),
                      child: const Icon(Icons.table_view_rounded, color: AppColors.brandGreen, size: 20),
                    ),
                    title: Text('Download Excel (.xlsx)', style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 14)),
                    subtitle: Text('Best for tax computation', style: GoogleFonts.inter(fontSize: 12, color: AppColors.textSub)),
                    onTap: () {
                      Navigator.pop(context);
                      _downloadReport('excel');
                    },
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ),
      );
    }
  }
}
