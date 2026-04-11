import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';

class AdaptiveWrapper extends StatelessWidget {
  final Widget child;
  final double maxWidth;
  final bool isAuth;

  const AdaptiveWrapper({
    super.key,
    required this.child,
    this.maxWidth = 1200,
    this.isAuth = false,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final screenWidth = constraints.maxWidth;
        final bool isDesktop = screenWidth > 600;

        if (!isDesktop) return child;

        // Desktop View
        return Container(
          color: isAuth ? const Color(0xFFF8FAFC) : Colors.transparent,
          alignment: Alignment.center,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: isAuth ? 480 : maxWidth,
            ),
            child: isAuth 
              ? Padding(
                  padding: const EdgeInsets.all(32),
                  child: Card(
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24),
                      side: BorderSide(color: Colors.grey[200]!, width: 1),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: child,
                    ),
                  ),
                )
              : child,
          ),
        );
      },
    );
  }
}
