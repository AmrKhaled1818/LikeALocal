class AppConfig {
  // Centralized runtime config.
  // Fill in your own keys here, or pass via --dart-define at run/build time.
  // Example: flutter run --dart-define=GROQ_API_KEY=gsk_...

  // Groq (OpenAI-compatible) — AI chat, trip planning, place tips, tagging.
  static const String groqApiKey = String.fromEnvironment(
    'GROQ_API_KEY',
    defaultValue: 'YOUR_GROQ_API_KEY_HERE',
  );

  /// High-quality model for conversational + generative work
  /// (chatbot, trip planner, place tips).
  static const String groqPrimaryModel = String.fromEnvironment(
    'GROQ_PRIMARY_MODEL',
    defaultValue: 'llama-3.3-70b-versatile',
  );

  /// Fast/cheap model for structured + lightweight work (tagging, vibe parsing).
  /// Also used as the retry target when the primary model returns HTTP 429.
  static const String groqFallbackModel = String.fromEnvironment(
    'GROQ_FALLBACK_MODEL',
    defaultValue: 'llama-3.1-8b-instant',
  );

  static const String groqBaseUrl = String.fromEnvironment(
    'GROQ_BASE_URL',
    defaultValue: 'https://api.groq.com/openai/v1',
  );

  // Maps
  static const String stadiaApiKey = String.fromEnvironment(
    'STADIA_API_KEY',
    defaultValue: 'YOUR_STADIA_MAPS_API_KEY_HERE',
  );

  // Cloudinary
  static const String cloudinaryCloudName = String.fromEnvironment(
    'CLOUDINARY_CLOUD_NAME',
    defaultValue: 'YOUR_CLOUDINARY_CLOUD_NAME',
  );
  static const String cloudinaryUploadPreset = String.fromEnvironment(
    'CLOUDINARY_UPLOAD_PRESET',
    defaultValue: 'YOUR_CLOUDINARY_UPLOAD_PRESET',
  );

  // Gemini — used by VisionService to auto-describe post images via Google AI Studio.
  // Get a key at https://aistudio.google.com/app/apikey
  static const String geminiApiKey = String.fromEnvironment(
    'GEMINI_API_KEY',
    defaultValue: 'YOUR_GEMINI_API_KEY_HERE',
  );

  static const String geminiVisionModel = String.fromEnvironment(
    'GEMINI_VISION_MODEL',
    defaultValue: 'gemini-2.5-flash',
  );

  static bool get hasAiKey => groqApiKey.isNotEmpty && groqApiKey != 'YOUR_GROQ_API_KEY_HERE';
  static bool get hasVisionKey => geminiApiKey.isNotEmpty && geminiApiKey != 'YOUR_GEMINI_API_KEY_HERE';
}
