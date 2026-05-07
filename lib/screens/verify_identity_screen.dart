import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../theme/app_theme.dart';
import '../widgets/unidrive_logo.dart';
import '../services/storage_service.dart';
import '../services/auth_service.dart';
import '../services/database_service.dart';

class VerifyIdentityScreen extends StatefulWidget {
  const VerifyIdentityScreen({super.key});
  @override
  State<VerifyIdentityScreen> createState() => _VerifyIdentityScreenState();
}

class _VerifyIdentityScreenState extends State<VerifyIdentityScreen> {
  bool _flashOn = false;
  bool _imageCaptured = false;
  bool _loading = false;
  String? _imagePath;

  Future<void> _pickImage() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.image);
    if (result != null && result.files.single.path != null && mounted) {
      setState(() {
        _imageCaptured = true;
        _imagePath = result.files.single.path;
      });
    }
  }

  Future<void> _verify() async {
    if (!_imageCaptured || _imagePath == null) return;
    setState(() => _loading = true);
    
    try {
      final uid = AuthService().currentUid;
      if (uid != null) {
        final url = await StorageService().uploadStudentId(uid, File(_imagePath!));
        await DatabaseService().updateUserProfile(uid, {'idImageUrl': url});
      }
      
      if (!mounted) return;
      setState(() => _loading = false);
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
    return Scaffold(
      backgroundColor: AppColors.darkBg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: BackButton(color: Colors.white.withValues(alpha: 0.8)),
        centerTitle: true,
        title: const UniDriveLogo(size: LogoSize.sm),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 16),
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppColors.darkSurface.withValues(alpha: 0.5),
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.darkBorder),
            ),
            child: const Icon(Icons.help_outline_rounded,
                color: Colors.white, size: 18),
          )
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
          // Ensures the content can scroll on short screens but fills the
          // full height on tall screens — safe replacement for Spacer/Expanded.
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: IntrinsicHeight(
              child: Column(
                children: [
                  const SizedBox(height: 24),
                  Text('Verify Identity',
                      style: GoogleFonts.plusJakartaSans(
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.5,
                          color: Colors.white)).animate().fadeIn().slideY(begin: -0.1),
                  const SizedBox(height: 12),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 40),
                    child: Text(
                      'Position your student ID card within the frame to begin the high-speed verification process.',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.plusJakartaSans(
                          fontSize: 14, color: AppColors.textMuted, height: 1.5),
                    ),
                  ).animate().fadeIn(delay: 100.ms),
                  const SizedBox(height: 32),

                  // Camera viewfinder — fixed height (safe in ScrollView)
                  SizedBox(
                    height: 220,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 32),
                      child: Stack(
                        fit: StackFit.expand,
                        alignment: Alignment.center,
                        children: [
                          Container(
                            constraints: const BoxConstraints(minHeight: 180),
                            decoration: BoxDecoration(
                              color: AppColors.darkSurface.withValues(alpha: 0.4),
                              borderRadius: BorderRadius.circular(24),
                              border: Border.all(
                                  color: AppColors.darkBorder.withValues(alpha: 0.5)),
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.blue.withValues(alpha: 0.05),
                                  blurRadius: 40,
                                  spreadRadius: 10,
                                )
                              ],
                            ),
                            child: _imageCaptured
                                ? Center(
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(Icons.check_circle_rounded,
                                                color: AppColors.success, size: 60)
                                            .animate()
                                            .scale(
                                                curve: Curves.easeOutBack,
                                                duration: 500.ms),
                                        const SizedBox(height: 16),
                                        Text('ID Captured!',
                                            style: GoogleFonts.plusJakartaSans(
                                                color: AppColors.success,
                                                fontWeight: FontWeight.w700,
                                                fontSize: 18)),
                                      ],
                                    ),
                                  )
                                : Center(
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.credit_card_rounded,
                                            size: 80,
                                            color: AppColors.textMuted
                                                .withValues(alpha: 0.2)),
                                        const SizedBox(height: 16),
                                        Text('Place ID card here',
                                            style: GoogleFonts.plusJakartaSans(
                                                color: AppColors.textMuted,
                                                fontSize: 13,
                                                fontWeight: FontWeight.w600)),
                                      ],
                                    ),
                                  ),
                          ),
                          // Corner brackets
                          ..._buildCorners(),
                          // Blue scan line
                          if (!_imageCaptured)
                            const Positioned(
                              left: 0,
                              right: 0,
                              top: 100,
                              child: Divider(
                                  color: AppColors.cyan, thickness: 2, height: 2),
                            )
                                .animate(onPlay: (c) => c.repeat(reverse: true))
                                .moveY(
                                    begin: -80,
                                    end: 80,
                                    duration: 2.seconds,
                                    curve: Curves.easeInOutSine),
                        ],
                      ),
                    ).animate().fadeIn(delay: 200.ms).scale(
                        begin: const Offset(0.95, 0.95)),
                  ),

                  const SizedBox(height: 32),

                  // Action buttons
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _ActionBtn(
                        icon: Icons.image_outlined,
                        label: 'UPLOAD',
                        onTap: _pickImage,
                      ),
                      const SizedBox(width: 32),
                      // Camera (primary)
                      GestureDetector(
                        onTap: () async {
                          final result = await FilePicker.platform
                              .pickFiles(type: FileType.image);
                          if (result != null && result.files.single.path != null && mounted) {
                            setState(() {
                              _imageCaptured = true;
                              _imagePath = result.files.single.path;
                            });
                          }
                        },
                        child: Container(
                          width: 76,
                          height: 76,
                          decoration: BoxDecoration(
                              color: AppColors.blue,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.blue.withValues(alpha: 0.3),
                                  blurRadius: 20,
                                  offset: const Offset(0, 8),
                                )
                              ]),
                          child: const Icon(Icons.camera_alt_rounded,
                              color: Colors.white, size: 32),
                        )
                            .animate(onPlay: (c) => c.repeat(reverse: true))
                            .scale(
                                begin: const Offset(1, 1),
                                end: const Offset(1.05, 1.05),
                                duration: 2.seconds),
                      ),
                      const SizedBox(width: 32),
                      _ActionBtn(
                        icon: _flashOn
                            ? Icons.flash_on_rounded
                            : Icons.flash_off_rounded,
                        label: 'FLASH',
                        onTap: () => setState(() => _flashOn = !_flashOn),
                        active: _flashOn,
                      ),
                    ],
                  ).animate().fadeIn(delay: 300.ms).slideY(begin: 0.1),

                  const SizedBox(height: 28),

                  // Verify button
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton(
                        onPressed: _loading ? null : _verify,
                        child: _loading
                            ? const CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white)
                            : Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text('VERIFY IDENTITY',
                                      style: GoogleFonts.plusJakartaSans(
                                          fontWeight: FontWeight.w800,
                                          fontSize: 15,
                                          letterSpacing: 1.5)),
                                  const SizedBox(width: 12),
                                  const Icon(Icons.arrow_forward_rounded,
                                      size: 20),
                                ],
                              ),
                      ),
                    ),
                  ).animate().fadeIn(delay: 400.ms).slideY(begin: 0.1),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _buildCorners() {
    const len = 32.0;
    const thick = 4.0;
    const rad = 8.0;
    return [
      Positioned(
          top: -2, left: -2,
          child: _Corner(len: len, thick: thick, rad: rad, top: true, left: true)),
      Positioned(
          top: -2, right: -2,
          child: _Corner(len: len, thick: thick, rad: rad, top: true, left: false)),
      Positioned(
          bottom: -2, left: -2,
          child: _Corner(len: len, thick: thick, rad: rad, top: false, left: true)),
      Positioned(
          bottom: -2, right: -2,
          child: _Corner(len: len, thick: thick, rad: rad, top: false, left: false)),
    ];
  }
}

