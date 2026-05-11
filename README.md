# LikeALocal

**LikeALocal** is a Flutter application designed to help users discover hidden gems in their city like a local. 

## 🌟 Features

- **Authentication**: Secure sign-up and login (Email/Password, Google Sign-In) powered by Firebase.
- **Interactive Map**: Explore local spots, view details, and find places near you using customized map integrations.
- **Social Feed**: Keep up to date with new discoveries and trending places in your area.
- **Search & Discovery**: Find users, tags, and specific locations effortlessly.
- **User Profiles**: Manage your personal profile, view your posts, and customize your experience.
- **Chat**: Connect with other locals and share recommendations directly.
- **Save & Organize**: Bookmark your favorite spots for future reference.
- **Notifications**: Stay informed with real-time alerts.
- **Create**: Add and share new hidden gems with the community.

## 🛠 Tech Stack

- **Framework**: [Flutter](https://flutter.dev/) (SDK ^3.5.0)
- **State Management**: [Provider](https://pub.dev/packages/provider)
- **Navigation**: [GoRouter](https://pub.dev/packages/go_router)
- **Backend & Services**: [Firebase](https://firebase.google.com/) (Auth, Firestore, Storage, Messaging)
- **Maps**: [flutter_map](https://pub.dev/packages/flutter_map), [latlong2](https://pub.dev/packages/latlong2)
- **Location**: [geolocator](https://pub.dev/packages/geolocator), [geocoding](https://pub.dev/packages/geocoding)
- **UI & Media**: Cached Network Image, Shimmer, Image Picker

## 📂 Project Structure

This project follows a feature-first architectural pattern, which helps in scaling and maintaining the codebase effectively.

```text
lib/
├── core/           # App-wide constants, theming, and utilities
│   ├── constants/
│   ├── theme/
│   └── utils/
├── data/           # Data layer: Models, Repositories, and Services
│   ├── models/
│   ├── repositories/
│   └── services/
├── features/       # Feature layer: Independent modules
│   ├── auth/
│   ├── chat/
│   ├── create/
│   ├── feed/
│   ├── map/
│   ├── notifications/
│   ├── profile/
│   ├── saved/
│   ├── search/
│   └── settings/
├── shared/         # Shared widgets and global providers
│   ├── providers/
│   └── widgets/
├── firebase_options.dart # Firebase configuration
└── main.dart       # App entry point
```

## 🚀 Getting Started

### Prerequisites

- Flutter SDK (^3.5.0)
- Dart SDK
- Android Studio, VS Code, or your preferred IDE
- A configured Firebase project 

### Installation

1. **Clone the repository:**
   ```bash
   git clone https://github.com/AmrKhaled1818/LikeALocal.git
   cd LikeALocal
   ```

2. **Install dependencies:**
   ```bash
   flutter pub get
   ```

3. **Configure Firebase:**
   Make sure you have connected the app to Firebase. If needed, configure the project using FlutterFire CLI:
   ```bash
   flutterfire configure
   ```

4. **Run the App:**
   ```bash
   flutter run
   ```

### Runtime API Config (Optional Overrides)

The project includes working default config values, so a fresh clone can run with just:

```bash
flutter run
```

If you want to use your own keys/models, pass `--dart-define` values:

```bash
flutter run \
  --dart-define=OPENROUTER_API_KEY=your_key \
  --dart-define=OPENROUTER_MODEL=openai/gpt-oss-20b:free \
  --dart-define=OPENROUTER_BASE_URL=https://openrouter.ai/api/v1 \
  --dart-define=STADIA_API_KEY=your_stadia_key \
  --dart-define=CLOUDINARY_CLOUD_NAME=your_cloud_name \
  --dart-define=CLOUDINARY_UPLOAD_PRESET=your_unsigned_preset
```

## 🤝 Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

---

*For help getting started with Flutter development, view the [online documentation](https://docs.flutter.dev/), which offers tutorials, samples, guidance on mobile development, and a full API reference.*
