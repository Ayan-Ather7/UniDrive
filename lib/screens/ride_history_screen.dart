import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../theme/app_theme.dart';
import '../models/ride_history_entry.dart';
import '../models/ride_model.dart';
import '../services/database_service.dart';
import '../services/auth_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
// RideHistoryScreen
//
// Displays the logged-in user's unified ride history — both rides they drove
// (DRIVER) and rides they took as a passenger (PASSENGER) — streamed from
// Firestore via DatabaseService.streamUnifiedRideHistory().
//
// The header shows driver & passenger ratings pulled from the user profile doc.
// ─────────────────────────────────────────────────────────────────────────────

class RideHistoryScreen extends StatelessWidget {
  const RideHistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final uid = AuthService().currentUid ?? '';
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (uid.isEmpty) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBg : AppColors.lightBg,
      // ── Outer StreamBuilder: user profile (for rating chips) ─────────────
      body: StreamBuilder<DocumentSnapshot>(
        stream: DatabaseService().streamUserData(uid),
        builder: (context, userSnap) {
          final userData =
              userSnap.hasData && userSnap.data!.exists
                  ? userSnap.data!.data() as Map<String, dynamic>
                  : <String, dynamic>{};

          final ratingDriver =
              (userData['ratingAsDriver'] as num?)?.toDouble() ?? 5.0;
          final ratingPassenger =
              (userData['ratingAsPassenger'] as num?)?.toDouble() ?? 5.0;

          // ── Inner StreamBuilder: unified ride history ──────────────────
          return StreamBuilder<List<RideHistoryEntry>>(
            stream: DatabaseService().streamUnifiedRideHistory(uid),
            builder: (context, histSnap) {
              final entries = histSnap.data ?? <RideHistoryEntry>[];
              final isLoading =
                  histSnap.connectionState == ConnectionState.waiting &&
                      entries.isEmpty;

              return CustomScrollView(
                slivers: [
                  // ── App Bar ─────────────────────────────────────────────
                  SliverAppBar(
                    expandedHeight: 170,
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
                                const EdgeInsets.fromLTRB(24, 16, 24, 16),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.end,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Ride History',
                                  style: GoogleFonts.plusJakartaSans(
                                    color: Colors.white,
                                    fontSize: 24,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: -0.5,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 6,
                                  children: [
                                    _HeaderChip(
                                      icon: Icons.directions_car_rounded,
                                      label:
                                          '${entries.length} ride${entries.length != 1 ? 's' : ''}',
                                      color: AppColors.cyan,
                                    ),
                                    _HeaderChip(
                                      icon: Icons.star_rounded,
                                      label:
                                          '${ratingDriver.toStringAsFixed(1)} as Driver',
                                      color: AppColors.orange,
                                    ),
                                    _HeaderChip(
                                      icon: Icons.person_rounded,
                                      label:
                                          '${ratingPassenger.toStringAsFixed(1)} as Rider',
                                      color: AppColors.violet,
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),

                  // ── Loading ──────────────────────────────────────────────
                  if (isLoading)
                    const SliverFillRemaining(
                      child: Center(child: CircularProgressIndicator()),
                    )

                  // ── Empty ────────────────────────────────────────────────
                  else if (entries.isEmpty)
                    SliverFillRemaining(
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.directions_car_outlined,
                              size: 80,
                              color: AppColors.textMuted
                                  .withValues(alpha: 0.2),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'No rides yet',
                              style: GoogleFonts.plusJakartaSans(
                                color: AppColors.textMuted,
                                fontWeight: FontWeight.w700,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Your completed and cancelled\nrides will appear here.',
                              textAlign: TextAlign.center,
                              style: GoogleFonts.plusJakartaSans(
                                color: AppColors.textMuted,
                                fontWeight: FontWeight.w500,
                                fontSize: 13,
                                height: 1.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )

                  // ── Ride list ────────────────────────────────────────────
                  else
                    SliverPadding(
                      padding:
                          const EdgeInsets.fromLTRB(20, 20, 20, 32),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, i) => _RideCard(
                            entry: entries[i],
                            isDark: isDark,
                          )
                              .animate()
                              .fadeIn(
                                  delay: Duration(milliseconds: 70 * i))
                              .slideY(begin: 0.08),
                          childCount: entries.length,
                        ),
                      ),
                    ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Header chip
// ─────────────────────────────────────────────────────────────────────────────

class _HeaderChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  const _HeaderChip(
      {required this.icon, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 5),
          Text(
            label,
            style: GoogleFonts.plusJakartaSans(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Ride card
// ─────────────────────────────────────────────────────────────────────────────

class _RideCard extends StatelessWidget {
  final RideHistoryEntry entry;
  final bool isDark;
  const _RideCard({required this.entry, required this.isDark});

  Color get _statusColor => switch (entry.status) {
        RideStatus.upcoming => AppColors.blue,
        RideStatus.active => AppColors.success,
        RideStatus.completed => AppColors.textMuted,
        RideStatus.cancelled => AppColors.maroonLight,
      };

  String get _statusLabel => switch (entry.status) {
        RideStatus.upcoming => 'Scheduled',
        RideStatus.active => 'Active',
        RideStatus.completed => 'Completed',
        RideStatus.cancelled => 'Cancelled',
      };

  Color get _roleColor =>
      entry.role == RideRole.driver ? AppColors.orange : AppColors.blue;

  String get _roleLabel =>
      entry.role == RideRole.driver ? 'DRIVER' : 'PASSENGER';

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
            color: isDark
                ? Colors.white.withValues(alpha: 0.05)
                : const Color(0xFFE5E7EB)),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.07),
              blurRadius: 12,
              offset: const Offset(0, 4))
        ],
      ),
      child: Column(
        children: [
          // ── Top row: role + date + status ─────────────────────────────
          Row(
            children: [
              // Role badge
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: _roleColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                  border:
                      Border.all(color: _roleColor.withValues(alpha: 0.35)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      entry.role == RideRole.driver
                          ? Icons.drive_eta_rounded
                          : Icons.airline_seat_recline_normal_rounded,
                      size: 11,
                      color: _roleColor,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      _roleLabel,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 9,
                        letterSpacing: 0.8,
                        color: _roleColor,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${entry.formattedDate} · ${entry.formattedTime}',
                  style: GoogleFonts.plusJakartaSans(
                      fontSize: 12,
                      color: AppColors.textMuted,
                      fontWeight: FontWeight.w600),
                ),
              ),
              // Status badge
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: _statusColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  _statusLabel.toUpperCase(),
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 9,
                    letterSpacing: 1,
                    color: _statusColor,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // ── Route + fare ─────────────────────────────────────────────
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Timeline dots
              Column(
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: const BoxDecoration(
                        color: AppColors.success,
                        shape: BoxShape.circle),
                  ),
                  Container(
                      width: 2,
                      height: 26,
                      color: AppColors.darkBorder),
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                        color: AppColors.maroon,
                        borderRadius: BorderRadius.circular(3)),
                  ),
                ],
              ),
              const SizedBox(width: 14),
              // Addresses
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      entry.from,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: isDark
                            ? AppColors.textPrimaryDark
                            : AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      entry.to,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: isDark
                            ? AppColors.textPrimaryDark
                            : AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              // Fare
              Text(
                'PKR ${entry.fare.toStringAsFixed(0)}',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 15,
                  color: AppColors.orange,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
