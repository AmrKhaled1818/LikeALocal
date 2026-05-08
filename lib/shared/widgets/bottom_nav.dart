import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/providers/auth_provider.dart';
import '../../shared/providers/chat_provider.dart';

class AppBottomNav extends StatelessWidget {
  final int currentIndex;
  final void Function(int)? onTap;

  const AppBottomNav({super.key, required this.currentIndex, this.onTap});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    // Calculate total unread messages
    final auth = context.watch<AuthProvider>();
    final chats = context.watch<ChatProvider>().chats;
    int unreadTotal = 0;
    if (auth.uid.isNotEmpty) {
      for (final chat in chats) {
        unreadTotal += chat.unreadCount[auth.uid] ?? 0;
      }
    }

    return Container(
      decoration: BoxDecoration(
        border: Border(
            top: BorderSide(
                color: isDark ? const Color(0xFF374151) : kMuted)),
      ),
      child: BottomNavigationBar(
        currentIndex: currentIndex,
        onTap: (i) => onTap != null ? onTap!(i) : _onTap(context, i),
        selectedItemColor: kOrange,
        unselectedItemColor: kMutedFg,
        type: BottomNavigationBarType.fixed,
        selectedFontSize: 11,
        unselectedFontSize: 11,
        items: [
          const BottomNavigationBarItem(
            icon: Icon(Icons.home_outlined),
            activeIcon: Icon(Icons.home),
            label: 'Posts',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.map_outlined),
            activeIcon: Icon(Icons.map),
            label: 'Map',
          ),
          BottomNavigationBarItem(
            icon: Container(
              padding: const EdgeInsets.all(8),
              decoration: const BoxDecoration(
                color: kOrange,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.add, color: Colors.white, size: 22),
            ),
            label: 'Create',
          ),
          BottomNavigationBarItem(
            icon: Badge(
              isLabelVisible: unreadTotal > 0,
              label: Text('$unreadTotal'),
              child: const Icon(Icons.chat_bubble_outline),
            ),
            activeIcon: Badge(
              isLabelVisible: unreadTotal > 0,
              label: Text('$unreadTotal'),
              child: const Icon(Icons.chat_bubble),
            ),
            label: 'Chat',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.search_outlined),
            activeIcon: Icon(Icons.search),
            label: 'Search',
          ),
        ],
      ),
    );
  }

  void _onTap(BuildContext context, int index) {
    switch (index) {
      case 0:
        context.go('/feed');
        break;
      case 1:
        context.go('/map');
        break;
      case 2:
        context.go('/create');
        break;
      case 3:
        context.go('/chat');
        break;
      case 4:
        context.go('/search');
        break;
    }
  }
}
