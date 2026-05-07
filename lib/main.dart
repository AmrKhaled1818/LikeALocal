import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'core/theme/app_theme.dart';
import 'data/services/notification_service.dart';
import 'features/auth/login_screen.dart';
import 'features/onboarding/onboarding_screen.dart';
import 'features/onboarding/splash_screen.dart';
import 'features/chat/chat_screen.dart';
import 'features/chat/conversation_screen.dart';
import 'features/create/create_post_screen.dart';
import 'features/feed/post_detail_screen.dart';
import 'features/feed/posts_screen.dart';
import 'features/map/map_screen.dart';
import 'features/notifications/notifications_screen.dart';
import 'features/profile/profile_screen.dart';
import 'features/search/search_screen.dart';
import 'features/faq/faq_screen.dart';
import 'features/saved/saved_posts_screen.dart';
import 'features/settings/settings_screen.dart';
import 'firebase_options.dart';
import 'shared/providers/auth_provider.dart';
import 'shared/providers/chat_provider.dart';
import 'shared/providers/connectivity_provider.dart';
import 'shared/providers/posts_provider.dart';
import 'shared/providers/theme_provider.dart';
import 'shared/providers/user_provider.dart';
import 'shared/widgets/bottom_nav.dart';
import 'shared/widgets/sidebar_menu.dart';
import 'shared/widgets/top_bar.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  FirebaseFirestore.instance.settings = const Settings(
    persistenceEnabled: true,
    cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
  );
  await NotificationService.initialize();
  runApp(const LikeALocalApp());
}

class LikeALocalApp extends StatelessWidget {
  const LikeALocalApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => PostsProvider()),
        ChangeNotifierProvider(create: (_) => ChatProvider()),
        ChangeNotifierProvider(create: (_) => UserProvider()),
        ChangeNotifierProvider(create: (_) => ConnectivityProvider()),
      ],
      child: const _AppRouter(),
    );
  }
}

// Separate StatefulWidget so the GoRouter is created once and never recreated
// on theme or auth rebuilds — fixes the duplicate GlobalKey crash.
class _AppRouter extends StatefulWidget {
  const _AppRouter();

  @override
  State<_AppRouter> createState() => _AppRouterState();
}

class _AppRouterState extends State<_AppRouter> {
  late final GoRouter _router;

  @override
  void initState() {
    super.initState();
    final authProvider = context.read<AuthProvider>();
    _router = GoRouter(
      initialLocation: '/splash',
      refreshListenable: authProvider,
      redirect: (ctx, state) {
        final isLoggedIn = authProvider.isLoggedIn;
        final loc = state.matchedLocation;
        if (loc == '/splash' || loc == '/onboarding') return null;
        if (!isLoggedIn && loc != '/login') return '/login';
        if (isLoggedIn && loc == '/login') return '/feed';
        return null;
      },
      routes: [
        GoRoute(
          path: '/splash',
          builder: (_, __) => const SplashScreen(),
        ),
        GoRoute(
          path: '/onboarding',
          builder: (_, __) => const OnboardingScreen(),
        ),
        GoRoute(
          path: '/login',
          builder: (_, __) => const LoginScreen(),
        ),
        ShellRoute(
          builder: (context, state, child) =>
              _MainShell(location: state.matchedLocation, child: child),
          routes: [
            GoRoute(
              path: '/feed',
              builder: (_, __) => const PostsScreen(),
            ),
            GoRoute(
              path: '/map',
              builder: (_, state) => MapScreen(
                focusPostId: state.uri.queryParameters['focusPostId'],
              ),
            ),
            GoRoute(
              path: '/create',
              builder: (_, __) => const CreatePostScreen(),
            ),
            GoRoute(
              path: '/chat',
              builder: (_, __) => const ChatScreen(),
            ),
            GoRoute(
              path: '/search',
              builder: (_, __) => const SearchScreen(),
            ),
          ],
        ),
        GoRoute(
          path: '/post/:postId',
          builder: (_, state) =>
              PostDetailScreen(postId: state.pathParameters['postId']!),
        ),
        GoRoute(
          path: '/conversation/:chatId',
          builder: (_, state) => ConversationScreen(
              chatId: state.pathParameters['chatId']!),
        ),
        GoRoute(
          path: '/profile',
          builder: (_, __) => const ProfileScreen(),
        ),
        GoRoute(
          path: '/notifications',
          builder: (_, __) => const NotificationsScreen(),
        ),
        GoRoute(
          path: '/saved',
          builder: (_, __) => const SavedPostsScreen(),
        ),
        GoRoute(
          path: '/settings',
          builder: (_, __) => const SettingsScreen(),
        ),
        GoRoute(
          path: '/faq',
          builder: (_, __) => const FaqScreen(),
        ),
      ],
      errorBuilder: (_, state) => Scaffold(
        body: Center(child: Text('Page not found: ${state.error}')),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    return MaterialApp.router(
      title: 'LikeALocal',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.theme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeProvider.mode,
      routerConfig: _router,
    );
  }
}

class _MainShell extends StatefulWidget {
  final String location;
  final Widget child;

  const _MainShell({required this.location, required this.child});

  @override
  State<_MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<_MainShell> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  int _prevIndex = 0;

  static int _indexFor(String loc) {
    switch (loc) {
      case '/feed':
        return 0;
      case '/map':
        return 1;
      case '/create':
        return 2;
      case '/chat':
        return 3;
      case '/search':
        return 4;
      default:
        return 0;
    }
  }

  int get _navIndex => _indexFor(widget.location);

  @override
  void didUpdateWidget(_MainShell old) {
    super.didUpdateWidget(old);
    if (old.location != widget.location) {
      _prevIndex = _indexFor(old.location);
    }
  }

  @override
  Widget build(BuildContext context) {
    final connectivity = context.watch<ConnectivityProvider>();
    final isCreate = widget.location == '/create';
    final goingRight = _navIndex > _prevIndex;

    return Scaffold(
      key: _scaffoldKey,
      appBar: isCreate ? null : AppTopBar(scaffoldKey: _scaffoldKey),
      drawer: const SidebarMenu(),
      body: Column(
        children: [
          if (!connectivity.isOnline) const _OfflineBanner(),
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 120),
              transitionBuilder: (child, animation) {
                final offset = goingRight
                    ? const Offset(1.0, 0.0)
                    : const Offset(-1.0, 0.0);
                return SlideTransition(
                  position: Tween<Offset>(
                    begin: offset,
                    end: Offset.zero,
                  ).animate(CurvedAnimation(
                    parent: animation,
                    curve: Curves.easeOutCubic,
                  )),
                  child: child,
                );
              },
              child: KeyedSubtree(
                key: ValueKey(widget.location),
                child: widget.child,
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: AppBottomNav(currentIndex: _navIndex),
    );
  }
}

class _OfflineBanner extends StatelessWidget {
  const _OfflineBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: const Color(0xFF374151),
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: const Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.wifi_off, color: Colors.white70, size: 14),
          SizedBox(width: 6),
          Text(
            'You are offline — showing cached content',
            style: TextStyle(color: Colors.white70, fontSize: 12),
          ),
        ],
      ),
    );
  }
}
