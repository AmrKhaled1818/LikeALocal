import 'package:cached_network_image/cached_network_image.dart';
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
          SvgPicture.asset('assets/icons/icon.svg', width: 24, height: 24),
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
        // Notification badge — stream created once per auth session
        Selector<AuthProvider, String>(
          selector: (_, a) => a.uid,
          builder: (context, uid, _) => uid.isEmpty
              ? IconButton(
                  icon: const Icon(Icons.notifications_outlined, color: Colors.white),
                  onPressed: () => context.push('/notifications'),
                )
              : _NotificationBadge(uid: uid),
        ),
        // Avatar
        Selector<AuthProvider, (String, String)>(
          selector: (_, a) => (a.userModel?.avatarUrl ?? '', a.userModel?.username ?? 'U'),
          builder: (context, data, _) {
            final (avatarUrl, username) = data;
            return GestureDetector(
              onTap: () => context.push('/profile'),
              child: Padding(
                padding: const EdgeInsets.only(right: 12),
                child: CircleAvatar(
                  radius: 16,
                  backgroundColor: kOrange,
                  backgroundImage: avatarUrl.isNotEmpty
                      ? CachedNetworkImageProvider(avatarUrl)
                      : null,
                  child: avatarUrl.isEmpty
                      ? Text(
                          username.substring(0, 1).toUpperCase(),
                          style: const TextStyle(color: Colors.white, fontSize: 12),
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

/// Subscribes to the unread notifications stream once and keeps it alive.
class _NotificationBadge extends StatefulWidget {
  final String uid;
  const _NotificationBadge({required this.uid});

  @override
  State<_NotificationBadge> createState() => _NotificationBadgeState();
}

class _NotificationBadgeState extends State<_NotificationBadge> {
  late final Stream<int> _unreadStream;

  @override
  void initState() {
    super.initState();
    _unreadStream = FirebaseFirestore.instance
        .collection('notifications')
        .where('userId', isEqualTo: widget.uid)
        .snapshots()
        .map((snap) =>
            snap.docs.where((d) => (d.data())['read'] == false).length);
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<int>(
      stream: _unreadStream,
      builder: (context, snap) {
        final unread = snap.data ?? 0;
        return Stack(
          children: [
            IconButton(
              icon: const Icon(Icons.notifications_outlined, color: Colors.white),
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
  }
}
