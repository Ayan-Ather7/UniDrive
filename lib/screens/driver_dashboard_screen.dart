import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../theme/app_theme.dart';
import '../services/database_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
// DriverDashboardScreen
//
// Displayed immediately after a driver creates a ride. Streams the live ride
// document and all bookings, letting the driver see who has joined, and
// providing Cancel and Close Offer actions.
// ─────────────────────────────────────────────────────────────────────────────

class DriverDashboardScreen extends StatelessWidget {
  final String rideId;
  const DriverDashboardScreen({super.key, required this.rideId});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final db     = DatabaseService();

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBg : AppColors.lightBg,
      // Stream the ride document itself
      body: StreamBuilder<DocumentSnapshot>(
        stream: db.streamRide(rideId),
        builder: (context, rideSnap) {
          if (!rideSnap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final ride   = rideSnap.data!;
          if (!ride.exists) {
            // Ride was deleted (e.g. cancelled)
            return _CancelledState(onBack: () => Navigator.pop(context));
          }

          final data          = ride.data() as Map<String, dynamic>;
          final status        = data['status'] as String? ?? 'Open';
          final availSeats    = data['availableSeats'] as int? ?? 4;
          final isPinkRide    = data['isPinkRide'] as bool? ?? false;
          final originAddr    = data['origin']?['address'] as String? ?? '—';
          final destAddr      = data['destination']?['address'] as String? ?? '—';
          final depTime       = data['departureTime'] as Timestamp?;
          final expiresAt     = data['expiresAt'] as Timestamp?;

          final depLabel = depTime != null
              ? TimeOfDay.fromDateTime(depTime.toDate()).format(context)
              : '—';

          final isClosed = status == 'InProgress' || status == 'Cancelled';

          return CustomScrollView(
            slivers: [
              // ── Header app bar ───────────────────────────────────────────
              SliverAppBar(
                expandedHeight: 200,
                pinned: true,
                backgroundColor:
                    isDark ? AppColors.darkCard : AppColors.navy,
                leading: IconButton(
                  icon: const Icon(Icons.arrow_back_ios_new_rounded,
                      color: Colors.white, size: 20),
                  onPressed: () => Navigator.pop(context),
                ),
                flexibleSpace: FlexibleSpaceBar(
                  background: Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [AppColors.navy, AppColors.maroon],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                    child: SafeArea(
                      child: Padding(
                        padding:
                            const EdgeInsets.fromLTRB(20, 16, 20, 16),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.end,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                // Status badge
                                _StatusBadge(status: status),
                                if (isPinkRide) ...[
                                  const SizedBox(width: 8),
                                  _PinkBadge(),
                                ],
                              ],
                            ),
                            const SizedBox(height: 10),
                            Text(
                              isClosed
                                  ? 'Offer Closed'
                                  : 'Finding Passengers…',
                              style: GoogleFonts.plusJakartaSans(
                                color: Colors.white,
                                fontSize: 22,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.5,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '$originAddr → $destAddr',
                              style: GoogleFonts.plusJakartaSans(
                                color: Colors.white70,
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              // ── Info row ─────────────────────────────────────────────────
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                  child: Row(
                    children: [
                      _InfoChip(
                          icon: Icons.schedule_rounded,
                          label: depLabel,
                          color: AppColors.blue),
                      const SizedBox(width: 10),
                      _InfoChip(
                          icon: Icons.airline_seat_recline_normal_rounded,
                          label: '$availSeats seats offered',
                          color: AppColors.cyan),
                      if (expiresAt != null) ...[
                        const SizedBox(width: 10),
                        _ExpiryChip(expiresAt: expiresAt),
                      ],
                    ],
                  ).animate().fadeIn(delay: 100.ms).slideY(begin: 0.1),
                ),
              ),

              // ── Passenger list ───────────────────────────────────────────
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 8),
                  child: Text(
                    'PASSENGERS',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textMuted,
                      letterSpacing: 1.5,
                    ),
                  ),
                ),
              ),

              StreamBuilder<QuerySnapshot>(
                stream: db.streamBookingsForRide(rideId),
                builder: (context, bookSnap) {
                  if (!bookSnap.hasData) {
                    return const SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.all(32),
                        child: Center(child: CircularProgressIndicator()),
                      ),
                    );
                  }

                  final bookings = bookSnap.data!.docs;

                  if (bookings.isEmpty) {
                    return SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 32),
                        child: Center(
                          child: Column(
                            children: [
                              Icon(Icons.person_search_rounded,
                                  size: 64,
                                  color: AppColors.textMuted
                                      .withValues(alpha: 0.25)),
                              const SizedBox(height: 12),
                              Text('No passengers yet',
                                  style: GoogleFonts.plusJakartaSans(
                                    color: AppColors.textMuted,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 14,
                                  )),
                              const SizedBox(height: 4),
                              Text(
                                  'Nearby students will see your offer automatically.',
                                  style: GoogleFonts.plusJakartaSans(
                                    color: AppColors.textMuted,
                                    fontSize: 12,
                                  ),
                                  textAlign: TextAlign.center),
                            ],
                          ),
                        ),
                      ),
                    );
                  }

                  return SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, i) {
                        final bData = bookings[i].data()
                            as Map<String, dynamic>;
                        final passengerId =
                            bData['passengerId'] as String? ?? '';
                        final bookingStatus =
                            bData['status'] as String? ?? 'Pending';

                        return _PassengerCard(
                          passengerId: passengerId,
                          bookingStatus: bookingStatus,
                          bookingId: bookings[i].id,
                          isDark: isDark,
                        )
                            .animate()
                            .fadeIn(
                                delay:
                                    Duration(milliseconds: 80 * i))
                            .slideY(begin: 0.1);
                      },
                      childCount: bookings.length,
                    ),
                  );
                },
              ),

              // ── Action buttons ───────────────────────────────────────────
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 36),
                  child: Column(
                    children: [
                      // Close Offer button (only when still Open)
                      if (!isClosed)
                        SizedBox(
                          width: double.infinity,
                          height: 52,
                          child: ElevatedButton.icon(
                            onPressed: () =>
                                _closeOffer(context, rideId, db),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.blue,
                              shape: RoundedRectangleBorder(
                                  borderRadius:
                                      BorderRadius.circular(16)),
                            ),
                            icon: const Icon(Icons.lock_clock_rounded,
                                size: 18),
                            label: Text(
                              'Close Offer & Start Ride',
                              style: GoogleFonts.plusJakartaSans(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 15),
                            ),
                          ),
                        ).animate().fadeIn(delay: 200.ms),

                      const SizedBox(height: 12),

                      // Cancel Ride button
                      if (status != 'Cancelled')
                        SizedBox(
                          width: double.infinity,
                          height: 52,
                          child: OutlinedButton.icon(
                            onPressed: () =>
                                _cancelRide(context, rideId, db),
                            style: OutlinedButton.styleFrom(
                              side: BorderSide(
                                  color: AppColors.maroon
                                      .withValues(alpha: 0.6)),
                              shape: RoundedRectangleBorder(
                                  borderRadius:
                                      BorderRadius.circular(16)),
                            ),
                            icon: const Icon(Icons.cancel_outlined,
                                size: 18, color: AppColors.maroonLight),
                            label: Text(
                              'Cancel Ride',
                              style: GoogleFonts.plusJakartaSans(
                                color: AppColors.maroonLight,
                                fontWeight: FontWeight.w700,
                                fontSize: 15,
                              ),
                            ),
                          ),
                        ).animate().fadeIn(delay: 260.ms),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _closeOffer(
      BuildContext context, String rideId, DatabaseService db) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Close Offer?',
            style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800)),
        content: Text(
          'No new passengers will be able to join. Current passengers will remain on the ride.',
          style: GoogleFonts.plusJakartaSans(),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Back')),
          ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style:
                  ElevatedButton.styleFrom(backgroundColor: AppColors.blue),
              child: const Text('Close & Start')),
        ],
      ),
    );
    if (confirmed == true && context.mounted) {
      await db.closeRideOffer(rideId);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Offer closed — ride is now in progress.'),
        backgroundColor: AppColors.blue,
        behavior: SnackBarBehavior.floating,
      ));
    }
  }

  Future<void> _cancelRide(
      BuildContext context, String rideId, DatabaseService db) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Cancel Ride?',
            style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800)),
        content: Text(
          'This will remove the ride for all passengers. This action cannot be undone.',
          style: GoogleFonts.plusJakartaSans(),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Back')),
          ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style:
                  ElevatedButton.styleFrom(backgroundColor: AppColors.maroon),
              child: const Text('Cancel Ride')),
        ],
      ),
    );
    if (confirmed == true && context.mounted) {
      await db.cancelRide(rideId);
      if (!context.mounted) return;
      Navigator.pop(context); // go back to home
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Passenger card — fetches the passenger's Firestore name
// ─────────────────────────────────────────────────────────────────────────────

class _PassengerCard extends StatelessWidget {
  final String passengerId;
  final String bookingStatus;
  final String bookingId;
  final bool isDark;

  const _PassengerCard({
    required this.passengerId,
    required this.bookingStatus,
    required this.bookingId,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
      child: StreamBuilder<DocumentSnapshot>(
        stream:
            DatabaseService().streamUserData(passengerId),
        builder: (context, snap) {
          final data = snap.hasData && snap.data!.exists
              ? snap.data!.data() as Map<String, dynamic>
              : <String, dynamic>{};
          final name = data['name'] as String? ?? 'Passenger';
          final isVerified = data['isVerified'] == true;

          final statusColor = bookingStatus == 'Accepted'
              ? AppColors.success
              : AppColors.orange;
          final statusLabel =
              bookingStatus == 'Accepted' ? 'Accepted' : 'Pending';

          return Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkCard : Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.06)
                      : const Color(0xFFE5E7EB)),
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withValues(alpha: 0.06),
                    blurRadius: 10,
                    offset: const Offset(0, 4)),
              ],
            ),
            child: Row(
              children: [
                // Avatar
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: AppColors.cyan.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.cyan, width: 1.5),
                  ),
                  child: const Icon(Icons.person_rounded,
                      color: AppColors.cyan, size: 24),
                ),
                const SizedBox(width: 14),

                // Name + verified
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            name,
                            style: GoogleFonts.plusJakartaSans(
                              fontWeight: FontWeight.w800,
                              fontSize: 14,
                              color: isDark
                                  ? AppColors.textPrimaryDark
                                  : AppColors.textPrimary,
                            ),
                          ),
                          if (isVerified) ...[
                            const SizedBox(width: 5),
                            const Icon(Icons.verified_rounded,
                                size: 13, color: AppColors.cyan),
                          ],
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        passengerId.substring(0, 8).toUpperCase(),
                        style: GoogleFonts.plusJakartaSans(
                            fontSize: 10,
                            color: AppColors.textMuted,
                            fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),

                // Status badge
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    statusLabel.toUpperCase(),
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: statusColor,
                      letterSpacing: 1,
                    ),
                  ),
                ),

                // Accept/Reject buttons (if Pending)
                if (bookingStatus == 'Pending') ...[
                  const SizedBox(width: 8),
                  _ActionBtn(
                    icon: Icons.check_rounded,
                    color: AppColors.success,
                    onTap: () => DatabaseService()
                        .updateBookingStatus(bookingId, 'Accepted'),
                  ),
                  const SizedBox(width: 6),
                  _ActionBtn(
                    icon: Icons.close_rounded,
                    color: AppColors.maroonLight,
                    onTap: () => DatabaseService()
                        .updateBookingStatus(bookingId, 'Rejected'),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}

class _ActionBtn extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  const _ActionBtn(
      {required this.icon, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, size: 16, color: color),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Helper widgets
// ─────────────────────────────────────────────────────────────────────────────

class _StatusBadge extends StatelessWidget {
  final String status;
  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      'Open'       => AppColors.success,
      'InProgress' => AppColors.blue,
      'Cancelled'  => AppColors.maroonLight,
      _            => AppColors.textMuted,
    };
    final label = switch (status) {
      'Open'       => 'OPEN',
      'InProgress' => 'IN PROGRESS',
      'Cancelled'  => 'CANCELLED',
      _            => status.toUpperCase(),
    };
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(20),
        border:
            Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                  color: color, shape: BoxShape.circle)),
          const SizedBox(width: 6),
          Text(label,
              style: GoogleFonts.plusJakartaSans(
                  color: color,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1)),
        ],
      ),
    );
  }
}

