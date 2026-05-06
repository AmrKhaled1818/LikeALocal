import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/providers/auth_provider.dart';

class AppTopBar extends StatelessWidget implements PreferredSizeWidget {
  final GlobalKey<ScaffoldState>? scaffoldKey;

  const AppTopBar({super.key, this.scaffoldKey});

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      leading: IconButton(
        icon: const Icon(Icons.menu, color: Colors.white),
        onPressed: () => scaffoldKey?.currentState?.openDrawer(),
      ),
      title: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SvgPicture.asset(
            'assets/icons/icon.svg',
            width: 24,
            height: 24,
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
        // F53 — Unread notification badge
        Consumer<AuthProvider>(
          builder: (context, auth, _) {
            if (auth.uid.isEmpty) {
              return IconButton(
                icon: const Icon(Icons.notifications_outlined, color: Colors.white),
                onPressed: () => context.push('/notifications'),
              );
            }
            return StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('notifications')
                  .where('userId', isEqualTo: auth.uid)
                  .snapshots(),
              builder: (context, snap) {
                // Filter unread client-side to avoid composite index
                final unread = snap.data?.docs
                        .where((d) => (d.data() as Map)['read'] == false)
                        .length ??
                    0;
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
