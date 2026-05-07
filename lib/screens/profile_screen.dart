import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../theme/app_theme.dart';
import '../models/ride_model.dart';
import '../main.dart';
import '../services/database_service.dart';
import '../services/auth_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});
  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  // Key used to trigger RefreshIndicator programmatically if needed
  final _refreshKey = GlobalKey<RefreshIndicatorState>();

  // Cached ride list rebuilt on every refresh / snapshot update
  List<RideModel> _rides = [];
  bool _ridesLoaded = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final appState = UniDriveApp.of(context);

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBg : AppColors.lightBg,
      body: RefreshIndicator(
        key: _refreshKey,
        color: AppColors.blue,
        onRefresh: () async {
          // Force a brief delay so the spinner is visible, then rebuild
          await Future.delayed(const Duration(milliseconds: 600));
          setState(() {});
        },
        child: NestedScrollView(
        headerSliverBuilder: (context, _) => [
          SliverAppBar(
            expandedHeight: 230,
            pinned: true,
            backgroundColor: isDark ? AppColors.darkCard : Colors.white,
            leading: const BackButton(color: Colors.white),
            actions: [
              IconButton(
                icon: Icon(
                    isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
                    color: Colors.white),
                onPressed: () => appState?.toggleTheme(),
              ),
              const SizedBox(width: 8),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: isDark
                        ? [AppColors.darkBg, AppColors.darkCard]
                        : [AppColors.navy, const Color(0xFF1A52A8)],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
                child: SafeArea(
                  child: StreamBuilder<DocumentSnapshot>(
                    stream: AuthService().currentUid != null
                        ? DatabaseService().streamUserData(
                            AuthService().currentUid!)
                        : null,
                    builder: (context, snapshot) {
                      String name = 'Loading...';
                      bool isVerified = false;

                      if (snapshot.hasData && snapshot.data!.exists) {
                        final data =
                            snapshot.data!.data() as Map<String, dynamic>;
                        name = data['name'] ?? 'Student';
                        isVerified = data['isVerified'] == true;
                      } else if (snapshot.connectionState ==
                          ConnectionState.waiting) {
                        name = 'Loading...';
                      }

                      // Derive ride count and rating from the loaded list
                      final rideCount = _ridesLoaded ? _rides.length : null;
                      final avgRating = (_ridesLoaded && _rides.isNotEmpty)
                          ? (_rides.fold(0.0, (s, r) => s + r.rating) /
                              _rides.length)
                          : null;

                      return Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const SizedBox(height: 16),
                          Container(
                            width: 84,
                            height: 84,
                            decoration: BoxDecoration(
                              color: AppColors.cyan.withValues(alpha: 0.15),
                              shape: BoxShape.circle,
                              border:
                                  Border.all(color: AppColors.cyan, width: 2),
                              boxShadow: [
                                BoxShadow(
                                  color:
                                      AppColors.cyan.withValues(alpha: 0.2),
                                  blurRadius: 20,
                                  offset: const Offset(0, 8),
                                )
                              ],
                            ),
                            child: const Icon(Icons.person_rounded,
                                size: 46, color: Colors.white),
                          ).animate().scale(
                              curve: Curves.easeOutBack, duration: 600.ms),
                          const SizedBox(height: 12),
                          Text(name,
                                  style: GoogleFonts.plusJakartaSans(
                                      color: Colors.white,
                                      fontSize: 22,
                                      letterSpacing: -0.5,
                                      fontWeight: FontWeight.w800))
                              .animate()
                              .fadeIn(delay: 200.ms),
                          const SizedBox(height: 4),
                          // Verified badge — ONLY shown when isVerified = true
                          if (isVerified)
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.verified_rounded,
                                    color: AppColors.cyan, size: 15),
                                const SizedBox(width: 5),
                                Text('Verified Student',
                                    style: GoogleFonts.plusJakartaSans(
                                        color: Colors.white70,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600)),
                              ],
                            ).animate().fadeIn(delay: 300.ms),
                          const SizedBox(height: 14),
                          // Live stats from Firestore data
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              _QuickStat(
                                value: rideCount != null
                                    ? '$rideCount'
                                    : '0',
                                label: 'Rides',
                              ),
                              _QuickStat(
                                value: avgRating != null
                                    ? '${avgRating.toStringAsFixed(1)}★'
                                    : 'N/A',
                                label: 'Rating',
                                valueCol:
                                    avgRating != null ? Colors.amber : null,
                              ),
                            ],
                          ).animate().fadeIn(delay: 400.ms).slideY(begin: 0.2),
                        ],
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
        ],
        body: ListView(
          children: [
            // ── Ride History ─────────────────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 12),
              child: Text('RIDE HISTORY',
                  style: GoogleFonts.plusJakartaSans(
                      fontSize: 11, fontWeight: FontWeight.w800,
                      color: AppColors.textMuted, letterSpacing: 1.5)),
            ),
            StreamBuilder<QuerySnapshot>(
              stream: DatabaseService().streamPastRides(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Padding(
                      padding: EdgeInsets.all(32),
                      child: Center(child: CircularProgressIndicator()));
                }
                final rides = snapshot.data!.docs.map((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  return RideModel(
                    id: doc.id,
                    driverId: data['driverId'] ?? '',
                    driverName: 'Driver ${doc.id.substring(0, 4)}',
                    from: data['origin']?['address'] ?? 'Origin',
                    to: data['destination']?['address'] ?? 'Destination',
                    date: 'Today',
                    time: data['departureTime'] != null
                        ? '${(data['departureTime'] as Timestamp).toDate().hour}:${(data['departureTime'] as Timestamp).toDate().minute}'
                        : 'Soon',
                    fare: (data['currentFarePerPassenger'] ?? 0).toDouble(),
                    status: data['status'] == 'Completed'
                        ? RideStatus.completed
                        : RideStatus.cancelled,
                    rating: 5.0,
                  );
                }).toList();
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted && (_rides.length != rides.length || !_ridesLoaded)) {
                    setState(() { _rides = rides; _ridesLoaded = true; });
                  }
                });
                if (rides.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 32),
                    child: Center(
                      child: Column(
                        children: [
                          Icon(Icons.directions_car_outlined, size: 64,
                              color: AppColors.textMuted.withValues(alpha: 0.2)),
                          const SizedBox(height: 12),
                          Text('No rides yet', style: GoogleFonts.plusJakartaSans(
                              color: AppColors.textMuted, fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ),
                  );
                }
                return Column(
                  children: rides.asMap().entries.map((e) =>
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                      child: _RideCard(ride: e.value, isDark: isDark)
                          .animate().fadeIn(delay: Duration(milliseconds: 120 * e.key)).slideY(begin: 0.1),
                    )
                  ).toList(),
                );
              },
            ),

            // ── Vehicle Details ────────────────────────────────────────────────────────────
            if (AuthService().currentUid != null)
              _VehicleSection(uid: AuthService().currentUid!, isDark: isDark),

            // ── Payment Methods ──────────────────────────────────────────────────────────
            if (AuthService().currentUid != null)
              _PaymentSection(uid: AuthService().currentUid!, isDark: isDark),

            const SizedBox(height: 32),
          ],
        ),
      ),
      ),
    );
  }
}

