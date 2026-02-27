import 'package:flutter/material.dart';
import '../config/theme.dart';

class AlertBanner extends StatelessWidget {
  final String message;
  final String severity; // 'info', 'warning', 'critical'
  final VoidCallback? onDismiss;
  final VoidCallback? onTap;

  const AlertBanner({
    super.key,
    required this.message,
    required this.severity,
    this.onDismiss,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(
          horizontal: AppTheme.spacingMd,
          vertical: AppTheme.spacingSm,
        ),
        padding: const EdgeInsets.all(AppTheme.spacingMd),
        decoration: BoxDecoration(
          gradient: _gradient,
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          boxShadow: [
            BoxShadow(
              color: _color.withValues(alpha: 0.3),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Icon(_icon, color: Colors.white, size: 24),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            if (onDismiss != null)
              GestureDetector(
                onTap: onDismiss,
                child: const Icon(Icons.close, color: Colors.white70, size: 20),
              ),
          ],
        ),
      ),
    );
  }

  Color get _color {
    switch (severity) {
      case 'critical':
        return AppTheme.danger;
      case 'warning':
        return AppTheme.warning;
      default:
        return AppTheme.info;
    }
  }

  LinearGradient get _gradient {
    switch (severity) {
      case 'critical':
        return AppTheme.dangerGradient;
      case 'warning':
        return const LinearGradient(
          colors: [Color(0xFFFF9800), Color(0xFFFFB74D)],
        );
      default:
        return const LinearGradient(
          colors: [Color(0xFF29B6F6), Color(0xFF4FC3F7)],
        );
    }
  }

  IconData get _icon {
    switch (severity) {
      case 'critical':
        return Icons.warning_amber_rounded;
      case 'warning':
        return Icons.info_outline;
      default:
        return Icons.notifications_outlined;
    }
  }
}
