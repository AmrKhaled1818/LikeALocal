import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/providers/auth_provider.dart';
import '../../shared/providers/theme_provider.dart';
import '../../shared/providers/user_provider.dart';
import 'preference_quiz_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _notificationsEnabled = true;
  bool _dmNotificationsEnabled = true;

  // Chat schedule state
  bool _scheduleEnabled = false;
  TimeOfDay _scheduleStart = const TimeOfDay(hour: 9, minute: 0);
  TimeOfDay _scheduleEnd = const TimeOfDay(hour: 22, minute: 0);

  @override
  void initState() {
    super.initState();
    final user = context.read<AuthProvider>().userModel;
    final schedule = user?.chatSchedule ?? {};
    if (schedule['enabled'] == true) {
      _scheduleEnabled = true;
      final startH = schedule['startHour'] as int? ?? 9;
      final startM = schedule['startMinute'] as int? ?? 0;
      final endH = schedule['endHour'] as int? ?? 22;
      final endM = schedule['endMinute'] as int? ?? 0;
      _scheduleStart = TimeOfDay(hour: startH, minute: startM);
      _scheduleEnd = TimeOfDay(hour: endH, minute: endM);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final user = auth.userModel;
    final chatEnabled = user?.chatEnabled ?? true;
    final prefs = user?.preferences ?? {};
    final budget = prefs['budget']?.toString() ?? '';
    final atmosphere = prefs['atmosphere']?.toString() ?? '';
    final cats = (prefs['favCategories'] as List?)?.cast<String>() ?? [];

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => context.pop(),
        ),
        title: const Text('Settings',
            style: TextStyle(
                color: Colors.white, fontWeight: FontWeight.bold)),
      ),
      body: ListView(
        children: [
          // Account
          _SectionHeader(title: 'Account'),
          _SettingsTile(
            icon: Icons.person_outline,
            title: 'Edit Profile',
            subtitle: user?.username ?? '',
            onTap: () => context.push('/profile'),
          ),
          _SettingsTile(
            icon: Icons.lock_outline,
            title: 'Change Password',
            onTap: () => _changePassword(context, auth),
          ),
          _SettingsTile(
            icon: Icons.delete_forever_outlined,
            title: 'Delete Account',
            subtitle: 'Permanently remove your account',
            onTap: () => _confirmDeleteAccount(context, auth),
          ),
          _SettingsTile(
            icon: Icons.email_outlined,
            title: 'Email',
            subtitle: auth.firebaseUser?.email ?? '',
            onTap: null,
          ),

          // Privacy & Chat
          _SectionHeader(title: 'Privacy & Chat'),
          SwitchListTile(
            secondary: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(8)),
              child: const Icon(Icons.message_outlined, size: 20),
            ),
            title: const Text('Allow Direct Messages',
                style: TextStyle(fontSize: 14)),
            subtitle: const Text('Let others send you DMs',
                style: TextStyle(fontSize: 12, color: kMutedFg)),
            value: chatEnabled,
            activeColor: kOrange,
            onChanged: (v) => context.read<UserProvider>().updateChatEnabled(v),
          ),

          // DND Schedule
          if (chatEnabled) ...[
            SwitchListTile(
              secondary: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(8)),
                child: Icon(
                  _scheduleEnabled
                      ? Icons.do_not_disturb_on_outlined
                      : Icons.schedule_outlined,
                  color: _scheduleEnabled ? kOrange : null,
                  size: 20,
                ),
              ),
              title: const Text('Chat Availability Schedule',
                  style: TextStyle(fontSize: 14)),
              subtitle: Text(
                _scheduleEnabled
                    ? 'Active ${_scheduleStart.format(context)} – ${_scheduleEnd.format(context)}'
                    : 'Available at all times',
                style: const TextStyle(fontSize: 12, color: kMutedFg),
              ),
              value: _scheduleEnabled,
              activeColor: kOrange,
              onChanged: (v) {
                setState(() => _scheduleEnabled = v);
                _saveSchedule();
              },
            ),
            if (_scheduleEnabled)
              Padding(
                padding:
                    const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Container(
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Theme.of(context).dividerColor),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: _TimeTile(
                          label: 'From',
                          time: _scheduleStart,
                          onTap: () async {
                            final t = await showTimePicker(
                                context: context,
                                initialTime: _scheduleStart);
                            if (t != null) {
                              setState(() => _scheduleStart = t);
                              _saveSchedule();
                            }
                          },
                        ),
                      ),
                      Container(width: 1, height: 48, color: kMuted),
                      Expanded(
                        child: _TimeTile(
                          label: 'To',
                          time: _scheduleEnd,
                          onTap: () async {
                            final t = await showTimePicker(
                                context: context,
                                initialTime: _scheduleEnd);
                            if (t != null) {
                              setState(() => _scheduleEnd = t);
                              _saveSchedule();
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],

          // Appearance
          _SectionHeader(title: 'Appearance'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Consumer<ThemeProvider>(
              builder: (context, tp, _) => Container(
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    _ThemeModeBtn(
                      label: 'Light',
                      icon: Icons.light_mode_outlined,
                      selected: tp.mode == ThemeMode.light,
                      onTap: () => tp.setMode(ThemeMode.light),
                    ),
                    _ThemeModeBtn(
                      label: 'System',
                      icon: Icons.brightness_auto_outlined,
                      selected: tp.mode == ThemeMode.system,
                      onTap: () => tp.setMode(ThemeMode.system),
                    ),
                    _ThemeModeBtn(
                      label: 'Dark',
                      icon: Icons.dark_mode_outlined,
                      selected: tp.mode == ThemeMode.dark,
                      onTap: () => tp.setMode(ThemeMode.dark),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Notifications
          _SectionHeader(title: 'Notifications'),
          SwitchListTile(
            secondary: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(8)),
              child: const Icon(Icons.notifications_outlined, size: 20),
            ),
            title: const Text('Push Notifications',
                style: TextStyle(fontSize: 14)),
            subtitle: const Text('Likes, comments, and mentions',
                style: TextStyle(fontSize: 12, color: kMutedFg)),
            value: _notificationsEnabled,
            activeColor: kOrange,
            onChanged: (v) => setState(() => _notificationsEnabled = v),
          ),
          SwitchListTile(
            secondary: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(8)),
              child: const Icon(Icons.chat_bubble_outline, size: 20),
            ),
            title: const Text('Message Notifications',
                style: TextStyle(fontSize: 14)),
            value: _dmNotificationsEnabled,
            activeColor: kOrange,
            onChanged: (v) =>
                setState(() => _dmNotificationsEnabled = v),
          ),

          // Preferences / AI Style
          _SectionHeader(title: 'AI Discovery Style'),
          ListTile(
            leading: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                    colors: [Color(0xFF8B5CF6), Color(0xFFEC4899)]),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.auto_awesome,
                  color: Colors.white, size: 18),
            ),
            title: const Text('Style Preferences Quiz',
                style: TextStyle(fontSize: 14)),
            subtitle: Text(
              _buildPrefSummary(budget, atmosphere, cats),
              style: const TextStyle(fontSize: 12, color: kMutedFg),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            trailing: const Icon(Icons.chevron_right, color: kMutedFg, size: 20),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) => const PreferenceQuizScreen()),
            ),
          ),

          // About
          _SectionHeader(title: 'About'),
          _SettingsTile(
            icon: Icons.info_outline,
            title: 'App Version',
            subtitle: '1.0.0',
            onTap: null,
          ),
          _SettingsTile(
            icon: Icons.privacy_tip_outlined,
            title: 'Privacy Policy',
            onTap: () {},
          ),
          _SettingsTile(
            icon: Icons.description_outlined,
            title: 'Terms of Service',
            onTap: () {},
          ),

          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: OutlinedButton.icon(
              onPressed: () => _confirmSignOut(context),
              icon: const Icon(Icons.logout, color: kDestructive),
              label: const Text('Log Out',
                  style: TextStyle(color: kDestructive)),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: kDestructive),
              ),
            ),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  String _buildPrefSummary(
      String budget, String atmosphere, List<String> cats) {
    if (budget.isEmpty && atmosphere.isEmpty) return 'Not set — tap to take quiz';
    final parts = <String>[];
    if (budget.isNotEmpty) parts.add(budget);
    if (atmosphere.isNotEmpty) parts.add(atmosphere);
    if (cats.isNotEmpty) parts.add(cats.take(2).join(', '));
    return parts.join(' · ');
  }

  Future<void> _saveSchedule() async {
    final user = context.read<AuthProvider>().userModel;
    if (user == null) return;
    await context.read<UserProvider>().updatePreferences({
      ...user.preferences,
    });
    // Save schedule to user doc directly
    await context.read<UserProvider>().updateChatSchedule({
      'enabled': _scheduleEnabled,
      'startHour': _scheduleStart.hour,
      'startMinute': _scheduleStart.minute,
      'endHour': _scheduleEnd.hour,
      'endMinute': _scheduleEnd.minute,
    });
  }

  void _changePassword(BuildContext context, AuthProvider auth) {
    final email = auth.firebaseUser?.email ?? '';
    if (email.isEmpty) return;
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Reset Password'),
        content: Text('A password reset link will be sent to $email'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await auth.resetPassword(email);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                    content: Text('Reset link sent!'),
                    backgroundColor: Colors.green));
              }
            },
            child: const Text('Send Link'),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteAccount(BuildContext context, AuthProvider auth) {
    final confirmCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setDialog) => AlertDialog(
          title: const Text('Delete Account',
              style: TextStyle(color: kDestructive)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'This is permanent. All your posts and data will be deleted.\n\nType DELETE to confirm:',
                style: TextStyle(fontSize: 14),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: confirmCtrl,
                autofocus: true,
                onChanged: (_) => setDialog(() {}),
                decoration: const InputDecoration(
                  hintText: 'DELETE',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: kDestructive),
              onPressed: confirmCtrl.text == 'DELETE'
                  ? () async {
                      Navigator.pop(ctx);
                      final ok = await auth.deleteAccount();
                      if (!ok && mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(auth.errorMessage ??
                                'Deletion failed'),
                            backgroundColor: kDestructive,
                          ),
                        );
                      }
                    }
                  : null,
              child: const Text('Delete',
                  style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmSignOut(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Log Out'),
        content: const Text('Are you sure you want to log out?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          ElevatedButton(
            style:
                ElevatedButton.styleFrom(backgroundColor: kDestructive),
            onPressed: () async {
              Navigator.pop(context);
              await context.read<AuthProvider>().signOut();
              if (context.mounted) context.go('/login');
            },
            child: const Text('Log Out',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}

class _TimeTile extends StatelessWidget {
  final String label;
  final TimeOfDay time;
  final VoidCallback onTap;

  const _TimeTile(
      {required this.label, required this.time, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label,
                style:
                    const TextStyle(fontSize: 11, color: kMutedFg)),
            const SizedBox(height: 2),
            Text(time.format(context),
                style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: kOrange)),
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 6),
      child: Text(title.toUpperCase(),
          style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2)),
    );
  }
}

class _ThemeModeBtn extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _ThemeModeBtn({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final unselectedColor = Theme.of(context).colorScheme.onSurfaceVariant;
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.all(3),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: selected ? kOrange : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon,
                  size: 18,
                  color: selected ? Colors.white : unselectedColor),
              const SizedBox(height: 4),
              Text(label,
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: selected ? Colors.white : unselectedColor)),
            ],
          ),
        ),
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback? onTap;

  const _SettingsTile(
      {required this.icon,
      required this.title,
      this.subtitle,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      leading: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(8)),
        child: Icon(icon, size: 20),
      ),
      title: Text(title, style: const TextStyle(fontSize: 14)),
      subtitle: subtitle != null && subtitle!.isNotEmpty
          ? Text(subtitle!,
              style: const TextStyle(color: kMutedFg, fontSize: 12))
          : null,
      trailing: onTap != null
          ? const Icon(Icons.chevron_right, color: kMutedFg, size: 20)
          : null,
    );
  }
}
