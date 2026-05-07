import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class VerifiedBadge extends StatelessWidget {
  final bool compact;
  const VerifiedBadge({super.key, this.compact = false});

  @override
  Widget build(BuildContext context) {
    final sz = compact ? 13.0 : 15.0;
    final fs = compact ? 11.0 : 12.0;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.verified_rounded, color: AppColors.blue, size: sz),
        const SizedBox(width: 4),
        Text(
          'Verified Student',
          style: TextStyle(
            color: AppColors.blue,
            fontSize: fs,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
