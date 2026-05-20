import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../theme/app_theme.dart';
import '../models/driver_model.dart';
import '../services/database_service.dart';
import '../services/auth_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../widgets/unidrive_logo.dart';
import '../widgets/verified_badge.dart';

// ── Payment model (Tasks 4 & 8) ──────────────────────────────────────────────
// Replaces the old `PaymentMethod` enum which had a defunct 'wallet' value
// and a hardcoded 'Visa 4242' card. Payment selection is now fully dynamic:
//  • Cash is always available.
//  • Cards come from the passenger's Firestore paymentMethods subcollection.
//  • Card option is gated by whether the driver has saved cards (Task 8).

@immutable
class _SelectedPayment {
  final bool isCash;
  final String label;     // e.g. '•••• 4242'
  final String? docId;    // Firestore doc ID; null for cash

  const _SelectedPayment.cash()
      : isCash = true,
        label = 'Cash',
        docId = null;

  const _SelectedPayment.card({
    required this.label,
    required this.docId,
  }) : isCash = false;

  IconData get icon =>
      isCash ? Icons.payments_rounded : Icons.credit_card_rounded;
  Color get color => isCash ? AppColors.success : AppColors.orange;
  String get subtitle =>
      isCash ? 'Pay the driver directly' : 'Credit / Debit Card';
}

class RideMatchScreen extends StatefulWidget {
  const RideMatchScreen({super.key});
  @override
  State<RideMatchScreen> createState() => _RideMatchScreenState();
}

class _RideMatchScreenState extends State<RideMatchScreen> {
  bool _pinkOnly = false;
  int _selectedDriverIdx = 0;
  _SelectedPayment _selectedPayment = const _SelectedPayment.cash();

  void _requestRide(DriverModel driver) async {
    final uid = AuthService().currentUid;
    if (uid != null) {
      await DatabaseService().requestBooking(
        rideId: driver.id,
        passengerId: uid,
      );
      if (!mounted) return; // guard against async gap
      Navigator.pushNamed(context, '/accepted', arguments: driver);
    }
  }

