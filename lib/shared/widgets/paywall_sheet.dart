import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/toast_utils.dart';
import '../../shared/providers/auth_provider.dart';
import '../../shared/providers/user_provider.dart';

// TODO: Replace with real RevenueCat / in_app_purchase integration before publishing.

enum PaywallTrigger { pins, posts }

class PaywallSheet extends StatelessWidget {
  final PaywallTrigger trigger;
  const PaywallSheet({super.key, required this.trigger});

  static Future<void> show(BuildContext context, PaywallTrigger trigger) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => PaywallSheet(trigger: trigger),
    );
  }

  @override
  Widget build(BuildContext context) {
    final limitLabel = trigger == PaywallTrigger.pins
        ? 'You\'ve used all 5 free pins.'
        : 'You\'ve created 3 free posts.';

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 36),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(bottom: 20),
            decoration: BoxDecoration(
              color: kMuted,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFE8580A), Color(0xFFD4820A)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(18),
            ),
            child: const Icon(Icons.rocket_launch_outlined,
                color: Colors.white, size: 32),
          ),
          const SizedBox(height: 16),
          const Text(
            'Upgrade to Premium',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            limitLabel,
            textAlign: TextAlign.center,
            style: const TextStyle(color: kMutedFg, fontSize: 14),
          ),
          const SizedBox(height: 24),
          _TierCard(
            label: 'Free',
            price: '€0/mo',
            features: const ['5 saved pins', '3 posts', 'Basic AI chat'],
            isHighlighted: false,
          ),
          const SizedBox(height: 10),
          _TierCard(
            label: 'Explorer',
            price: '€2.99/mo',
            features: const ['Unlimited pins', '10 posts/mo', 'AI chat priority'],
            isHighlighted: true,
          ),
          const SizedBox(height: 10),
          _TierCard(
            label: 'Local Pro',
            price: '€7.99/mo',
            features: const ['Everything unlimited', 'AI captions', 'Super User fast-track'],
            isHighlighted: false,
          ),
          const SizedBox(height: 16),
          Consumer<AuthProvider>(
            builder: (ctx, auth, _) {
              final isPremium = auth.userModel?.isPremium ?? false;
              return TextButton.icon(
                onPressed: () async {
                  final userProvider = ctx.read<UserProvider>();
                  await userProvider.updateField(auth.uid, {'isPremium': !isPremium});
                  if (ctx.mounted) Navigator.of(ctx).pop();
                  AppToast.success(isPremium
                      ? 'Premium simulation off.'
                      : 'Premium simulated! Limits lifted.');
                },
                icon: Icon(
                  isPremium ? Icons.toggle_on_outlined : Icons.science_outlined,
                  size: 16,
                  color: kMutedFg,
                ),
                label: Text(
                  isPremium ? 'Disable Premium Simulation' : 'Simulate Premium (Demo)',
                  style: const TextStyle(color: kMutedFg, fontSize: 12),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _TierCard extends StatelessWidget {
  final String label;
  final String price;
  final List<String> features;
  final bool isHighlighted;

  const _TierCard({
    required this.label,
    required this.price,
    required this.features,
    required this.isHighlighted,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isHighlighted
            ? kOrange.withValues(alpha: 0.08)
            : Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isHighlighted ? kOrange : Colors.transparent,
          width: 1.5,
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(label,
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: isHighlighted ? kOrange : null)),
                    if (isHighlighted) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: kOrange,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text('Popular',
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                ...features.map((f) => Row(
                      children: [
                        Icon(Icons.check_circle_outline,
                            size: 12,
                            color: isHighlighted ? kOrange : kMutedFg),
                        const SizedBox(width: 6),
                        Text(f,
                            style: const TextStyle(
                                fontSize: 12, color: kMutedFg)),
                      ],
                    )),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(price,
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color: isHighlighted ? kOrange : null)),
              const SizedBox(height: 8),
              SizedBox(
                height: 32,
                child: ElevatedButton(
                  // TODO: wire up RevenueCat purchase here
                  onPressed: () {
                    Navigator.of(context).pop();
                    AppToast.info('In-app purchases coming soon!');
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isHighlighted ? kOrange : null,
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                  ),
                  child: const Text('Select', style: TextStyle(fontSize: 12)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
