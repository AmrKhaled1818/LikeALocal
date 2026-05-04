class Validators {
  static String? validateEmail(String? val) {
    if (val == null || val.isEmpty) return 'Email is required';
    if (!val.contains('@') || !val.contains('.')) return 'Enter a valid email';
    return null;
  }

  static String? validatePassword(String? val) {
    if (val == null || val.isEmpty) return 'Password is required';
    if (val.length < 6) return 'Password must be at least 6 characters';
    return null;
  }

  static String? validateUsername(String? val) {
    if (val == null || val.isEmpty) return 'Username is required';
    if (val.length < 3) return 'Username must be at least 3 characters';
    if (val.contains(' ')) return 'Username cannot contain spaces';
    return null;
  }

  static String? validateNotEmpty(String? val, String fieldName) {
    if (val == null || val.trim().isEmpty) return '$fieldName is required';
    return null;
  }
}
