import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';

/// Compact "% match" pill shown on place cards (the Vibe Match Score).
class VibeBadge extends StatelessWidget {
  final int score; // 0-100
  final bool showLabel;

  const VibeBadge({super.key, required this.score, this.showLabel = false});

  Color get _color {
    if (score >= 80) return const Color(0xFF16A34A); // green
    if (score >= 60) return kOrange;
    return kMutedFg;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: _color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.favorite, size: 11, color: _color),
          const SizedBox(width: 4),
          Text(
            '$score% match',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: _color,
            ),
          ),
        ],
      ),
    );
  }
}