class _PinkBadge extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.pink.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.pink.withValues(alpha: 0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.female_rounded, size: 12, color: AppColors.pink),
          const SizedBox(width: 4),
          Text('Pink Ride',
              style: GoogleFonts.plusJakartaSans(
                  color: AppColors.pink,
                  fontSize: 10,
                  fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  const _InfoChip(
      {required this.icon, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 5),
          Text(label,
              style: GoogleFonts.plusJakartaSans(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: color)),
        ],
      ),
    );
  }
}

class _ExpiryChip extends StatelessWidget {
  final Timestamp expiresAt;
  const _ExpiryChip({required this.expiresAt});

  @override
  Widget build(BuildContext context) {
    final remaining = expiresAt.toDate().difference(DateTime.now());
    final mins = remaining.inMinutes.clamp(0, 60);
    final expired = remaining.isNegative;
    final color = expired
        ? AppColors.maroonLight
        : (mins < 10 ? AppColors.orange : AppColors.textMuted);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.timer_outlined, size: 13, color: color),
          const SizedBox(width: 5),
          Text(
            expired ? 'Expired' : 'Expires in ${mins}m',
            style: GoogleFonts.plusJakartaSans(
                fontSize: 12, fontWeight: FontWeight.w700, color: color),
          ),
        ],
      ),
    );
  }
}

class _CancelledState extends StatelessWidget {
  final VoidCallback onBack;
  const _CancelledState({required this.onBack});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.cancel_outlined,
              size: 80,
              color: AppColors.maroonLight.withValues(alpha: 0.5)),
          const SizedBox(height: 16),
          Text('Ride Cancelled',
              style: GoogleFonts.plusJakartaSans(
                  fontSize: 20, fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          Text('This ride no longer exists.',
              style: GoogleFonts.plusJakartaSans(color: AppColors.textMuted)),
          const SizedBox(height: 24),
          ElevatedButton(
              onPressed: onBack,
              child: const Text('Go Back')),
        ],
      ),
    );
  }
}
