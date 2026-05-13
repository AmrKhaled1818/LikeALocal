import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/vibe_score.dart';

const _moodIcons = <String, IconData>{
  '': Icons.auto_awesome_outlined,
  'chill': Icons.spa_outlined,
  'adventurous': Icons.hiking_outlined,
  'hungry': Icons.restaurant_outlined,
  'cultural': Icons.museum_outlined,
};

/// Horizontal row of mood chips. [selected] is '' for "Any vibe".
class MoodSelector extends StatelessWidget {
  final String selected;
  final ValueChanged<String> onSelect;
  final bool compact;

  const MoodSelector({
    super.key,
    required this.selected,
    required this.onSelect,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final entries = <String>['', ...kMoods];
    return SizedBox(
      height: compact ? 32 : 36,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: entries.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final m = entries[i];
          final isSel = m == selected;
          return GestureDetector(
            onTap: () => onSelect(m),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              padding: EdgeInsets.symmetric(
                  horizontal: compact ? 10 : 12, vertical: compact ? 5 : 7),
              decoration: BoxDecoration(
                color: isSel ? kOrange : Colors.white.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isSel ? kOrange : Colors.white.withValues(alpha: 0.18),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(_moodIcons[m] ?? Icons.auto_awesome_outlined,
                      size: 14,
                      color: isSel ? Colors.white : kMutedFg),
                  const SizedBox(width: 5),
                  Text(
                    kMoodLabels[m] ?? m,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: isSel ? Colors.white : kMutedFg,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