  void _handlePinkToggle(bool canAccessPinkRide) {
    if (!canAccessPinkRide) {
      // Show access denied snackbar
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Pink Ride is available to Female students only.',
            style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600),
          ),
          backgroundColor: AppColors.maroon,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          margin: const EdgeInsets.all(16),
        ),
      );
      return;
    }
    setState(() => _pinkOnly = !_pinkOnly);
  }

  @override
  Widget build(BuildContext context) {
    final isDark   = Theme.of(context).brightness == Brightness.dark;
    final uid = AuthService().currentUid;

    return StreamBuilder<DocumentSnapshot>(
      stream: uid != null ? DatabaseService().streamUserData(uid) : null,
      builder: (context, userSnap) {
        bool canAccessPinkRide = false;
        if (userSnap.hasData && userSnap.data!.exists) {
          final data = userSnap.data!.data() as Map<String, dynamic>;
          canAccessPinkRide = data['gender'] == 'Female';
        }

        return Scaffold(
          backgroundColor: isDark ? AppColors.darkBg : AppColors.lightBg,
          appBar: AppBar(
            backgroundColor: isDark ? AppColors.darkBg : AppColors.lightBg,
            elevation: 0,
            leading: BackButton(color: isDark ? Colors.white : Colors.black),
            centerTitle: true,
            title: Column(
              children: [
                const UniDriveLogo(size: LogoSize.sm),
                Text('ELITE SELECTION',
                    style: GoogleFonts.plusJakartaSans(
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textMuted,
                        letterSpacing: 2.5)),
              ],
            ).animate().fadeIn(duration: 500.ms).slideY(begin: -0.2),
            actions: [
              // Pink ride filter — shows lock icon if user is not female
              IconButton(
                icon: Stack(
                  children: [
                    Icon(Icons.tune_rounded,
                        color: _pinkOnly
                            ? AppColors.pink
                            : isDark
                                ? Colors.white
                                : Colors.black),
                    if (!canAccessPinkRide)
                      Positioned(
                        right: 0,
                        bottom: 0,
                        child: Container(
                          width: 12,
                          height: 12,
                          decoration: const BoxDecoration(
                              color: AppColors.maroon, shape: BoxShape.circle),
                          child: const Icon(Icons.lock_rounded,
                              size: 8, color: Colors.white),
                        ),
                      ),
                  ],
                ),
                onPressed: () => _handlePinkToggle(canAccessPinkRide),
                tooltip: _pinkOnly ? 'Show All' : 'Pink Ride Only',
              ).animate().fadeIn(),
            ],
          ),
          body: StreamBuilder<QuerySnapshot>(
        stream: DatabaseService().streamAvailableRides(_pinkOnly),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
             return const Center(child: CircularProgressIndicator(color: AppColors.blue));
          }

          final drivers = snapshot.data!.docs.map((doc) {
             final data = doc.data() as Map<String, dynamic>;
             return DriverModel(
               id: doc.id,
               driverId: data['driverId'] as String? ?? doc.id,
               name: 'Driver ${doc.id.substring(0, 4)}',
               avatarUrl: '',
               carModel: 'Honda Civic',
               carColor: 'Silver',
               licensePlate: 'ABC-123',
               rating: 4.9,
               matchPercent: 95,
               perHeadFare: (data['currentFarePerPassenger'] ?? 300).toDouble(),
               availableSeats: data['availableSeats'] ?? 3,
               occupiedSeats: 3 - (data['availableSeats'] as int? ?? 3),
               from: data['origin']?['address'] ?? 'Current Location',
               to: data['destination']?['address'] ?? 'Destination',
               departureTime: data['departureTime'] != null ? (data['departureTime'] as Timestamp).toDate().toString() : 'Soon',
               isVerified: true,
               isPinkRide: data['isPinkRide'] ?? false,
               etaMinutes: 4,
               gender: data['isPinkRide'] == true ? 'female' : 'male',
             );
          }).toList();

          final featured = drivers.isNotEmpty
              ? drivers[_selectedDriverIdx.clamp(0, drivers.length - 1)]
              : null;

          if (featured == null) {
            return Center(
               child: Text('No drivers found',
                   style: GoogleFonts.plusJakartaSans(
                       color: AppColors.textMuted)));
          }

          return Column(
              children: [
                // ── Hero panel: compact 1/4 of screen (1:3 ratio) ──────
                SizedBox(
                  height: MediaQuery.of(context).size.height * 0.22,
                  child: _CarPanel(driver: featured, isDark: isDark),
                ),

                // ── Driver list: fills remaining 3/4 ───────────────────
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
                        child: Row(
                          children: [
                            Text('VERIFIED PARTNERS',
                                style: GoogleFonts.plusJakartaSans(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.textMuted,
                                    letterSpacing: 1.5)),
                            const Spacer(),
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                  color: AppColors.success,
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                        color: AppColors.success
                                            .withValues(alpha: 0.4),
                                        blurRadius: 6)
                                  ]),
                            ).animate(onPlay: (c) => c.repeat(reverse: true))
                                .scale(duration: 800.ms),
                            const SizedBox(width: 8),
                            Text('${drivers.length} Drivers Nearby',
                                style: GoogleFonts.plusJakartaSans(
                                    fontSize: 12,
                                    color: AppColors.success,
                                    fontWeight: FontWeight.w700)),
                          ],
                        ),
                      ).animate().fadeIn(delay: 300.ms),

                      // Pink ride banner
                      if (_pinkOnly)
                        Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 24, vertical: 4),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 8),
                            decoration: BoxDecoration(
                              color: AppColors.pink.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                  color:
                                      AppColors.pink.withValues(alpha: 0.3)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.female_rounded,
                                    color: AppColors.pink, size: 16),
                                const SizedBox(width: 6),
                                Text('Pink Ride Active — Female Drivers Only',
                                    style: GoogleFonts.plusJakartaSans(
                                        color: AppColors.pink,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w800)),
                              ],
                            ),
                          ),
                        ),

                      Expanded(
                        child: ListView.builder(
                          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                          itemCount: drivers.length,
                          itemBuilder: (_, i) => _DriverCard(
                            driver: drivers[i],
                            isDark: isDark,
                            isSelected: i ==
                                _selectedDriverIdx.clamp(
                                    0, drivers.length - 1),
                            selectedPayment: _selectedPayment,
                            onTap: () =>
                                setState(() => _selectedDriverIdx = i),
                            onRequest: () => _requestRide(drivers[i]),
                            onPaymentTap: () async {
                              final result =
                                  await showModalBottomSheet<_SelectedPayment>(
                                context: context,
                                backgroundColor: Colors.transparent,
                                isScrollControlled: true,
                                builder: (_) => _PaymentSheet(
                                  isDark: isDark,
                                  selected: _selectedPayment,
                                  passengerId: uid ?? '',
                                  driverId: drivers[i].driverId,
                                ),
                              );
                              if (result != null) {
                                setState(() => _selectedPayment = result);
                              }
                            },
                          ).animate().fadeIn(
                              delay: Duration(
                                  milliseconds: 300 + (100 * i))).slideX(begin: 0.1),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
        }
      ),
    );
   });
  }
}

