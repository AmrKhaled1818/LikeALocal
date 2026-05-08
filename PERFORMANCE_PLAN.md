# LikeALocal — Performance & Release Plan

> **How to read this:** Each problem has a severity badge, the exact file/line, the root cause, and the exact fix. Problems are ordered by impact — fix the top ones first and the app will feel dramatically different before you even reach the bottom.

---

## Table of Contents
1. [Flutter Rebuild Problems](#1-flutter-rebuild-problems)
2. [Map Screen — Why It Fails for Some Users](#2-map-screen--why-it-fails-for-some-users)
3. [Firestore / Network Problems](#3-firestore--network-problems)
4. [Advanced Flutter Techniques to Apply](#4-advanced-flutter-techniques-to-apply)
5. [APK Release Checklist](#5-apk-release-checklist)
6. [Priority Implementation Order](#6-priority-implementation-order)

---

## 1. Flutter Rebuild Problems

These are the biggest source of jank. Every unnecessary rebuild means Flutter has to re-layout, re-paint, and sometimes re-download images. On a mid-range phone this is what makes the app feel sluggish.

---

### 🔴 Problem 1 — Every PostCard rebuilds on any auth change
**File:** `lib/shared/widgets/post_card.dart` line 136  
**Severity:** Critical — affects every visible card at once

```dart
// CURRENT — rebuilds every PostCard every time karma increments, avatar updates, etc.
final auth = context.watch<AuthProvider>();
final avatarUrl = (post.userId == auth.uid)
    ? (auth.userModel?.avatarUrl ?? post.userAvatarUrl)
    : post.userAvatarUrl;
```

`AuthProvider` calls `notifyListeners()` 4 times across its lifecycle (auth state change, loading toggle, error set, karma increment from upvote). With 10 cards visible, one upvote causes **10 full widget rebuilds**. Fix with `context.select()`:

```dart
// FIX — only rebuilds this card when the avatar URL string itself changes
final avatarUrl = context.select<AuthProvider, String>((a) =>
    (post.userId == a.uid)
        ? (a.userModel?.avatarUrl ?? post.userAvatarUrl)
        : post.userAvatarUrl);
```

---

### 🔴 Problem 2 — The whole feed list rebuilds on every small action
**File:** `lib/features/feed/posts_screen.dart` + `lib/shared/providers/posts_provider.dart`  
**Severity:** Critical — causes visible scroll jank on upvote/save

`PostsProvider` calls `notifyListeners()` 21 times throughout the file. The `Consumer<PostsProvider>` wrapping the entire `CustomScrollView` means every single one of those 21 calls rebuilds the entire feed from scratch — headers, list, footer, everything.

```dart
// CURRENT — one giant Consumer wraps everything
return Consumer<PostsProvider>(
  builder: (context, posts, _) {
    // rebuilds ALL of this on every notifyListeners()
    return CustomScrollView( ... );
  },
);
```

Fix: split into granular `Selector` widgets. The scroll list only needs to rebuild when the posts list itself changes; the loading indicator only when `isLoading` changes:

```dart
// FIX — outer scaffold reads only loading/error, inner list reads only posts
Selector<PostsProvider, (bool, String?)>(
  selector: (_, p) => (p.isLoading, p.error),
  builder: (context, (isLoading, error), _) {
    if (isLoading) return _buildShimmer();
    if (error != null) return ErrorRetryWidget(...);
    return Selector<PostsProvider, List<PostModel>>(
      selector: (_, p) => p.feedPosts,
      builder: (context, posts, _) => CustomScrollView(...),
    );
  },
)
```

---

### 🔴 Problem 3 — Inline comment TextField in every PostCard
**File:** `lib/shared/widgets/post_card.dart` bottom section  
**Severity:** Critical for scroll performance

Every PostCard has a live `TextField` + `TextEditingController`. With 10 cards in the feed, there are **10 active text input widgets** all attached to the Flutter input system, all listening for keyboard events, all maintaining focus nodes. This is a major source of scroll jank and memory pressure.

**Fix:** Remove the inline comment box from PostCard entirely. Users can tap through to `PostDetailScreen` to comment. The "Add a comment..." prompt can remain as a tappable decoration (not a real TextField) that navigates to the detail screen:

```dart
// Replace the TextField in PostCard with a simple tappable row
GestureDetector(
  onTap: () => context.push('/post/${post.postId}'),
  child: Container(
    padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
    child: Row(
      children: [
        CircleAvatar(radius: 12, ...),
        const SizedBox(width: 8),
        const Text('Add a comment...', style: TextStyle(color: kMutedFg, fontSize: 13)),
      ],
    ),
  ),
)
```

---

### 🔴 Problem 4 — TopBar opens a Firestore stream inside a StatelessWidget
**File:** `lib/shared/widgets/top_bar.dart` line 54  
**Severity:** High — fires on every TopBar build, loads all notifications

`AppTopBar` is a `StatelessWidget`, so `build()` is called frequently. Inside it creates a `StreamBuilder` on the Firestore notifications collection, fetching **all notifications** for the user and filtering `read == false` client-side:

```dart
// CURRENT — stream recreated on every build, no server-side read filter
stream: FirebaseFirestore.instance
    .collection('notifications')
    .where('userId', isEqualTo: auth.uid)
    .snapshots(),
// Then filters client-side: .where((d) => d['read'] == false)
```

Two fixes needed:
1. Move `AppTopBar` to a `StatefulWidget` so the stream subscription is created once and reused
2. Filter on the server (add `.where('read', isEqualTo: false)` — requires a Firestore composite index on `userId + read`)

```dart
// FIX — stream created once in initState, not on every build
class _NotificationBadge extends StatefulWidget { ... }
class _NotificationBadgeState extends State<_NotificationBadge> {
  late final Stream<int> _unreadStream;

  @override
  void initState() {
    super.initState();
    _unreadStream = FirebaseFirestore.instance
        .collection('notifications')
        .where('userId', isEqualTo: widget.uid)
        .where('read', isEqualTo: false)  // server-side filter
        .snapshots()
        .map((s) => s.docs.length);
  }
  // ...
}
```

---

### 🟠 Problem 5 — Avatar images bypass the image cache
**Files:** `post_card.dart:173`, `post_card.dart:437`, `top_bar.dart:108`, `sidebar_menu.dart:35`  
**Severity:** Medium — re-downloads on every rebuild

Post images correctly use `CachedNetworkImage`, but all avatar `CircleAvatar` widgets use plain `NetworkImage`:

```dart
// CURRENT — no cache, re-downloads on every rebuild
backgroundImage: avatarUrl.isNotEmpty ? NetworkImage(avatarUrl) : null,

// FIX — uses disk + memory cache
backgroundImage: avatarUrl.isNotEmpty
    ? CachedNetworkImageProvider(avatarUrl)
    : null,
```

Apply this to all 4 locations.

---

### 🟠 Problem 6 — Map rebuilds entirely on GPS position updates
**File:** `lib/features/map/map_screen.dart` lines 218–230  
**Severity:** Medium-High — GPS fires every 5 metres of movement

The location stream calls `setState(() => _currentPosition = pos)` which rebuilds the **entire map** — including recreating all marker widgets, rebuilding all filter chips, recalculating all distances. Fix: isolate the location dot into its own `StatefulWidget` driven by a `ValueNotifier`:

```dart
// In _MapScreenState:
final _positionNotifier = ValueNotifier<Position?>(null);

// In the stream listener:
_locationSub = Geolocator.getPositionStream(...).listen((pos) {
  _positionNotifier.value = pos;  // no setState — only the dot rebuilds
  if (_following && _mapReady) {
    _mapController.move(LatLng(pos.latitude, pos.longitude), ...);
  }
});

// The pulsing dot reads from the notifier directly
ValueListenableBuilder<Position?>(
  valueListenable: _positionNotifier,
  builder: (_, pos, __) => pos != null
      ? MarkerLayer(markers: [Marker(point: LatLng(pos.latitude, pos.longitude), child: const _PulsingDot())])
      : const SizedBox.shrink(),
),
```

---

### 🟡 Problem 7 — Map screen wraps everything in Consumer
**File:** `lib/features/map/map_screen.dart` line 530  
**Severity:** Medium — every PostsProvider change rebuilds the whole map

Same root cause as Problem 2. The `Consumer<PostsProvider>` wraps the entire `FlutterMap` + all overlays. When a user upvotes a post in the feed, the map redraws even though it's hidden. Fix: use `Selector` scoped to the filtered post list only:

```dart
// Only rebuild when the list of posts with GPS coords actually changes
Selector<PostsProvider, List<PostModel>>(
  selector: (_, p) => p.feedPosts.where((post) => post.lat != 0).toList(),
  shouldRebuild: (prev, next) => prev.length != next.length,
  builder: (context, geoPostes, _) { ... },
)
```

---

## 2. Map Screen — Why It Fails for Some Users

The map uses two tile sources. Here is exactly what goes wrong for each failure mode.

### Root Cause A — `com.example` package name gets rate-limited by OSM ⚠️
**File:** `lib/features/map/map_screen.dart` line 635

```dart
userAgentPackageName: 'com.example.like_a_local',  // ← PROBLEM
```

OpenStreetMap's tile policy requires a valid, unique user agent identifying your actual app. The `com.example.*` prefix is reserved for testing and OSM servers **actively rate-limit or block** requests with generic example package names. This is almost certainly why some users see grey tiles.

**Fix:** Change the package name first (see APK checklist), then update this to match:
```dart
userAgentPackageName: 'com.likealocal.app',
```

### Root Cause B — No persistent tile cache across app restarts
Tiles are loaded fresh from the network every time the app starts. On a slow network, the map shows grey for several seconds while tiles download. Flutter Map v7 includes in-memory tile caching per-session, but there is no disk cache configured.

**Fix:** Add the `flutter_map_cache` package (or use `dio_cache_interceptor` with a custom `TileProvider`). This keeps downloaded tiles on disk so the map loads instantly even offline:

```yaml
# pubspec.yaml — add:
flutter_map_cache: ^1.5.0
dio_cache_interceptor: ^3.5.0
dio_cache_interceptor_hive_store: ^3.2.2
```

```dart
// In TileLayer:
TileLayer(
  urlTemplate: _lightTileUrl,
  tileProvider: CachedTileProvider(
    maxStale: const Duration(days: 14),
    store: HiveCacheStore(tileCachePath),
  ),
),
```

### Root Cause C — Stadia dark tile `{api_key}` substitution depends on flutter_map version
**File:** `lib/features/map/map_screen.dart` line 633

```dart
additionalOptions: _darkMap ? const {'api_key': AppConfig.stadiaApiKey} : const {},
```

flutter_map v7 does support URL template variable substitution via `additionalOptions`. This should work correctly. However if users on dark mode see grey tiles, it means the Stadia API key is invalid or has hit its quota. The `fallbackUrl` correctly falls back to OSM, so this is non-critical but worth monitoring.

### Root Cause D — `launchUrl` for directions fails on some devices
**File:** `lib/features/map/map_screen.dart` line 1226

The error snackbar says "Please fully restart the app (stop & rebuild)" — this is a sign that `launchUrl` with `LaunchMode.externalApplication` is failing silently because Google Maps isn't installed or the intent is blocked. The fix is to try multiple fallback URLs:

```dart
Future<void> _openDirections(PostModel post) async {
  final query = Uri.encodeComponent('${post.title}, ${post.location}');
  
  // Try Google Maps app first
  final googleMapsApp = Uri.parse('google.navigation:q=$query&mode=d');
  // Fallback: Google Maps web
  final googleMapsWeb = Uri.parse('https://www.google.com/maps/dir/?api=1&destination=$query');
  // Last resort: Any maps app
  final geoUri = Uri.parse('geo:0,0?q=$query');

  if (await canLaunchUrl(googleMapsApp)) {
    await launchUrl(googleMapsApp);
  } else if (await canLaunchUrl(geoUri)) {
    await launchUrl(geoUri);
  } else {
    await launchUrl(googleMapsWeb, mode: LaunchMode.externalApplication);
  }
}
```

Also ensure `AndroidManifest.xml` has the `google.navigation` scheme in the `<queries>` block:
```xml
<intent>
  <action android:name="android.intent.action.VIEW" />
  <data android:scheme="google.navigation" />
</intent>
```

---

## 3. Firestore / Network Problems

---

### 🟠 Problem 8 — Map streams ALL posts with no limit
**File:** `lib/data/repositories/posts_repo.dart` → `getFeedPosts()`

```dart
// CURRENT — no limit, downloads the entire collection as a live stream
return _db.collection('posts')
    .orderBy('createdAt', descending: true)
    .snapshots();
```

As the database grows (100 → 500 → 1000 posts), this stream downloads and monitors everything. The map doesn't need live updates — it just needs a snapshot when it opens.

```dart
// FIX option 1 — one-shot fetch with a reasonable cap
Future<List<PostModel>> getMapPosts() async {
  final snap = await _db
      .collection('posts')
      .orderBy('createdAt', descending: true)
      .limit(300)
      .get();
  return snap.docs.map((d) => PostModel.fromMap(d.data(), d.id)).toList();
}

// FIX option 2 — keep the stream but cap it
Stream<List<PostModel>> getFeedPosts() {
  return _db.collection('posts')
      .orderBy('createdAt', descending: true)
      .limit(300)          // ← add this
      .snapshots()
      .map(...);
}
```

---

### 🟡 Problem 9 — Save limit check does N individual Firestore reads
**Files:** `post_card.dart:548`, `map_screen.dart:1188`

```dart
// CURRENT — fetches all saved posts individually just to count them
final savedPosts = await posts.getSavedPosts(auth.uid);  // N reads!
if (savedPosts.length >= 5) { ... }
```

`getSavedPosts` calls `getPost(id)` once per saved post. With 5 saves = 5 Firestore reads every time someone taps the bookmark. The local cache already exists:

```dart
// FIX — use the already-loaded local cache (zero Firestore reads)
// Add this getter to PostsProvider:
int get savedPostCount => _savedPostIds.length;

// Then in PostCard and MapScreen._PostBottomSheet:
final count = posts.savedPostCount;  // instant, no network
if (!isSuperUser && count >= 5) { ... }
```

---

### 🟡 Problem 10 — getSavedPosts fetches posts one by one
**File:** `lib/data/repositories/posts_repo.dart`

```dart
// CURRENT — waterfall: each read waits for the last
Future<List<PostModel>> getSavedPosts(String userId) async {
  final ids = await getSavedPostIds(userId);
  final posts = await Future.wait(ids.map((id) => getPost(id)));  // N parallel reads
  return posts.whereType<PostModel>().toList();
}
```

`Future.wait` already runs them in parallel, which is acceptable. However Firestore supports `whereIn` for up to 30 IDs, which is a single read instead of N:

```dart
// FIX — single Firestore query instead of N reads
Future<List<PostModel>> getSavedPosts(String userId) async {
  final ids = await getSavedPostIds(userId);
  if (ids.isEmpty) return [];
  // Firestore whereIn limit is 30 per query
  final chunks = <List<String>>[];
  for (var i = 0; i < ids.length; i += 30) {
    chunks.add(ids.sublist(i, i + 30 > ids.length ? ids.length : i + 30));
  }
  final results = await Future.wait(chunks.map((chunk) =>
      _db.collection('posts').where(FieldPath.documentId, whereIn: chunk).get()));
  return results.expand((snap) =>
      snap.docs.map((d) => PostModel.fromMap(d.data(), d.id))).toList();
}
```

---

## 4. Advanced Flutter Techniques to Apply

These are Flutter-specific tools that directly address performance. Each one is applicable to your app right now.

---

### Technique 1 — `AutomaticKeepAliveClientMixin` on tab screens

**Problem:** Every time you switch from the Feed tab to the Map tab and back, the Feed re-runs its entire build, re-renders the shimmer, and re-fetches the first page of posts.

**Fix:** Add `AutomaticKeepAliveClientMixin` to `PostsScreen`, `MapScreen`, `SearchScreen`, and `ChatScreen`:

```dart
class _PostsScreenState extends State<PostsScreen>
    with AutomaticKeepAliveClientMixin {        // ← add this
  
  @override
  bool get wantKeepAlive => true;              // ← add this

  @override
  Widget build(BuildContext context) {
    super.build(context);                      // ← add this line
    // ... rest of build unchanged
  }
}
```

This keeps the widget tree alive in memory when you switch tabs, so switching back is instant. `StatefulShellRoute.indexedStack` already supports this.

---

### Technique 2 — `RepaintBoundary` around expensive widgets

**Problem:** When any part of the screen repaints (e.g., the notification badge updates), Flutter repaints everything in the same repaint layer.

**Fix:** Wrap `PostCard` and the map marker cluster in `RepaintBoundary` to isolate their repaints from the rest of the screen:

```dart
// In PostsScreen SliverList:
child: RepaintBoundary(
  child: PostCard(post: posts.feedPosts[i]),
),

// In MapScreen around the FlutterMap:
RepaintBoundary(
  child: FlutterMap(...),
),
```

Flutter then only re-rasterizes what's inside the boundary, not the whole screen.

---

### Technique 3 — `ValueKey` on list items for efficient diffing

**Problem:** When a new post is prepended to the feed (after `createPost`), Flutter doesn't know which items moved — it rebuilds all of them.

**Fix:** Add a `ValueKey` based on `postId` to each list item:

```dart
SliverChildBuilderDelegate(
  (context, i) => Padding(
    key: ValueKey(posts.feedPosts[i].postId),   // ← add this
    padding: const EdgeInsets.only(bottom: 12),
    child: PostCard(post: posts.feedPosts[i]),
  ),
  childCount: posts.feedPosts.length,
),
```

Flutter's element diffing algorithm uses the key to match old and new items, so only genuinely new or changed items are rebuilt.

---

### Technique 4 — `compute()` for heavy filtering

**Problem:** `_getFilteredPosts` in `MapScreen` runs on the main UI thread. With 300 posts and distance calculations for each, this can block a frame.

**Fix:** Move it to an isolate with `compute()`:

```dart
// Define a top-level or static function (compute requires this):
List<PostModel> _filterPostsIsolate(_FilterParams params) {
  return params.posts.where((p) {
    final matchSearch = params.query.isEmpty || ...;
    final matchCat = ...;
    return matchSearch && matchCat && p.lat != 0;
  }).toList();
}

// In MapScreen build():
FutureBuilder<List<PostModel>>(
  future: compute(_filterPostsIsolate, _FilterParams(posts: allPosts, query: _searchCtrl.text, ...)),
  builder: (context, snap) {
    final filtered = snap.data ?? [];
    ...
  },
)
```

Note: only worth adding compute() once the posts list exceeds ~100. For now, the bigger wins are Problems 1–7.

---

### Technique 5 — Debounce map search to stop per-keystroke rebuilds

**Problem:** `_searchCtrl.onChanged` calls `setState()` on every single keystroke, which rebuilds the entire map screen including recalculating all markers.

**Fix:** Add a 300ms debounce:

```dart
Timer? _searchDebounce;

// In initState:
_searchCtrl.addListener(() {
  _searchDebounce?.cancel();
  _searchDebounce = Timer(const Duration(milliseconds: 300), () {
    if (mounted) setState(() => _showSuggestions = _searchCtrl.text.isNotEmpty);
  });
});

// Remove the onChanged lambda from the TextField
```

---

### Technique 6 — `MediaQuery.sizeOf(context)` instead of `MediaQuery.of(context)`

**Problem:** `MediaQuery.of(context)` subscribes to ALL media changes — keyboard appearing, brightness change, text scale change. If the keyboard shows up (in a TextField), every widget that called `MediaQuery.of(context)` rebuilds.

In `ConversationScreen`:
```dart
// CURRENT — rebuilds on keyboard show/hide, brightness changes, etc.
maxWidth: MediaQuery.of(context).size.width * 0.72,

// FIX — only rebuilds on size changes
maxWidth: MediaQuery.sizeOf(context).width * 0.72,
```

---

### Technique 7 — `CacheExtent` tuning on the feed scroll view

**Problem:** By default, Flutter pre-renders ~250px outside the visible area. For a feed with large images, this means 1–2 extra cards are always being rendered below the fold.

**Fix:** Increase cache extent slightly so images are already loaded before the user scrolls to them, reducing the "pop-in" effect:

```dart
CustomScrollView(
  controller: _scrollCtrl,
  cacheExtent: 500,   // pre-render 500px outside viewport (default is 250)
  slivers: [...],
)
```

---

### Technique 8 — Lazy-load post images with fade-in placeholder

**Problem:** `CachedNetworkImage` currently uses a solid color placeholder. On slow connections the placeholder is visible for a long time and the transition to the loaded image is jarring.

**Fix:** Use `fadeInDuration` and a shimmer placeholder for a polished feel:

```dart
CachedNetworkImage(
  imageUrl: post.imageUrl,
  height: 200,
  width: double.infinity,
  fit: BoxFit.cover,
  fadeInDuration: const Duration(milliseconds: 200),
  placeholder: (_, __) => Shimmer.fromColors(
    baseColor: Theme.of(context).colorScheme.surfaceContainerHighest,
    highlightColor: Theme.of(context).colorScheme.surface,
    child: Container(height: 200, color: Colors.white),
  ),
  errorWidget: (_, __, ___) => Container(
    height: 200,
    color: Theme.of(context).colorScheme.surfaceContainerHighest,
    child: const Icon(Icons.image_outlined, color: kMutedFg),
  ),
),
```

---

### Technique 9 — `flutter_native_splash` for a professional startup

**Problem:** The app shows a blank white screen during Firebase initialization before the splash screen renders.

**Fix:** Add the `flutter_native_splash` package so the splash is shown immediately from the native layer, before Flutter even boots:

```yaml
# pubspec.yaml dev_dependencies:
flutter_native_splash: ^2.4.0
```

```yaml
# pubspec.yaml (top level):
flutter_native_splash:
  color: "#1A1A2E"
  image: assets/images/logo.png
  android_12:
    color: "#1A1A2E"
    image: assets/images/logo.png
```

```bash
dart run flutter_native_splash:create
```

---

### Technique 10 — `flutter build apk --split-per-abi` + ProGuard

Enable R8 minification for a smaller, faster APK. Add to `android/app/build.gradle.kts`:

```kotlin
buildTypes {
    release {
        isMinifyEnabled = true
        isShrinkResources = true
        proguardFiles(
            getDefaultProguardFile("proguard-android-optimize.txt"),
            "proguard-rules.pro"
        )
    }
}
```

Create `android/app/proguard-rules.pro`:
```
# Firebase
-keep class com.google.firebase.** { *; }
-keep class com.google.android.gms.** { *; }
# Flutter
-keep class io.flutter.** { *; }
# Cloudinary
-keep class com.cloudinary.** { *; }
```

---

## 5. APK Release Checklist

Everything needed to build and distribute a test APK that works reliably on any Android device.

---

### Step 1 — Change the app ID (Required)
**File:** `android/app/build.gradle.kts` line ~14

```kotlin
// CURRENT
applicationId = "com.example.like_a_local"

// CHANGE TO
applicationId = "com.likealocal.app"
```

Also update `userAgentPackageName` in `map_screen.dart` to match.

---

### Step 2 — Create a release signing keystore (Required for distribution)

Run this once (save the keystore file and the password somewhere safe):
```bash
keytool -genkey -v \
  -keystore android/app/likealocal-release.jks \
  -keyalg RSA -keysize 2048 -validity 10000 \
  -alias likealocal \
  -storepass YOUR_STORE_PASS \
  -keypass YOUR_KEY_PASS \
  -dname "CN=LikeALocal, O=LikeALocal, C=EG"
```

Add to `android/app/build.gradle.kts`:
```kotlin
android {
    signingConfigs {
        create("release") {
            storeFile = file("likealocal-release.jks")
            storePassword = System.getenv("STORE_PASS") ?: "YOUR_STORE_PASS"
            keyAlias = "likealocal"
            keyPassword = System.getenv("KEY_PASS") ?: "YOUR_KEY_PASS"
        }
    }
    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("release")
        }
    }
}
```

---

### Step 3 — Add the `google.navigation` intent query (Maps fix)
**File:** `android/app/src/main/AndroidManifest.xml`

Add inside the existing `<queries>` block:
```xml
<queries>
  <!-- existing entries -->
  <intent>
    <action android:name="android.intent.action.VIEW" />
    <data android:scheme="google.navigation" />
  </intent>
  <intent>
    <action android:name="android.intent.action.VIEW" />
    <data android:scheme="geo" />
  </intent>
</queries>
```

---

### Step 4 — Build the release APK

```bash
# Build split APKs (smaller, recommended for sharing)
flutter build apk --release --split-per-abi

# Output files:
# build/app/outputs/flutter-apk/app-arm64-v8a-release.apk  ← share this one (covers 95%+ of phones)
# build/app/outputs/flutter-apk/app-armeabi-v7a-release.apk
# build/app/outputs/flutter-apk/app-x86_64-release.apk
```

---

### Step 5 — Firebase configuration for testers

Testers need to be added to your Firebase project's **Authentication** allowed users (if using email/password). For broader testing use **Firebase App Distribution**:

```bash
# Install Firebase CLI if not already
npm install -g firebase-tools
firebase login

# Distribute to testers
firebase appdistribution:distribute \
  build/app/outputs/flutter-apk/app-arm64-v8a-release.apk \
  --app YOUR_FIREBASE_APP_ID \
  --testers "tester1@email.com,tester2@email.com" \
  --release-notes "First test build"
```

---

### Step 6 — Connectivity & services checklist

| Service | Works offline? | Required for APK? | Notes |
|---|---|---|---|
| Firebase Auth | No | Yes | Needs internet for first login |
| Firestore | Yes (cached) | Yes | Offline persistence already enabled |
| FCM Notifications | No | Yes | Needs Google Play Services |
| Map tiles (OSM) | After first load | Yes | Tiles cached in memory per session; add disk cache for true offline |
| Map tiles (Stadia dark) | No | No | Falls back to OSM |
| AI Chat | No | No | Needs OpenRouter internet access |
| Image upload (Cloudinary) | No | No | Needs internet |
| Google Maps Directions | No | No | Opens external app |

---

## 6. Priority Implementation Order

| # | Fix | File(s) | Est. Time | Impact |
|---|---|---|---|---|
| 1 | `context.select` for avatar in PostCard | `post_card.dart:136` | 5 min | 🔴 Eliminates 80% of card rebuilds |
| 2 | Remove inline comment TextField from PostCard | `post_card.dart` bottom | 15 min | 🔴 Fixes scroll jank |
| 3 | Replace `NetworkImage` → `CachedNetworkImageProvider` on avatars | 4 files | 10 min | 🔴 Stops repeated image downloads |
| 4 | Fix `userAgentPackageName` + change app ID | `map_screen.dart`, `build.gradle.kts` | 5 min | 🔴 Fixes map tiles for all users |
| 5 | Add multi-fallback to `launchUrl` for directions | `map_screen.dart` | 10 min | 🔴 Fixes directions on all devices |
| 6 | Move TopBar notification stream to StatefulWidget | `top_bar.dart` | 20 min | 🟠 Fixes stream-per-build |
| 7 | Use `Selector` in PostsScreen + MapScreen | `posts_screen.dart`, `map_screen.dart` | 30 min | 🟠 Scopes rebuild cascades |
| 8 | `ValueNotifier` for GPS position in MapScreen | `map_screen.dart` | 20 min | 🟠 Isolates dot repaints from map |
| 9 | Fix save count check to use local cache | `post_card.dart:548`, `map_screen.dart:1188` | 5 min | 🟠 Removes N Firestore reads |
| 10 | Add `AutomaticKeepAliveClientMixin` to tab screens | 4 screen files | 10 min | 🟠 Instant tab switching |
| 11 | Add tile disk caching to MapScreen | `map_screen.dart` + `pubspec.yaml` | 30 min | 🟠 Map loads offline |
| 12 | `RepaintBoundary` around PostCard + FlutterMap | 2 files | 5 min | 🟡 Isolates expensive repaints |
| 13 | `ValueKey` on feed list items | `posts_screen.dart` | 2 min | 🟡 Efficient list diffing |
| 14 | Debounce map search | `map_screen.dart` | 10 min | 🟡 Removes per-keystroke rebuilds |
| 15 | `MediaQuery.sizeOf` in ConversationScreen | `conversation_screen.dart` | 2 min | 🟡 Avoids keyboard-triggered rebuilds |
| 16 | `CacheExtent` + shimmer placeholders on feed | `posts_screen.dart`, `post_card.dart` | 10 min | 🟡 Smoother scroll & image load |
| 17 | `flutter_native_splash` | `pubspec.yaml` + config | 15 min | 🟡 No blank screen on startup |
| 18 | Create signing keystore + update `build.gradle.kts` | `build.gradle.kts` | 15 min | Required for APK distribution |
| 19 | Add `google.navigation` scheme to `AndroidManifest.xml` | `AndroidManifest.xml` | 2 min | Required for directions on all devices |
| 20 | `flutter build apk --release --split-per-abi` | CLI | 5 min | Produces the shareable APK |

> **Recommended session plan:**
> - **Session 1 (1 hr):** Do items 1–5. These fix the most visible issues.  
> - **Session 2 (1 hr):** Do items 6–11. These fix the map and the remaining provider issues.  
> - **Session 3 (30 min):** Do items 12–17. Polish pass.  
> - **Session 4 (30 min):** Do items 18–20. Ship the APK.
