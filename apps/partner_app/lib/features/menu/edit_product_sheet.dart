import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_core/models/product.dart';
import 'package:shared_core/theme/app_colors.dart';
import 'menu_provider.dart';
import '../../shared/widgets/adaptive_wrapper.dart';

class EditProductSheet extends ConsumerStatefulWidget {
  final Product? product;

  const EditProductSheet({super.key, this.product});

  @override
  ConsumerState<EditProductSheet> createState() => _EditProductSheetState();
}

class _EditProductSheetState extends ConsumerState<EditProductSheet> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _descController;
  late TextEditingController _priceController;
  late TextEditingController _originalPriceController;
  late TextEditingController _discountController;
  late String _category;
  late bool _isVeg;
  late String _dietaryType; // 'veg', 'non-veg', 'egg', 'vegan'
  late bool _isAvailable;
  late String _serviceType;
  late List<String> _selectedMissionTags;
  late TextEditingController _calController;
  late TextEditingController _proController;
  late TextEditingController _carbController;
  late TextEditingController _fatController;
  late TextEditingController _fiberController;
  late TextEditingController _sugarController;
  bool _isDirty = false;

  final List<String> _categories = [
    'Breakfast',
    'Salads',
    'Bowls',
    'Soups',
    'Wraps & Rolls',
    'Smoothies',
    'Juices',
    'Mains',
    'Snacks',
    'Desserts'
  ];

  final List<String> _serviceCategoryList = [
    'Instant', 'Freshly Prepared', 'Pre-Order'
  ];

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.product?.name ?? '')
      ..addListener(_markDirty);
    _descController = TextEditingController(text: widget.product?.description ?? '')
      ..addListener(_markDirty);
    _priceController = TextEditingController(text: widget.product?.price.toString() ?? '');
    _originalPriceController = TextEditingController(text: widget.product?.originalPrice?.toString() ?? '')
      ..addListener(_markDirty);
    _discountController = TextEditingController(text: widget.product?.discountPct?.toString() ?? '0')
      ..addListener(_markDirty);
    _category = widget.product?.category ?? _categories[0];
    _isVeg = widget.product?.isVeg ?? true;
    _dietaryType = widget.product?.dietaryType ?? 'veg';
    _isAvailable = widget.product?.isAvailable ?? true;
    
    final existingTags = widget.product?.dietTags ?? [];
    _serviceType = existingTags.firstWhere((t) => t.startsWith('Type:'), orElse: () => 'Type:Instant');
    
    // Mission Tags Mapping
    _selectedMissionTags = existingTags.where((t) => 
      ['low calorie', 'high protein', 'high fiber', 'sugar free'].contains(t)
    ).toList();

    final nutrition = widget.product?.nutritionalInfo;
    _calController = TextEditingController(text: nutrition?['calories']?.toString() ?? '')
      ..addListener(_markDirty);
    _proController = TextEditingController(text: nutrition?['protein']?.toString() ?? '')
      ..addListener(_markDirty);
    _carbController = TextEditingController(text: nutrition?['carbs']?.toString() ?? '')
      ..addListener(_markDirty);
    _fatController = TextEditingController(text: nutrition?['fat']?.toString() ?? '')
      ..addListener(_markDirty);
    _fiberController = TextEditingController(text: nutrition?['fiber']?.toString() ?? '')
      ..addListener(_markDirty);
    _sugarController = TextEditingController(text: nutrition?['sugar']?.toString() ?? '')
      ..addListener(_markDirty);

    _originalPriceController.addListener(_calculatePrice);
    _discountController.addListener(_calculatePrice);
  }

  void _markDirty() {
    if (!_isDirty) setState(() => _isDirty = true);
  }

  void _calculatePrice() {
    setState(() {
      final original = double.tryParse(_originalPriceController.text) ?? 0;
      final discount = double.tryParse(_discountController.text) ?? 0;
      if (original > 0) {
        final finalPrice = (original * (1 - discount / 100)).round().toDouble();
        _priceController.text = finalPrice.toString();
      }
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descController.dispose();
    _priceController.dispose();
    _originalPriceController.dispose();
    _discountController.dispose();
    _calController.dispose();
    _proController.dispose();
    _carbController.dispose();
    _fatController.dispose();
    _fiberController.dispose();
    _sugarController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
  
    final allTags = [_serviceType, ..._selectedMissionTags];
    final tagsString = allTags.join(',');
    final descriptionWithTags = '${_descController.text} [TAGS:$tagsString]';
  
    final updatedProduct = widget.product?.copyWith(
      name: _nameController.text,
      description: descriptionWithTags,
      price: double.parse(_priceController.text),
      originalPrice: double.tryParse(_originalPriceController.text),
      discountPct: double.tryParse(_discountController.text),
      category: _category,
      isVeg: _dietaryType != 'non-veg',
      dietaryType: _dietaryType,
      isAvailable: _isAvailable,
      dietTags: allTags,
      nutritionalInfo: {
        'calories': double.tryParse(_calController.text),
        'protein': double.tryParse(_proController.text),
        'carbs': double.tryParse(_carbController.text),
        'fat': double.tryParse(_fatController.text),
        'fiber': double.tryParse(_fiberController.text),
        'sugar': double.tryParse(_sugarController.text),
      },
    ) ?? Product(
      id: '',
      vendorId: '', 
      name: _nameController.text,
      description: descriptionWithTags,
      price: double.parse(_priceController.text),
      originalPrice: double.tryParse(_originalPriceController.text),
      discountPct: double.tryParse(_discountController.text),
      category: _category,
      isVeg: _dietaryType != 'non-veg',
      dietaryType: _dietaryType,
      isAvailable: _isAvailable,
      image: '',
      createdAt: DateTime.now(),
      dietTags: allTags,
      nutritionalInfo: {
        'calories': double.tryParse(_calController.text),
        'protein': double.tryParse(_proController.text),
        'carbs': double.tryParse(_carbController.text),
        'fat': double.tryParse(_fatController.text),
        'fiber': double.tryParse(_fiberController.text),
        'sugar': double.tryParse(_sugarController.text),
      },
    );

    try {
      if (widget.product == null) {
      } else {
        await ref.read(menuProvider.notifier).updateProduct(updatedProduct);
      }
      if (mounted) Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to save: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isIOS = Theme.of(context).platform == TargetPlatform.iOS;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: isIOS 
        ? CupertinoNavigationBar(
            middle: Text(
              widget.product == null ? 'ADD PRODUCT' : 'EDIT PRODUCT',
              style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 13, letterSpacing: 0.5),
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'IN STOCK',
                  style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w900, color: AppColors.textSub),
                ),
                const SizedBox(width: 4),
                Transform.scale(
                  scale: 0.7,
                  child: CupertinoSwitch(
                    value: _isAvailable,
                    activeColor: AppColors.brandGreen,
                    onChanged: (val) {
                      _markDirty();
                      setState(() => _isAvailable = val);
                    },
                  ),
                ),
              ],
            ),
          ) as PreferredSizeWidget
        : AppBar(
            leading: IconButton(icon: const Icon(Icons.close_rounded), onPressed: () => Navigator.pop(context)),
            title: Text(
              widget.product == null ? 'ADD PRODUCT' : 'EDIT PRODUCT',
              style: GoogleFonts.inter(fontWeight: FontWeight.w900, fontSize: 14, letterSpacing: 1.2),
            ),
            actions: [
              Row(
                children: [
                  Text(
                    'IN STOCK',
                    style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w900, color: AppColors.textSub),
                  ),
                  const SizedBox(width: 4),
                  Transform.scale(
                    scale: 0.8,
                    child: Switch.adaptive(
                      value: _isAvailable,
                      activeColor: AppColors.brandGreen,
                      onChanged: (val) {
                        _markDirty();
                        setState(() => _isAvailable = val);
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                ],
              ),
            ],
          ),
      body: AdaptiveWrapper(
        child: Column(
          children: [
            Expanded(
              child: Form(
                key: _formKey,
                child: ListView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
                  children: [
                    _buildSectionHeader('ITEM IDENTITY'),
                    _buildCard(
                      children: [
                        Center(
                          child: Stack(
                            children: [
                              Container(
                                width: 110,
                                height: 110,
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF1F5F9),
                                  borderRadius: BorderRadius.circular(28),
                                  image: widget.product?.image != null && widget.product!.image.isNotEmpty
                                    ? DecorationImage(image: NetworkImage(widget.product!.image), fit: BoxFit.cover)
                                    : null,
                                ),
                                child: widget.product?.image == null || widget.product!.image.isEmpty
                                  ? Icon(isIOS ? CupertinoIcons.camera_fill : Icons.add_photo_alternate_rounded, size: 36, color: Colors.blueGrey[200])
                                  : null,
                              ),
                              Positioned(
                                bottom: 0,
                                right: 0,
                                child: Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: AppColors.brandGreen, 
                                    shape: BoxShape.circle,
                                    border: Border.all(color: Colors.white, width: 2),
                                  ),
                                  child: Icon(isIOS ? CupertinoIcons.pencil : Icons.edit_rounded, color: Colors.white, size: 14),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),
                        _buildTextField(
                          controller: _nameController,
                          label: 'DISH NAME',
                          placeholder: 'e.g. Classic Paneer Tikka',
                          icon: isIOS ? CupertinoIcons.tag : Icons.restaurant_rounded,
                        ),
                        const SizedBox(height: 20),
                        _buildTextField(
                          controller: _descController,
                          label: 'DESCRIPTION',
                          placeholder: 'Ingredients, preparation notes...',
                          maxLines: 4,
                          icon: isIOS ? CupertinoIcons.text_alignleft : Icons.description_rounded,
                        ),
                      ]
                    ),
                    const SizedBox(height: 24),
  
                    _buildSectionHeader('PRICING & DISCOUNT'),
                    _buildCard(
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: _buildTextField(
                                controller: _originalPriceController,
                                label: 'BASE PRICE (₹)',
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                isNumeric: true,
                                icon: isIOS ? CupertinoIcons.money_dollar : Icons.currency_rupee_rounded,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: _buildTextField(
                                controller: _discountController,
                                label: 'DISCOUNT (%)',
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                isNumeric: true,
                                color: Colors.orange[700],
                                icon: isIOS ? CupertinoIcons.percent : Icons.percent_rounded,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        _buildCheckoutSummary(),
                      ]
                    ),
                    const SizedBox(height: 24),
  
                    _buildSectionHeader('CLASSIFICATION'),
                    _buildCard(
                      children: [
                        _buildCategorySelector(),
                      ],
                    ),
                    const SizedBox(height: 24),

                    _buildSectionHeader('HEALTH MISSIONS (GOALS)'),
                    _buildCard(
                      children: [
                        _buildMissionSelector(),
                      ],
                    ),
                    const SizedBox(height: 24),

                    _buildSectionHeader('NUTRITIONAL FACTS'),
                    _buildCard(
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: _buildTextField(
                                controller: _calController,
                                label: 'CALORIES (kcal)',
                                placeholder: '0',
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                isNumeric: true,
                                icon: isIOS ? CupertinoIcons.bolt_fill : Icons.bolt_rounded,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: _buildTextField(
                                controller: _proController,
                                label: 'PROTEIN (g)',
                                placeholder: '0',
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                isNumeric: true,
                                color: Colors.blue[700],
                                icon: isIOS ? CupertinoIcons.square_stack_3d_up_fill : Icons.fitness_center_rounded,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: _buildTextField(
                                controller: _carbController,
                                label: 'CARBS (g)',
                                placeholder: '0',
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                isNumeric: true,
                                color: Colors.orange[700],
                                icon: isIOS ? CupertinoIcons.graph_circle : Icons.grain_rounded,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: _buildTextField(
                                controller: _fatController,
                                label: 'FATS (g)',
                                placeholder: '0',
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                isNumeric: true,
                                color: Colors.red[700],
                                icon: isIOS ? CupertinoIcons.drop_fill : Icons.water_drop_rounded,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16), // Added breathing room
                        Row(
                          children: [
                            Expanded(
                              child: _buildTextField(
                                controller: _fiberController,
                                label: 'FIBER (g)',
                                placeholder: '0',
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                isNumeric: true,
                                color: Colors.green[700],
                                icon: isIOS ? CupertinoIcons.leaf_arrow_circlepath : Icons.grass_rounded,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: _buildTextField(
                                controller: _sugarController,
                                label: 'SUGAR (g)',
                                placeholder: '0',
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                isNumeric: true,
                                color: Colors.pink[700],
                                icon: isIOS ? CupertinoIcons.nosign : Icons.block_rounded,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Detailed macros build trust with healthy mission users.',
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    _buildSectionHeader('OPERATIONS'),
                    _buildCard(
                      children: [
                        _buildServiceSelector(),
                        const SizedBox(height: 20),
                        _buildSectionHeader('DIETARY PREFERENCE', topPadding: 0),
                        _buildDietarySelector(isIOS),
                      ],
                    ),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
            if (!isIOS) _buildBottomAction(),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String label, {double? topPadding}) {
    return Padding(
      padding: EdgeInsets.only(left: 4, bottom: 12, top: topPadding ?? 24),
      child: Text(
        label,
        style: GoogleFonts.inter(
          fontSize: 11,
          fontWeight: FontWeight.w900,
          color: AppColors.brandGreen,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _buildMissionSelector() {
    final missions = [
      {'label': 'Weight Loss', 'tag': 'low calorie'},
      {'label': 'Muscle Gain', 'tag': 'high protein'},
      {'label': 'Skin Glow', 'tag': 'high fiber'},
      {'label': 'Diabetic Friendly', 'tag': 'sugar free'},
    ];

    return Wrap(
      spacing: 8,
      runSpacing: 10,
      children: missions.map((m) {
        final isSelected = _selectedMissionTags.contains(m['tag']);
        return FilterChip(
          label: Text(m['label']!.toUpperCase()),
          selected: isSelected,
          onSelected: (val) {
            _markDirty();
            setState(() {
              if (val) _selectedMissionTags.add(m['tag']!);
              else _selectedMissionTags.remove(m['tag']);
            });
          },
          selectedColor: AppColors.brandGreen,
          checkmarkColor: Colors.white,
          labelStyle: GoogleFonts.inter(
            fontSize: 9, 
            fontWeight: FontWeight.w900, 
            color: isSelected ? Colors.white : AppColors.textMain,
            letterSpacing: 0.5,
          ),
          backgroundColor: const Color(0xFFF1F5F9),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide.none),
          padding: const EdgeInsets.symmetric(horizontal: 4),
        );
      }).toList(),
    );
  }

  Widget _buildServiceSelector() {
    final isIOS = Theme.of(context).platform == TargetPlatform.iOS;
    return Row(
      children: [
        Expanded(
          child: _buildServiceCard(
            title: 'INSTANT',
            subtitle: 'On-demand',
            icon: isIOS ? CupertinoIcons.rocket_fill : Icons.rocket_launch_rounded,
            isSelected: _serviceType == 'Type:Instant',
            onTap: () {
              _markDirty();
              setState(() => _serviceType = 'Type:Instant');
            },
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildServiceCard(
            title: 'MEAL PLAN',
            subtitle: 'Scheduled',
            icon: isIOS ? CupertinoIcons.calendar : Icons.calendar_month_rounded,
            isSelected: false,
            onTap: () {},
            isUpcoming: true,
          ),
        ),
      ],
    );
  }

  Widget _buildBottomAction() {
    return Container(
      padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + MediaQuery.of(context).padding.bottom),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -4))],
      ),
      child: SizedBox(
        width: double.infinity,
        height: 56,
        child: ElevatedButton(
          onPressed: _isDirty ? _save : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.brandGreen,
            foregroundColor: Colors.white,
            disabledBackgroundColor: Colors.grey[100],
            disabledForegroundColor: Colors.grey[400],
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            elevation: 0,
          ),
          child: Text(
            'SAVE PRODUCT CHANGES',
            style: GoogleFonts.inter(fontWeight: FontWeight.w900, letterSpacing: 0.5, fontSize: 13),
          ),
        ),
      ),
    );
  }

  Widget _buildCard({required List<Widget> children, EdgeInsets? padding}) {
    return Container(
      width: double.infinity,
      padding: padding ?? const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white, width: 0),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }

  Widget _buildCheckoutSummary() {
    final isIOS = Theme.of(context).platform == TargetPlatform.iOS;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFE8F6F1), Color(0xFFF0FDF4)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFCDEBDD), width: 1.5),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.8),
              shape: BoxShape.circle,
            ),
            child: Icon(isIOS ? CupertinoIcons.chart_bar_alt_fill : Icons.auto_graph_rounded, color: const Color(0xFF10B981), size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'MARKETPLACE PRICE',
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    color: const Color(0xFF0F766E),
                    letterSpacing: 0.5,
                  ),
                ),
                Text(
                  'Final customer checkout price',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: const Color(0xFF0F766E).withOpacity(0.6),
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '₹${_priceController.text}',
                style: GoogleFonts.inter(
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  color: const Color(0xFF0F766E),
                ),
              ),
              Text(
                'incl. all taxes',
                style: GoogleFonts.inter(
                  fontSize: 8,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF0F766E).withOpacity(0.5),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildServiceCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
    bool isUpcoming = false,
  }) {
    return GestureDetector(
      onTap: isUpcoming ? null : onTap,
      child: Opacity(
        opacity: isUpcoming ? 0.5 : 1.0,
        child: Stack(
          children: [
            Container(
              height: 100,
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isSelected ? const Color(0xFFE8F6F1) : const Color(0xFFF9F9F9),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isSelected ? AppColors.brandGreen : Colors.grey[200]!,
                  width: isSelected ? 2 : 1,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    icon,
                    size: 20,
                    color: isSelected ? AppColors.brandGreen : Colors.grey[400],
                  ),
                  const Spacer(),
                  Text(
                    title,
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: isSelected ? const Color(0xFF0F6E56) : Colors.grey[500],
                    ),
                  ),
                  Text(
                    subtitle,
                    style: GoogleFonts.inter(
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                      color: isSelected ? const Color(0xFF0F6E56).withOpacity(0.6) : Colors.grey[400],
                    ),
                  ),
                ],
              ),
            ),
            if (isUpcoming)
              Positioned(
                top: 12,
                right: 12,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    'COMING SOON',
                    style: GoogleFonts.inter(
                      fontSize: 7,
                      fontWeight: FontWeight.w900,
                      color: Colors.grey[700],
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionLabel(String label) {
    return Text(
      label,
      style: GoogleFonts.inter(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        color: Colors.blueGrey[400],
        letterSpacing: 1.0,
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    String? placeholder,
    int maxLines = 1,
    TextInputType keyboardType = TextInputType.text,
    Color? color,
    bool isNumeric = false,
    IconData? icon,
  }) {
    final isIOS = Theme.of(context).platform == TargetPlatform.iOS;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            if (icon != null) Icon(icon, size: 12, color: AppColors.textSub),
            if (icon != null) const SizedBox(width: 6),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 10,
                fontWeight: FontWeight.w900,
                color: AppColors.textSub,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        isIOS 
          ? CupertinoTextField(
              controller: controller,
              maxLines: maxLines,
              placeholder: placeholder,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              keyboardType: keyboardType,
              inputFormatters: isNumeric ? [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))] : null,
              style: GoogleFonts.inter(
                fontSize: 14, 
                fontWeight: FontWeight.w700,
                color: color ?? AppColors.textMain,
              ),
              placeholderStyle: GoogleFonts.inter(color: Colors.grey[300], fontSize: 13, fontWeight: FontWeight.w500),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(14),
              ),
            )
          : TextFormField(
              controller: controller,
              maxLines: maxLines,
              keyboardType: keyboardType,
              inputFormatters: isNumeric ? [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))] : null,
              style: GoogleFonts.inter(
                fontSize: 14, 
                fontWeight: FontWeight.w700,
                color: color ?? AppColors.textMain,
              ),
              decoration: InputDecoration(
                hintText: placeholder,
                hintStyle: GoogleFonts.inter(color: Colors.grey[300], fontSize: 13, fontWeight: FontWeight.w500),
                filled: true,
                fillColor: const Color(0xFFF1F5F9),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: AppColors.brandGreen, width: 1.5),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
              validator: (val) => val == null || val.isEmpty ? 'Required' : null,
            ),
      ],
    );
  }

  void _showCategoryPicker() {
    final isIOS = Theme.of(context).platform == TargetPlatform.iOS;
    if (isIOS) {
      showCupertinoModalPopup(
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
                    CupertinoButton(child: const Text('Cancel'), onPressed: () => Navigator.pop(context)),
                    CupertinoButton(child: const Text('Done'), onPressed: () => Navigator.pop(context)),
                  ],
                ),
              ),
              Expanded(
                child: CupertinoPicker(
                  itemExtent: 40,
                  onSelectedItemChanged: (idx) {
                    _markDirty();
                    setState(() => _category = _categories[idx]);
                  },
                  children: _categories.map((c) => Center(child: Text(c, style: GoogleFonts.inter(fontSize: 16)))).toList(),
                ),
              ),
            ],
          ),
        ),
      );
    } else {
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.white,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        builder: (context) => Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.7,
          ),
          padding: const EdgeInsets.symmetric(vertical: 24),
          child: ListView(
            shrinkWrap: true,
            physics: const BouncingScrollPhysics(),
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Text(
                  'SELECT PRIMARY CATEGORY',
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    color: Colors.blueGrey[400],
                    letterSpacing: 1.2,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              ..._categories.map((c) {
                final isSelected = _category == c;
                return ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
                  onTap: () {
                    _markDirty();
                    setState(() => _category = c);
                    Navigator.pop(context);
                  },
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: isSelected ? AppColors.brandGreen.withOpacity(0.1) : Colors.transparent,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      isSelected ? Icons.check_circle_rounded : Icons.circle_outlined,
                      color: isSelected ? AppColors.brandGreen : Colors.grey[300],
                      size: 20,
                    ),
                  ),
                  title: Text(
                    c,
                    style: GoogleFonts.inter(
                      fontSize: 15,
                      fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                      color: isSelected ? AppColors.brandGreen : AppColors.textMain,
                    ),
                  ),
                  trailing: isSelected 
                    ? const Icon(Icons.arrow_right_alt_rounded, color: AppColors.brandGreen)
                    : null,
                );
              }).toList(),
              const SizedBox(height: 16),
            ],
          ),
        ),
      );
    }
  }

  Widget _buildCategorySelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Primary Category',
          style: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: AppColors.textMain,
          ),
        ),
        const SizedBox(height: 12),
        GestureDetector(
          onTap: _showCategoryPicker,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey[200]!, width: 1),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: AppColors.brandGreen.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.category_rounded, size: 16, color: AppColors.brandGreen),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _category,
                    style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textMain),
                  ),
                ),
                const Icon(Icons.keyboard_arrow_down_rounded, color: AppColors.textDisabled, size: 20),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTagChip({required String label, required bool isSelected, required Function(bool) onSelected}) {
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: onSelected,
      selectedColor: AppColors.brandGreen,
      backgroundColor: Colors.white,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      labelStyle: GoogleFonts.inter(
        fontSize: 10,
        fontWeight: FontWeight.w900,
        color: isSelected ? Colors.white : AppColors.textSub,
        letterSpacing: 0.5,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: isSelected ? AppColors.brandGreen : Colors.grey[200]!),
      ),
    );
  }

  Widget _buildDietarySelector(bool isIOS) {
    final options = {
      'veg': {'label': 'VEG', 'icon': isIOS ? CupertinoIcons.leaf_arrow_circlepath : Icons.eco_rounded, 'color': Colors.green},
      'egg': {'label': 'EGG', 'icon': isIOS ? CupertinoIcons.circle_fill : Icons.egg_rounded, 'color': Colors.amber[700]},
      'non-veg': {'label': 'NON-VEG', 'icon': isIOS ? CupertinoIcons.bolt_fill : Icons.restaurant_rounded, 'color': Colors.red},
      'vegan': {'label': 'VEGAN', 'icon': isIOS ? CupertinoIcons.sparkles : Icons.spa_rounded, 'color': Colors.teal},
    };

    if (isIOS) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        width: double.infinity,
        child: CupertinoSlidingSegmentedControl<String>(
          groupValue: _dietaryType,
          backgroundColor: const Color(0xFFF1F5F9),
          thumbColor: Colors.white,
          children: options.map((key, val) => MapEntry(
            key,
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(val['icon'] as IconData, size: 12, color: _dietaryType == key ? val['color'] as Color : AppColors.textSub),
                  const SizedBox(width: 4),
                  Text(
                    val['label'] as String,
                    style: GoogleFonts.inter(
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      color: _dietaryType == key ? AppColors.textMain : AppColors.textSub,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ),
          )),
          onValueChanged: (val) {
            if (val != null) {
              _markDirty();
              setState(() => _dietaryType = val);
            }
          },
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: options.entries.map((entry) {
          final isSelected = _dietaryType == entry.key;
          return Expanded(
            child: GestureDetector(
              onTap: () {
                _markDirty();
                setState(() => _dietaryType = entry.key);
              },
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 2),
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: isSelected ? (entry.value['color'] as Color).withOpacity(0.1) : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isSelected ? entry.value['color'] as Color : Colors.transparent,
                    width: 2,
                  ),
                ),
                child: Column(
                  children: [
                    Icon(entry.value['icon'] as IconData, 
                      size: 20, 
                      color: isSelected ? entry.value['color'] as Color : AppColors.textSub
                    ),
                    const SizedBox(height: 4),
                    Text(
                      entry.value['label'] as String,
                      style: GoogleFonts.inter(
                        fontSize: 9,
                        fontWeight: FontWeight.w900,
                        color: isSelected ? AppColors.textMain : AppColors.textSub,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildSwitchRow({
    required String label,
    required bool value,
    required Function(bool) onChanged,
    required IconData icon,
    required Color activeColor,
  }) {
    final isIOS = Theme.of(context).platform == TargetPlatform.iOS;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: activeColor.withOpacity(0.1), shape: BoxShape.circle),
            child: Icon(icon, size: 16, color: activeColor),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              label,
              style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textMain),
            ),
          ),
          isIOS 
            ? CupertinoSwitch(value: value, activeColor: activeColor, onChanged: onChanged)
            : Switch.adaptive(value: value, activeColor: activeColor, onChanged: onChanged),
        ],
      ),
    );
  }
}
