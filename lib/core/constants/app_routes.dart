class AppRoutes {
  static const String login = '/login';
  static const String feed = '/feed';
  static const String map = '/map';
  static const String create = '/create';
  static const String chat = '/chat';
  static const String search = '/search';
  static const String profile = '/profile';
  static const String notifications = '/notifications';
  static const String saved = '/saved';
  static const String settings = '/settings';
  static const String postDetail = '/post/:postId';
  static const String conversation = '/conversation/:chatId';

  static String postDetailPath(String postId) => '/post/$postId';
  static String conversationPath(String chatId) => '/conversation/$chatId';
}