class _QuickStat extends StatelessWidget {
  final String value, label;
  final Color? valueCol;
  const _QuickStat({required this.value, required this.label, this.valueCol});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Column(
        children: [
          Text(value,
              style: GoogleFonts.plusJakartaSans(
                  color: valueCol ?? Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 18)),
          const SizedBox(height: 2),
          Text(label,
              style: GoogleFonts.plusJakartaSans(
                  color: Colors.white60,
                  fontSize: 11,
                  fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class _RideList extends StatefulWidget {
  final List<RideModel> rides;
  final bool isDark;
  const _RideList({required this.rides, required this.isDark});

  @override
  State<_RideList> createState() => _RideListState();
}

class _RideListState extends State<_RideList>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final rides = widget.rides;
    final isDark = widget.isDark;
    if (rides.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.directions_car_outlined,
                size: 80,
                color: AppColors.textMuted.withValues(alpha: 0.2)),
            const SizedBox(height: 16),
            Text('No rides yet',
                style: GoogleFonts.plusJakartaSans(
                    color: AppColors.textMuted, fontWeight: FontWeight.w600)),
          ],
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      itemCount: rides.length,
      itemBuilder: (_, i) => RepaintBoundary(
        child: _RideCard(ride: rides[i], isDark: isDark)
            .animate()
            .fadeIn(delay: Duration(milliseconds: 150 * i))
            .slideY(begin: 0.1),
      ),
    );
  }
}

class _RideCard extends StatelessWidget {
  final RideModel ride;
  final bool isDark;
  const _RideCard({required this.ride, required this.isDark});

