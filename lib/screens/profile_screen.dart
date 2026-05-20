import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../theme/app_theme.dart';
import '../services/database_service.dart';
import '../services/auth_service.dart';
import '../widgets/verified_badge.dart';

// ─────────────────────────────────────────────────────────────────────────────
// ProfileScreen
//
// Displays: User Header · Vehicle Details · Payment Methods
// Ride History has been moved to its own dedicated screen (ride_history_screen).
// ─────────────────────────────────────────────────────────────────────────────

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _db = DatabaseService();
  final _auth = AuthService();

  // ── Vehicle edit controllers ───────────────────────────────────────────────
  final _makeCtrl = TextEditingController();
  final _modelCtrl = TextEditingController();
  final _colorCtrl = TextEditingController();
  final _plateCtrl = TextEditingController();

  @override
  void dispose() {
    _makeCtrl.dispose();
    _modelCtrl.dispose();
    _colorCtrl.dispose();
    _plateCtrl.dispose();
    super.dispose();
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  String _initials(String name) {
    final parts = name.trim().split(' ');
    if (parts.length >= 2) return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    if (name.isNotEmpty) return name[0].toUpperCase();
    return '?';
  }

  // ── Vehicle bottom sheet ──────────────────────────────────────────────────

  void _showVehicleSheet(String uid, Map<String, dynamic>? existing) {
    _makeCtrl.text = existing?['make'] ?? '';
    _modelCtrl.text = existing?['model'] ?? '';
    _colorCtrl.text = existing?['color'] ?? '';
    _plateCtrl.text = existing?['licensePlate'] ?? '';

    final isDark = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDark ? AppColors.darkCard : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(
            24, 20, 24, MediaQuery.of(ctx).viewInsets.bottom + 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40, height: 4,
                decoration: BoxDecoration(
                  color: AppColors.darkBorder,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              existing != null ? 'Edit Vehicle' : 'Add Vehicle',
              style: GoogleFonts.plusJakartaSans(
                fontWeight: FontWeight.w800, fontSize: 18,
                color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 20),
            _SheetField(ctrl: _makeCtrl, label: 'Make', hint: 'e.g. Toyota'),
            const SizedBox(height: 12),
            _SheetField(ctrl: _modelCtrl, label: 'Model', hint: 'e.g. Corolla'),
            const SizedBox(height: 12),
            _SheetField(ctrl: _colorCtrl, label: 'Color', hint: 'e.g. White'),
            const SizedBox(height: 12),
            _SheetField(ctrl: _plateCtrl, label: 'License Plate', hint: 'e.g. ABC-123'),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () async {
                  if (_makeCtrl.text.trim().isEmpty ||
                      _modelCtrl.text.trim().isEmpty) {
                    return;
                  }
                  await _db.saveVehicleProfile(uid,
                    make: _makeCtrl.text.trim(),
                    model: _modelCtrl.text.trim(),
                    color: _colorCtrl.text.trim(),
                    licensePlate: _plateCtrl.text.trim(),
                  );
                  if (ctx.mounted) Navigator.pop(ctx);
                },
                child: const Text('Save Vehicle'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Add Card bottom sheet (Task 6 & 7) ──────────────────────────────────────
  // • Cash is the default fallback — not selectable here.
  // • CVV is NEVER persisted to Firestore; only last 4 digits + expiry are stored.

  void _showAddPaymentSheet(String uid) {
    final cardNumberCtrl = TextEditingController();
    final expiryCtrl     = TextEditingController();
    final cvvCtrl        = TextEditingController();
    final formKey        = GlobalKey<FormState>();
    final isDark         = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDark ? AppColors.darkCard : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(
            24, 20, 24, MediaQuery.of(ctx).viewInsets.bottom + 28),
        child: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Drag handle ──────────────────────────────────────────
              Center(
                child: Container(
                  width: 40, height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.darkBorder,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // ── Title ────────────────────────────────────────────────
              Text(
                'Add New Card',
                style: GoogleFonts.plusJakartaSans(
                  fontWeight: FontWeight.w800,
                  fontSize: 18,
                  color: isDark
                      ? AppColors.textPrimaryDark
                      : AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Your CVV is never stored — only the last 4 digits are saved.',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 11,
                  color: AppColors.textMuted,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 22),

              // ── Card Number ──────────────────────────────────────────
              _fieldLabel('CARD NUMBER'),
              const SizedBox(height: 8),
              TextFormField(
                controller: cardNumberCtrl,
                keyboardType: TextInputType.number,
                inputFormatters: [_CardNumberFormatter()],
                maxLength: 19, // 16 digits + 3 spaces
                style: TextStyle(
                  color: isDark
                      ? AppColors.textPrimaryDark
                      : AppColors.textPrimary,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 2.5,
                ),
                decoration: InputDecoration(
                  hintText: '0000 0000 0000 0000',
                  prefixIcon: const Icon(
                      Icons.credit_card_rounded, size: 20),
                  counterText: '',
                ),
                validator: (v) {
                  final digits = (v ?? '').replaceAll(' ', '');
                  if (digits.length != 16) {
                    return 'Please enter a valid 16-digit card number';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 14),

              // ── Expiry + CVV row ─────────────────────────────────────
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Expiry
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _fieldLabel('EXPIRY DATE'),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: expiryCtrl,
                          keyboardType: TextInputType.number,
                          inputFormatters: [_ExpiryFormatter()],
                          maxLength: 5,
                          style: TextStyle(
                            color: isDark
                                ? AppColors.textPrimaryDark
                                : AppColors.textPrimary,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 1.5,
                          ),
                          decoration: const InputDecoration(
                            hintText: 'MM/YY',
                            prefixIcon: Icon(
                                Icons.calendar_month_rounded, size: 20),
                            counterText: '',
                          ),
                          validator: (v) {
                            if (v == null || v.length != 5) {
                              return 'Enter MM/YY';
                            }
                            final parts = v.split('/');
                            final month =
                                int.tryParse(parts.first) ?? 0;
                            if (month < 1 || month > 12) {
                              return 'Invalid month';
                            }
                            return null;
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 14),
                  // CVV
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _fieldLabel('CVV'),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: cvvCtrl,
                          keyboardType: TextInputType.number,
                          obscureText: true,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                          ],
                          maxLength: 3,
                          style: TextStyle(
                            color: isDark
                                ? AppColors.textPrimaryDark
                                : AppColors.textPrimary,
                            fontWeight: FontWeight.w600,
                          ),
                          decoration: const InputDecoration(
                            hintText: '•••',
                            prefixIcon: Icon(
                                Icons.lock_outline_rounded, size: 20),
                            counterText: '',
                          ),
                          validator: (v) {
                            if (v == null || v.length != 3) {
                              return '3 digits required';
                            }
                            return null;
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // ── Security note ─────────────────────────────────────────
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: AppColors.blue.withValues(alpha: 0.07),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: AppColors.blue.withValues(alpha: 0.2)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.shield_outlined,
                        size: 16, color: AppColors.blue),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Encrypted connection · CVV is never stored.',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 11,
                          color: AppColors.blue,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 22),

              // ── Save button ───────────────────────────────────────────
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.credit_card_rounded, size: 18),
                  label: const Text('Save Card'),
                  onPressed: () async {
                    if (!formKey.currentState!.validate()) return;
                    final digits =
                        cardNumberCtrl.text.replaceAll(' ', '');
                    final last4 = digits.substring(digits.length - 4);
                    // ⚠️  CVV intentionally NOT stored — only display metadata.
                    await _db.savePaymentMethod(uid, {
                      'type':       'Card',
                      'last4':      last4,
                      'label':      '•••• $last4',
                      'expiryMmYy': expiryCtrl.text.trim(),
                    });
                    cardNumberCtrl.dispose();
                    expiryCtrl.dispose();
                    cvvCtrl.dispose();
                    if (ctx.mounted) Navigator.pop(ctx);
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Logout ────────────────────────────────────────────────────────────────

  Future<void> _logout() async {
    await _auth.logout();
    if (mounted) {
      Navigator.of(context).pushNamedAndRemoveUntil('/welcome', (_) => false);
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final uid = _auth.currentUid;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (uid == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBg : AppColors.lightBg,
      body: StreamBuilder<DocumentSnapshot>(
        stream: _db.streamUserData(uid),
        builder: (context, userSnap) {
          final userData =
              userSnap.hasData && userSnap.data!.exists
                  ? userSnap.data!.data() as Map<String, dynamic>
                  : <String, dynamic>{};

          final name = userData['name'] as String? ?? 'UniDriver';
          final email = userData['email'] as String? ?? '';
          final isVerified = userData['isVerified'] as bool? ?? false;
          final ratingDriver =
              (userData['ratingAsDriver'] as num?)?.toDouble() ?? 5.0;
          final ratingPassenger =
              (userData['ratingAsPassenger'] as num?)?.toDouble() ?? 5.0;
          final vehicle = userData['vehicle'] as Map<String, dynamic>?;

          return CustomScrollView(
            slivers: [
              // ── App Bar ──────────────────────────────────────────────────
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
                actions: [
                  IconButton(
                    icon: const Icon(Icons.logout_rounded,
                        color: Colors.white70, size: 20),
                    tooltip: 'Sign out',
                    onPressed: _logout,
                  ),
                ],
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
                            // Avatar row
                            Row(
                              children: [
                                Container(
                                  width: 60,
                                  height: 60,
                                  decoration: BoxDecoration(
                                    gradient: const LinearGradient(
                                      colors: [AppColors.blue, AppColors.cyan],
                                    ),
                                    borderRadius:
                                        BorderRadius.circular(18),
                                    boxShadow: [
                                      BoxShadow(
                                        color: AppColors.blue
                                            .withValues(alpha: 0.4),
                                        blurRadius: 12,
                                        offset: const Offset(0, 4),
                                      )
                                    ],
                                  ),
                                  child: Center(
                                    child: Text(
                                      _initials(name),
                                      style: GoogleFonts.plusJakartaSans(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w800,
                                        fontSize: 22,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Flexible(
                                            child: Text(
                                              name,
                                              maxLines: 1,
                                              overflow:
                                                  TextOverflow.ellipsis,
                                              style:
                                                  GoogleFonts.plusJakartaSans(
                                                color: Colors.white,
                                                fontWeight: FontWeight.w800,
                                                fontSize: 18,
                                              ),
                                            ),
                                          ),
                                          if (isVerified) ...[
                                            const SizedBox(width: 6),
                                            const VerifiedBadge(),
                                          ],
                                        ],
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        email,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style:
                                            GoogleFonts.plusJakartaSans(
                                          color: Colors.white70,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            // Rating chips
                            Row(
                              children: [
                                _RatingChip(
                                  icon: Icons.directions_car_rounded,
                                  label:
                                      '${ratingDriver.toStringAsFixed(1)} Driver',
                                  color: AppColors.orange,
                                ),
                                const SizedBox(width: 8),
                                _RatingChip(
                                  icon: Icons.person_rounded,
                                  label:
                                      '${ratingPassenger.toStringAsFixed(1)} Rider',
                                  color: AppColors.cyan,
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

              // ── Body ─────────────────────────────────────────────────────
              SliverPadding(
                padding:
                    const EdgeInsets.fromLTRB(20, 24, 20, 40),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    // ── Vehicle Details ──────────────────────────────────
                    _SectionCard(
                      isDark: isDark,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Section header — overflow-safe Row
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  'VEHICLE DETAILS',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 1.2,
                                    color: AppColors.textMuted,
                                  ),
                                ),
                              ),
                              TextButton.icon(
                                onPressed: () =>
                                    _showVehicleSheet(uid, vehicle),
                                icon: Icon(
                                  vehicle != null
                                      ? Icons.edit_rounded
                                      : Icons.add_rounded,
                                  size: 15,
                                ),
                                label: Text(
                                  vehicle != null ? 'Edit' : 'Add Vehicle',
                                ),
                                style: TextButton.styleFrom(
                                  foregroundColor: AppColors.blue,
                                  textStyle: GoogleFonts.plusJakartaSans(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 13,
                                  ),
                                  padding: EdgeInsets.zero,
                                  minimumSize: Size.zero,
                                  tapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          if (vehicle == null)
                            _EmptyState(
                              icon: Icons.directions_car_outlined,
                              message: 'No vehicle added yet',
                              subtitle:
                                  'Add your vehicle to start offering rides.',
                            )
                          else ...[
                            _VehicleRow(
                                icon: Icons.directions_car_filled_rounded,
                                label: 'Make & Model',
                                value:
                                    '${vehicle['make']} ${vehicle['model']}'),
                            _VehicleRow(
                                icon: Icons.palette_rounded,
                                label: 'Color',
                                value:
                                    vehicle['color'] ?? '—'),
                            _VehicleRow(
                                icon: Icons.pin_rounded,
                                label: 'Plate',
                                value:
                                    vehicle['licensePlate'] ?? '—'),
                          ],
                        ],
                      ),
                    )
                        .animate()
                        .fadeIn(delay: 80.ms)
                        .slideY(begin: 0.06),

                    const SizedBox(height: 16),

                    // ── Payment Methods ──────────────────────────────────
                    StreamBuilder<QuerySnapshot>(
                      stream: _db.streamPaymentMethods(uid),
                      builder: (context, paySnap) {
                        final methods = paySnap.hasData
                            ? paySnap.data!.docs
                            : <QueryDocumentSnapshot>[];

                        return _SectionCard(
                          isDark: isDark,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // ── OVERFLOW FIX: Expanded on title ────────
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      'PAYMENT METHODS',
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: 1.2,
                                        color: AppColors.textMuted,
                                      ),
                                    ),
                                  ),
                                  TextButton.icon(
                                    onPressed: () =>
                                        _showAddPaymentSheet(uid),
                                    icon: const Icon(Icons.add_rounded,
                                        size: 15),
                                    label: const Text('Add Card'),
                                    style: TextButton.styleFrom(
                                      foregroundColor: AppColors.blue,
                                      textStyle:
                                          GoogleFonts.plusJakartaSans(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 13,
                                      ),
                                      padding: EdgeInsets.zero,
                                      minimumSize: Size.zero,
                                      tapTargetSize:
                                          MaterialTapTargetSize.shrinkWrap,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              if (methods.isEmpty)
                                _EmptyState(
                                  icon: Icons.credit_card_rounded,
                                  message: 'No payment methods',
                                  subtitle:
                                      'Add Cash or a Card to pay for rides.',
                                )
                              else
                                ...methods.map((doc) {
                                  final d =
                                      doc.data() as Map<String, dynamic>;
                                  final isCard =
                                      d['type'] == 'Card';
                                  return _PaymentTile(
                                    isDark: isDark,
                                    icon: isCard
                                        ? Icons.credit_card_rounded
                                        : Icons.payments_rounded,
                                    label: d['label'] as String? ??
                                        d['type'] as String? ??
                                        'Method',
                                    color: isCard
                                        ? AppColors.violet
                                        : AppColors.success,
                                    onDelete: () async {
                                      await _db.deletePaymentMethod(
                                          uid, doc.id);
                                    },
                                  );
                                }),
                            ],
                          ),
                        )
                            .animate()
                            .fadeIn(delay: 140.ms)
                            .slideY(begin: 0.06);
                      },
                    ),

                    const SizedBox(height: 24),

                    // ── Ride History shortcut ────────────────────────────
                    OutlinedButton.icon(
                      onPressed: () =>
                          Navigator.pushNamed(context, '/ride-history'),
                      icon: const Icon(Icons.history_rounded, size: 18),
                      label: const Text('View Ride History'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        side: BorderSide(
                            color: isDark
                                ? AppColors.darkBorder
                                : const Color(0xFFE5E7EB)),
                        foregroundColor: AppColors.textMuted,
                      ),
                    )
                        .animate()
                        .fadeIn(delay: 200.ms),
                  ]),
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
// Private sub-widgets
// ─────────────────────────────────────────────────────────────────────────────

class _SectionCard extends StatelessWidget {
  final Widget child;
  final bool isDark;
  const _SectionCard({required this.child, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.05)
              : const Color(0xFFE5E7EB),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.07),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _RatingChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  const _RatingChip(
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
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 5),
          Text(
            label,
            style: GoogleFonts.plusJakartaSans(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _VehicleRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _VehicleRow(
      {required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppColors.blue.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 18, color: AppColors.blue),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 11,
                  color: AppColors.textMuted,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                value,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: isDark
                      ? AppColors.textPrimaryDark
                      : AppColors.textPrimary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PaymentTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final bool isDark;
  final VoidCallback onDelete;
  const _PaymentTile({
    required this.icon,
    required this.label,
    required this.color,
    required this.isDark,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: isDark
            ? AppColors.darkSurface.withValues(alpha: 0.5)
            : AppColors.bgGrey,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 18, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: GoogleFonts.plusJakartaSans(
                fontWeight: FontWeight.w700,
                fontSize: 14,
                color: isDark
                    ? AppColors.textPrimaryDark
                    : AppColors.textPrimary,
              ),
            ),
          ),
          IconButton(
            icon: Icon(Icons.delete_outline_rounded,
                size: 18, color: AppColors.maroonLight),
            onPressed: onDelete,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String message;
  final String subtitle;
  const _EmptyState(
      {required this.icon,
      required this.message,
      required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon,
              size: 36, color: AppColors.textMuted.withValues(alpha: 0.4)),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  message,
                  style: GoogleFonts.plusJakartaSans(
                    color: AppColors.textMuted,
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
                Text(
                  subtitle,
                  style: GoogleFonts.plusJakartaSans(
                    color: AppColors.textMuted,
                    fontWeight: FontWeight.w500,
                    fontSize: 12,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// _SheetField is retained for the Vehicle bottom sheet.
class _SheetField extends StatelessWidget {
  final TextEditingController ctrl;
  final String label;
  final String hint;
  const _SheetField({
    required this.ctrl,
    required this.label,
    required this.hint,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: ctrl,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Card input formatters (Task 7)
// ─────────────────────────────────────────────────────────────────────────────

/// Small uppercase field label used inside the Add Card sheet.
Widget _fieldLabel(String text) => Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Text(
        text,
        style: GoogleFonts.plusJakartaSans(
          fontSize: 10,
          fontWeight: FontWeight.w800,
          color: AppColors.textMuted,
          letterSpacing: 1.5,
        ),
      ),
    );

/// Groups card digits into blocks of 4 separated by spaces: XXXX XXXX XXXX XXXX
class _CardNumberFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    final digits = newValue.text.replaceAll(' ', '');
    if (digits.length > 16) return oldValue;
    final buffer = StringBuffer();
    for (int i = 0; i < digits.length; i++) {
      if (i > 0 && i % 4 == 0) buffer.write(' ');
      buffer.write(digits[i]);
    }
    final result = buffer.toString();
    return TextEditingValue(
      text: result,
      selection: TextSelection.collapsed(offset: result.length),
    );
  }
}

/// Auto-inserts a slash after the 2nd digit to produce MM/YY.
class _ExpiryFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    final digits = newValue.text.replaceAll('/', '');
    if (digits.length > 4) return oldValue;
    final buffer = StringBuffer();
    for (int i = 0; i < digits.length; i++) {
      if (i == 2) buffer.write('/');
      buffer.write(digits[i]);
    }
    final result = buffer.toString();
    return TextEditingValue(
      text: result,
      selection: TextSelection.collapsed(offset: result.length),
    );
  }
}
