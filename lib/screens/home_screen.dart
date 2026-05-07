import 'dart:ui';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' as mbx;
import 'package:permission_handler/permission_handler.dart';
import 'package:geolocator/geolocator.dart' as geo;
import 'package:http/http.dart' as http;
import '../theme/app_theme.dart';
import '../widgets/unidrive_logo.dart';
import '../services/auth_service.dart';
import '../services/database_service.dart';
import 'search_filter_screen.dart';
import 'offer_ride_sheet.dart';
import '../main.dart';

const _mapboxPublicToken =
    'pk.eyJ1IjoiYXlhbi1hdGhlcjciLCJhIjoiY21vdW1oMG81MGNjdTJxczliYng0dHl1MCJ9.ordjfmdd2DXXpA04Sr_pKA';



class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _isDriverMode = false;
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  mbx.MapboxMap? _mapboxMap;

  // Fixed-pin reverse geocode state
  String _centerAddress = '';
  bool   _geocoding     = false;

  @override
  void initState() {
    super.initState();
    mbx.MapboxOptions.setAccessToken(_mapboxPublicToken);
    _requestLocationPermission();
  }

  Future<void> _requestLocationPermission() async {
    await Permission.locationWhenInUse.request();
  }

  Future<void> _flyToUserLocation() async {
    final mapbox = _mapboxMap;
    if (mapbox == null) return;
    try {
      final pos = await geo.Geolocator.getCurrentPosition(
        locationSettings: const geo.LocationSettings(
          accuracy: geo.LocationAccuracy.high,
          timeLimit: Duration(seconds: 8),
        ),
      );
      mapbox.flyTo(
        mbx.CameraOptions(
          center: mbx.Point(
              coordinates: mbx.Position(pos.longitude, pos.latitude)),
          zoom: 15.5,
        ),
        mbx.MapAnimationOptions(duration: 800),
      );
    } catch (_) {
      // Permission not granted or location unavailable — silently ignore
    }
  }

  /// Called when the Mapbox camera stops moving.
  /// Extracts center coords and reverse-geocodes them via Photon.
  Future<void> _onCameraIdle() async {
    final mapbox = _mapboxMap;
    if (mapbox == null || _geocoding) return;
    try {
      final cam = await mapbox.getCameraState();
      final center = cam.center;
      if (center == null) return;
      final lng = center.coordinates.lng;
      final lat = center.coordinates.lat;
      setState(() => _geocoding = true);
      final uri = Uri.parse(
          'https://photon.komoot.io/reverse?lon=$lng&lat=$lat&limit=1');
      final res = await http.get(uri).timeout(const Duration(seconds: 5));
      if (res.statusCode == 200) {
        final data  = jsonDecode(res.body) as Map<String, dynamic>;
        final feats = (data['features'] as List?) ?? [];
        if (feats.isNotEmpty) {
          final p = (feats.first as Map)['properties'] as Map<String, dynamic>;
          final parts = [p['name'], p['street'], p['city']]
              .where((e) => e != null && (e as String).isNotEmpty)
              .join(', ');
          if (mounted) setState(() => _centerAddress = parts);
        }
      }
    } catch (_) {
      // Reverse geocode failed — silently ignore
    } finally {
      if (mounted) setState(() => _geocoding = false);
    }
  }

  void _showFilter() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => SearchFilterSheet(
        onFindRides: () {
          Navigator.pop(context);
          Navigator.pushNamed(context, '/matches');
        },
      ),
    );
  }

  void _showOfferRide() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const OfferRideSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: isDark ? AppColors.darkBg : AppColors.lightBg,
      drawer: _AppDrawer(
        isDark: isDark,
        isDriverMode: _isDriverMode,
        onDriverModeToggle: (val) => setState(() => _isDriverMode = val),
      ),
      body: Stack(
        children: [
          // ── Full-screen Mapbox map ──────────────────────────────────
          Positioned.fill(
            child: mbx.MapWidget(
              onMapCreated: (mapboxMap) {
                _mapboxMap = mapboxMap;
                mapboxMap.compass.updateSettings(
                    mbx.CompassSettings(enabled: false));
                mapboxMap.scaleBar.updateSettings(
                    mbx.ScaleBarSettings(enabled: false));
                mapboxMap.logo.updateSettings(
                    mbx.LogoSettings(enabled: false));
                mapboxMap.attribution.updateSettings(
                    mbx.AttributionSettings(enabled: false));
                mapboxMap.location.updateSettings(mbx.LocationComponentSettings(
                  enabled: true,
                  pulsingEnabled: true,
                  puckBearingEnabled: true,
                ));
                mapboxMap.setCamera(mbx.CameraOptions(
                  center: mbx.Point(
                      coordinates: mbx.Position(67.0883, 24.8934)),
                  zoom: 14.5,
                ));
              },
              onCameraChangeListener: (_) => _onCameraIdle(),
              styleUri: isDark
                  ? mbx.MapboxStyles.DARK
                  : mbx.MapboxStyles.MAPBOX_STREETS,
            ).animate().fadeIn(duration: 800.ms),
          ),

          // ── Fixed center pin (reverse geocode anchor) ───────────────────
          Positioned.fill(
            child: IgnorePointer(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (_centerAddress.isNotEmpty)
                    Container(
                      margin: const EdgeInsets.only(bottom: 6),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: isDark
                            ? AppColors.darkCard.withValues(alpha: 0.92)
                            : Colors.white.withValues(alpha: 0.95),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [BoxShadow(
                            color: Colors.black.withValues(alpha: 0.15),
                            blurRadius: 8)],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (_geocoding)
                            const SizedBox(width: 12, height: 12,
                                child: CircularProgressIndicator(
                                    strokeWidth: 1.5, color: AppColors.blue))
                          else
                            const Icon(Icons.location_on_rounded,
                                size: 13, color: AppColors.maroon),
                          const SizedBox(width: 6),
                          ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 200),
                            child: Text(
                              _centerAddress,
                              style: GoogleFonts.plusJakartaSans(
                                  fontSize: 12, fontWeight: FontWeight.w600),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  const Icon(Icons.location_pin,
                      size: 44, color: AppColors.maroon),
                  // Offset so the pin base sits at the exact center
                  const SizedBox(height: 44),
                ],
              ),
            ),
          ),

          // ── Top bar ──────────────────────────────────────────────────
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                child: Column(
                  children: [
                    Row(
                      children: [
                        // Hamburger
                        RepaintBoundary(
                          child: _MapBtn(
                            onTap: () => _scaffoldKey.currentState?.openDrawer(),
                            child: const Icon(Icons.menu_rounded,
                                size: 20, color: Colors.white),
                          ).animate().fadeIn(delay: 200.ms).slideX(begin: -0.2),
                        ),

                        const Spacer(),

                        // Logo pill
                        RepaintBoundary(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(30),
                            child: BackdropFilter(
                              filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 14, vertical: 8),
                                decoration: BoxDecoration(
                                  color: AppColors.darkCard.withValues(alpha: 0.7),
                                  border: Border.all(
                                      color: Colors.white.withValues(alpha: 0.12)),
                                ),
                                child: const UniDriveLogo(size: LogoSize.sm),
                              ),
                            ),
                          ).animate().fadeIn(delay: 200.ms).slideY(begin: -0.2),
                        ),

                        const Spacer(),

                        // Avatar
                        RepaintBoundary(
                          child: _MapBtn(
                            onTap: () => Navigator.pushNamed(context, '/profile'),
                            child: const Icon(Icons.person_rounded,
                                size: 22, color: Colors.white),
                          ).animate().fadeIn(delay: 200.ms).slideX(begin: 0.2),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Search bar
                    RepaintBoundary(
                      child: GestureDetector(
                        onTap: _showFilter,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(20),
                          child: BackdropFilter(
                            filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                            child: Container(
                              height: 50,
                              padding: const EdgeInsets.symmetric(horizontal: 18),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.92),
                                border: Border.all(
                                    color: Colors.white.withValues(alpha: 0.2)),
                              ),
                              child: const Row(
                                children: [
                                  Icon(Icons.search_rounded,
                                      color: AppColors.textPrimary, size: 20),
                                  SizedBox(width: 12),
                                  Expanded(
                                      child: Text('Where to?',
                                          style: TextStyle(
                                            color: AppColors.textPrimary,
                                            fontSize: 15,
                                            fontWeight: FontWeight.w600,
                                          ))),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ).animate().fadeIn(delay: 300.ms).slideY(begin: -0.2),

                    // Driver-mode banner
                    if (_isDriverMode)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(14),
                          child: BackdropFilter(
                            filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 6),
                              decoration: BoxDecoration(
                                color: AppColors.maroon.withValues(alpha: 0.25),
                                border: Border.all(
                                    color: AppColors.maroon.withValues(alpha: 0.5)),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.drive_eta_rounded,
                                      color: Colors.white, size: 14),
                                  SizedBox(width: 6),
                                  Text('DRIVER MODE ACTIVE',
                                      style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 10,
                                          fontWeight: FontWeight.w800,
                                          letterSpacing: 1.5)),
                                ],
                              ),
                            ),
                          ),
                        ).animate().fadeIn(duration: 300.ms),
                      ),
                  ],
                ),
              ),
            ),
          ),

          // ── Zoom controls ─────────────────────────────────────────────
          Positioned(
            right: 14,
            bottom: 170,
            child: Column(
              children: [
                RepaintBoundary(
                  child: _MapBtn(
                    onTap: () async {
                      final cam = await _mapboxMap?.getCameraState();
                      if (cam != null) {
                        _mapboxMap?.flyTo(
                          mbx.CameraOptions(
                              center: cam.center,
                              zoom: (cam.zoom) + 1),
                          mbx.MapAnimationOptions(duration: 300),
                        );
                      }
                    },
                    child: const Icon(Icons.add, size: 20, color: Colors.white),
                  ),
                ),
                const SizedBox(height: 10),
                RepaintBoundary(
                  child: _MapBtn(
                    onTap: () async {
                      final cam = await _mapboxMap?.getCameraState();
                      if (cam != null) {
                        _mapboxMap?.flyTo(
                          mbx.CameraOptions(
                              center: cam.center,
                              zoom: (cam.zoom) - 1),
                          mbx.MapAnimationOptions(duration: 300),
                        );
                      }
                    },
                    child: const Icon(Icons.remove, size: 20, color: Colors.white),
                  ),
                ),
                const SizedBox(height: 10),
                RepaintBoundary(
                  child: _MapBtn(
                    onTap: _flyToUserLocation,
                    child: const Icon(Icons.my_location_rounded,
                        size: 18, color: AppColors.cyan),
                  ),
                ),
              ],
            ).animate().fadeIn(delay: 600.ms).slideX(begin: 0.2),
          ),

          // ── Compact bottom card ──────────────────────────────────────
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: RepaintBoundary(
              child: _BottomCard(
                isDark: isDark,
                isDriverMode: _isDriverMode,
                onFindRide: _showFilter,
                onOfferRide: _showOfferRide,
              ).animate().slideY(
                  begin: 1.0, curve: Curves.easeOutExpo, duration: 500.ms),
            ),
          ),
        ],
      ),
    );
  }

}

