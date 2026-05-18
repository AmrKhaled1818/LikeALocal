import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/responsive.dart';
import '../../core/utils/vibe_score.dart';
import '../../shared/providers/auth_provider.dart';
import '../../shared/providers/posts_provider.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _pageCtrl = PageController();
  int _page = 0;
  String _selectedMood = '';

  static const _slides = [
    _SlideData(
      icon: Icons.explore_rounded,
      color: kOrange,
      title: 'Discover Local Gems',
      subtitle:
          'Find hidden restaurants, parks, and spots that only locals know about — right in your city.',
    ),
    _SlideData(
      icon: Icons.camera_alt_rounded,
      color: Color(0xFF7C3AED),
      title: 'Share Your Finds',
      subtitle:
          'Post photos, tips, and reviews so others can experience the real Cairo — not the tourist version.',
    ),
    _SlideData(
      icon: Icons.people_rounded,
      color: Color(0xFF0EA5E9),
      title: 'Connect with Locals',
      subtitle:
          'Chat with fellow explorers, follow friends, and build a community around authentic local culture.',
    ),
  ];

  Future<void> _finish() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboarding_seen', true);
    if (_selectedMood.isNotEmpty) {
      await prefs.setString('home_mood', _selectedMood);
    }
    if (!mounted) return;
    // PostsProvider was constructed at app start and already finished its
    // initial _loadMood (which read an empty mood). Push the user's pick
    // straight into the provider so the feed reflects it immediately
    // without waiting for the next app launch.
    final posts = context.read<PostsProvider>();
    await posts.setMood(_selectedMood);
    if (!mounted) return;
    final auth = context.read<AuthProvider>();
    context.go(auth.isLoggedIn ? '/feed' : '/login');
  }

  @override
  void dispose() {
    _pageCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pageCount = _slides.length + 1; // + mood picker
    final isLast = _page == pageCount - 1;
    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          SafeArea(
            child: ResponsiveBody(
              maxWidth: AppBreakpoints.maxFormWidth,
              child: Column(
                children: [
                  const SizedBox(height: 44), // space for skip button
                  Expanded(
                    child: PageView.builder(
                      controller: _pageCtrl,
                      onPageChanged: (i) => setState(() => _page = i),
                      itemCount: pageCount,
                      itemBuilder: (_, i) => i < _slides.length
                          ? _OnboardingSlide(data: _slides[i])
                          : _MoodPickSlide(
                              selected: _selectedMood,
                              onSelect: (m) =>
                                  setState(() => _selectedMood = m),
                            ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(pageCount, (i) {
                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        width: _page == i ? 28 : 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: _page == i ? kOrange : kMuted,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: 32),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: isLast
                            ? _finish
                            : () => _pageCtrl.nextPage(
                                  duration: const Duration(milliseconds: 350),
                                  curve: Curves.easeInOut,
                                ),
                        child: Text(isLast ? 'Get Started' : 'Next',
                            style: const TextStyle(fontSize: 15)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 28),
                ],
              ),
            ),
          ),
          // Skip always anchored to real top-right of screen, never constrained
          SafeArea(
            child: Align(
              alignment: Alignment.topRight,
              child: TextButton(
                onPressed: _finish,
                child: const Text('Skip',
                    style: TextStyle(color: kMutedFg, fontSize: 14)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SlideData {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;

  const _SlideData({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
  });
}

class _MoodPickSlide extends StatelessWidget {
  final String selected;
  final ValueChanged<String> onSelect;

  const _MoodPickSlide({required this.selected, required this.onSelect});

  static const _moods = <(String, IconData, String, Color)>[
    ('chill', Icons.spa_outlined, 'Easygoing — cafés, parks, viewpoints',
        Color(0xFF0EA5E9)),
    ('cafe', Icons.local_cafe_outlined,
        'Coffee & pastries — slow mornings, cozy spots', Color(0xFFE8580A)),
    ('hungry', Icons.restaurant_outlined,
        'On the hunt for food — restaurants & eats', Color(0xFFD4820A)),
    ('cultural', Icons.palette_outlined,
        'Soaking up the city — history, art, heritage', Color(0xFF7C3AED)),
  ];

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("What's your vibe today?",
              style: TextStyle(
                  fontSize: 24, fontWeight: FontWeight.bold, color: kDark)),
          const SizedBox(height: 6),
          const Text(
            'We\'ll tune your feed to match. You can change it anytime from the feed.',
            style: TextStyle(fontSize: 14, color: kMutedFg, height: 1.5),
          ),
          const SizedBox(height: 20),
          ..._moods.map((m) {
            final (value, icon, subtitle, color) = m;
            final isSel = selected == value;
            return GestureDetector(
              onTap: () => onSelect(isSel ? '' : value),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: isSel ? color.withValues(alpha: 0.08) : Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                      color: isSel ? color : kMuted, width: isSel ? 2 : 1),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(icon, color: color, size: 22),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(kMoodLabels[value] ?? value,
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                  color: kDark)),
                          Text(subtitle,
                              style: const TextStyle(
                                  fontSize: 12, color: kMutedFg)),
                        ],
                      ),
                    ),
                    if (isSel)
                      Icon(Icons.check_circle, color: color, size: 20),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _OnboardingSlide extends StatelessWidget {
  final _SlideData data;

  const _OnboardingSlide({required this.data});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              color: data.color.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(data.icon, color: data.color, size: 56),
          ),
          const SizedBox(height: 40),
          Text(
            data.title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.bold,
              color: kDark,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            data.subtitle,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 15,
              color: kMutedFg,
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }
}
