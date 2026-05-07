import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Uses a single AnimationController for both ripple rings, which is far
/// cheaper than flutter_animate's per-widget repeat hooks.
class AnimatedPulseMarker extends StatefulWidget {
  final Color color;
  final IconData icon;
  final double size;

  const AnimatedPulseMarker({
    super.key,
    required this.color,
    required this.icon,
    required this.size,
  });

  @override
  State<AnimatedPulseMarker> createState() => _AnimatedPulseMarkerState();
}

class _AnimatedPulseMarkerState extends State<AnimatedPulseMarker>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scale;
  late final Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();

    _scale = Tween<double>(begin: 0.5, end: 1.2).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic),
    );
    _fade = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = widget.size;
    final color = widget.color;
    final ringSize = size * 1.8;

    return Stack(
      alignment: Alignment.center,
      children: [
        // Outer ripple 1
        AnimatedBuilder(
          animation: _ctrl,
          builder: (context, child) => Opacity(
            opacity: _fade.value * 0.25,
            child: Transform.scale(
              scale: _scale.value,
              child: Container(
                width: ringSize,
                height: ringSize,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ),
        ),

        // Outer ripple 2 — offset by half a cycle via interval
        AnimatedBuilder(
          animation: _ctrl,
          builder: (context, child) {
            // Use a phase-shifted version of the animation value
            final t = (_ctrl.value + 0.5) % 1.0;
            final scale = 0.5 + t * 0.7;       // 0.5 → 1.2
            final opacity = (1.0 - t) * 0.15;  // fade out
            return Opacity(
              opacity: opacity,
              child: Transform.scale(
                scale: scale,
                child: Container(
                  width: ringSize,
                  height: ringSize,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            );
          },
        ),

        // Inner glowing core — static, no animation needed
        Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: AppColors.darkCard,
            shape: BoxShape.circle,
            border: Border.all(color: color, width: 2.5),
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: 0.5),
                blurRadius: 12,
                spreadRadius: 2,
              )
            ],
          ),
          child: Icon(widget.icon, color: color, size: size * 0.5),
        ),
      ],
    );
  }
}