  Color get _statusColor => switch (ride.status) {
        RideStatus.upcoming => AppColors.blue,
        RideStatus.active => AppColors.success,
        RideStatus.completed => AppColors.textMuted,
        RideStatus.cancelled => AppColors.maroonLight,
      };

  String get _statusLabel => switch (ride.status) {
        RideStatus.upcoming => 'Scheduled',
        RideStatus.active => 'Active',
        RideStatus.completed => 'Completed',
        RideStatus.cancelled => 'Cancelled',
      };

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
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 12,
              offset: const Offset(0, 4))
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppColors.blue.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.directions_car_filled_rounded,
                    color: AppColors.blue, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(ride.driverName,
                        style: GoogleFonts.plusJakartaSans(
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                          color: isDark
                              ? AppColors.textPrimaryDark
                              : AppColors.textPrimary,
                        )),
                    const SizedBox(height: 2),
                    Text('${ride.date} · ${ride.time}',
                        style: GoogleFonts.plusJakartaSans(
                            fontSize: 12,
                            color: AppColors.textMuted,
                            fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: _statusColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(_statusLabel.toUpperCase(),
                    style: GoogleFonts.plusJakartaSans(
                        fontSize: 10,
                        letterSpacing: 1,
                        color: _statusColor,
                        fontWeight: FontWeight.w800)),
              ),
            ],
          ),
          const SizedBox(height: 20),
          // Route
          Row(
            children: [
              Column(
                children: [
                  Container(
                      width: 10,
                      height: 10,
                      decoration: const BoxDecoration(
                          color: AppColors.success, shape: BoxShape.circle)),
                  Container(
                      width: 2, height: 28, color: AppColors.darkBorder),
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                        color: AppColors.maroon,
                        borderRadius: BorderRadius.circular(3)),
                  ),
                ],
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(ride.from,
                        style: GoogleFonts.plusJakartaSans(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: isDark
                                ? AppColors.textPrimaryDark
                                : AppColors.textPrimary)),
                    const SizedBox(height: 16),
                    Text(ride.to,
                        style: GoogleFonts.plusJakartaSans(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: isDark
                                ? AppColors.textPrimaryDark
                                : AppColors.textPrimary)),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('PKR ${ride.fare.toStringAsFixed(0)}',
                      style: GoogleFonts.plusJakartaSans(
                          fontSize: 16,
                          color: AppColors.orange,
                          fontWeight: FontWeight.w800)),
                  const SizedBox(height: 4),
                  if (ride.rating > 0)
                    Row(
                      children: [
                        const Icon(Icons.star_rounded,
                            size: 14, color: Colors.amber),
                        const SizedBox(width: 4),
                        Text(ride.rating.toStringAsFixed(1),
                            style: GoogleFonts.plusJakartaSans(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textMuted)),
                      ],
                    ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Vehicle Details Section
// ─────────────────────────────────────────────────────────────────────────────

class _VehicleSection extends StatefulWidget {
  final String uid;
  final bool isDark;
  const _VehicleSection({required this.uid, required this.isDark});

  @override
  State<_VehicleSection> createState() => _VehicleSectionState();
}

class _VehicleSectionState extends State<_VehicleSection> {
  final _makeCtrl   = TextEditingController();
  final _modelCtrl  = TextEditingController();
  final _colorCtrl  = TextEditingController();
  final _plateCtrl  = TextEditingController();
  bool _saving = false;
  bool _editing = false;

  @override
  void dispose() {
    _makeCtrl.dispose(); _modelCtrl.dispose();
    _colorCtrl.dispose(); _plateCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await DatabaseService().saveVehicleProfile(widget.uid,
        make: _makeCtrl.text.trim(),
        model: _modelCtrl.text.trim(),
        color: _colorCtrl.text.trim(),
        licensePlate: _plateCtrl.text.trim(),
      );
      if (mounted) setState(() => _editing = false);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark   = widget.isDark;
    final cardBg   = isDark ? AppColors.darkCard : Colors.white;
    final textColor = isDark ? AppColors.textPrimaryDark : AppColors.textPrimary;
    final fieldFill = isDark ? AppColors.darkSurface : AppColors.bgGrey;

    return StreamBuilder<DocumentSnapshot>(
      stream: DatabaseService().streamVehicleProfile(widget.uid),
      builder: (context, snap) {
        final data = snap.hasData && snap.data!.exists
            ? snap.data!.data() as Map<String, dynamic>
            : <String, dynamic>{};
        final v = data['vehicle'] as Map<String, dynamic>?;

        if (!_editing && v != null) {
          _makeCtrl.text  = v['make']  ?? '';
          _modelCtrl.text = v['model'] ?? '';
          _colorCtrl.text = v['color'] ?? '';
          _plateCtrl.text = v['licensePlate'] ?? '';
        }

        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: isDark
                  ? Colors.white.withValues(alpha: 0.06)
                  : const Color(0xFFE5E7EB)),
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06),
                  blurRadius: 12, offset: const Offset(0, 4))],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 36, height: 36,
                      decoration: BoxDecoration(
                        color: AppColors.blue.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.directions_car_rounded,
                          color: AppColors.blue, size: 18),
                    ),
                    const SizedBox(width: 12),
                    Text('VEHICLE DETAILS',
                        style: GoogleFonts.plusJakartaSans(
                            fontSize: 11, fontWeight: FontWeight.w800,
                            color: AppColors.textMuted, letterSpacing: 1.5)),
                    const Spacer(),
                    TextButton(
                      onPressed: () => setState(() => _editing = !_editing),
                      child: Text(_editing ? 'Cancel' : (v == null ? 'Add' : 'Edit'),
                          style: GoogleFonts.plusJakartaSans(
                              color: AppColors.blue, fontWeight: FontWeight.w700)),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                if (!_editing && v == null)
                  Center(
                    child: Text('No vehicle added yet.',
                        style: GoogleFonts.plusJakartaSans(
                            color: AppColors.textMuted, fontSize: 13)),
                  )
                else if (!_editing && v != null)
                  // Read-only display
                  Column(
                    children: [
                      _VehicleRow(label: 'Make',    value: v['make']  ?? '—', isDark: isDark),
                      _VehicleRow(label: 'Model',   value: v['model'] ?? '—', isDark: isDark),
                      _VehicleRow(label: 'Color',   value: v['color'] ?? '—', isDark: isDark),
                      _VehicleRow(label: 'Plate',   value: v['licensePlate'] ?? '—', isDark: isDark),
                    ],
                  )
                else
                  // Edit form
                  Column(
                    children: [
                      _VehicleField(ctrl: _makeCtrl,  label: 'Car Make (e.g. Honda)',   fill: fieldFill, textColor: textColor),
                      const SizedBox(height: 10),
                      _VehicleField(ctrl: _modelCtrl, label: 'Car Model (e.g. Civic)',  fill: fieldFill, textColor: textColor),
                      const SizedBox(height: 10),
                      _VehicleField(ctrl: _colorCtrl, label: 'Color (e.g. Silver)',     fill: fieldFill, textColor: textColor),
                      const SizedBox(height: 10),
                      _VehicleField(ctrl: _plateCtrl, label: 'License Plate',           fill: fieldFill, textColor: textColor,
                          inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9\-]'))]),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity, height: 48,
                        child: ElevatedButton(
                          onPressed: _saving ? null : _save,
                          child: _saving
                              ? const SizedBox(width: 18, height: 18,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                              : Text('Save Vehicle', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800)),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ).animate().fadeIn(delay: 100.ms).slideY(begin: 0.1),
        );
      },
    );
  }
}

