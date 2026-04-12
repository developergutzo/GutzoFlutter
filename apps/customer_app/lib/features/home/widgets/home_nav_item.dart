import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class HomeNavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;
  final Color activeColor;

  const HomeNavItem({
    Key? key,
    required this.icon,
    required this.label,
    required this.active,
    this.activeColor = const Color(0xFF00A36C),
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          icon,
          color: active ? activeColor : Colors.grey.shade400,
          size: 22,
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: GoogleFonts.inter(
            color: active ? activeColor : Colors.grey.shade400,
            fontSize: 10,
            fontWeight: active ? FontWeight.w900 : FontWeight.w700,
          ),
        ),
      ],
    );
  }
}
