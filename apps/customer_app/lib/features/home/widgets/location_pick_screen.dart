import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:shared_core/services/location_service.dart';
import 'package:shared_core/theme/app_colors.dart';
import 'package:google_fonts/google_fonts.dart';
import 'location_search_screen.dart';
import 'add_address_detail_screen.dart';
import 'location_pick_view.dart';

class LocationPickScreen extends ConsumerWidget {
  final bool isAddingAddress;
  const LocationPickScreen({super.key, this.isAddingAddress = false});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: LocationPickView(
        isAddingAddress: isAddingAddress,
      ),
    );
  }
}
