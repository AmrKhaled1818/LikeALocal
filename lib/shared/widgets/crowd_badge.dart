import 'package:flutter/material.dart';
import '../../core/utils/crowd_utils.dart';
import '../../data/models/post_model.dart';
import '../../data/repositories/posts_repo.dart';
import '../../data/services/ai_service.dart';

/// "Busy right now" / "Liveliest around 6 PM" / AI best-time pill for a place.
/// Set [autoGenerate] (e.g. on the detail screen) to lazily fetch + cache an
/// AI best-time hint when no live data exists yet.
class CrowdBadge extends StatefulWidget {
  final PostModel post;
  final bool autoGenerate;
  final bool dense;

  const CrowdBadge({
    super.key,
    required this.post,
    this.autoGenerate = false,
    this.dense = true,
  });

  @override
  State<CrowdBadge> createState() => _CrowdBadgeState();
}

class _CrowdBadgeState extends State<CrowdBadge> {
  String? _aiHint;
  bool _requested = false;

  bool get _needsHint =>
      !isBusyNow(widget.post) &&
      peakHour(widget.post) == null &&
      widget.post.bestTime.trim().isEmpty;

  @override
  void initState() {
    super.initState();
    if (widget.autoGenerate && _needsHint) {
      _requested = true;
      _fetchHint();
    }
  }

  Future<void> _fetchHint() async {
    try {
      final hint = await AIService().generateBestTimeHint(
        title: widget.post.title,
        category: widget.post.category,
        description: widget.post.description,
      );
      if (hint.isNotEmpty) {
        // Cache for everyone else; ignore failures.
        PostsRepo().updateBestTime(widget.post.postId, hint);
        if (mounted) setState(() => _aiHint = hint);
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final post =
        _aiHint != null ? widget.post.copyWith(bestTime: _aiHint) : widget.post;
    final info = crowdInfo(post);
    final showSpinner = widget.autoGenerate && _requested && _aiHint == null && _needsHint;

    final vPad = widget.dense ? 3.0 : 5.0;
    final fontSize = widget.dense ? 11.0 : 12.0;
    final iconSize = widget.dense ? 12.0 : 14.0;

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8, vertical: vPad),
      decoration: BoxDecoration(
        color: info.color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (info.isLive)
            _PulsingDot(color: info.color)
          else
            Icon(info.icon, size: iconSize, color: info.color),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              info.label,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: fontSize,
                fontWeight: FontWeight.w700,
                color: info.color,
              ),
            ),
          ),
          if (showSpinner) ...[
            const SizedBox(width: 6),
            SizedBox(
              width: iconSize - 2,
              height: iconSize - 2,
              child: CircularProgressIndicator(strokeWidth: 1.6, color: info.color),
            ),
          ],
        ],
      ),
    );
  }
}

class _PulsingDot extends StatefulWidget {
  final Color color;
  const _PulsingDot({required this.color});

  @override
  State<_PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<_PulsingDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 900))
        ..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: Tween<double>(begin: 0.35, end: 1.0).animate(_c),
      child: Container(
        width: 8,
        height: 8,
        decoration: BoxDecoration(color: widget.color, shape: BoxShape.circle),
      ),
    );
  }
}
