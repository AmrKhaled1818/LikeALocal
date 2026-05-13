import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../../core/theme/app_colors.dart';
import '../../core/utils/responsive.dart';
import '../../data/models/message_model.dart';
import '../../shared/providers/auth_provider.dart';

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    if (auth.uid.isEmpty) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator(color: kOrange)),
      );
    }

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => context.pop(),
        ),
        title: const Text('Notifications',
            style: TextStyle(
                color: Colors.white, fontWeight: FontWeight.bold)),
        actions: [
          TextButton(
            onPressed: () => _markAllRead(auth.uid),
            child: const Text('Mark all read',
                style: TextStyle(color: Colors.white70, fontSize: 13)),
          ),
        ],
      ),
      body: ResponsiveBody(
        maxWidth: AppBreakpoints.maxFeedWidth,
        child: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('notifications')
            .where('userId', isEqualTo: auth.uid)
            .limit(50)
            .snapshots(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(
                child: CircularProgressIndicator(color: kOrange));
          }

          // Sort client-side to avoid composite index requirement
          final docs = List.from(snap.data?.docs ?? [])
            ..sort((a, b) {
              final aTime = (a.data() as Map)['createdAt'];
              final bTime = (b.data() as Map)['createdAt'];
              if (aTime == null || bTime == null) return 0;
              return bTime.compareTo(aTime);
            });
          if (docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.notifications_none,
                      size: 64, color: kMutedFg.withValues(alpha: 0.4)),
                  const SizedBox(height: 16),
                  const Text('No notifications yet',
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: null)),
                  const SizedBox(height: 4),
                  const Text('You\'ll see likes, comments, and more here',
                      style: TextStyle(color: kMutedFg)),
                ],
              ),
            );
          }

          final notifications = docs
              .map((d) => NotificationModel.fromMap(
                  d.data() as Map<String, dynamic>, d.id))
              .toList();

          return ListView.separated(
            itemCount: notifications.length,
            separatorBuilder: (_, __) =>
                const Divider(height: 1, indent: 72),
            itemBuilder: (_, i) =>
                _NotificationTile(notif: notifications[i]),
          );
        },
        ),
      ),
    );
  }

  Future<void> _markAllRead(String uid) async {
    final batch = FirebaseFirestore.instance.batch();
    final snap = await FirebaseFirestore.instance
        .collection('notifications')
        .where('userId', isEqualTo: uid)
        .where('read', isEqualTo: false)
        .get();
    for (final doc in snap.docs) {
      batch.update(doc.reference, {'read': true});
    }
    await batch.commit();
  }
}

class _NotificationTile extends StatelessWidget {
  final NotificationModel notif;
  const _NotificationTile({required this.notif});

  IconData get _icon {
    switch (notif.type) {
      case 'upvote':
        return Icons.thumb_up_outlined;
      case 'comment':
        return Icons.comment_outlined;
      case 'dm':
      case 'message':
        return Icons.message_outlined;
      case 'superuser':
        return Icons.workspace_premium_outlined;
      case 'nearby':
        return Icons.near_me_outlined;
      default:
        return Icons.notifications_outlined;
    }
  }

  Color get _iconColor {
    switch (notif.type) {
      case 'upvote':
        return Colors.blue;
      case 'comment':
        return kOrange;
      case 'dm':
      case 'message':
        return const Color(0xFF8B5CF6);
      case 'superuser':
        return kAmber;
      case 'nearby':
        return Colors.teal;
      default:
        return kMutedFg;
    }
  }

  @override
  Widget build(BuildContext context) {
    final time = timeago.format(notif.createdAt.toDate(), allowFromNow: true);

    return ListTile(
      tileColor: notif.read ? null : kOrange.withValues(alpha: 0.04),
      onTap: () {
        // Mark by document ID — avoids full collection scan and
        // accidental multi-match when two notifications share the same text
        if (!notif.read && notif.notifId.isNotEmpty) {
          FirebaseFirestore.instance
              .collection('notifications')
              .doc(notif.notifId)
              .update({'read': true});
        }
        if (notif.postId != null && notif.postId!.isNotEmpty) {
          context.push('/post/${notif.postId}');
        }
      },
      leading: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: _iconColor.withValues(alpha: 0.12),
          shape: BoxShape.circle,
        ),
        child: Icon(_icon, color: _iconColor, size: 20),
      ),
      title: Text(
        notif.title,
        style: TextStyle(
          fontWeight: notif.read ? FontWeight.normal : FontWeight.w600,
          fontSize: 14,
          color: null,
        ),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(notif.body,
              style: const TextStyle(color: kMutedFg, fontSize: 12),
              maxLines: 2,
              overflow: TextOverflow.ellipsis),
          if (time.isNotEmpty)
            Text(time,
                style:
                    const TextStyle(color: kMutedFg, fontSize: 11)),
        ],
      ),
      trailing: !notif.read
          ? Container(
              width: 8,
              height: 8,
              decoration: const BoxDecoration(
                color: kOrange,
                shape: BoxShape.circle,
              ),
            )
          : null,
    );
  }
}
