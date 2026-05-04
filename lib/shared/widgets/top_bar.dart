import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/providers/auth_provider.dart';
import '../../shared/providers/chat_provider.dart';

class AppTopBar extends StatelessWidget implements PreferredSizeWidget {
  final GlobalKey<ScaffoldState>? scaffoldKey;

  const AppTopBar({super.key, this.scaffoldKey});

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: kDark,
      leading: IconButton(
        icon: const Icon(Icons.menu, color: Colors.white),
        onPressed: () => scaffoldKey?.currentState?.openDrawer(),
      ),
      title: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [kOrange, Color(0xFFFF6B9D)],
              ),
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Icon(Icons.layers_rounded, color: Colors.white, size: 18),
          ),
          const SizedBox(width: 8),
          const Text(
            'LikeALocal',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
      actions: [
        Consumer<ChatProvider>(
          builder: (context, chatProvider, _) {
            final authProvider = context.read<AuthProvider>();
            final unread = chatProvider.getUnreadCount(authProvider.uid);
            return Stack(
              children: [
                IconButton(
                  icon: const Icon(Icons.notifications_outlined,
                      color: Colors.white),
                  onPressed: () => context.push('/notifications'),
                ),
                if (unread > 0)
                  Positioned(
                    right: 8,
                    top: 8,
                    child: Container(
                      padding: const EdgeInsets.all(3),
                      decoration: const BoxDecoration(
                        color: kDestructive,
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        unread > 9 ? '9+' : '$unread',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
        Consumer<AuthProvider>(
          builder: (context, auth, _) {
            final avatarUrl = auth.userModel?.avatarUrl ?? '';
            return GestureDetector(
              onTap: () => context.push('/profile'),
              child: Padding(
                padding: const EdgeInsets.only(right: 12),
                child: CircleAvatar(
                  radius: 16,
                  backgroundColor: kOrange,
                  backgroundImage:
                      avatarUrl.isNotEmpty ? NetworkImage(avatarUrl) : null,
                  child: avatarUrl.isEmpty
                      ? Text(
                          (auth.userModel?.username ?? 'U')
                              .substring(0, 1)
                              .toUpperCase(),
                          style: const TextStyle(
                              color: Colors.white, fontSize: 12),
                        )
                      : null,
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}
