import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_core/theme/app_colors.dart';
import 'package:shared_core/utils/responsive.dart';

class ModernDialog extends StatelessWidget {
  final String title;
  final String? message;
  final Widget? content;
  final String primaryLabel;
  final String? secondaryLabel;
  final VoidCallback onPrimary;
  final VoidCallback? onSecondary;
  final bool isDestructive;

  const ModernDialog({
    super.key,
    required this.title,
    this.message,
    this.content,
    required this.primaryLabel,
    this.secondaryLabel,
    required this.onPrimary,
    this.onSecondary,
    this.isDestructive = false,
  }) : assert(message != null || content != null);

  @override
  Widget build(BuildContext context) {
    final isDesktop = context.isDesktop || context.isTablet;

    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
      child: Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        insetPadding: EdgeInsets.symmetric(
          horizontal: isDesktop ? 0 : 20,
          vertical: 24,
        ),
        child: Container(
          constraints: BoxConstraints(
            maxWidth: isDesktop ? 440 : double.infinity,
          ),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.95),
            borderRadius: BorderRadius.circular(32),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.3),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.12),
                blurRadius: 40,
                offset: const Offset(0, 20),
              ),
              BoxShadow(
                color: (isDestructive ? AppColors.errorRed : AppColors.brandGreen).withValues(alpha: 0.05),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header with Close
              Padding(
                padding: const EdgeInsets.fromLTRB(32, 28, 20, 0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.poppins(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textMain,
                        letterSpacing: -0.5,
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: AppColors.bg,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.close, size: 18, color: AppColors.textSub),
                      ),
                    ),
                  ],
                ),
              ),

              // Content
              Padding(
                padding: const EdgeInsets.fromLTRB(32, 12, 32, 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (content != null) ...[
                      content!,
                    ] else ...[
                      Text(
                        message!,
                        style: GoogleFonts.poppins(
                          fontSize: 15,
                          color: AppColors.textSub,
                          height: 1.6,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                    const SizedBox(height: 32),
                    
                    // Actions
                    Row(
                      children: [
                        if (secondaryLabel != null) ...[
                          Expanded(
                            child: _ActionButton(
                              label: secondaryLabel!,
                              onPressed: onSecondary ?? () => Navigator.pop(context),
                              isPrimary: false,
                            ),
                          ),
                          const SizedBox(width: 12),
                        ],
                        Expanded(
                          child: _ActionButton(
                            label: primaryLabel.toUpperCase(),
                            onPressed: onPrimary,
                            isPrimary: true,
                            isDestructive: isDestructive,
                          ),
                        ),
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

class _ActionButton extends StatefulWidget {
  final String label;
  final VoidCallback onPressed;
  final bool isPrimary;
  final bool isDestructive;

  const _ActionButton({
    required this.label,
    required this.onPressed,
    required this.isPrimary,
    this.isDestructive = false,
  });

  @override
  State<_ActionButton> createState() => _ActionButtonState();
}

class _ActionButtonState extends State<_ActionButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final bgColor = widget.isPrimary 
        ? (widget.isDestructive ? AppColors.errorRed : AppColors.brandGreen)
        : Colors.transparent;
    
    final textColor = widget.isPrimary 
        ? Colors.white 
        : (widget.isDestructive ? AppColors.errorRed : AppColors.textMain);

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        child: ElevatedButton(
          onPressed: widget.onPressed,
          style: ElevatedButton.styleFrom(
            backgroundColor: _isHovered && !widget.isPrimary 
                ? (widget.isDestructive ? AppColors.errorBg : AppColors.bg)
                : bgColor,
            foregroundColor: textColor,
            elevation: widget.isPrimary && _isHovered ? 8 : 0,
            shadowColor: bgColor.withValues(alpha: 0.4),
            padding: const EdgeInsets.symmetric(vertical: 18),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: !widget.isPrimary 
                  ? BorderSide(color: AppColors.border.withValues(alpha: 0.5))
                  : BorderSide.none,
            ),
          ).copyWith(
            overlayColor: WidgetStateProperty.all(Colors.black.withValues(alpha: 0.05)),
          ),
          child: Text(
            widget.label,
            style: GoogleFonts.poppins(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.5,
            ),
          ),
        ),
      ),
    );
  }
}