class _VehicleRow extends StatelessWidget {
  final String label, value;
  final bool isDark;
  const _VehicleRow({required this.label, required this.value, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          SizedBox(
            width: 56,
            child: Text(label, style: GoogleFonts.plusJakartaSans(
                fontSize: 12, color: AppColors.textMuted, fontWeight: FontWeight.w600)),
          ),
          const SizedBox(width: 12),
          Text(value, style: GoogleFonts.plusJakartaSans(
              fontSize: 13, fontWeight: FontWeight.w700,
              color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimary)),
        ],
      ),
    );
  }
}

class _VehicleField extends StatelessWidget {
  final TextEditingController ctrl;
  final String label;
  final Color fill, textColor;
  final List<TextInputFormatter>? inputFormatters;
  const _VehicleField({required this.ctrl, required this.label,
      required this.fill, required this.textColor, this.inputFormatters});

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: ctrl,
      inputFormatters: inputFormatters,
      style: TextStyle(color: textColor, fontWeight: FontWeight.w600, fontSize: 14),
      decoration: InputDecoration(
        hintText: label,
        filled: true, fillColor: fill,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Payment Methods Section
// ─────────────────────────────────────────────────────────────────────────────

class _PaymentSection extends StatelessWidget {
  final String uid;
  final bool isDark;
  const _PaymentSection({required this.uid, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final cardBg = isDark ? AppColors.darkCard : Colors.white;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: isDark
              ? Colors.white.withValues(alpha: 0.06)
              : const Color(0xFFE5E7EB)),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 12, offset: const Offset(0, 4))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 36, height: 36,
                  decoration: BoxDecoration(
                    color: AppColors.orange.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.payment_rounded,
                      color: AppColors.orange, size: 18),
                ),
                const SizedBox(width: 12),
                Text('PAYMENT METHODS',
                    style: GoogleFonts.plusJakartaSans(
                        fontSize: 11, fontWeight: FontWeight.w800,
                        color: AppColors.textMuted, letterSpacing: 1.5)),
                const Spacer(),
                TextButton(
                  onPressed: () => _showAddCard(context),
                  child: Text('+ Add Card',
                      style: GoogleFonts.plusJakartaSans(
                          color: AppColors.blue, fontWeight: FontWeight.w700)),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Cash — always shown as default
            _PaymentTile(
              icon: Icons.money_rounded, label: 'Cash',
              sublabel: 'Default payment method', color: AppColors.success, isDark: isDark),

            // Saved cards from Firestore
            StreamBuilder<QuerySnapshot>(
              stream: DatabaseService().streamPaymentMethods(uid),
              builder: (context, snap) {
                if (!snap.hasData || snap.data!.docs.isEmpty) {
                  return const SizedBox.shrink();
                }
                return Column(
                  children: snap.data!.docs.map((doc) {
                    final d = doc.data() as Map<String, dynamic>;
                    final last4 = d['last4'] as String? ?? '••••';
                    final brand = d['brand'] as String? ?? 'Card';
                    return _PaymentTile(
                      icon: Icons.credit_card_rounded,
                      label: '$brand •••• $last4',
                      sublabel: 'Expires ${d['expiry'] ?? '—'}',
                      color: AppColors.blue, isDark: isDark,
                    );
                  }).toList(),
                );
              },
            ),
          ],
        ),
      ).animate().fadeIn(delay: 140.ms).slideY(begin: 0.1),
    );
  }

  Future<void> _showAddCard(BuildContext context) async {
    final brandCtrl  = TextEditingController();
    final last4Ctrl  = TextEditingController();
    final expiryCtrl = TextEditingController();
    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Add Card', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: brandCtrl, decoration: const InputDecoration(labelText: 'Card Brand (Visa / Mastercard)')),
            TextField(controller: last4Ctrl, keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(4)],
                decoration: const InputDecoration(labelText: 'Last 4 digits')),
            TextField(controller: expiryCtrl, decoration: const InputDecoration(labelText: 'Expiry (MM/YY)')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              if (brandCtrl.text.isNotEmpty && last4Ctrl.text.length == 4) {
                await DatabaseService().savePaymentMethod(uid, {
                  'brand': brandCtrl.text.trim(),
                  'last4': last4Ctrl.text.trim(),
                  'expiry': expiryCtrl.text.trim(),
                  'type': 'card',
                });
                if (context.mounted) Navigator.pop(context);
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
}

class _PaymentTile extends StatelessWidget {
  final IconData icon;
  final String label, sublabel;
  final Color color;
  final bool isDark;
  const _PaymentTile({required this.icon, required this.label,
      required this.sublabel, required this.color, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: GoogleFonts.plusJakartaSans(
                    fontSize: 14, fontWeight: FontWeight.w700,
                    color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimary)),
                Text(sublabel, style: GoogleFonts.plusJakartaSans(
                    fontSize: 11, color: AppColors.textMuted, fontWeight: FontWeight.w500)),
              ],
            ),
          ),
          const Icon(Icons.check_circle_rounded, color: AppColors.success, size: 18),
        ],
      ),
    );
  }
}
