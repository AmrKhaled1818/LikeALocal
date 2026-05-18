# LikeALocal

> Discover hidden gems in your city — like a local.

A Flutter social app for sharing favourite local spots (restaurants, cafés, parks, viewpoints), discovering them on a map, chatting with friends, and getting AI-powered recommendations.

---

## Contents

- [What it does](#what-it-does)
- [Tech stack](#tech-stack)
- [Project structure](#project-structure)
- [Getting started](#getting-started)
  1. [Prerequisites](#1-prerequisites)
  2. [Install](#2-install)
  3. [Firebase](#3-firebase)
  4. [API keys](#4-api-keys)
  5. [Cloudinary](#5-cloudinary)
  6. [Run the app](#6-run-the-app)
- [Firestore](#firestore)
- [Routes](#routes)
- [Data models](#data-models)
- [Build & release](#build--release)
- [Troubleshooting](#troubleshooting)

---

## What it does

**Core**
- Post hidden gems with up to 5 photos *or* a video, GPS pin, category, tips, dishes.
- Infinite-scroll feed ranked by **Super User → Vibe Match → recency**.
- Interactive map (flutter_map + Stadia tiles) with marker clustering.
- 1:1 DMs with typing indicators and read receipts.
- AI chat assistant (Groq, Llama 3.3 70B) aware of your preferences, location and feed.

**Smart**
- **Vibe Match** — 0–100% score per post from your mood + saved preferences.
- **Mood selector** — `chill / adventurous / hungry / cultural`, instantly re-ranks the feed.
- **AI Trip Planner** — multi-stop itinerary built from feed candidates.
- **Live crowd indicator** — "Busy right now" / "Liveliest around 6 PM" from check-ins.
- **AI image descriptions** — OpenRouter Nemotron auto-describes uploads.
- **Place grouping** — posts about the same spot are merged with combined reviews.

**Social**
- Email + Google sign-in (Firebase Auth).
- Karma points (post +10, upvote received +2, comment +1, DM +3, check-in +1).
- **Super User** auto-promotion at 100 karma — amber badge, posts pinned, unlimited AI.
- Save posts → background **proximity alert** when you're within 500 m.

---

## Tech stack

| Layer | Tools |
|------|-------|
| **Framework** | Flutter (Dart `^3.5.0`) |
| **State** | `provider` (ChangeNotifier) |
| **Routing** | `go_router` (5-tab `StatefulShellRoute`) |
| **Backend** | Firebase: Auth, Firestore, Storage, Messaging |
| **Maps** | `flutter_map` + Stadia Maps, `geolocator`, `geocoding` |
| **Media** | Cloudinary (`cloudinary_public`) |
| **AI** | Groq (chat, planner), OpenRouter (vision) |
| **Background** | `workmanager` |
| **Local** | `shared_preferences`, `flutter_secure_storage` |

---

## Project structure

```
lib/
├── core/
│   ├── constants/app_config.dart      # All API keys
│   ├── theme/                          # Colors + light/dark themes
│   ├── services/proximity_service.dart # Background geofence
│   └── utils/                          # vibe_score, crowd_utils, trip_planner_util
├── data/
│   ├── models/                         # Post, User, Message, Comment, PlaceGroup
│   ├── repositories/                   # Raw Firestore access
│   ├── services/                       # AI, Vision, Cloudinary, Notifications
│   └── seed_places.dart                # Initial curated places
├── features/                           # One folder per screen
│   └── auth, chat, create, edit, feed, map, profile, search, trip, ...
├── shared/
│   ├── providers/                      # auth, posts, chat, user, theme
│   └── widgets/                        # PostCard, VibeBadge, CrowdBadge, ...
└── main.dart                           # Bootstrap + router
```

**Data flow:** Firestore → Repository → Provider → Widget. Screens never call repos directly.

---

## Getting started

### 1. Prerequisites

- Flutter SDK 3.5+
- Android Studio (SDK 34) **or** Xcode 15+
- A Firebase project
- Free accounts at: [Cloudinary](https://cloudinary.com), [Stadia Maps](https://client.stadiamaps.com), [Groq](https://console.groq.com), [OpenRouter](https://openrouter.ai) *(optional)*

Install the FlutterFire CLI once:
```bash
dart pub global activate flutterfire_cli
npm install -g firebase-tools
```

### 2. Install

```bash
git clone <your-repo-url> likealocal
cd likealocal
flutter pub get
```

### 3. Firebase

To use your own Firebase project:

```bash
firebase login
flutterfire configure
```

This regenerates `lib/firebase_options.dart`, `google-services.json` and `GoogleService-Info.plist`.

In the Firebase console, enable:
- **Authentication** → Email/Password + Google
- **Cloud Firestore** (production mode)
- **Storage**
- **Cloud Messaging**

For Google Sign-In on Android, add your **debug & release SHA-1** fingerprints to Firebase, then re-download `google-services.json`.

### 4. API keys

All keys are read via `String.fromEnvironment` in `lib/core/constants/app_config.dart`. Pass them at run time:

| Variable | Required | Get it from |
|----------|----------|-------------|
| `GROQ_API_KEY` | Yes | https://console.groq.com |
| `STADIA_API_KEY` | Yes | https://client.stadiamaps.com |
| `CLOUDINARY_CLOUD_NAME` | Yes | Cloudinary dashboard |
| `CLOUDINARY_UPLOAD_PRESET` | Yes | Cloudinary → Upload presets |
| `OPENROUTER_API_KEY` | Optional | https://openrouter.ai/keys |

The easiest way is a **`dart_define.json`** file (add it to `.gitignore`):

```json
{
  "GROQ_API_KEY": "gsk_...",
  "STADIA_API_KEY": "...",
  "CLOUDINARY_CLOUD_NAME": "...",
  "CLOUDINARY_UPLOAD_PRESET": "likealocal_unsigned",
  "OPENROUTER_API_KEY": "sk-or-v1-..."
}
```

### 5. Cloudinary

1. Create an account.
2. **Settings → Upload → Add upload preset**.
3. Set **Signing mode** to **Unsigned**, name it `likealocal_unsigned`.
4. Copy your **cloud name** and the **preset name** into your config.

Images are compressed to 1080×1080 (q72) before upload. Up to **5 images OR 1 video** per post.

### 6. Run the app

```bash
flutter run --dart-define-from-file=dart_define.json
```

On first launch:
1. Splash → checks auth state
2. New users → onboarding (4 slides, sets initial mood)
3. Signed in → feed (5-tab shell)

> **WSL users:** run `flutter run` from a **Windows terminal** or Android Studio. ADB device discovery from WSL is unreliable.

---

## Firestore

### Collections

| Path | Stores |
|------|--------|
| `posts/{postId}` | `PostModel` |
| `posts/{postId}/comments/{commentId}` | `CommentModel` |
| `users/{uid}` | `UserModel` |
| `users/{uid}/savedPosts/{postId}` | Saved post refs |
| `chats/{chatId}` | Metadata + typing state |
| `chats/{chatId}/messages/{msgId}` | `MessageModel` |
| `notifications/{uid}/items/{notifId}` | In-app notifications |

AI chats use the prefix `ai_{userId}` for their chatId.

### Starter security rules

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{db}/documents {

    function signedIn() { return request.auth != null; }
    function isUser(uid) { return signedIn() && request.auth.uid == uid; }

    match /users/{uid} {
      allow read: if signedIn();
      allow write: if isUser(uid);
      match /savedPosts/{postId} {
        allow read, write: if isUser(uid);
      }
    }

    match /posts/{postId} {
      allow read: if true;
      allow create: if signedIn() && request.resource.data.userId == request.auth.uid;
      allow update, delete: if signedIn() && (
        resource.data.userId == request.auth.uid ||
        request.resource.data.diff(resource.data).affectedKeys().hasOnly([
          'upvotes','downvotes','upvotedBy','commentCount',
          'checkinsByHour','lastCheckinAt','bestTime'
        ])
      );

      match /comments/{commentId} {
        allow read: if true;
        allow create: if signedIn() && request.resource.data.userId == request.auth.uid;
        allow update, delete: if signedIn() && resource.data.userId == request.auth.uid;
      }
    }

    match /chats/{chatId} {
      allow read, write: if signedIn() && request.auth.uid in resource.data.participants;
      allow create: if signedIn() && request.auth.uid in request.resource.data.participants;

      match /messages/{msgId} {
        allow read, write: if signedIn() &&
          request.auth.uid in get(/databases/$(db)/documents/chats/$(chatId)).data.participants;
      }
    }

    match /notifications/{uid}/items/{notifId} {
      allow read, write: if isUser(uid);
      allow create: if signedIn();
    }
  }
}
```

> Firestore will surface a "create index" link the first time a query needs one — click it.

---

## Routes

5-tab shell + top-level routes:

| Route | Screen |
|-------|--------|
| `/splash` | SplashScreen |
| `/onboarding` | Onboarding (4 slides) |
| `/login` | Email + Google |
| `/feed` *(tab 0)* | Ranked feed |
| `/map` *(tab 1)* | Map view |
| `/create` *(tab 2)* | New post |
| `/chat` *(tab 3)* | DM list |
| `/search` *(tab 4)* | Posts + Places |
| `/post/:postId` | Post detail |
| `/conversation/:chatId` | DM or AI chat |
| `/profile` | Profile |
| `/notifications` | Notifications |
| `/saved` | Saved posts |
| `/leaderboard` | Karma leaderboard |
| `/trip` | Trip planner |
| `/settings`, `/faq` | Misc |

---

## Data models

**PostModel** — `title`, `description`, `localTips`, `recommendedDishes[]`, `imageUrls[]` *(up to 5)* or `videoUrl`, `location`, `lat/lng`, `category`, `upvotes`, `downvotes`, `commentCount`, `checkinsByHour`, `bestTime`, `aiSummary`.

**UserModel** — `username`, `avatarUrl`, `bio`, `karma`, `isSuperUser`, `preferences{ budget, atmosphere, favCategories[] }`, `fcmToken`.

**MessageModel** — `senderId` *(`'ai'` for assistant)*, `text`, `type`, `readBy[]`, `createdAt`.

**CommentModel** — `content`, `parentId` *(null = top-level, set = reply)*, `editedAt`.

**Categories:** Restaurant, Café, Mall, Park, Cultural, Viewpoint, Shop.

---

## Build & release

```bash
flutter analyze            # lint
flutter test               # all tests
flutter build apk          # debug Android
flutter build apk --release --dart-define-from-file=dart_define.json
flutter build ios --release --dart-define-from-file=dart_define.json
```

Before publishing:
1. Generate a release keystore.
2. Add `signingConfigs` in `android/app/build.gradle.kts`.
3. Add release SHA-1 to Firebase.
4. Rotate any keys committed during development.

Android notes:
- `minSdk = 23` (required by workmanager)
- Java 17 + core library desugaring
- `ACCESS_BACKGROUND_LOCATION` declared for proximity scans

---

## Troubleshooting

| Problem | Fix |
|---------|-----|
| Build fails on minSdk | Must be `23` — workmanager requires it |
| Map tiles are grey | Bad / rate-limited Stadia key |
| AI returns 401 | Bad Groq key — verify at console.groq.com |
| AI vision missing | OpenRouter key missing or model throttled |
| "Daily AI limit" | 20 msgs / 24h; clearing chat doesn't reset; unlimited at 100 karma |
| Google Sign-In `ApiException: 10` | Missing SHA-1 in Firebase or stale `google-services.json` |
| Proximity alerts silent | Grant background location + disable battery optimisation |
| Duplicate `GlobalKey` crash | Router must live in `initState`, not `build` |
| Firestore permission denied | Check rules; ensure user doc exists |
| `MissingPluginException` | `flutter clean && flutter pub get`, rebuild |

---

## Project rules

- All API keys in `lib/core/constants/app_config.dart`.
- All Firebase calls wrapped in `try/catch`; errors via SnackBar/toast, never `print`.
- Auth errors mapped to friendly messages.
- Screens go through providers, never repos directly.
- "Get Directions" uses **text query**, not raw lat/lng — pinned coords are approximate.
- `flutter analyze` clean before every commit.

---

## License

Private / unpublished.
