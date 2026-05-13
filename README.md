# LikeALocal

**LikeALocal** is a Flutter social app where users discover and share hidden gem locations — restaurants, cafés, parks, viewpoints, and more — through a live map, social feed, AI recommendations, and direct messaging.

---

## Features

| Feature | Description |
|---|---|
| **Social Feed** | Infinite-scroll feed of hidden gem posts with upvote/downvote, comments, and saves |
| **Interactive Map** | Live map of all posts with marker clustering, category filters, distance filter, and GPS navigation |
| **Create & Edit Posts** | Post up to 5 photos, pick a map location, choose a category, and add local tips |
| **Search & Discovery** | Full-text search across posts; Places tab groups posts about the same real-world spot |
| **AI Assistant** | Chat with an AI that knows every post in the app and your preferences (20 msgs/day free) |
| **Direct Messaging** | Real-time DM with any user; unread badge counts |
| **User Profiles** | Avatar, bio, karma score, post history, and SuperUser badge for top contributors |
| **Saved Posts** | Bookmark spots for later |
| **Notifications** | Push (FCM) + local notifications for upvotes and messages |
| **Preference Quiz** | Onboarding quiz that personalises AI recommendations |
| **Dark / Light Mode** | System-aware theme with manual override |
| **Offline Support** | Firestore persistence keeps the feed readable without a connection |

---

## Tech Stack

| Layer | Technology |
|---|---|
| Framework | Flutter 3.5+ / Dart |
| State Management | Provider (ChangeNotifier) |
| Navigation | GoRouter |
| Backend | Firebase (Auth · Firestore · Cloud Messaging) |
| Image Hosting | Cloudinary (unsigned upload preset) |
| Maps | flutter_map + OpenStreetMap tiles + Stadia Maps (dark mode) |
| Location | geolocator + geocoding |
| AI | OpenRouter API (OpenAI-compatible) |
| Notifications | flutter_local_notifications + FCM |

---

## Download & Try (Android APK)

