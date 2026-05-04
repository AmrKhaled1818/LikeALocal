import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';

class FriendsSidebar extends StatefulWidget {
  final bool isOpen;
  final VoidCallback onClose;

  const FriendsSidebar(
      {super.key, required this.isOpen, required this.onClose});

  @override
  State<FriendsSidebar> createState() => _FriendsSidebarState();
}

class _FriendsSidebarState extends State<FriendsSidebar> {
  final _searchCtrl = TextEditingController();
  String _query = '';

  // Mock friends data — will be replaced with real data from Firestore
  static const _friends = [
    {'name': 'Sarah Chen', 'online': true},
    {'name': 'Mike Johnson', 'online': true},
    {'name': 'Emma Wilson', 'online': false},
    {'name': 'Alex Rodriguez', 'online': true},
    {'name': 'Lisa Park', 'online': false},
  ];

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isOpen) return const SizedBox.shrink();

    final filtered = _friends
        .where((f) =>
            (f['name'] as String).toLowerCase().contains(_query.toLowerCase()))
        .toList();
    final online = filtered.where((f) => f['online'] as bool).toList();
    final offline = filtered.where((f) => !(f['online'] as bool)).toList();

    return GestureDetector(
      onTap: widget.onClose,
      child: Material(
        color: Colors.black.withOpacity(0.4),
        child: Row(
          children: [
            GestureDetector(
              onTap: () {}, // prevent close on sidebar tap
              child: Container(
                width: MediaQuery.of(context).size.width * 0.75,
                color: Colors.white,
                child: SafeArea(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 16, 8, 8),
                        child: Row(
                          children: [
                            const Text('Friends',
                                style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: kDark)),
                            const Spacer(),
                            IconButton(
                              icon: const Icon(Icons.close),
                              onPressed: widget.onClose,
                            ),
                          ],
                        ),
                      ),
                      // Search
                      Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        child: TextField(
                          controller: _searchCtrl,
                          onChanged: (v) => setState(() => _query = v),
                          decoration: const InputDecoration(
                            prefixIcon:
                                Icon(Icons.search, color: kMutedFg, size: 20),
                            hintText: 'Search friends...',
                          ),
                        ),
                      ),

                      // Online section
                      if (online.isNotEmpty) ...[
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                          child: Text(
                            '${online.length} Online',
                            style: const TextStyle(
                                color: kMutedFg,
                                fontSize: 12,
                                fontWeight: FontWeight.w600),
                          ),
                        ),
                        ...online.map((f) => _FriendItem(
                            name: f['name'] as String, online: true)),
                      ],
                      if (offline.isNotEmpty)
                        ...offline.map((f) => _FriendItem(
                            name: f['name'] as String, online: false)),

                      const Spacer(),
                      // Add friend
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: TextButton.icon(
                          onPressed: () => _showAddFriend(context),
                          icon: const Icon(Icons.person_add_outlined,
                              color: kOrange),
                          label: const Text('Add Friend',
                              style: TextStyle(color: kOrange)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const Expanded(child: SizedBox()),
          ],
        ),
      ),
    );
  }

  void _showAddFriend(BuildContext context) {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Add Friend'),
        content: TextField(
          controller: ctrl,
          decoration: const InputDecoration(hintText: 'Enter username'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                    content: Text(
                        'Friend request sent to ${ctrl.text}')),
              );
            },
            child: const Text('Send Request'),
          ),
        ],
      ),
    );
  }
}

class _FriendItem extends StatelessWidget {
  final String name;
  final bool online;

  const _FriendItem({required this.name, required this.online});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Stack(
        children: [
          CircleAvatar(
            backgroundColor: kOrange,
            child: Text(name.substring(0, 1),
                style: const TextStyle(color: Colors.white, fontSize: 14)),
          ),
          Positioned(
            bottom: 0,
            right: 0,
            child: Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: online ? Colors.green : kMutedFg,
                shape: BoxShape.circle,
                border:
                    Border.all(color: Colors.white, width: 1.5),
              ),
            ),
          ),
        ],
      ),
      title: Text(name,
          style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14)),
      subtitle: Text(online ? 'Online' : 'Offline',
          style: TextStyle(
              color: online ? Colors.green : kMutedFg, fontSize: 12)),
    );
  }
}