class _Corner extends StatelessWidget {
  final double len, thick, rad;
  final bool top, left;
  const _Corner(
      {required this.len,
      required this.thick,
      required this.rad,
      required this.top,
      required this.left});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: len,
      height: len,
      child: CustomPaint(
        painter: _CornerPainter(top: top, left: left, thick: thick, rad: rad),
      ),
    );
  }
}

class _CornerPainter extends CustomPainter {
  final bool top, left;
  final double thick, rad;
  const _CornerPainter(
      {required this.top, required this.left, required this.thick, required this.rad});
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.cyan
      ..strokeWidth = thick
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    final path = Path();
    final x = left ? 0.0 : size.width;
    final y = top ? 0.0 : size.height;
    final dx = left ? size.width : -size.width;
    final dy = top ? size.height : -size.height;
    path.moveTo(x, y + dy * 0.6);
    path.lineTo(x, y);
    path.lineTo(x + dx * 0.6, y);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_) => false;
}

class _ActionBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool active;
  const _ActionBtn(
      {required this.icon,
      required this.label,
      required this.onTap,
      this.active = false});
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: active
                  ? AppColors.blue.withValues(alpha: 0.2)
                  : AppColors.darkSurface.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                  color: active ? AppColors.blue : AppColors.darkBorder.withValues(alpha: 0.5)),
            ),
            child: Icon(icon,
                color: active ? AppColors.blue : Colors.white.withValues(alpha: 0.8), size: 24),
          ),
          const SizedBox(height: 8),
          Text(label,
              style: GoogleFonts.plusJakartaSans(
                  color: AppColors.textMuted,
                  fontSize: 11,
                  fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}
