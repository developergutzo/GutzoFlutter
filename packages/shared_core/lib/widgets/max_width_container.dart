import 'package:flutter/material.dart';

/// A utility widget that constrains its child's width to a maximum value
/// and centers it. Ideal for desktop/web layouts to prevent content stretching.
class MaxWidthContainer extends StatelessWidget {
  final Widget child;
  final double maxWidth;
  final EdgeInsetsGeometry? padding;

  const MaxWidthContainer({
    super.key,
    required this.child,
    this.maxWidth = 1200,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: Padding(
          padding: padding ?? const EdgeInsets.symmetric(horizontal: 20),
          child: child,
        ),
      ),
    );
  }
}
