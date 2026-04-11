import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_core/theme/app_colors.dart';
import 'package:google_fonts/google_fonts.dart';
import 'location_sheet.dart';
import 'location_pick_view.dart';
import 'add_address_detail_screen.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:shared_core/services/location_service.dart';

enum LocationPanelView { list, map, details }

class WebLocationPanel extends ConsumerStatefulWidget {
  const WebLocationPanel({super.key});

  static void show(BuildContext context) {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'LocationPanel',
      barrierColor: Colors.black.withOpacity(0.5),
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (context, anim1, anim2) {
        return const Align(
          alignment: Alignment.centerLeft,
          child: WebLocationPanel(),
        );
      },
      transitionBuilder: (context, anim1, anim2, child) {
        return SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(-1, 0),
            end: Offset.zero,
          ).animate(CurvedAnimation(parent: anim1, curve: Curves.easeOutQuart)),
          child: child,
        );
      },
    );
  }

  @override
  ConsumerState<WebLocationPanel> createState() => _WebLocationPanelState();
}

class _WebLocationPanelState extends ConsumerState<WebLocationPanel> {
  LocationPanelView _currentView = LocationPanelView.list;
  
  // Data passed between views
  bool _isAddingAddress = false;
  LatLng? _selectedPosition;
  DetailedAddress? _selectedAddress;

  void _switchToMap({bool isAdding = false}) {
    setState(() {
      _isAddingAddress = isAdding;
      _currentView = LocationPanelView.map;
    });
  }

  void _switchToDetails(LatLng position, DetailedAddress address) {
    setState(() {
      _selectedPosition = position;
      _selectedAddress = address;
      _currentView = LocationPanelView.details;
    });
  }

  void _switchBack() {
    setState(() {
      if (_currentView == LocationPanelView.details) {
        _currentView = LocationPanelView.map;
      } else if (_currentView == LocationPanelView.map) {
        _currentView = LocationPanelView.list;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Container(
        width: 600,
        height: double.infinity,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.horizontal(right: Radius.circular(32)),
          boxShadow: [
            BoxShadow(
              color: Colors.black12,
              blurRadius: 40,
              offset: Offset(10, 0),
            ),
          ],
        ),
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 32, 24, 16),
              child: Row(
                children: [
                  if (_currentView != LocationPanelView.list)
                    IconButton(
                      onPressed: _switchBack,
                      icon: const Icon(Icons.arrow_back, color: AppColors.textMain),
                    ),
                  Text(
                    _getTitle(),
                    style: GoogleFonts.poppins(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textMain,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close, color: AppColors.textDisabled, size: 28),
                  ),
                ],
              ),
            ),
            
            Expanded(
              child: _buildCurrentView(),
            ),
          ],
        ),
      ),
    );
  }

  String _getTitle() {
    switch (_currentView) {
      case LocationPanelView.list:
        return 'Select Location';
      case LocationPanelView.map:
        return 'Choose on Map';
      case LocationPanelView.details:
        return 'Delivery Details';
    }
  }

  Widget _buildCurrentView() {
    switch (_currentView) {
      case LocationPanelView.list:
        return LocationSheet(
          isEmbedded: true,
          onOpenMap: () => _switchToMap(isAdding: false),
          onAddNew: () => _switchToMap(isAdding: true),
          onLocationSelected: () => Navigator.pop(context),
        );
      case LocationPanelView.map:
        return LocationPickView(
          isAddingAddress: _isAddingAddress,
          isEmbedded: true,
          onBack: _switchBack,
          onConfirm: (pos, addr) {
            if (_isAddingAddress) {
              _switchToDetails(pos, addr);
            } else {
              // Location already overridden in logic, just close
              Navigator.pop(context);
            }
          },
        );
      case LocationPanelView.details:
        return AddAddressDetailView(
          position: _selectedPosition!,
          address: _selectedAddress!,
          isEmbedded: true,
          onSaved: () => setState(() => _currentView = LocationPanelView.list),
        );
    }
  }
}
