import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import '../theme/app_theme.dart';
import '../models/driver_model.dart';

class ActiveRideScreen extends StatefulWidget {
  final DriverModel driver;
  const ActiveRideScreen({super.key, required this.driver});
  @override
  State<ActiveRideScreen> createState() => _ActiveRideScreenState();
}

class _ActiveRideScreenState extends State<ActiveRideScreen> {

  @override
  void initState() {
    super.initState();
    MapboxOptions.setAccessToken(
        'pk.eyJ1IjoiYXlhbi1hdGhlcjciLCJhIjoiY21vdW1oMG81MGNjdTJxczliYng0dHl1MCJ9.ordjfmdd2DXXpA04Sr_pKA');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: Padding(
          padding: const EdgeInsets.only(left: 16, top: 8),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.darkCard.withValues(alpha: 0.65),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                ),
                child: IconButton(
                  icon: const Icon(Icons.close_rounded, color: Colors.white),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
            ),
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16, top: 8),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: AppColors.darkCard.withValues(alpha: 0.65),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                  ),
                  child: Row(
                    children: [
                      Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                              color: AppColors.success, shape: BoxShape.circle)
                      ).animate(onPlay: (c) => c.repeat(reverse: true)).scale(duration: 800.ms),
                      const SizedBox(width: 8),
                      Text('Active Ride',
                          style: GoogleFonts.plusJakartaSans(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                              letterSpacing: 0.5)),
                    ],
                  ),
                ),
              ),
            ),
          ).animate().fadeIn(delay: 200.ms).slideY(begin: -0.2),
        ],
      ),
      body: Stack(
        children: [
          MapWidget(
            onMapCreated: (mapboxMap) {
              mapboxMap.compass.updateSettings(
                  CompassSettings(enabled: false));
              mapboxMap.scaleBar.updateSettings(
                  ScaleBarSettings(enabled: false));
              // Set initial camera — replaces deprecated cameraOptions param
              mapboxMap.setCamera(CameraOptions(
                center: Point(
                    coordinates: Position(67.0650, 24.8500)),
                zoom: 12.5,
              ));
            },
            styleUri: MapboxStyles.DARK,
          ).animate().fadeIn(duration: 600.ms),

          // ── SOS FAB ────────────────────────────────────────────────
          Positioned(
            left: 20,
            bottom: 240,
            child: FloatingActionButton(
              heroTag: 'sos',
              backgroundColor: AppColors.maroonLight,
              onPressed: () {},
              elevation: 4,
              child: const Icon(Icons.warning_amber_rounded, color: Colors.white),
            ).animate().fadeIn(delay: 400.ms).slideX(begin: -0.2),
          ),

          // ── Chat FAB ────────────────────────────────────────────────
          Positioned(
            right: 20,
            bottom: 240,
            child: FloatingActionButton(
              heroTag: 'chat',
              backgroundColor: AppColors.blue,
              onPressed: () => Navigator.pushNamed(context, '/chat'),
              elevation: 4,
              child: const Icon(Icons.chat_bubble_rounded, color: Colors.white),
            ).animate().fadeIn(delay: 400.ms).slideX(begin: 0.2),
          ),

          // ── Bottom Info Card ──────────────────────────────────────────
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                child: Container(
                  padding: const EdgeInsets.fromLTRB(28, 32, 28, 40),
                  decoration: BoxDecoration(
                    color: AppColors.darkBg.withValues(alpha: 0.85),
                    border: Border(top: BorderSide(color: Colors.white.withValues(alpha: 0.1))),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Stats Row
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _Stat('ETA', '${widget.driver.etaMinutes} min', AppColors.cyan),
                          Container(width: 1, height: 40, color: AppColors.darkBorder),
                          _Stat('Fare', 'PKR ${widget.driver.farePerPerson.toStringAsFixed(0)}', AppColors.orange),
                          Container(width: 1, height: 40, color: AppColors.darkBorder),
                          _Stat('To', widget.driver.to.isNotEmpty ? widget.driver.to : 'Campus', AppColors.success),
                        ],
                      ).animate().fadeIn(delay: 600.ms),
                      const SizedBox(height: 32),
                      
                      // Driver Info
                      Row(
                        children: [
                          Container(
                            width: 60,
                            height: 60,
                            decoration: BoxDecoration(
                              color: AppColors.darkSurface,
                              shape: BoxShape.circle,
                              border: Border.all(color: AppColors.cyan, width: 2),
                            ),
                            child: const Icon(Icons.person_rounded,
                                color: AppColors.textMuted, size: 32),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(widget.driver.name,
                                    style: GoogleFonts.plusJakartaSans(
                                        fontSize: 20,
                                        fontWeight: FontWeight.w800,
                                        color: Colors.white)),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    Text('${widget.driver.carModel} · ',
                                        style: GoogleFonts.plusJakartaSans(
                                            fontSize: 14, color: AppColors.textMuted)),
                                    Icon(Icons.star_rounded, size: 14, color: AppColors.orange),
                                    Text(' ${widget.driver.rating}',
                                        style: GoogleFonts.plusJakartaSans(
                                            fontSize: 14, color: Colors.white, fontWeight: FontWeight.w700)),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          // License Plate Pill
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                            decoration: BoxDecoration(
                              color: AppColors.blue.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: AppColors.blue.withValues(alpha: 0.3)),
                            ),
                            child: Text(
                              widget.driver.licensePlate,
                              style: GoogleFonts.plusJakartaSans(
                                color: AppColors.cyan,
                                fontWeight: FontWeight.w800,
                                fontSize: 13,
                                letterSpacing: 1
                              ),
                            ),
                          ),
                        ],
                      ).animate().fadeIn(delay: 700.ms).slideY(begin: 0.2),
                    ],
                  ),
                ),
              ),
            ).animate().slideY(begin: 1.0, duration: 600.ms, curve: Curves.easeOutExpo),
          ),
        ],
      ),
    );
  }

}

class _Stat extends StatelessWidget {
  final String label, val;
  final Color color;
  const _Stat(this.label, this.val, this.color);
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(label,
            style: GoogleFonts.plusJakartaSans(
                color: AppColors.textMuted,
                fontSize: 12,
                fontWeight: FontWeight.w600,
                letterSpacing: 1)),
        const SizedBox(height: 6),
        Text(val,
            style: GoogleFonts.plusJakartaSans(
                color: color, fontWeight: FontWeight.w800, fontSize: 16)),
      ],
    );
  }
}
