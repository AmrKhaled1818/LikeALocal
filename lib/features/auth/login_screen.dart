import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/toast_utils.dart';
import '../../core/utils/validators.dart';
import '../../core/utils/responsive.dart';
import '../../shared/providers/auth_provider.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool _isLogin = true;
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _usernameCtrl = TextEditingController();
  bool _obscurePassword = true;

  bool _rememberMe = false;
  bool _emailTouched = false;
  bool _passwordTouched = false;
  bool _usernameTouched = false;

  String? get _emailError => Validators.validateEmail(_emailCtrl.text);
  String? get _passwordError => Validators.validatePassword(_passwordCtrl.text);
  String? get _usernameError => Validators.validateUsername(_usernameCtrl.text);

  @override
  void initState() {
    super.initState();
    _loadRememberedEmail();
    _emailCtrl.addListener(() {
      if (!_emailTouched && _emailCtrl.text.isNotEmpty) {
        setState(() => _emailTouched = true);
      } else if (_emailTouched) {
        setState(() {});
      }
    });
    _passwordCtrl.addListener(() {
      if (!_passwordTouched && _passwordCtrl.text.isNotEmpty) {
        setState(() => _passwordTouched = true);
      } else if (_passwordTouched) {
        setState(() {});
      }
    });
    _usernameCtrl.addListener(() {
      if (!_usernameTouched && _usernameCtrl.text.isNotEmpty) {
        setState(() => _usernameTouched = true);
      } else if (_usernameTouched) {
        setState(() {});
      }
    });
  }

  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  Future<void> _loadRememberedEmail() async {
    try {
      final savedEmail = await _storage.read(key: 'remembered_email');
      final savedPassword = await _storage.read(key: 'remembered_password');
      if (savedEmail != null && savedEmail.isNotEmpty && mounted) {
        setState(() {
          _emailCtrl.text = savedEmail;
          _rememberMe = true;
          _emailTouched = true;
        });
      }
      if (savedPassword != null && savedPassword.isNotEmpty && mounted) {
        setState(() {
          _passwordCtrl.text = savedPassword;
          _passwordTouched = true;
        });
      }
    } catch (_) {}
  }

  Future<void> _saveRememberedEmail(String email) async {
    try {
      if (_rememberMe) {
        await _storage.write(key: 'remembered_email', value: email);
        await _storage.write(
            key: 'remembered_password', value: _passwordCtrl.text);
      } else {
        await _storage.delete(key: 'remembered_email');
        await _storage.delete(key: 'remembered_password');
      }
    } catch (_) {}
  }

  Widget _validationIcon(bool touched, String? error) {
    if (!touched) return const SizedBox.shrink();
    return Icon(
      error == null ? Icons.check_circle : Icons.cancel,
      color: error == null ? Colors.green : kDestructive,
      size: 20,
    );
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _usernameCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFFFF7F2), Color(0xFFFCE8E0)],
          ),
        ),
        child: SafeArea(
          child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: AppBreakpoints.maxFormWidth),
              child: SingleChildScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                const SizedBox(height: 32),
                // Logo
                SvgPicture.asset(
                  'assets/images/logo.svg',
                  width: 80,
                  height: 80,
                ),
                const SizedBox(height: 20),
                const Text(
                  'LikeALocal',
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: kDark,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Discover hidden gems in your city',
                  style: TextStyle(color: kMutedFg, fontSize: 15),
                ),
                const SizedBox(height: 32),

                // Form Card
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.08),
                        blurRadius: 20,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      // Tab toggle
                      Container(
                        decoration: BoxDecoration(
                          color: kMuted,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: GestureDetector(
                                onTap: () =>
                                    setState(() => _isLogin = true),
                                child: Container(
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 12),
                                  decoration: BoxDecoration(
                                    color: _isLogin ? kDark : Colors.transparent,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    'Log In',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: _isLogin
                                          ? Colors.white
                                          : kMutedFg,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            Expanded(
                              child: GestureDetector(
                                onTap: () =>
                                    setState(() => _isLogin = false),
                                child: Container(
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 12),
                                  decoration: BoxDecoration(
                                    color: !_isLogin
                                        ? kDark
                                        : Colors.transparent,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    'Sign Up',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: !_isLogin
                                          ? Colors.white
                                          : kMutedFg,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),

                      Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Email',
                                style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                    color: kDark)),
                            const SizedBox(height: 6),
                            TextFormField(
                              controller: _emailCtrl,
                              keyboardType: TextInputType.emailAddress,
                              validator: Validators.validateEmail,
                              decoration: InputDecoration(
                                hintText: 'you@example.com',
                                suffixIcon: _validationIcon(
                                    _emailTouched, _emailError),
                              ),
                            ),
                            const SizedBox(height: 14),
                            const Text('Password',
                                style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                    color: kDark)),
                            const SizedBox(height: 6),
                            TextFormField(
                              controller: _passwordCtrl,
                              obscureText: _obscurePassword,
                              validator: Validators.validatePassword,
                              decoration: InputDecoration(
                                hintText: '••••••••',
                                suffixIcon: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    _validationIcon(
                                        _passwordTouched, _passwordError),
                                    IconButton(
                                      icon: Icon(
                                        _obscurePassword
                                            ? Icons.visibility_off_outlined
                                            : Icons.visibility_outlined,
                                        color: kMutedFg,
                                        size: 20,
                                      ),
                                      onPressed: () => setState(() =>
                                          _obscurePassword = !_obscurePassword),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            if (_isLogin) ...[
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  SizedBox(
                                    width: 24,
                                    height: 24,
                                    child: Checkbox(
                                      value: _rememberMe,
                                      activeColor: kOrange,
                                      shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(4)),
                                      onChanged: (v) => setState(
                                          () => _rememberMe = v ?? false),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  const Text('Remember me',
                                      style: TextStyle(
                                          fontSize: 13, color: kDark)),
                                ],
                              ),
                            ],
                            if (!_isLogin) ...[
                              const SizedBox(height: 14),
                              const Text('Username',
                                  style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500,
                                      color: kDark)),
                              const SizedBox(height: 6),
                              TextFormField(
                                controller: _usernameCtrl,
                                validator: Validators.validateUsername,
                                decoration: InputDecoration(
                                  hintText: 'explorer123',
                                  suffixIcon: _validationIcon(
                                      _usernameTouched, _usernameError),
                                ),
                              ),
                            ],
                            const SizedBox(height: 20),
                            Consumer<AuthProvider>(
                              builder: (context, auth, _) {
                                return SizedBox(
                                  width: double.infinity,
                                  child: ElevatedButton(
                                    onPressed: auth.isLoading
                                        ? null
                                        : () => _submit(context, auth),
                                    child: auth.isLoading
                                        ? const SizedBox(
                                            height: 18,
                                            width: 18,
                                            child: CircularProgressIndicator(
                                                color: Colors.white,
                                                strokeWidth: 2),
                                          )
                                        : Text(
                                            _isLogin
                                                ? 'Log In'
                                                : 'Create Account',
                                            style: const TextStyle(fontSize: 15),
                                          ),
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 20),
                      Row(
                        children: const [
                          Expanded(child: Divider()),
                          Padding(
                            padding: EdgeInsets.symmetric(horizontal: 12),
                            child: Text('or',
                                style: TextStyle(color: kMutedFg, fontSize: 13)),
                          ),
                          Expanded(child: Divider()),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Google button
                      Consumer<AuthProvider>(
                        builder: (context, auth, _) => SizedBox(
                          width: double.infinity,
                          child: OutlinedButton(
                            onPressed: auth.isLoading
                                ? null
                                : () => _googleSignIn(context),
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: kMuted),
                              padding:
                                  const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8)),
                            ),
                            child: auth.isLoading
                                ? const SizedBox(
                                    height: 18,
                                    width: 18,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2),
                                  )
                                : Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Image.network(
                                        'https://cdn1.iconfinder.com/data/icons/google-s-logo/150/Google_Icons-09-512.png',
                                        height: 18,
                                        width: 18,
                                        errorBuilder: (_, __, ___) =>
                                            const Icon(Icons.g_mobiledata,
                                                color: kOrange),
                                      ),
                                      const SizedBox(width: 10),
                                      const Text('Continue with Google',
                                          style: TextStyle(
                                              color: kDark, fontSize: 14)),
                                    ],
                                  ),
                          ),
                        ),
                      ),

                      if (_isLogin) ...[
                        const SizedBox(height: 14),
                        TextButton(
                          onPressed: () => _forgotPassword(context),
                          child: const Text('Forgot password?',
                              style: TextStyle(color: kMutedFg, fontSize: 13)),
                        ),
                      ],
                    ],
                  ),
                ),

                const SizedBox(height: 20),
                const Text(
                  'By continuing, you agree to our Terms of Service and Privacy Policy',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: kMutedFg, fontSize: 12),
                ),
              ],
            ),
          ),
        ),
      ),
          ),
        ),
    );
  }

  Future<void> _submit(BuildContext context, AuthProvider auth) async {
    if (!_formKey.currentState!.validate()) return;

    bool success;
    if (_isLogin) {
      await _saveRememberedEmail(_emailCtrl.text.trim());
      success = await auth.signIn(
          _emailCtrl.text.trim(), _passwordCtrl.text);
    } else {
      success = await auth.register(_emailCtrl.text.trim(),
          _passwordCtrl.text, _usernameCtrl.text.trim());
    }

    if (!success && auth.errorMessage != null) {
      AppToast.error(auth.errorMessage!);
    } else if (success) {
      final prefs = await SharedPreferences.getInstance();
      if (!(prefs.getBool('onboarding_seen') ?? false)) {
        if (context.mounted) context.go('/onboarding');
      } else {
        if (context.mounted) context.go('/feed');
      }
    }
  }

  Future<void> _googleSignIn(BuildContext context) async {
    final auth = context.read<AuthProvider>();
    final success = await auth.signInWithGoogle();
    if (!success && auth.errorMessage != null) {
      AppToast.error(auth.errorMessage!);
    } else if (success) {
      final prefs = await SharedPreferences.getInstance();
      if (!(prefs.getBool('onboarding_seen') ?? false)) {
        if (context.mounted) context.go('/onboarding');
      } else {
        if (context.mounted) context.go('/feed');
      }
    }
  }

  Future<void> _forgotPassword(BuildContext context) async {
    if (_emailCtrl.text.trim().isEmpty) {
      AppToast.error('Enter your email above first');
      return;
    }
    final auth = context.read<AuthProvider>();
    final success = await auth.resetPassword(_emailCtrl.text.trim());
    if (success) {
      AppToast.success('Password reset email sent!');
    } else {
      AppToast.error(auth.errorMessage ?? 'Failed to send reset email');
    }
  }
}
