import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// A utility class for handling responsive layouts in Gutzo applications.
/// Provides standardized breakpoints and helper methods for platform-aware UI.
class Responsive extends StatelessWidget {
  final Widget mobile;
  final Widget? tablet;
  final Widget desktop;

  const Responsive({
    super.key,
    required this.mobile,
    this.tablet,
    required this.desktop,
  });

  // Breakpoints
  static const double mobileMax = 600;
  static const double tabletMax = 1100;

  /// Returns true if the platform is Web
  static bool get isWebPlatform => kIsWeb;

  /// Returns true if current width matches Mobile (Standard)
  static bool isMobile(BuildContext context) =>
      MediaQuery.of(context).size.width < mobileMax;

  /// Returns true if current width matches Tablet
  static bool isTablet(BuildContext context) =>
      MediaQuery.of(context).size.width >= mobileMax &&
      MediaQuery.of(context).size.width < tabletMax;

  /// Returns true if current width matches Desktop (High density)
  static bool isDesktop(BuildContext context) =>
      MediaQuery.of(context).size.width >= tabletMax;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= tabletMax) {
          return desktop;
        } else if (constraints.maxWidth >= mobileMax) {
          return tablet ?? desktop;
        } else {
          return mobile;
        }
      },
    );
  }
}

/// Helper extension for easy access to platform/size checks
extension ResponsiveExtension on BuildContext {
  bool get isMobile => Responsive.isMobile(this);
  bool get isTablet => Responsive.isTablet(this);
  bool get isDesktop => Responsive.isDesktop(this);
  bool get isWeb => kIsWeb;
  
  /// Returns a responsive value based on current size
  T responsiveValue<T>({
    required T mobile,
    T? tablet,
    required T desktop,
  }) {
    if (isDesktop) return desktop;
    if (isTablet) return tablet ?? desktop;
    return mobile;
  }
}
