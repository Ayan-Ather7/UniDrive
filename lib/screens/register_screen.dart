import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../theme/app_theme.dart';
import '../widgets/unidrive_logo.dart';
import '../services/auth_service.dart';
import '../services/storage_service.dart';
import '../services/database_service.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';

// ─────────────────────────────────────────────────────────────────────────────
// Mock user state — in production this would come from an auth provider.
// Gender is used to gate Pink Ride access: only 'Female' users may see/request
// Pink Ride drivers.
// ─────────────────────────────────────────────────────────────────────────────

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});
  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl          = TextEditingController();
  final _emailCtrl         = TextEditingController();
  final _recoveryEmailCtrl = TextEditingController();
  final _passCtrl          = TextEditingController();
  final _confirmCtrl       = TextEditingController();
  bool _obscure = true;
  bool _loading = false;

  // ── New fields ──────────────────────────────────────────────────────────
  // NOTE: These values will later be cross-referenced and auto-corrected by
  // scanning the University ID Card during the identity verification step.
  String? _selectedGender; // 'Male' | 'Female' | 'Other'
  DateTime? _selectedDob;
  File? _idImage;

  // Inline error flags for custom widgets (Dropdown & DatePicker)
  String? _genderError;
  String? _dobError;
  String? _idImageError;

  static const _genders = ['Male', 'Female', 'Other'];

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _recoveryEmailCtrl.dispose();
    _passCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDob() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime(now.year - 20),
      firstDate: DateTime(1990),
      lastDate: DateTime(now.year - 16),
      helpText: 'DATE OF BIRTH',
      builder:
          (context, child) => Theme(
            data: Theme.of(context).copyWith(
              colorScheme: ColorScheme.dark(
                primary: AppColors.blue,
                onPrimary: Colors.white,
                surface: AppColors.darkCard,
                onSurface: AppColors.textPrimaryDark,
              ),
            ),
            child: child!,
          ),
    );
    if (picked != null) {
      setState(() {
        _selectedDob = picked;
        _dobError = null; // clear error once selected
      });
    }
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery, imageQuality: 70);
    if (picked != null) {
      setState(() {
        _idImage = File(picked.path);
        _idImageError = null;
      });
    }
  }

  /// Validates all fields (including custom Gender & DOB widgets).
  /// Returns true only when every field passes.
  bool _validate() {
    // Validate the Form fields (name, email, password, confirm)
    final formValid = _formKey.currentState?.validate() ?? false;

    // Validate Gender
    final genderValid = _selectedGender != null;
    setState(
      () => _genderError = genderValid ? null : 'Please select your gender',
    );

    // Validate Date of Birth
    final dobValid = _selectedDob != null;
    setState(
      () => _dobError = dobValid ? null : 'Please select your date of birth',
    );

    // Validate ID Image
    final imageValid = _idImage != null;
    setState(
      () => _idImageError = imageValid ? null : 'Please upload your University ID',
    );

    return formValid && genderValid && dobValid && imageValid;
  }

  Future<void> _register() async {
    if (!_validate()) return; // stop if any field is invalid

    setState(() => _loading = true);
    try {
      final credential = await AuthService().registerUser(
        email: _emailCtrl.text,
        password: _passCtrl.text,
        name: _nameCtrl.text,
        gender: _selectedGender!,
        dob: _selectedDob!,
        recoveryEmail: _recoveryEmailCtrl.text,
      );
      
      if (credential?.user != null) {
        final uid = credential!.user!.uid;
        final imageUrl = await StorageService().uploadStudentId(uid, _idImage!);
        await DatabaseService().updateUserProfile(uid, {'idImageUrl': imageUrl});
      }
      if (!mounted) return;
      setState(() => _loading = false);
      // ID upload complete — proceed directly to home; admin verifies asynchronously.
      Navigator.pushNamedAndRemoveUntil(context, '/home', (r) => false);
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceAll('Exception: ', '')),
          backgroundColor: AppColors.maroon,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? AppColors.darkCard : Colors.white;
    final textColor =
        isDark ? AppColors.textPrimaryDark : AppColors.textPrimary;
    final fieldFill = isDark ? AppColors.darkSurface : AppColors.bgGrey;
    final dobLabel =
        _selectedDob != null
            ? '${_selectedDob!.day.toString().padLeft(2, '0')}/${_selectedDob!.month.toString().padLeft(2, '0')}/${_selectedDob!.year}'
            : 'Select your date of birth';

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBg : AppColors.lightBg,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                // Top buffer — pushes logo toward center
                const SizedBox(height: 100),
                const UniDriveLogo(
                  size: LogoSize.md,
                ).animate().fadeIn(duration: 500.ms).slideY(begin: -0.2),
                const SizedBox(height: 6),
                Text(
                  'JOIN THE PROFESSIONAL NETWORK',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textMuted,
                    letterSpacing: 2.5,
                  ),
                ).animate().fadeIn(delay: 200.ms),
                // Large gap between heading and form card
                const SizedBox(height: 50),

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
                          // ── Full Name ──────────────────────────────────────
                          _Label('FULL NAME'),
                          const SizedBox(height: 10),
                          TextFormField(
                            controller: _nameCtrl,
                            style: TextStyle(
                              color: textColor,
                              fontWeight: FontWeight.w500,
                            ),
                            decoration: const InputDecoration(
                              hintText: 'Your full name',
                              prefixIcon: Icon(
                                Icons.person_outline_rounded,
                                size: 20,
                              ),
                            ),
                            validator: (v) {
                              if (v == null || v.trim().isEmpty) {
                                return 'Full name is required';
                              }
                              if (v.trim().length < 3) {
                                return 'Name must be at least 3 characters';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 20),

                          // ── University Email ───────────────────────────────
                          _Label('UNIVERSITY EMAIL'),
                          const SizedBox(height: 10),
                          TextFormField(
                            controller: _emailCtrl,
                            keyboardType: TextInputType.emailAddress,
                            style: TextStyle(
                              color: textColor,
                              fontWeight: FontWeight.w500,
                            ),
                            decoration: const InputDecoration(
                              hintText: 'name@university.edu.pk',
                              prefixIcon: Icon(
                                Icons.alternate_email_rounded,
                                size: 20,
                              ),
                            ),
                            validator: (v) {
                              if (v == null || v.trim().isEmpty) {
                                return 'University email is required';
                              }
                              final email = v.trim().toLowerCase();
                              final isValidUniEmail =
                                  email.endsWith('.edu.pk') || email.endsWith('.edu');
                              if (!email.contains('@') || !isValidUniEmail) {
                                return 'Must be a valid university email (e.g. name@uni.edu.pk or name@uni.edu)';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 20),

                          // ── Recovery Email ──────────────────────────────────
                          _Label('RECOVERY EMAIL'),
                          const SizedBox(height: 6),
                          Text(
                            'Used for password resets — must be a personal email, not your university address.',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 10,
                              color: AppColors.textMuted,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 10),
                          TextFormField(
                            controller: _recoveryEmailCtrl,
                            keyboardType: TextInputType.emailAddress,
                            style: TextStyle(
                              color: textColor,
                              fontWeight: FontWeight.w500,
                            ),
                            decoration: const InputDecoration(
                              hintText: 'yourname@gmail.com',
                              prefixIcon: Icon(
                                Icons.mark_email_read_outlined,
                                size: 20,
                              ),
                            ),
                            validator: (v) {
                              if (v == null || v.trim().isEmpty) {
                                return 'Recovery email is required';
                              }
                              final recovery = v.trim().toLowerCase();
                              if (!recovery.contains('@') ||
                                  !recovery.contains('.')) {
                                return 'Please enter a valid email address';
                              }
                              // Must NOT be a university address
                              if (recovery.endsWith('.edu.pk') ||
                                  recovery.endsWith('.edu')) {
                                return 'Recovery email cannot be a university (.edu) address';
                              }
                              // Cross-field: must differ from the uni email
                              final uniEmail =
                                  _emailCtrl.text.trim().toLowerCase();
                              if (recovery == uniEmail) {
                                return 'Recovery email must be different from your university email';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 20),

                          // ── Gender (will be verified against university ID) ─
                          _Label('GENDER'),
                          const SizedBox(height: 6),
                          Text(
                            '* Will be auto-verified from your University ID Card',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 10,
                              color: AppColors.textMuted,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: fieldFill,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color:
                                    _genderError != null
                                        ? AppColors.maroonLight
                                        : Colors.transparent,
                                width: 1.5,
                              ),
                            ),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<String>(
                                value: _selectedGender,
                                isExpanded: true,
                                hint: Text(
                                  'Select gender',
                                  style: GoogleFonts.plusJakartaSans(
                                    color:
                                        _genderError != null
                                            ? AppColors.maroonLight
                                            : AppColors.textMuted,
                                    fontSize: 14,
                                  ),
                                ),
                                icon: Icon(
                                  Icons.expand_more_rounded,
                                  color:
                                      _genderError != null
                                          ? AppColors.maroonLight
                                          : AppColors.textMuted,
                                ),
                                dropdownColor:
                                    isDark ? AppColors.darkCard : Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                items:
                                    _genders
                                        .map(
                                          (g) => DropdownMenuItem(
                                            value: g,
                                            child: Text(
                                              g,
                                              style:
                                                  GoogleFonts.plusJakartaSans(
                                                    color: textColor,
                                                    fontWeight: FontWeight.w600,
                                                    fontSize: 14,
                                                  ),
                                            ),
                                          ),
                                        )
                                        .toList(),
                                onChanged:
                                    (val) => setState(() {
                                      _selectedGender = val;
                                      _genderError =
                                          null; // clear error on selection
                                    }),
                              ),
                            ),
                          ),
                          if (_genderError != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 6, left: 4),
                              child: Text(
                                _genderError!,
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 12,
                                  color: AppColors.maroonLight,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          const SizedBox(height: 20),

                          // ── Date of Birth (verified against ID) ───────────
                          _Label('DATE OF BIRTH'),
                          const SizedBox(height: 6),
                          Text(
                            '* Will be auto-verified from your University ID Card',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 10,
                              color: AppColors.textMuted,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 10),
                          GestureDetector(
                            onTap: _pickDob,
                            child: Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 15,
                              ),
                              decoration: BoxDecoration(
                                color: fieldFill,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color:
                                      _dobError != null
                                          ? AppColors.maroonLight
                                          : Colors.transparent,
                                  width: 1.5,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.calendar_today_rounded,
                                    size: 18,
                                    color:
                                        _dobError != null
                                            ? AppColors.maroonLight
                                            : _selectedDob != null
                                            ? AppColors.blue
                                            : AppColors.textMuted,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      dobLabel,
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 14,
                                        fontWeight:
                                            _selectedDob != null
                                                ? FontWeight.w600
                                                : FontWeight.w400,
                                        color:
                                            _dobError != null
                                                ? AppColors.maroonLight
                                                : _selectedDob != null
                                                ? textColor
                                                : AppColors.textMuted,
                                      ),
                                    ),
                                  ),
                                  Icon(
                                    Icons.expand_more_rounded,
                                    color:
                                        _dobError != null
                                            ? AppColors.maroonLight
                                            : AppColors.textMuted,
                                    size: 20,
                                  ),
                                ],
                              ),
                            ),
                          ),
                          if (_dobError != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 6, left: 4),
                              child: Text(
                                _dobError!,
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 12,
                                  color: AppColors.maroonLight,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          const SizedBox(height: 20),

                          // ── University ID Image ─────────────────────────────
                          _Label('UNIVERSITY ID CARD'),
                          const SizedBox(height: 10),
                          GestureDetector(
                            onTap: _pickImage,
                            child: Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(vertical: 20),
                              decoration: BoxDecoration(
                                color: fieldFill,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: _idImageError != null
                                      ? AppColors.maroonLight
                                      : _idImage != null
                                          ? AppColors.blue.withValues(alpha: 0.5)
                                          : Colors.transparent,
                                  width: 1.5,
                                ),
                              ),
                              child: Column(
                                children: [
                                  Icon(
                                    _idImage != null ? Icons.check_circle_outline_rounded : Icons.camera_alt_outlined,
                                    size: 28,
                                    color: _idImage != null ? AppColors.blue : AppColors.textMuted,
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    _idImage != null ? 'ID Image Selected' : 'Tap to Upload University ID',
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 13,
                                      fontWeight: _idImage != null ? FontWeight.w700 : FontWeight.w500,
                                      color: _idImage != null ? textColor : AppColors.textMuted,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          if (_idImageError != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 6, left: 4),
                              child: Text(
                                _idImageError!,
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 12,
                                  color: AppColors.maroonLight,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          const SizedBox(height: 20),

                          // ── Password ───────────────────────────────────────
                          _Label('PASSWORD'),
                          const SizedBox(height: 10),
                          TextFormField(
                            controller: _passCtrl,
                            obscureText: _obscure,
                            style: TextStyle(
                              color: textColor,
                              fontWeight: FontWeight.w500,
                            ),
                            decoration: InputDecoration(
                              hintText: 'Min 8 characters',
                              prefixIcon: const Icon(
                                Icons.lock_outline_rounded,
                                size: 20,
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
                            validator: (v) {
                              if (v == null || v.isEmpty) {
                                return 'Password is required';
                              }
                              if (v.length < 8) {
                                return 'Password must be at least 8 characters';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 20),

                          // ── Confirm Password ───────────────────────────────
                          _Label('CONFIRM PASSWORD'),
                          const SizedBox(height: 10),
                          TextFormField(
                            controller: _confirmCtrl,
                            obscureText: true,
                            style: TextStyle(
                              color: textColor,
                              fontWeight: FontWeight.w500,
                            ),
                            decoration: const InputDecoration(
                              hintText: 'Re-enter password',
                              prefixIcon: Icon(Icons.lock_rounded, size: 20),
                            ),
                            validator: (v) {
                              if (v == null || v.isEmpty) {
                                return 'Please confirm your password';
                              }
                              if (v != _passCtrl.text) {
                                return 'Passwords do not match';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 32),

                          // ── CTA ────────────────────────────────────────────
                          SizedBox(
                            width: double.infinity,
                            height: 56,
                            child: ElevatedButton.icon(
                              onPressed: _loading ? null : _register,
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
                                      : const Icon(
                                        Icons.person_add_rounded,
                                        size: 20,
                                      ),
                              label: const Text('Create Account'),
                            ),
                          ),
                        ],
                      ),
                    )
                    .animate()
                    .fadeIn(delay: 300.ms)
                    .slideY(begin: 0.1, curve: Curves.easeOutExpo),

                const SizedBox(height: 32),

                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Already have an account? ',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 14,
                        color: AppColors.textMuted,
                      ),
                    ),
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Text(
                        'Sign In',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 14,
                          color: textColor,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ).animate().fadeIn(delay: 400.ms),
              ],
            ),
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
  Widget build(BuildContext context) => Text(
    text,
    style: GoogleFonts.plusJakartaSans(
      fontSize: 11,
      fontWeight: FontWeight.w800,
      color: AppColors.textMuted,
      letterSpacing: 1.5,
    ),
  );
}
