import 'dart:ui';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:toastification/toastification.dart';

import 'core/theme/app_colors.dart';
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
import 'features/leaderboard/leaderboard_screen.dart';
import 'features/trip/trip_planner_screen.dart';
import 'firebase_options.dart';
import 'core/services/proximity_service.dart';
import 'shared/providers/auth_provider.dart';
import 'shared/providers/chat_provider.dart';
import 'shared/providers/connectivity_provider.dart';
import 'shared/providers/posts_provider.dart';
import 'shared/providers/theme_provider.dart';
import 'shared/providers/user_provider.dart';
import 'core/utils/responsive.dart';
import 'shared/widgets/bottom_nav.dart';
import 'shared/widgets/sidebar_menu.dart';
import 'shared/widgets/top_bar.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  FlutterError.onError = (details) {
    FlutterError.presentError(details);
  };
  PlatformDispatcher.instance.onError = (error, stack) {
    debugPrint('Uncaught error: $error\n$stack');
    return true;
  };

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  FirebaseFirestore.instance.settings = const Settings(
    persistenceEnabled: true,
    cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
  );
  await NotificationService.initialize();
  await ProximityService.setup();
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

class _AppRouterState extends State<_AppRouter> with WidgetsBindingObserver {
  late final GoRouter _router;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final authProvider = context.read<AuthProvider>();
    _router = GoRouter(
      initialLocation: '/splash',
      refreshListenable: authProvider,
      redirect: (ctx, state) {
        final isLoggedIn = authProvider.isLoggedIn;
        final loc = state.matchedLocation;
        if (loc == '/splash' || loc == '/onboarding') return null;
        if (!isLoggedIn && loc != '/login') return '/login';
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
        StatefulShellRoute.indexedStack(
          builder: (context, state, navigationShell) =>
              _MainShell(navigationShell: navigationShell),
          branches: [
            StatefulShellBranch(routes: [
              GoRoute(
                path: '/feed',
                builder: (_, __) => const PostsScreen(),
              ),
            ]),
            StatefulShellBranch(routes: [
              GoRoute(
                path: '/map',
                builder: (_, state) => MapScreen(
                  focusPostId: state.uri.queryParameters['focusPostId'],
                ),
              ),
            ]),
            StatefulShellBranch(routes: [
              GoRoute(
                path: '/create',
                builder: (_, __) => const CreatePostScreen(),
              ),
            ]),
            StatefulShellBranch(routes: [
              GoRoute(
                path: '/chat',
                builder: (_, __) => const ChatScreen(),
              ),
            ]),
            StatefulShellBranch(routes: [
              GoRoute(
                path: '/search',
                builder: (_, __) => const SearchScreen(),
              ),
            ]),
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
          path: '/user/:uid',
          builder: (_, state) =>
              ProfileScreen(userId: state.pathParameters['uid']),
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
        GoRoute(
          path: '/leaderboard',
          builder: (_, __) => const LeaderboardScreen(),
        ),
        GoRoute(
          path: '/trip',
          builder: (_, __) => const TripPlannerScreen(),
        ),
      ],
      errorBuilder: (_, state) => Scaffold(
        body: Center(child: Text('Page not found: ${state.error}')),
      ),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final auth = context.read<AuthProvider>();
    if (state == AppLifecycleState.resumed) {
      auth.setOnline(true);
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      auth.setOnline(false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    return ToastificationWrapper(
      child: MaterialApp.router(
        title: 'LikeALocal',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.theme,
        darkTheme: AppTheme.darkTheme,
        themeMode: themeProvider.mode,
        routerConfig: _router,
      ),
    );
  }
}

class _MainShell extends StatefulWidget {
  final StatefulNavigationShell navigationShell;

  const _MainShell({required this.navigationShell});

  @override
  State<_MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<_MainShell> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  late final AuthProvider _authProvider;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _authProvider = context.read<AuthProvider>();
      _authProvider.addListener(_onAuthChanged);
      _onAuthChanged();
      ProximityService.maybeRequestConsent(context);
    });
  }

  void _onAuthChanged() {
    if (!mounted) return;
    final uid = _authProvider.uid;
    final chatProvider = context.read<ChatProvider>();
    if (uid.isNotEmpty) {
      chatProvider.startListening(uid);
    } else {
      chatProvider.stopListening();
    }
  }

  @override
  void dispose() {
    _authProvider.removeListener(_onAuthChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final connectivity = context.watch<ConnectivityProvider>();
    final navShell = widget.navigationShell;
    final isCreate = navShell.currentIndex == 2;
    final screenWidth = MediaQuery.sizeOf(context).width;
    final isWide = screenWidth >= AppBreakpoints.tablet;

    void onBranch(int i) =>
        navShell.goBranch(i, initialLocation: i == navShell.currentIndex);

    if (isWide) {
      return Scaffold(
        key: _scaffoldKey,
        appBar: isCreate ? null : AppTopBar(scaffoldKey: _scaffoldKey),
        drawer: const SidebarMenu(),
        body: Column(
          children: [
            if (!connectivity.isOnline) const _OfflineBanner(),
            Expanded(
              child: Row(
                children: [
                  _AppNavigationRail(
                    currentIndex: navShell.currentIndex,
                    extended: screenWidth >= AppBreakpoints.desktop,
                    onTap: onBranch,
                  ),
                  const VerticalDivider(width: 1, thickness: 1),
                  Expanded(child: navShell),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return Scaffold(
      key: _scaffoldKey,
      appBar: isCreate ? null : AppTopBar(scaffoldKey: _scaffoldKey),
      drawer: const SidebarMenu(),
      body: Column(
        children: [
          if (!connectivity.isOnline) const _OfflineBanner(),
          Expanded(child: navShell),
        ],
      ),
      bottomNavigationBar: AppBottomNav(
        currentIndex: navShell.currentIndex,
        onTap: onBranch,
      ),
    );
  }
}

class _AppNavigationRail extends StatelessWidget {
  final int currentIndex;
  final bool extended;
  final void Function(int) onTap;

  const _AppNavigationRail({
    required this.currentIndex,
    required this.extended,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final chats = context.watch<ChatProvider>().chats;
    int unread = 0;
    for (final chat in chats) {
      unread += chat.unreadCount[auth.uid] ?? 0;
    }

    return NavigationRail(
      selectedIndex: currentIndex,
      extended: extended,
      onDestinationSelected: onTap,
      selectedIconTheme: const IconThemeData(color: kOrange),
      selectedLabelTextStyle: const TextStyle(
          color: kOrange, fontWeight: FontWeight.w600, fontSize: 12),
      unselectedLabelTextStyle:
          const TextStyle(color: kMutedFg, fontSize: 12),
      destinations: [
        const NavigationRailDestination(
          icon: Icon(Icons.home_outlined),
          selectedIcon: Icon(Icons.home),
          label: Text('Posts'),
        ),
        const NavigationRailDestination(
          icon: Icon(Icons.map_outlined),
          selectedIcon: Icon(Icons.map),
          label: Text('Map'),
        ),
        NavigationRailDestination(
          icon: Container(
            padding: const EdgeInsets.all(6),
            decoration: const BoxDecoration(
                color: kOrange, shape: BoxShape.circle),
            child: const Icon(Icons.add, color: Colors.white, size: 20),
          ),
          label: const Text('Create'),
        ),
        NavigationRailDestination(
          icon: Badge(
            isLabelVisible: unread > 0,
            label: Text('$unread'),
            child: const Icon(Icons.chat_bubble_outline),
          ),
          selectedIcon: Badge(
            isLabelVisible: unread > 0,
            label: Text('$unread'),
            child: const Icon(Icons.chat_bubble),
          ),
          label: const Text('Chat'),
        ),
        const NavigationRailDestination(
          icon: Icon(Icons.search_outlined),
          selectedIcon: Icon(Icons.search),
          label: Text('Search'),
        ),
      ],
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
