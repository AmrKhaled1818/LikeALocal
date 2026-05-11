import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/providers/auth_provider.dart';

class SidebarMenu extends StatelessWidget {
  const SidebarMenu({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, auth, _) {
        final user = auth.userModel;
        final karma = user?.karma ?? 0;
        final score = (karma / 100 * 100).clamp(0.0, 100.0);
        final isSuperUser = user?.isSuperUser ?? false;
        final remaining = (100 - karma).clamp(0, 100);

        return Drawer(
          child: SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Container(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      CircleAvatar(
                        radius: 30,
                        backgroundColor: kOrange,
                        backgroundImage: (user?.avatarUrl.isNotEmpty ?? false)
                            ? CachedNetworkImageProvider(user!.avatarUrl)
                            : null,
                        child: (user?.avatarUrl.isEmpty ?? true)
                            ? Text(
                                (user?.username ?? 'U')
                                    .substring(0, 1)
                                    .toUpperCase(),
                                style: const TextStyle(
                                    color: Colors.white, fontSize: 22),
                              )
                            : null,
                      ),
                      const SizedBox(height: 10),
                      Text(
                        user?.username ?? 'User',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Row(
                        children: [
                          const Icon(Icons.trending_up,
                              size: 14, color: kOrange),
                          const SizedBox(width: 4),
                          Text(
                            '$karma karma',
                            style: const TextStyle(
                                color: kMutedFg, fontSize: 13),
                          ),
                          if (isSuperUser) ...[
                            const SizedBox(width: 6),
                            const Icon(Icons.star_rounded,
                                size: 14, color: kAmber),
                            const Text(
                              'Super User',
                              style: TextStyle(
                                  color: kAmber,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 14),
                      // Progress bar
                      const Text(
                        'Path to Super User',
                        style: TextStyle(
                            fontSize: 12,
                            color: kMutedFg,
                            fontWeight: FontWeight.w500),
                      ),
                      const SizedBox(height: 6),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: (score / 100).clamp(0.0, 1.0),
                          backgroundColor: kMuted,
                          valueColor:
                              const AlwaysStoppedAnimation<Color>(kAmber),
                          minHeight: 6,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        isSuperUser
                            ? '✓ You are a Super User!'
                            : '${score.toStringAsFixed(0)}% — $remaining more karma to Super User',
                        style: const TextStyle(
                            color: kMutedFg, fontSize: 11),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                const SizedBox(height: 8),
                _menuItem(
                  context,
                  icon: Icons.person_outline,
                  label: 'Profile',
                  route: '/profile',
                ),
                _menuItem(
                  context,
                  icon: Icons.bookmark_outline,
                  label: 'Saved Posts',
                  route: '/saved',
                ),
                _menuItem(
                  context,
                  icon: Icons.notifications_outlined,
                  label: 'Notifications',
                  route: '/notifications',
                ),
                _menuItem(
                  context,
                  icon: Icons.settings_outlined,
                  label: 'Settings',
                  route: '/settings',
                ),
                _menuItem(
                  context,
                  icon: Icons.leaderboard_outlined,
                  label: 'Karma Leaderboard',
                  route: '/leaderboard',
                ),
                _menuItem(
                  context,
                  icon: Icons.help_outline,
                  label: 'Help & FAQ',
                  route: '/faq',
                ),
                const Spacer(),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: TextButton.icon(
                    onPressed: () async {
                      Navigator.of(context).pop();
                      await auth.signOut();
                    },
                    icon: const Icon(Icons.logout, color: kDestructive),
                    label: const Text('Log Out',
                        style: TextStyle(color: kDestructive)),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _menuItem(BuildContext context,
      {required IconData icon,
      required String label,
      required String route}) {
    return ListTile(
      leading: Icon(icon, size: 22),
      title: Text(label,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
      onTap: () {
        Navigator.of(context).pop();
        context.push(route);
      },
    );
  }
}