// ── Featured car panel ────────────────────────────────────────────────────────

class _CarPanel extends StatelessWidget {
  final DriverModel driver;
  final bool isDark;
  const _CarPanel({required this.driver, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: isDark ? AppColors.darkCard : const Color(0xFF1C2333),
      child: Stack(
        children: [
          // Background glow
          Positioned(
            right: -30,
            top: -30,
            child: Container(
              width: 140,
              height: 140,
              decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.cyan.withValues(alpha: 0.08)),
            ),
          ).animate(onPlay: (c) => c.repeat(reverse: true))
              .moveX(end: 16, duration: 4.seconds),

          // Car icon — smaller to fit compact hero
          Center(
            child: Icon(Icons.directions_car_filled_rounded,
                    size: 64, color: Colors.white.withValues(alpha: 0.8))
                .animate(key: ValueKey(driver.id))
                .fadeIn(duration: 400.ms)
                .scale(begin: const Offset(0.9, 0.9)),
          ),

          // Gradient overlay
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.transparent,
                  Colors.black.withValues(alpha: 0.85),
                ],
              ),
            ),
          ),

          // Car meta row — tighter bottom padding for compact hero
          Positioned(
            bottom: 12,
            left: 20,
            right: 20,
            child: Row(
              children: [
                _MetaTile(label: 'MODEL', value: driver.carModel),
                const SizedBox(width: 24),
                _MetaTile(label: 'COLOR', value: driver.carColor),
                const Spacer(),
                _MetaTile(
                    label: 'RATING',
                    value: '${driver.rating} ★',
                    valueColor: Colors.amber,
                    alignRight: true),
              ],
            ),
          ).animate(key: ValueKey('meta_${driver.id}'))
              .fadeIn(duration: 400.ms)
              .slideY(begin: 0.2),
        ],
      ),
    );
  }
}

class _MetaTile extends StatelessWidget {
  final String label, value;
  final Color valueColor;
  final bool alignRight;
  const _MetaTile(
      {required this.label,
      required this.value,
      this.valueColor = Colors.white,
      this.alignRight = false});
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment:
          alignRight ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        Text(label,
            style: GoogleFonts.plusJakartaSans(
                fontSize: 9,
                color: Colors.white54,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.5)),
        const SizedBox(height: 2),
        Text(value,
            style: GoogleFonts.plusJakartaSans(
                fontSize: 13, color: valueColor, fontWeight: FontWeight.w800)),
      ],
    );
  }
}

// ── Driver card ───────────────────────────────────────────────────────────────

class _DriverCard extends StatelessWidget {
  final DriverModel driver;
  final bool isDark, isSelected;
  final VoidCallback onTap, onRequest, onPaymentTap;
  final _SelectedPayment selectedPayment;
  const _DriverCard({
    required this.driver,
    required this.isDark,
    required this.isSelected,
    required this.selectedPayment,
    required this.onTap,
    required this.onRequest,
    required this.onPaymentTap,
  });

