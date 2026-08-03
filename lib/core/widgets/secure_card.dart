import 'dart:ui';
import 'package:flutter/material.dart';
import '../../app/app_colors.dart';

class SecureCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final VoidCallback? onTap;

  const SecureCard({
    super.key,
    required this.child,
    this.padding,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    Widget cardContent = Padding(
      padding: padding ?? const EdgeInsets.all(20),
      child: child,
    );

    if (onTap != null) {
      cardContent = InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: cardContent,
      );
    }

    if (isDark) {
      // Glassmorphism for dark mode
      return ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            decoration: BoxDecoration(
              color: ObsidianColors.level1Card.withOpacity(0.5),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: ObsidianColors.outline.withOpacity(0.1),
                width: 1,
              ),
            ),
            child: cardContent,
          ),
        ),
      );
    } else {
      // Solid background with shadow for light mode
      return Container(
        decoration: BoxDecoration(
          color: CrystalColors.background,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: CrystalColors.outlineVariant,
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: CrystalColors.shadow.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          child: cardContent,
        ),
      );
    }
  }
}
