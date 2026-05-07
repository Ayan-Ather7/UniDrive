import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../theme/app_theme.dart';
import '../widgets/unidrive_logo.dart';
import '../services/auth_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _obscure = true;
  bool _loading = false;
  String? _emailError;
  String? _passError;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  bool _validateEmail(String value) {
    final pattern = RegExp(
        r'^[\w.+-]+@[\w-]+(\.[\w-]+)*\.edu(\.pk)?$',
        caseSensitive: false);
    return pattern.hasMatch(value.trim());
  }

  Future<void> _showForgotPassword() async {
    final emailCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor:
            Theme.of(context).brightness == Brightness.dark
                ? AppColors.darkCard
                : Colors.white,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Reset Password',
          style: GoogleFonts.plusJakartaSans(
              fontWeight: FontWeight.w800, fontSize: 18),
        ),
        content: Form(
          key: formKey,
          child: TextFormField(
            controller: emailCtrl,
            keyboardType: TextInputType.emailAddress,
            decoration: InputDecoration(
              hintText: 'name@university.edu.pk',
              prefixIcon:
                  const Icon(Icons.alternate_email_rounded, size: 20),
            ),
            validator: (v) {
              if (v == null || v.trim().isEmpty) {
                return 'Please enter your email';
              }
              return null;
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel',
                style: GoogleFonts.plusJakartaSans(
                    color: AppColors.textMuted,
                    fontWeight: FontWeight.w600)),
          ),
          ElevatedButton(
            onPressed: () async {
              if (!formKey.currentState!.validate()) return;
              Navigator.pop(ctx);
              try {
                await FirebaseAuth.instance
                    .sendPasswordResetEmail(
                        email: emailCtrl.text.trim());
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                        'Password reset email sent! Check your inbox.',
                        style: GoogleFonts.plusJakartaSans(
                            fontWeight: FontWeight.w600)),
                    backgroundColor: AppColors.success,
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              } catch (e) {
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Error: ${e.toString()}',
                        style: GoogleFonts.plusJakartaSans(
                            fontWeight: FontWeight.w600)),
                    backgroundColor: AppColors.maroon,
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            },
            child: Text('Send Reset Link',
                style: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  Future<void> _signIn() async {
    final email = _emailCtrl.text.trim();
    final pass = _passCtrl.text;

    setState(() {
      _emailError = email.isEmpty
          ? 'Please enter your university email'
          : !_validateEmail(email)
              ? 'Must be a valid university email (e.g. name@uni.edu.pk or name@uni.edu)'
              : null;
      _passError = pass.isEmpty ? 'Please enter your password' : null;
    });

    if (_emailError != null || _passError != null) return;

    setState(() => _loading = true);
    
    try {
      await AuthService().login(email: email, password: pass);
      if (!mounted) return;
      setState(() => _loading = false);
      Navigator.pushNamedAndRemoveUntil(context, '/home', (r) => false);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _passError = 'Login failed. Please check your credentials.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? AppColors.darkCard : Colors.white;
    final textColor =
        isDark ? AppColors.textPrimaryDark : AppColors.textPrimary;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBg : AppColors.lightBg,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              // Top buffer — pushes logo toward center
              const SizedBox(height: 100),

              // Header
              const UniDriveLogo(
                size: LogoSize.md,
              ).animate().fadeIn(duration: 500.ms).slideY(begin: -0.2),
              const SizedBox(height: 6),
              Text(
                'THE PROFESSIONAL STUDENT NETWORK',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textMuted,
                  letterSpacing: 2.5,
                ),
              ).animate().fadeIn(delay: 200.ms),
              // Large gap between heading and first form field
              const SizedBox(height: 50),

              // Card
              Container(
                    padding: const EdgeInsets.all(28),
                    decoration: BoxDecoration(
                      color: cardColor,
                      borderRadius: BorderRadius.circular(28),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.2),
                          blurRadius: 24,
                          offset: const Offset(0, 12),
                        ),
                      ],
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.05),
                        width: 1,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _Label('UNIVERSITY EMAIL'),
                        const SizedBox(height: 10),
                        TextField(
                          controller: _emailCtrl,
                          keyboardType: TextInputType.emailAddress,
                          onChanged: (_) => setState(() => _emailError = null),
                          style: TextStyle(
                            color: textColor,
                            fontWeight: FontWeight.w500,
                          ),
                          decoration: InputDecoration(
                            hintText: 'name@university.edu.pk',
                            prefixIcon: const Icon(
                              Icons.alternate_email_rounded,
                              size: 20,
                            ),
                            errorText: _emailError,
                            errorStyle: GoogleFonts.plusJakartaSans(
                              fontSize: 11,
                              color: AppColors.maroonLight,
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: BorderSide(
                                color:
                                    _emailError != null
                                        ? AppColors.maroon
                                        : Colors.transparent,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        _Label('PASSWORD'),
                        const SizedBox(height: 10),
                        TextField(
                          controller: _passCtrl,
                          obscureText: _obscure,
                          onChanged: (_) => setState(() => _passError = null),
                          style: TextStyle(
                            color: textColor,
                            fontWeight: FontWeight.w500,
                          ),
                          decoration: InputDecoration(
                            hintText: '••••••••',
                            prefixIcon: const Icon(
                              Icons.lock_outline_rounded,
                              size: 20,
                            ),
                            errorText: _passError,
                            errorStyle: GoogleFonts.plusJakartaSans(
                              fontSize: 11,
                              color: AppColors.maroonLight,
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: BorderSide(
                                color:
                                    _passError != null
                                        ? AppColors.maroon
                                        : Colors.transparent,
                              ),
                            ),
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscure
                                    ? Icons.visibility_off_outlined
                                    : Icons.visibility_outlined,
                                size: 20,
                              ),
                              onPressed:
                                  () => setState(() => _obscure = !_obscure),
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),

                        // Sign In
                        SizedBox(
                          width: double.infinity,
                          height: 56,
                          child: ElevatedButton.icon(
                            onPressed: _loading ? null : _signIn,
                            icon:
                                _loading
                                    ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                    : const Icon(Icons.login_rounded, size: 20),
                            label: const Text('Sign In'),
                          ),
                        ),
                      ],
                    ),
                  )
                  .animate()
                  .fadeIn(delay: 300.ms)
                  .slideY(begin: 0.1, curve: Curves.easeOutExpo),

              const SizedBox(height: 20),

              // Forgot password
              TextButton(
                onPressed: _showForgotPassword,
                child: Text(
                  'Forgot your password?',
                  style: GoogleFonts.plusJakartaSans(
                    color: AppColors.blue,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
              ).animate().fadeIn(delay: 400.ms),

              const SizedBox(height: 20),

              // Footer: go to register
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'New to UniDrive? ',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 14,
                      color: AppColors.textMuted,
                    ),
                  ),
                  GestureDetector(
                    onTap: () => Navigator.pushNamed(context, '/register'),
                    child: Text(
                      'Create Account',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 14,
                        color: textColor,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ).animate().fadeIn(delay: 500.ms),
            ],
          ),
        ),
      ),
    );
  }
}

class _Label extends StatelessWidget {
  final String text;
  const _Label(this.text);
  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: GoogleFonts.plusJakartaSans(
        fontSize: 11,
        fontWeight: FontWeight.w800,
        color: AppColors.textMuted,
        letterSpacing: 1.5,
      ),
    );
  }
}