A pre-built release APK is available on the [**GitHub Releases**](https://github.com/AmrKhaled1818/LikeALocal/releases) page.

### Steps

1. Go to [Releases](https://github.com/AmrKhaled1818/LikeALocal/releases) and download the latest `app-release.apk`.
2. On your Android device open **Settings → Security** and enable **Install unknown apps** for your browser or Files app.
3. Open the downloaded APK and tap **Install**.
4. Launch **LikeALocal**, create an account or sign in with Google, and start exploring.

> The APK uses shared Firebase + Cloudinary + OpenRouter back-ends, so everything works out of the box — no API key setup required.

---

## Run From Source (with your own keys)

### Prerequisites

- Flutter SDK ≥ 3.5 ([install guide](https://docs.flutter.dev/get-started/install))
- Android Studio or VS Code with Flutter/Dart extensions
- A Firebase project (free Spark plan is enough)
- A Cloudinary account (free tier)
- An OpenRouter account for the AI feature (free models available)
- A Stadia Maps API key for dark-mode map tiles (free tier available — light tiles use OpenStreetMap and need no key)

### 1 — Clone

```bash
git clone https://github.com/AmrKhaled1818/LikeALocal.git
cd LikeALocal
```

### 2 — Firebase setup

1. Create a Firebase project at [console.firebase.google.com](https://console.firebase.google.com).
2. Add an **Android app** (package name: `com.likealocal.app`).
3. Download `google-services.json` and place it at `android/app/google-services.json`.
4. Enable **Email/Password** and **Google** sign-in in Authentication.
5. Create a **Firestore** database in production mode.
6. Install the FlutterFire CLI and run:

```bash
dart pub global activate flutterfire_cli
flutterfire configure
```

This regenerates `lib/firebase_options.dart` for your project.

### 3 — Create your API config file

Create `lib/core/constants/app_config.dart` (this file is gitignored — never commit it):

```dart
class AppConfig {
  // OpenRouter (AI chat) — https://openrouter.ai
  static const openRouterApiKey  = 'sk-or-v1-YOUR_KEY';
  static const openRouterModel   = 'openai/gpt-4o-mini';          // or any free model
  static const openRouterBaseUrl = 'https://openrouter.ai/api/v1';

  // Stadia Maps (dark-mode tiles) — https://stadiamaps.com
  // Light-mode tiles use OpenStreetMap and need no key.
  static const stadiaMapsApiKey  = 'YOUR_STADIA_KEY';

  // Cloudinary — https://cloudinary.com
  // Create an unsigned upload preset named "likealocal_unsigned"
  static const cloudinaryCloudName    = 'YOUR_CLOUD_NAME';
  static const cloudinaryUploadPreset = 'likealocal_unsigned';
}
```

### 4 — Install dependencies and run

```bash
flutter pub get
flutter run                  # debug on connected device / emulator
flutter run --release        # release build (requires signing config)
```

### 5 — Build a release APK

Configure signing by creating `android/key.properties` (gitignored):

```
storePassword=YOUR_STORE_PASSWORD
keyPassword=YOUR_KEY_PASSWORD
keyAlias=YOUR_KEY_ALIAS
storeFile=C:\\path\\to\\your.jks
```

Generate a keystore if you don't have one:

```bash
keytool -genkey -v -keystore my-release-key.jks \
  -keyalg RSA -keysize 2048 -validity 10000 \
  -alias my-key-alias
```

Then build:

```bash
flutter build apk --release          # single APK
flutter build apk --split-per-abi    # smaller per-architecture APKs
```

Output is at `build/app/outputs/flutter-apk/app-release.apk`.

---

## Project Structure

```
lib/
├── core/
│   ├── constants/      # app_config.dart (gitignored), other constants
│   ├── theme/          # app_colors.dart, app_theme.dart
│   └── utils/          # validators, responsive layout, toast helpers, map utils
├── data/
│   ├── models/         # PostModel, UserModel, MessageModel, CommentModel, PlaceGroup
│   ├── repositories/   # PostsRepo, AuthRepo, UserRepo, ChatRepo
│   └── services/       # AIService, CloudinaryService, NotificationService
├── features/
│   ├── auth/           # LoginScreen (sign-in + sign-up + Google)
│   ├── chat/           # ChatScreen, ConversationScreen, FriendsSidebar
│   ├── create/         # CreatePostScreen, LocationPickerScreen
│   ├── edit/           # EditPostScreen
│   ├── faq/            # FaqScreen
│   ├── feed/           # PostsScreen, PostDetailScreen
│   ├── map/            # MapScreen
│   ├── notifications/  # NotificationsScreen
│   ├── onboarding/     # OnboardingScreen
│   ├── profile/        # ProfileScreen
│   ├── saved/          # SavedPostsScreen
│   ├── search/         # SearchScreen, PlaceDetailScreen
│   └── settings/       # SettingsScreen, PreferenceQuizScreen
├── shared/
│   ├── providers/      # AuthProvider, PostsProvider, ChatProvider, ThemeProvider, ...
│   └── widgets/        # PostCard, TopBar, BottomNav, ImageViewer, SuperUserBadge, ...
├── firebase_options.dart   # auto-generated (gitignored)
└── main.dart
```

### Data flow

```
Firestore / REST API
      ↓
  Repository        ← raw data access, no business logic
      ↓
  Provider          ← ChangeNotifier, holds state, calls repository
      ↓
  Widget            ← context.watch<Provider>()
```

---

## Firestore Collections

| Collection | Purpose |
|---|---|
| `posts/{postId}` | Post documents |
| `users/{uid}` | User profiles + karma + preferences |
| `chats/{chatId}` | Chat metadata (participants, lastMessage, unreadCount) |
| `chats/{chatId}/messages/{msgId}` | Individual messages |
| `posts/{postId}/comments/{commentId}` | Threaded comments |
| `users/{uid}/savedPosts/{postId}` | Saved post references |
| `notifications/{uid}/items/{notifId}` | In-app notifications |

---

## Karma & SuperUser System

- Every post created: **+10 karma**
- Every message sent: **+3 karma**
- Users with `isSuperUser: true` get an amber badge and bypass the AI daily message limit
- SuperUser status is set manually in Firestore (future: auto-promote at karma ≥ 1000)

---

## Environment Notes

- **WSL users**: run `flutter` commands from a Windows terminal or Android Studio. Connect devices via `adb` on the Windows host.
- **Offline**: Firestore persistence is enabled with unlimited cache — the feed remains readable without internet.
- **AI limit**: tracked in `SharedPreferences` (`ai_count_{uid}`, `ai_reset_{uid}`), not in Firestore. Clearing chat history does not reset the counter.

---

## License

This project is for educational and portfolio purposes.