// ── Drawer ──────────────────────────────────────────────────────────────────

class _AppDrawer extends StatelessWidget {
  final bool isDark;
  final bool isDriverMode;
  final ValueChanged<bool> onDriverModeToggle;

  const _AppDrawer({
    required this.isDark,
    required this.isDriverMode,
    required this.onDriverModeToggle,
  });

  @override
  Widget build(BuildContext context) {
    final appState   = UniDriveApp.of(context);
    final bg         = isDark ? AppColors.darkBg : AppColors.lightBg;
    final cardBg     = isDark ? AppColors.darkCard : Colors.white;
    final textPrimary = isDark ? AppColors.textPrimaryDark : AppColors.textPrimary;
    final border     = isDark
        ? Colors.white.withValues(alpha: 0.07)
        : Colors.black.withValues(alpha: 0.07);

    return Drawer(
      backgroundColor: bg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.horizontal(right: Radius.circular(28)),
      ),
      child: SafeArea(
        child: Column(
          children: [
            // ── Header ─────────────────────────────────────────────────
            Container(
              width: double.infinity,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: isDark
                      ? [AppColors.navy, AppColors.darkCard]
                      : [AppColors.navy, const Color(0xFF1A3A6A)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
              child: Row(
                children: [
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      color: AppColors.cyan.withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.cyan, width: 2),
                      boxShadow: [
                        BoxShadow(color: AppColors.cyan.withValues(alpha: 0.3), blurRadius: 12)
                      ],
                    ),
                    child: const Icon(Icons.person_rounded, size: 32, color: Colors.white),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: StreamBuilder<DocumentSnapshot>(
                      stream: AuthService().currentUid != null
                          ? DatabaseService().streamUserData(AuthService().currentUid!)
                          : null,
                      builder: (context, snapshot) {
                        String displayName = 'Loading...';
                        String displayEmail =
                            FirebaseAuth.instance.currentUser?.email ?? '';
                        bool isVerified = false;

                        if (snapshot.hasData && snapshot.data!.exists) {
                          final data =
                              snapshot.data!.data() as Map<String, dynamic>?;
                          displayName = data?['name'] ?? displayEmail.split('@').first;
                          displayEmail = data?['email'] ?? displayEmail;
                          isVerified = data?['isVerified'] ?? false;
                        } else if (!snapshot.hasData ||
                            snapshot.connectionState == ConnectionState.waiting) {
                          displayName =
                              FirebaseAuth.instance.currentUser?.displayName ??
                              FirebaseAuth.instance.currentUser?.email?.split('@').first ??
                              'Student';
                        }

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              displayName,
                              style: GoogleFonts.plusJakartaSans(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.3,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              displayEmail,
                              style: GoogleFonts.plusJakartaSans(
                                color: Colors.white70,
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: (isVerified ? AppColors.cyan : AppColors.orange)
                                    .withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: (isVerified ? AppColors.cyan : AppColors.orange)
                                      .withValues(alpha: 0.5),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    isVerified
                                        ? Icons.verified_rounded
                                        : Icons.hourglass_top_rounded,
                                    color: isVerified
                                        ? AppColors.cyan
                                        : AppColors.orange,
                                    size: 11,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    isVerified ? 'Verified Student' : 'Pending Verification',
                                    style: GoogleFonts.plusJakartaSans(
                                      color: isVerified
                                          ? AppColors.cyan
                                          : AppColors.orange,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),

            // ── Mode toggle ─────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: cardBg,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: border),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: _ModeTab(
                        label: 'Passenger',
                        icon: Icons.airline_seat_recline_normal_rounded,
                        selected: !isDriverMode,
                        accentColor: AppColors.blue,
                        onTap: () => onDriverModeToggle(false),
                      ),
                    ),
                    Expanded(
                      child: _ModeTab(
                        label: 'Driver',
                        icon: Icons.drive_eta_rounded,
                        selected: isDriverMode,
                        accentColor: AppColors.maroon,
                        onTap: () => onDriverModeToggle(true),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 8),

            // ── Nav items ───────────────────────────────────────────────
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                children: [
                  _DrawerTile(icon: Icons.person_outline_rounded, label: 'My Profile', isDark: isDark,
                      onTap: () { Navigator.pop(context); Navigator.pushNamed(context, '/profile'); }),
                  _DrawerTile(icon: Icons.history_rounded, label: 'Ride History', isDark: isDark,
                      onTap: () { Navigator.pop(context); Navigator.pushNamed(context, '/profile'); }),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Divider(color: border, height: 1),
                  ),
                  _DrawerTile(
                    icon: Icons.headset_mic_rounded, label: 'Helpline & Support',
                    isDark: isDark, accentColor: AppColors.maroon,
                    trailing: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppColors.maroon.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text('24/7', style: GoogleFonts.plusJakartaSans(
                          color: AppColors.maroon, fontSize: 10, fontWeight: FontWeight.w800)),
                    ),
                    onTap: () {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        content: Text('Helpline: 0800-UNIDRIVE',
                            style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600)),
                        backgroundColor: AppColors.maroon,
                        behavior: SnackBarBehavior.floating,
                      ));
                    },
                  ),

                ],
              ),
            ),

            // ── Footer ─────────────────────────────────────────────────
            Container(
              decoration: BoxDecoration(border: Border(top: BorderSide(color: border))),
              padding: const EdgeInsets.fromLTRB(20, 16, 16, 16),
              child: Column(
                children: [
                  Row(
                    children: [
                      Icon(isDark ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
                          color: AppColors.textMuted, size: 20),
                      const SizedBox(width: 12),
                      Text('Dark Mode',
                          style: GoogleFonts.plusJakartaSans(
                              color: textPrimary, fontSize: 14, fontWeight: FontWeight.w600)),
                      const Spacer(),
                      Switch(
                        value: isDark,
                        onChanged: (_) => appState?.toggleTheme(),
                        activeThumbColor: AppColors.blue,
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        await AuthService().logout();
                        if (context.mounted) {
                          Navigator.of(context)
                              .pushNamedAndRemoveUntil('/welcome', (r) => false);
                        }
                      },
                      icon: const Icon(Icons.logout_rounded, size: 18, color: AppColors.maroonLight),
                      label: Text('Log Out',
                          style: GoogleFonts.plusJakartaSans(
                              color: AppColors.maroonLight, fontWeight: FontWeight.w700, fontSize: 14)),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: AppColors.maroon.withValues(alpha: 0.5)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Mode tab ────────────────────────────────────────────────────────────────

class _ModeTab extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final Color accentColor;
  final VoidCallback onTap;
  const _ModeTab({required this.label, required this.icon, required this.selected,
      required this.accentColor, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: selected ? accentColor.withValues(alpha: 0.15) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: selected ? Border.all(color: accentColor.withValues(alpha: 0.5)) : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 15, color: selected ? accentColor : AppColors.textMuted),
            const SizedBox(width: 5),
            Text(label, style: GoogleFonts.plusJakartaSans(
                fontSize: 13,
                fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                color: selected ? accentColor : AppColors.textMuted)),
          ],
        ),
      ),
    );
  }
}

// ── Drawer tile ──────────────────────────────────────────────────────────────

class _DrawerTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isDark;
  final Color? accentColor;
  final Widget? trailing;
  final VoidCallback onTap;

  const _DrawerTile({required this.icon, required this.label, required this.isDark,
      this.accentColor, this.trailing, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final color = accentColor ?? (isDark ? AppColors.textPrimaryDark : AppColors.textPrimary);
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 34, height: 34,
                decoration: BoxDecoration(
                  color: (accentColor ?? AppColors.blue).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 17, color: color),
              ),
              const SizedBox(width: 12),
              Expanded(child: Text(label, style: GoogleFonts.plusJakartaSans(
                  fontSize: 14, fontWeight: FontWeight.w600, color: color))),
              if (trailing != null) trailing!,
              if (trailing == null)
                Icon(Icons.chevron_right_rounded, size: 18, color: AppColors.textMuted),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Map button ───────────────────────────────────────────────────────────────

class _MapBtn extends StatelessWidget {
  final VoidCallback onTap;
  final Widget child;
  const _MapBtn({required this.onTap, required this.child});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.darkCard.withValues(alpha: 0.72),
              border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}

// ── Compact bottom card ──────────────────────────────────────────────────────

class _BottomCard extends StatelessWidget {
  final bool isDark;
  final bool isDriverMode;
  final VoidCallback onFindRide;
  final VoidCallback onOfferRide;
  const _BottomCard({
    required this.isDark,
    required this.isDriverMode,
    required this.onFindRide,
    required this.onOfferRide,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
          decoration: BoxDecoration(
            color: AppColors.darkBg.withValues(alpha: 0.88),
            border: Border(top: BorderSide(color: Colors.white.withValues(alpha: 0.08))),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Headline
              Text(
                isDriverMode ? 'Ready to accept rides?' : 'Find a Ride',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.4,
                  color: AppColors.textPrimaryDark,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                isDriverMode
                    ? 'Students nearby are waiting for a ride.'
                    : 'Join verified students heading to campus.',
                style: GoogleFonts.plusJakartaSans(
                    fontSize: 13, color: AppColors.textMuted,
                    height: 1.3, fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 16),

              // Passenger mode: only "Find a Ride"
              if (!isDriverMode)
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton.icon(
                    onPressed: onFindRide,
                    icon: const Icon(Icons.directions_run_rounded, size: 18),
                    label: const Text('Find a Ride'),
                  ),
                ),

              // Driver mode: "Offer a Ride"
              if (isDriverMode)
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton.icon(
                    onPressed: onOfferRide,
                    style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.maroon),
                    icon: const Icon(Icons.drive_eta_rounded, size: 18),
                    label: const Text('Offer a Ride'),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