  @override
  Widget build(BuildContext context) {
    final cardBg = isDark
        ? (isSelected ? AppColors.darkSurface : AppColors.darkCard)
        : Colors.white;
    final borderColor = isSelected
        ? AppColors.blue
        : isDark
            ? Colors.white.withValues(alpha: 0.05)
            : const Color(0xFFE5E7EB);

    // Dynamic per-person fare display
    final totalSeats      = driver.availableSeats;
    final occupied        = driver.occupiedSeats;
    final farePerPerson   = driver.farePerPerson;
    final fareLabel       = 'PKR ${farePerPerson.toStringAsFixed(0)}/person';
    final seatsLabel      = 'Seats $occupied/$totalSeats';
    final seatsRemaining  = totalSeats - occupied;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: borderColor, width: isSelected ? 1.5 : 1),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: AppColors.blue.withValues(alpha: 0.15),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  )
                ]
              : [
                  BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 10,
                      offset: const Offset(0, 4))
                ],
        ),
        child: Column(
          children: [
            Row(
              children: [
                // Avatar
                Stack(
                  children: [
                    CircleAvatar(
                      radius: 24,
                      backgroundColor: AppColors.blue.withValues(alpha: 0.15),
                      child: Icon(
                        driver.gender == 'female'
                            ? Icons.face_3_rounded
                            : Icons.face_rounded,
                        size: 26,
                        color: AppColors.blue,
                      ),
                    ),
                    if (driver.isVerified)
                      Positioned(
                        right: 0,
                        bottom: 0,
                        child: Container(
                          width: 16,
                          height: 16,
                          decoration: BoxDecoration(
                              color: AppColors.blue,
                              shape: BoxShape.circle,
                              border:
                                  Border.all(color: cardBg, width: 2)),
                          child: const Icon(Icons.check_rounded,
                              size: 9, color: Colors.white),
                        ),
                      ),
                  ],
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(driver.name,
                                style: GoogleFonts.plusJakartaSans(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 15,
                                    color: isDark
                                        ? AppColors.textPrimaryDark
                                        : AppColors.textPrimary)),
                          ),
                          // Pink ride badge only
                          if (driver.isPinkRide)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: AppColors.pink.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                    color:
                                        AppColors.pink.withValues(alpha: 0.35)),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.female_rounded,
                                      color: AppColors.pink, size: 11),
                                  const SizedBox(width: 3),
                                  Text('Pink Ride',
                                      style: GoogleFonts.plusJakartaSans(
                                          fontSize: 10,
                                          color: AppColors.pink,
                                          fontWeight: FontWeight.w800)),
                                ],
                              ),
                            ),
                        ],
                      ),
                      if (driver.isVerified)
                        const Padding(
                            padding: EdgeInsets.only(top: 4),
                            child: VerifiedBadge(compact: true)),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 14),

            // Stats row with seat + dynamic fare
            Row(
              children: [
                _Stat(
                    icon: Icons.schedule_rounded,
                    label: 'ETA',
                    value: '${driver.etaMinutes} mins',
                    color: AppColors.cyan),
                const SizedBox(width: 16),
                // Dynamic fare per-person
                _Stat(
                    icon: Icons.payments_rounded,
                    label: 'PER PERSON',
                    value: fareLabel,
                    color: AppColors.orange),
                const SizedBox(width: 16),
                // Seat occupancy indicator
                _Stat(
                    icon: Icons.airline_seat_recline_normal_rounded,
                    label: 'SEATS',
                    value: seatsLabel,
                    color: seatsRemaining <= 1
                        ? AppColors.maroonLight
                        : AppColors.success),
                const SizedBox(width: 16),
                _Stat(
                    icon: Icons.star_rounded,
                    label: 'RATING',
                    value: driver.rating.toStringAsFixed(1),
                    color: Colors.amber),
              ],
            ),

            // Occupied seats info chip (if someone is already sharing)
            if (occupied > 0)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.orange.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                        color: AppColors.orange.withValues(alpha: 0.25)),
                  ),
                  child: Text(
                    '$occupied student${occupied > 1 ? 's are' : ' is'} already sharing → fare '
                    'split by ${occupied + 1} = PKR ${farePerPerson.toStringAsFixed(0)}/person',
                    style: GoogleFonts.plusJakartaSans(
                        fontSize: 11,
                        color: AppColors.orange,
                        fontWeight: FontWeight.w600),
                  ),
                ),
              ),

            if (isSelected) ...[
              const SizedBox(height: 16),

              // Payment method selector
              _PaymentTile(
                payment: selectedPayment,
                isDark: isDark,
                onTap: onPaymentTap,
              ).animate().fadeIn(duration: 250.ms),

              const SizedBox(height: 12),

              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: onRequest,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('REQUEST RIDE',
                          style: GoogleFonts.plusJakartaSans(
                              fontWeight: FontWeight.w800, letterSpacing: 1.5)),
                      const SizedBox(width: 10),
                      const Icon(Icons.arrow_forward_rounded, size: 18),
                    ],
                  ),
                ),
              ).animate().fadeIn(duration: 200.ms).slideY(begin: 0.2),
            ],
          ],
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final IconData icon;
  final String label, value;
  final Color color;
  const _Stat(
      {required this.icon,
      required this.label,
      required this.value,
      required this.color});
  @override
  Widget build(BuildContext context) {
    return Flexible(
      child: Row(
        children: [
          Icon(icon, color: color, size: 14),
          const SizedBox(width: 4),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: GoogleFonts.plusJakartaSans(
                        fontSize: 8,
                        color: AppColors.textMuted,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.8)),
                const SizedBox(height: 1),
                Text(value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.plusJakartaSans(
                        fontSize: 11, color: color, fontWeight: FontWeight.w800)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Payment tile ──────────────────────────────────────────────────────────────

class _PaymentTile extends StatelessWidget {
  final _SelectedPayment payment;
  final bool isDark;
  final VoidCallback onTap;

  const _PaymentTile({
    required this.payment,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final border = payment.color.withValues(alpha: 0.35);

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: payment.color.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: border, width: 1.5),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: payment.color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(payment.icon, color: payment.color, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('PAYMENT METHOD',
                      style: GoogleFonts.plusJakartaSans(
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textMuted,
                          letterSpacing: 1.5)),
                  const SizedBox(height: 2),
                  Text(payment.label,
                      style: GoogleFonts.plusJakartaSans(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: payment.color)),
                ],
              ),
            ),
            Icon(Icons.expand_more_rounded,
                color: AppColors.textMuted, size: 20),
          ],
        ),
      ),
    );
  }
}

