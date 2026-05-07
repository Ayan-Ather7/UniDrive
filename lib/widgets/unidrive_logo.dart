import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

enum LogoSize { sm, md, lg }

/// Inline horizontal logo — icon and text perfectly baseline-aligned.
/// The icon height always equals the rendered text cap-height.
class UniDriveLogo extends StatelessWidget {
  final LogoSize size;
  final bool showText;
  const UniDriveLogo({
    super.key,
    this.size = LogoSize.md,
    this.showText = true,
  });

  double get _textSize => switch (size) {
    LogoSize.sm => 16,
    LogoSize.md => 22,
    LogoSize.lg => 38,
  };

  // Match icon height exactly to font size for visual alignment
  double get _iconSize => _textSize * 1.25;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Image.asset(
          'assets/images/unidrive_logo.png',
          width: _iconSize,
          height: _iconSize,
          fit: BoxFit.contain,
        ),
        if (showText) ...[
          SizedBox(width: _iconSize * 0.35),
          ShaderMask(
            shaderCallback:
                (bounds) => const LinearGradient(
                  colors: [Color(0xFF7C3AED), Color(0xFF00C9FF)],
                ).createShader(bounds),
            child: Text(
              'UniDrive',
              style: GoogleFonts.plusJakartaSans(
                fontSize: _textSize,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.5,
                color: Colors.white,
                height: 1.0,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

/// Stacked logo for welcome/splash screens
class UniDriveLogoStacked extends StatelessWidget {
  const UniDriveLogoStacked({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Image.asset(
          'assets/images/unidrive_logo.png',
          width: 100,
          height: 100,
          fit: BoxFit.contain,
        ),
        const SizedBox(height: 14),
        ShaderMask(
          shaderCallback:
              (bounds) => const LinearGradient(
                colors: [Color(0xFF7C3AED), Color(0xFF00C9FF)],
              ).createShader(bounds),
          child: Text(
            'UniDrive',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 36,
              fontWeight: FontWeight.w800,
              letterSpacing: -1.0,
              color: Colors.white,
              height: 1.0,
            ),
          ),
        ),
      ],
    );
  }
}
