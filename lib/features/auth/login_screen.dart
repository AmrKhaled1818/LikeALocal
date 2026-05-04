import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/validators.dart';
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
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                const SizedBox(height: 32),
                // Logo
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [kOrange, Color(0xFFFF6B9D)],
                    ),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: const Icon(Icons.layers_rounded,
                      color: Colors.white, size: 40),
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
                        color: Colors.black.withOpacity(0.08),
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
                              decoration: const InputDecoration(
                                hintText: 'you@example.com',
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
                                suffixIcon: IconButton(
                                  icon: Icon(
                                    _obscurePassword
                                        ? Icons.visibility_off_outlined
                                        : Icons.visibility_outlined,
                                    color: kMutedFg,
                                    size: 20,
                                  ),
                                  onPressed: () => setState(
                                      () => _obscurePassword = !_obscurePassword),
                                ),
                              ),
                            ),
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
                                decoration: const InputDecoration(
                                  hintText: 'explorer123',
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
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton(
                          onPressed: () => _googleSignIn(context),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: kMuted),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8)),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Image.network(
                                'https://upload.wikimedia.org/wikipedia/commons/thumb/c/c1/Google_%22G%22_logo.svg/768px-Google_%22G%22_logo.svg.png',
                                height: 18,
                                width: 18,
                                errorBuilder: (_, __, ___) => const Icon(
                                    Icons.g_mobiledata,
                                    color: kOrange),
                              ),
                              const SizedBox(width: 10),
                              const Text('Continue with Google',
                                  style:
                                      TextStyle(color: kDark, fontSize: 14)),
                            ],
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
    );
  }

  Future<void> _submit(BuildContext context, AuthProvider auth) async {
    if (!_formKey.currentState!.validate()) return;

    bool success;
    if (_isLogin) {
      success = await auth.signIn(
          _emailCtrl.text.trim(), _passwordCtrl.text);
    } else {
      success = await auth.register(_emailCtrl.text.trim(),
          _passwordCtrl.text, _usernameCtrl.text.trim());
    }

    if (!success && mounted && auth.errorMessage != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(auth.errorMessage!),
          backgroundColor: kDestructive,
        ),
      );
    }
    // GoRouter redirects automatically via auth state
  }

  Future<void> _googleSignIn(BuildContext context) async {
    final auth = context.read<AuthProvider>();
    final success = await auth.signInWithGoogle();
    if (!success && mounted && auth.errorMessage != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(auth.errorMessage!),
          backgroundColor: kDestructive,
        ),
      );
    }
  }

  Future<void> _forgotPassword(BuildContext context) async {
    if (_emailCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Enter your email above first'),
          backgroundColor: kDestructive,
        ),
      );
      return;
    }
    final auth = context.read<AuthProvider>();
    final success = await auth.resetPassword(_emailCtrl.text.trim());
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            success
                ? 'Password reset email sent!'
                : (auth.errorMessage ?? 'Failed to send reset email'),
          ),
          backgroundColor: success ? Colors.green : kDestructive,
        ),
      );
    }
  }
}