// ── Payment bottom sheet (Tasks 4 & 8) ───────────────────────────────────────
// • Streams passenger's saved cards from Firestore in real time
// • Streams driver's paymentMethods subcollection to gate card availability
// • Returns a _SelectedPayment via Navigator.pop(context, payment)

class _PaymentSheet extends StatefulWidget {
  final bool isDark;
  final _SelectedPayment selected;
  final String passengerId;
  final String driverId;

  const _PaymentSheet({
    required this.isDark,
    required this.selected,
    required this.passengerId,
    required this.driverId,
  });

  @override
  State<_PaymentSheet> createState() => _PaymentSheetState();
}

class _PaymentSheetState extends State<_PaymentSheet> {
  final _db = DatabaseService();

  @override
  Widget build(BuildContext context) {
    final bg = widget.isDark ? AppColors.darkCard : Colors.white;
    final textPrimary =
        widget.isDark ? AppColors.textPrimaryDark : AppColors.textPrimary;

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 24),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.25),
              blurRadius: 32,
              offset: const Offset(0, -8))
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Container(
            margin: const EdgeInsets.only(top: 12, bottom: 4),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.darkBorder,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
            child: Row(
              children: [
                Text('Select Payment',
                    style: GoogleFonts.plusJakartaSans(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: textPrimary,
                        letterSpacing: -0.3)),
                const Spacer(),
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Icon(Icons.close_rounded,
                      color: AppColors.textMuted, size: 22),
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),

          // ── Cash (always available) ──────────────────────────────
          _buildOption(
            payment: const _SelectedPayment.cash(),
            driverAcceptsCards: true, // cash never gated
            delay: 0,
          ),

          // ── Saved cards from Firestore ───────────────────────────
          // Check driver's cards first (Task 8), then show passenger cards
          StreamBuilder<QuerySnapshot>(
            stream: _db.streamDriverPaymentMethods(widget.driverId),
            builder: (ctx, driverSnap) {
              final driverHasCards = (driverSnap.data?.docs.isNotEmpty) ?? false;

              return StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('users')
                    .doc(widget.passengerId)
                    .collection('paymentMethods')
                    .snapshots(),
                builder: (ctx, passengerSnap) {
                  if (passengerSnap.connectionState ==
                      ConnectionState.waiting) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: Center(
                          child: SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2))),
                    );
                  }

                  final cards = passengerSnap.data?.docs ?? [];

                  if (cards.isEmpty) {
                    // Passenger has no saved cards
                    return Padding(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
                      child: Material(
                        color: Colors.transparent,
                        borderRadius: BorderRadius.circular(18),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(18),
                          onTap: () {
                            Navigator.pop(context);
                            Navigator.pushNamed(context, '/profile');
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 14),
                            decoration: BoxDecoration(
                              color: widget.isDark
                                  ? AppColors.darkBg
                                  : AppColors.bgGrey,
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(
                                  color: AppColors.blue
                                      .withValues(alpha: 0.3),
                                  style: BorderStyle.solid),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 44,
                                  height: 44,
                                  decoration: BoxDecoration(
                                    color: AppColors.blue
                                        .withValues(alpha: 0.1),
                                    borderRadius:
                                        BorderRadius.circular(12),
                                  ),
                                  child: const Icon(
                                      Icons.add_card_rounded,
                                      color: AppColors.blue,
                                      size: 22),
                                ),
                                const SizedBox(width: 16),
                                Text('+ Add a Card',
                                    style: GoogleFonts.plusJakartaSans(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.blue)),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  }

                  // Show each saved card
                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (int i = 0; i < cards.length; i++)
                        _buildOption(
                          payment: _SelectedPayment.card(
                            label: cards[i]['label'] as String? ??
                                '•••• ????',
                            docId: cards[i].id,
                          ),
                          driverAcceptsCards: driverHasCards,
                          delay: i + 1,
                        ),
                      if (!driverHasCards)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(
                              20, 4, 20, 0),
                          child: Row(
                            children: [
                              const Icon(Icons.info_outline_rounded,
                                  size: 14,
                                  color: AppColors.textMuted),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  'This driver accepts cash only.',
                                  style: GoogleFonts.plusJakartaSans(
                                      fontSize: 11,
                                      color: AppColors.textMuted,
                                      fontWeight: FontWeight.w500),
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  );
                },
              );
            },
          ),

          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildOption({
    required _SelectedPayment payment,
    required bool driverAcceptsCards,
    required int delay,
  }) {
    final isCard = !payment.isCash;
    final disabled = isCard && !driverAcceptsCards;
    final isSelected = !disabled &&
        (widget.selected.isCash == payment.isCash &&
            widget.selected.docId == payment.docId);
    final surfaceBg =
        widget.isDark ? AppColors.darkBg : AppColors.bgGrey;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Opacity(
        opacity: disabled ? 0.4 : 1.0,
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(18),
          child: InkWell(
            onTap: disabled
                ? null
                : () => Navigator.pop(context, payment),
            borderRadius: BorderRadius.circular(18),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeOutCubic,
              padding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: isSelected
                    ? payment.color.withValues(alpha: 0.08)
                    : surfaceBg,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: isSelected
                      ? payment.color.withValues(alpha: 0.5)
                      : Colors.transparent,
                  width: 1.5,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: payment.color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(payment.icon,
                        color: payment.color, size: 22),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(payment.label,
                            style: GoogleFonts.plusJakartaSans(
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                                color: isSelected
                                    ? payment.color
                                    : (widget.isDark
                                        ? AppColors.textPrimaryDark
                                        : AppColors.textPrimary))),
                        const SizedBox(height: 2),
                        Text(payment.subtitle,
                            style: GoogleFonts.plusJakartaSans(
                                fontSize: 12,
                                color: AppColors.textMuted,
                                fontWeight: FontWeight.w500)),
                      ],
                    ),
                  ),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    child: isSelected
                        ? Container(
                            key: const ValueKey('check'),
                            width: 24,
                            height: 24,
                            decoration: BoxDecoration(
                              color: payment.color,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.check_rounded,
                                size: 14, color: Colors.white),
                          )
                        : Container(
                            key: const ValueKey('empty'),
                            width: 24,
                            height: 24,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                  color: AppColors.darkBorder,
                                  width: 1.5),
                            ),
                          ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ).animate().fadeIn(
        delay: Duration(milliseconds: 80 * delay));
  }
}


