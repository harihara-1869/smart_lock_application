import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class PrimaryButton extends StatefulWidget {
  final String text;
  final VoidCallback? onPressed;
  final bool isLoading;
  final IconData? icon;

  const PrimaryButton({
    super.key,
    required this.text,
    this.onPressed,
    this.isLoading = false,
    this.icon,
  });

  @override
  State<PrimaryButton> createState() => _PrimaryButtonState();
}

class _PrimaryButtonState extends State<PrimaryButton> with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 4.0, end: 12.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return AnimatedBuilder(
      animation: _pulseAnimation,
      builder: (context, child) {
        final glowColor = isDark 
            ? ObsidianColors.electricBlue.withOpacity(widget.onPressed == null ? 0 : 0.4) 
            : Colors.transparent;
            
        return Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              if (isDark && widget.onPressed != null && !widget.isLoading)
                BoxShadow(
                  color: glowColor,
                  blurRadius: _pulseAnimation.value,
                  spreadRadius: _pulseAnimation.value / 2,
                ),
            ],
          ),
          child: ElevatedButton(
            onPressed: widget.isLoading ? null : widget.onPressed,
            style: ElevatedButton.styleFrom(
              backgroundColor: isDark ? ObsidianColors.electricBlue : CrystalColors.primary,
              foregroundColor: isDark ? ObsidianColors.onPrimary : CrystalColors.onPrimary,
              disabledBackgroundColor: isDark ? ObsidianColors.surfaceVariant : CrystalColors.surfaceVariant,
              disabledForegroundColor: isDark ? ObsidianColors.onSurfaceVariant : CrystalColors.onSurfaceVariant,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 0,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (widget.isLoading)
                  SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        isDark ? ObsidianColors.onPrimary : CrystalColors.onPrimary,
                      ),
                    ),
                  )
                else if (widget.icon != null) ...[
                  Icon(widget.icon, size: 20),
                  const SizedBox(width: 8),
                ],
                if (!widget.isLoading)
                  Text(
                    widget.text,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: isDark ? ObsidianColors.onPrimary : CrystalColors.onPrimary,
                    ),
                  ),
              ],
            ),
          ),
        );
      }
    );
  }
}
