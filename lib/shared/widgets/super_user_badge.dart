import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';

class SuperUserBadge extends StatelessWidget {
  const SuperUserBadge({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: kSuperUserBg,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: kAmber, width: 0.5),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.star_rounded, color: kAmber, size: 12),
          SizedBox(width: 3),
          Text(
            'Super User',
            style: TextStyle(
              color: kAmber,
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
