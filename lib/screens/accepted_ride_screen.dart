import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import '../models/driver_model.dart';
import '../services/database_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../theme/app_theme.dart';
import '../widgets/verified_badge.dart';
import '../core/constants.dart';



/// AcceptedRideScreen
/// Shown after a ride is confirmed. Dynamically renders either:
///   • Passenger mode — shows the approaching driver's info, ETA, and fare.
///   • Driver mode    — shows the passenger to pick up, seat count, and pickup location.
///
/// Pass [isDriverMode: true] via route arguments map to activate driver view:
///   Navigator.pushNamed(context, '/accepted',
///       arguments: {'driver': driverModel, 'isDriverMode': true});
class AcceptedRideScreen extends StatefulWidget {
  const AcceptedRideScreen({super.key});

  @override
  State<AcceptedRideScreen> createState() => _AcceptedRideScreenState();
}

class _AcceptedRideScreenState extends State<AcceptedRideScreen>
    with TickerProviderStateMixin {
  late AnimationController _pulseCtrl;
  int _etaMinutes = 8;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _startMockCountdown();
  }

  void _startMockCountdown() async {
    while (mounted && _etaMinutes > 0) {
      await Future.delayed(const Duration(seconds: 8));
      if (mounted) setState(() => _etaMinutes--);
    }
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    super.dispose();
  }

  void _cancelRide(BuildContext context) {
    showDialog(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: const Text('Cancel Ride?'),
            content: const Text('Are you sure you want to cancel this ride?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('No, Keep It'),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  Navigator.pop(context);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.maroonLight,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    'Yes, Cancel',
                    style: GoogleFonts.plusJakartaSans(
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // ── Unpack route arguments ──────────────────────────────────────────────
    final args = ModalRoute.of(context)?.settings.arguments;
    DriverModel? driver;
    bool isDriverMode = false;

    if (args is Map) {
      driver = args['driver'] as DriverModel?;
      isDriverMode = args['isDriverMode'] as bool? ?? false;
    } else if (args is DriverModel) {
      driver = args;
    }

    final theme = Theme.of(context);
    final primary = theme.primaryColor;
    final isDark = theme.brightness == Brightness.dark;

    // AppBar label depends on mode
    final appBarLabel = isDriverMode ? 'Passenger En Route' : 'Driver En Route';
    final appBarIcon =
        isDriverMode
            ? Icons.person_pin_circle_rounded
            : Icons.directions_car_filled_rounded;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: Container(
          margin: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color:
                isDark
                    ? AppColors.darkCard.withValues(alpha: 0.9)
                    : Colors.white.withValues(alpha: 0.9),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.15),
                blurRadius: 8,
              ),
            ],
          ),
          child: BackButton(color: primary),
        ),
        title: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
          decoration: BoxDecoration(
            color:
                isDark
                    ? AppColors.darkCard.withValues(alpha: 0.9)
                    : Colors.white.withValues(alpha: 0.9),
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 8,
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Pulsing live dot
              AnimatedBuilder(
                animation: _pulseCtrl,
                builder:
                    (_, child) => Container(
                      width: 9,
                      height: 9,
                      decoration: BoxDecoration(
                        color: AppColors.success,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.success.withValues(
                              alpha: _pulseCtrl.value * 0.7,
                            ),
                            blurRadius: 8,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                    ),
              ),
              const SizedBox(width: 8),
              Icon(
                appBarIcon,
                size: 16,
                color:
                    isDark ? AppColors.textPrimaryDark : AppColors.textPrimary,
              ),
              const SizedBox(width: 6),
              Text(
                appBarLabel,
                style: GoogleFonts.plusJakartaSans(
                  color:
                      isDark
                          ? AppColors.textPrimaryDark
                          : AppColors.textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ),

      // ── Full-screen body ──────────────────────────────────────────────────
      body: StreamBuilder<DocumentSnapshot>(
        stream: DatabaseService().streamRide(driver?.id ?? ''),
        builder: (context, snapshot) {
          // If the ride was cancelled or completed from another client, we could react here.
          // For now, we still show the tracking UI.
          
          return Stack(
        children: [
          // ── Mapbox full-screen map ─────────────────────────────────
          MapWidget(
            onMapCreated: (mapboxMap) {
              MapboxOptions.setAccessToken(kMapboxPublicToken);
              mapboxMap.compass.updateSettings(
                  CompassSettings(enabled: false));
              mapboxMap.scaleBar.updateSettings(
                  ScaleBarSettings(enabled: false));
              // Set initial camera — preferred over deprecated cameraOptions param
              mapboxMap.setCamera(CameraOptions(
                center: Point(coordinates: Position(67.0670, 24.8530)),
                zoom: 13.0,
              ));
            },
            styleUri: MapboxStyles.DARK,
          ),

          // ── Ultra-compact Bottom Card ───────────────────────────────────
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: _BottomCard(
              driver: driver,
              isDriverMode: isDriverMode,
              etaMinutes: _etaMinutes,
              isDark: isDark,
              primary: primary,
              onCancel: () => _cancelRide(context),
              onTrack:
                  () => Navigator.pushNamed(
                    context,
                    '/active',
                    arguments: driver,
                  ),
            ),
          ),
        ],
      );
     },
    ),
   );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Bottom card — swaps content based on isDriverMode
// ─────────────────────────────────────────────────────────────────────────────

class _BottomCard extends StatelessWidget {
  final DriverModel? driver;
  final bool isDriverMode;
  final int etaMinutes;
  final bool isDark;
  final Color primary;
  final VoidCallback onCancel;
  final VoidCallback onTrack;

  const _BottomCard({
    required this.driver,
    required this.isDriverMode,
    required this.etaMinutes,
    required this.isDark,
    required this.primary,
    required this.onCancel,
    required this.onTrack,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cardBg = isDark ? AppColors.darkCard : Colors.white;
    final surface = isDark ? AppColors.darkSurface : AppColors.bgGrey;

    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: 20,
            offset: const Offset(0, -3),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Container(
            width: 36,
            height: 4,
            margin: const EdgeInsets.only(bottom: 10),
            decoration: BoxDecoration(
              color: theme.dividerColor,
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // ── Mode label chip ─────────────────────────────────────────
          Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color:
                  isDriverMode
                      ? AppColors.orange.withValues(alpha: 0.12)
                      : primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color:
                    isDriverMode
                        ? AppColors.orange.withValues(alpha: 0.3)
                        : primary.withValues(alpha: 0.25),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  isDriverMode
                      ? Icons.directions_car_filled_rounded
                      : Icons.person_rounded,
                  size: 13,
                  color: isDriverMode ? AppColors.orange : primary,
                ),
                const SizedBox(width: 5),
                Text(
                  isDriverMode ? 'DRIVER MODE' : 'PASSENGER MODE',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1,
                    color: isDriverMode ? AppColors.orange : primary,
                  ),
                ),
              ],
            ),
          ),

          // ── Row 1: Stats ────────────────────────────────────────────
          isDriverMode
              ? _DriverStatsRow(
                driver: driver,
                isDark: isDark,
                dividerColor: theme.dividerColor,
              )
              : _PassengerStatsRow(
                driver: driver,
                etaMinutes: etaMinutes,
                primary: primary,
                isDark: isDark,
                dividerColor: theme.dividerColor,
              ),

          const SizedBox(height: 10),
          Divider(color: theme.dividerColor, height: 1),
          const SizedBox(height: 10),

          // ── Row 2: Profile ──────────────────────────────────────────
          isDriverMode
              ? _PassengerProfileRow(
                isDark: isDark,
                passengerName: driver?.name,
                passengerPickup: driver?.from,
                seatNumber: (driver?.occupiedSeats ?? 0) + 1,
              )
              : _DriverProfileRow(
                driver: driver,
                isDark: isDark,
                primary: primary,
                surface: surface,
                dividerColor: theme.dividerColor,
              ),

          const SizedBox(height: 10),

          // ── Row 3: Route pill ───────────────────────────────────────
          _RoutePill(
            driver: driver,
            isDriverMode: isDriverMode,
            surface: surface,
            primary: primary,
            dividerColor: theme.dividerColor,
          ),

          const SizedBox(height: 12),

          // ── Action Buttons ──────────────────────────────────────────
          Row(
            children: [
              // Cancel — compact outlined
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onCancel,
                  icon: const Icon(Icons.close_rounded, size: 15),
                  label: const Text('Cancel'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.maroonLight,
                    side: BorderSide(
                      color: AppColors.maroonLight.withValues(alpha: 0.6),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 11),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              // Track — primary blue, wider
              Expanded(
                flex: 2,
                child: ElevatedButton.icon(
                  onPressed: onTrack,
                  icon: const Icon(Icons.navigation_rounded, size: 15),
                  label: const Text('Track Active Ride'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 11),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Passenger mode — stats row (ETA + Fare)
// ─────────────────────────────────────────────────────────────────────────────

class _PassengerStatsRow extends StatelessWidget {
  final DriverModel? driver;
  final int etaMinutes;
  final Color primary;
  final bool isDark;
  final Color dividerColor;

  const _PassengerStatsRow({
    required this.driver,
    required this.etaMinutes,
    required this.primary,
    required this.isDark,
    required this.dividerColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _InfoTile(
            icon: Icons.schedule_rounded,
            iconColor: primary,
            label: 'Driver ETA',
            value: '$etaMinutes min',
            valueColor: etaMinutes <= 3 ? AppColors.maroonLight : primary,
          ),
        ),
        Container(width: 1, height: 36, color: dividerColor),
        Expanded(
          child: _InfoTile(
            icon: Icons.payments_rounded,
            iconColor: AppColors.orange,
            label: 'Your Fare',
            value: 'PKR ${driver?.farePerPerson.toStringAsFixed(0) ?? '—'}',
            valueColor: AppColors.orange,
          ),
        ),
        Container(width: 1, height: 36, color: dividerColor),
        Expanded(
          child: _InfoTile(
            icon: Icons.airline_seat_recline_normal_rounded,
            iconColor: AppColors.navy,
            label: 'Seat',
            value:
                '${(driver?.occupiedSeats ?? 0) + 1} of ${driver?.availableSeats ?? '—'}',
            valueColor:
                isDark ? AppColors.textPrimaryDark : AppColors.textPrimary,
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Driver mode — stats row (Passenger name + Seat count)
// ─────────────────────────────────────────────────────────────────────────────

class _DriverStatsRow extends StatelessWidget {
  final DriverModel? driver;
  final bool isDark;
  final Color dividerColor;

  const _DriverStatsRow({
    required this.driver,
    required this.isDark,
    required this.dividerColor,
  });

  @override
  Widget build(BuildContext context) {
    final textColor =
        isDark ? AppColors.textPrimaryDark : AppColors.textPrimary;
    final occupied = driver?.occupiedSeats ?? 0;
    final total    = driver?.availableSeats ?? 0;
    final isFull   = total > 0 && occupied >= total;
    return Row(
      children: [
        Expanded(
          child: _InfoTile(
            icon: Icons.person_rounded,
            iconColor: AppColors.blue,
            label: 'Passenger',
            value: driver?.name ?? 'Passenger',
            valueColor: textColor,
          ),
        ),
        Container(width: 1, height: 36, color: dividerColor),
        Expanded(
          child: _InfoTile(
            icon: Icons.airline_seat_recline_normal_rounded,
            iconColor: AppColors.success,
            label: 'Seats Occupied',
            value: driver != null ? '$occupied of $total' : '—',
            valueColor: isFull ? AppColors.maroonLight : AppColors.success,
          ),
        ),
        Container(width: 1, height: 36, color: dividerColor),
        Expanded(
          child: _InfoTile(
            icon: Icons.verified_rounded,
            iconColor: AppColors.cyan,
            label: 'Status',
            value: driver?.isVerified == true ? 'Verified' : 'Pending',
            valueColor: driver?.isVerified == true ? AppColors.cyan : AppColors.orange,
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Passenger mode — driver profile row
// ─────────────────────────────────────────────────────────────────────────────

class _DriverProfileRow extends StatelessWidget {
  final DriverModel? driver;
  final bool isDark;
  final Color primary;
  final Color surface;
  final Color dividerColor;

  const _DriverProfileRow({
    required this.driver,
    required this.isDark,
    required this.primary,
    required this.surface,
    required this.dividerColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        CircleAvatar(
          radius: 22,
          backgroundColor: AppColors.blue.withValues(alpha: 0.15),
          child: Icon(
            driver?.gender == 'female'
                ? Icons.face_3_rounded
                : Icons.face_rounded,
            size: 24,
            color: AppColors.blue,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                driver?.name ?? '—',
                style: GoogleFonts.plusJakartaSans(
                  fontWeight: FontWeight.w800,
                  fontSize: 14,
                  color: isDark
                      ? AppColors.textPrimaryDark
                      : AppColors.textPrimary,
                ),
              ),
              Text(
                '${driver?.carModel ?? 'Unknown'} · ${driver?.carColor ?? 'Unknown'}',
                style: theme.textTheme.bodySmall,
              ),
              if (driver?.isVerified == true)
                const Padding(
                  padding: EdgeInsets.only(top: 3),
                  child: VerifiedBadge(compact: true),
                ),
            ],
          ),
        ),
        // License plate
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
          decoration: BoxDecoration(
            color: surface,
            borderRadius: BorderRadius.circular(9),
            border: Border.all(color: dividerColor),
          ),
          child: Text(
            driver?.licensePlate ?? '—',
            style: TextStyle(
              color: primary,
              fontWeight: FontWeight.w800,
              fontSize: 11,
              letterSpacing: 1.5,
            ),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Driver mode — passenger profile row
// ─────────────────────────────────────────────────────────────────────────────

class _PassengerProfileRow extends StatelessWidget {
  final bool isDark;
  final String? passengerName;
  final String? passengerPickup;
  final int seatNumber;

  const _PassengerProfileRow({
    required this.isDark,
    this.passengerName,
    this.passengerPickup,
    this.seatNumber = 1,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        CircleAvatar(
          radius: 22,
          backgroundColor: AppColors.orange.withValues(alpha: 0.15),
          child: const Icon(
            Icons.person_rounded,
            size: 24,
            color: AppColors.orange,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                passengerName ?? 'Passenger',
                style: GoogleFonts.plusJakartaSans(
                  fontWeight: FontWeight.w800,
                  fontSize: 14,
                  color: isDark
                      ? AppColors.textPrimaryDark
                      : AppColors.textPrimary,
                ),
              ),
              if (passengerPickup != null)
                Text(
                  passengerPickup!,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              const Padding(
                padding: EdgeInsets.only(top: 3),
                child: VerifiedBadge(compact: true),
              ),
            ],
          ),
        ),
        // Seat indicator badge
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
          decoration: BoxDecoration(
            color: AppColors.success.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(9),
            border: Border.all(color: AppColors.success.withValues(alpha: 0.3)),
          ),
          child: Text(
            'Seat $seatNumber',
            style: GoogleFonts.plusJakartaSans(
              color: AppColors.success,
              fontWeight: FontWeight.w800,
              fontSize: 11,
              letterSpacing: 0.5,
            ),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Route pill — adapts content for passenger vs driver view
// ─────────────────────────────────────────────────────────────────────────────

class _RoutePill extends StatelessWidget {
  final DriverModel? driver;
  final bool isDriverMode;
  final Color surface;
  final Color primary;
  final Color dividerColor;

  const _RoutePill({
    required this.driver,
    required this.isDriverMode,
    required this.surface,
    required this.primary,
    required this.dividerColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // In driver mode: show only passenger's pickup (single-stop)
    // In passenger mode: show full from → to route
    final showSingleStop = isDriverMode;
    final line1 = isDriverMode
        ? (driver?.from ?? '—')
        : (driver?.from ?? '—');
    final line2 = driver?.to ?? '—';
    final time  = driver?.departureTime ?? '—';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          // Route connector dots
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: AppColors.success,
                  shape: BoxShape.circle,
                ),
              ),
              if (!showSingleStop) ...[
                Container(width: 2, height: 18, color: dividerColor),
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: AppColors.maroon,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  showSingleStop ? 'Passenger Pickup' : 'Pickup',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 9,
                    color: AppColors.textMuted,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1,
                  ),
                ),
                Text(
                  line1,
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (!showSingleStop) ...[
                  const SizedBox(height: 6),
                  Text(
                    line2,
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ],
            ),
          ),
          Text(
            time,
            style: GoogleFonts.plusJakartaSans(
              color: primary,
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Shared stat tile
// ─────────────────────────────────────────────────────────────────────────────

class _InfoTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final String value;
  final Color valueColor;

  const _InfoTile({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.value,
    required this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: iconColor, size: 19),
        const SizedBox(height: 3),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 1),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: GoogleFonts.plusJakartaSans(
            color: valueColor,
            fontWeight: FontWeight.w800,
            fontSize: 13,
          ),
        ),
      ],
    );
  }
}
