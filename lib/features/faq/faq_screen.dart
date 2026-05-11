import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/responsive.dart';

class FaqScreen extends StatelessWidget {
  const FaqScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => context.pop(),
        ),
        title: const Text(
          'Help & FAQ',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
      body: ResponsiveBody(
        maxWidth: AppBreakpoints.maxFormWidth,
        child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
        children: const [
          _Section(
            icon: Icons.trending_up,
            title: 'What are karma points & how do they work?',
            body:
                'Karma points are your reputation score on LikeALocal. You earn them by contributing to the community:\n\n'
                '• +10 karma when you create a post\n'
                '• +5 karma when someone upvotes your post\n'
                '• +2 karma when someone comments on your post\n\n'
                'Karma is cumulative and never decreases. The more you share hidden gems and engage with others, the faster it grows.',
          ),
          _Section(
            icon: Icons.star_rounded,
            title: 'What is a Super User & how do I become one?',
            body:
                'Super Users are trusted community members who have demonstrated consistent, quality contributions.\n\n'
                'You automatically become a Super User once you reach 100 karma points. Your profile will show a gold star badge and you unlock:\n\n'
                '• Unlimited posts per day (free users: 3/day)\n'
                '• Unlimited saved posts (free users: 5 max)\n'
                '• Unlimited AI assistant messages (free users: 20/day)',
          ),
          _Section(
            icon: Icons.lock_outline,
            title: 'What are the free tier limits?',
            body:
                'Free users have the following daily limits to keep the community balanced:\n\n'
                '• Posts: 3 per day (resets after 24 hours)\n'
                '• Saved posts: 5 total\n'
                '• AI assistant messages: 20 per day (resets after 24 hours)\n\n'
                'Reach 100 karma to become a Super User and remove all limits.',
          ),
          _Section(
            icon: Icons.smart_toy_outlined,
            title: 'How does the AI assistant work?',
            body:
                'The AI assistant is a local guide powered by a language model. It knows about all the places posted in the app and can:\n\n'
                '• Recommend spots based on your mood, budget, or vibe\n'
                '• Answer questions about places in the feed\n'
                '• Suggest itineraries and things to do nearby\n\n'
                'The AI is aware of your location and preferences set in your profile. It keeps the last 10 messages as context so you can have a natural back-and-forth conversation.\n\n'
                'Free users get 20 messages per day. The counter resets 24 hours after your first message of the day.',
          ),
          _Section(
            icon: Icons.add_location_alt_outlined,
            title: 'How do I post a hidden gem?',
            body:
                'Sharing a place takes less than a minute:\n\n'
                '1. Tap the + button in the bottom navigation bar\n'
                '2. Add a photo from your gallery (optional but recommended)\n'
                '3. Give your gem a title and pick a category\n'
                '4. Write a short description and any local tips\n'
                '5. Pin the location on the map or type the address\n'
                '6. Tap Post!\n\n'
                'Great posts are specific — mention what makes the place special, the best time to visit, what to order, or how to find the entrance. Quality posts earn more upvotes and karma.',
          ),
        ],
        ),
      ),
    );
  }
}

class _Section extends StatefulWidget {
  final IconData icon;
  final String title;
  final String body;

  const _Section({
    required this.icon,
    required this.title,
    required this.body,
  });

  @override
  State<_Section> createState() => _SectionState();
}

class _SectionState extends State<_Section> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).colorScheme.outlineVariant,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => setState(() => _expanded = !_expanded),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: kOrange.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(widget.icon, color: kOrange, size: 18),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      widget.title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  Icon(
                    _expanded ? Icons.expand_less : Icons.expand_more,
                    color: kMutedFg,
                    size: 20,
                  ),
                ],
              ),
              if (_expanded) ...[
                const SizedBox(height: 12),
                const Divider(height: 1),
                const SizedBox(height: 12),
                Text(
                  widget.body,
                  style: const TextStyle(
                    fontSize: 13,
                    color: kMutedFg,
                    height: 1.55,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
