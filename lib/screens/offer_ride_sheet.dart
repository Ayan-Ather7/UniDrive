import 'dart:async';
import 'dart:convert';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart';
import '../theme/app_theme.dart';
import '../services/database_service.dart';
import '../services/auth_service.dart';
import 'driver_dashboard_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────
// OfferRideSheet
// Shown as a modal bottom sheet when a driver taps "Offer a Ride".
// Collects route, seats, fare, time, and pink-ride preference, then calls
// DatabaseService.createRide() with the fully populated payload.
// ─────────────────────────────────────────────────────────────────────────────

class OfferRideSheet extends StatefulWidget {
  const OfferRideSheet({super.key});

  @override
  State<OfferRideSheet> createState() => _OfferRideSheetState();
}

class _OfferRideSheetState extends State<OfferRideSheet> {
  // ── Controllers ─────────────────────────────────────────────────────────────
  final _pickupCtrl   = TextEditingController();
  final _destCtrl     = TextEditingController();
  final _fareCtrl     = TextEditingController();

  // ── State ────────────────────────────────────────────────────────────────────
  int    _seats       = 4;          // default: full car
  bool   _isPinkRide  = false;
  bool   _isLoading   = false;
  TimeOfDay _depTime  = TimeOfDay(
    hour: TimeOfDay.now().hour,
    minute: (TimeOfDay.now().minute ~/ 15 + 1) * 15 % 60,
  );

  // ── Photon autocomplete ──────────────────────────────────────────────────────
  List<String> _pickupSugg = [];
  List<String> _destSugg   = [];
  Timer? _pickupDebounce;
  Timer? _destDebounce;

  Future<List<String>> _photon(String q) async {
    if (q.trim().length < 3) return [];
    try {
      final uri = Uri.parse(
          'https://photon.komoot.io/api/?q=${Uri.encodeComponent(q)}&limit=5');
      final res = await http.get(uri).timeout(const Duration(seconds: 5));
      if (res.statusCode != 200) return [];
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      return ((data['features'] as List?) ?? []).map((f) {
        final p = (f as Map)['properties'] as Map<String, dynamic>;
        return [p['name'], p['street'], p['city']]
            .where((e) => e != null && (e as String).isNotEmpty)
            .join(', ');
      }).toList();
    } catch (_) {
      return [];
    }
  }

  void _onPickup(String v) {
    _pickupDebounce?.cancel();
    _pickupDebounce = Timer(const Duration(milliseconds: 400), () async {
      final r = await _photon(v);
      if (mounted) setState(() => _pickupSugg = r);
    });
  }

  void _onDest(String v) {
    _destDebounce?.cancel();
    _destDebounce = Timer(const Duration(milliseconds: 400), () async {
      final r = await _photon(v);
      if (mounted) setState(() => _destSugg = r);
    });
  }

  // ── Submission ───────────────────────────────────────────────────────────────
  Future<void> _submit() async {
    final pickup = _pickupCtrl.text.trim();
    final dest   = _destCtrl.text.trim();
    final fare   = double.tryParse(_fareCtrl.text.trim()) ?? 0;

    if (pickup.isEmpty || dest.isEmpty || fare <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please fill in all fields and enter a valid fare.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final uid = AuthService().currentUid;
    if (uid == null) return;

    setState(() => _isLoading = true);
    try {
      final now = DateTime.now();
      final departure = DateTime(
          now.year, now.month, now.day, _depTime.hour, _depTime.minute);

      final rideId = await DatabaseService().createRide(
        driverId:      uid,
        vehicleId:     uid,
        origin:        {'address': pickup, 'lat': 0.0, 'lng': 0.0},
        destination:   {'address': dest,   'lat': 0.0, 'lng': 0.0},
        departureTime: departure,
        baseFare:      fare,
        isPinkRide:    _isPinkRide,
        availableSeats: _seats,
      );

      if (!mounted) return;
      // Navigate to Driver Dashboard — replacing the sheet
      Navigator.pop(context);
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => DriverDashboardScreen(rideId: rideId),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to offer ride: $e'),
          backgroundColor: AppColors.maroonLight,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _pickupCtrl.dispose();
    _destCtrl.dispose();
    _fareCtrl.dispose();
    _pickupDebounce?.cancel();
    _destDebounce?.cancel();
    super.dispose();
  }

  // ── Build ────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final isDark     = Theme.of(context).brightness == Brightness.dark;
    final bg         = isDark
        ? AppColors.darkBg.withValues(alpha: 0.95)
        : Colors.white.withValues(alpha: 0.97);
    final fieldFill  = isDark
        ? AppColors.darkSurface.withValues(alpha: 0.6)
        : AppColors.bgGrey;
    final textColor  = isDark ? AppColors.textPrimaryDark : AppColors.textPrimary;

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          decoration: BoxDecoration(
            color: bg,
            border: Border(
                top: BorderSide(color: Colors.white.withValues(alpha: 0.1))),
          ),
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
                20, 12, 20, MediaQuery.of(context).viewInsets.bottom + 28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Handle ──────────────────────────────────────────────────
                Center(
                  child: Container(
                    width: 44,
                    height: 4,
                    decoration: BoxDecoration(
                      color: isDark
                          ? AppColors.darkBorder
                          : const Color(0xFFE5E7EB),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // ── Title ────────────────────────────────────────────────────
                Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: AppColors.maroon.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.drive_eta_rounded,
                          color: AppColors.maroon, size: 22),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Offer a Ride',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.4,
                        color: textColor,
                      ),
                    ),
                  ],
                ).animate().fadeIn(delay: 60.ms).slideY(begin: -0.1),

                const SizedBox(height: 24),

                // ── A. Route ─────────────────────────────────────────────────
                _SectionLabel('ROUTE', isDark: isDark),
                const SizedBox(height: 10),
                _AutoField(
                  controller: _pickupCtrl,
                  hint: 'Pickup location',
                  icon: Icons.radio_button_checked_rounded,
                  iconColor: AppColors.success,
                  fieldFill: fieldFill,
                  textColor: textColor,
                  isDark: isDark,
                  suggestions: _pickupSugg,
                  onChanged: _onPickup,
                  onSelected: (v) {
                    _pickupCtrl.text = v;
                    setState(() => _pickupSugg = []);
                  },
                ).animate().fadeIn(delay: 100.ms).slideY(begin: 0.1),

                const SizedBox(height: 10),

                _AutoField(
                  controller: _destCtrl,
                  hint: 'Destination',
                  icon: Icons.location_on_rounded,
                  iconColor: AppColors.maroon,
                  fieldFill: fieldFill,
                  textColor: textColor,
                  isDark: isDark,
                  suggestions: _destSugg,
                  onChanged: _onDest,
                  onSelected: (v) {
                    _destCtrl.text = v;
                    setState(() => _destSugg = []);
                  },
                ).animate().fadeIn(delay: 140.ms).slideY(begin: 0.1),

                const SizedBox(height: 20),

                // ── B. Departure time ─────────────────────────────────────────
                _SectionLabel('DEPARTURE TIME', isDark: isDark),
                const SizedBox(height: 10),
                GestureDetector(
                  onTap: () async {
                    final picked = await showTimePicker(
                      context: context,
                      initialTime: _depTime,
                    );
                    if (picked != null) setState(() => _depTime = picked);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 14),
                    decoration: BoxDecoration(
                      color: fieldFill,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.schedule_rounded,
                            size: 18, color: AppColors.blue),
                        const SizedBox(width: 12),
                        Text(
                          _depTime.format(context),
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: textColor,
                          ),
                        ),
                        const Spacer(),
                        Icon(Icons.chevron_right_rounded,
                            color: AppColors.textMuted, size: 18),
                      ],
                    ),
                  ),
                ).animate().fadeIn(delay: 180.ms).slideY(begin: 0.1),

                const SizedBox(height: 20),

                // ── C. Fare + Seats ────────────────────────────────────────
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Fare field — takes all remaining width
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _SectionLabel('BASE FARE (PKR)', isDark: isDark),
                          const SizedBox(height: 10),
                          TextField(
                            controller: _fareCtrl,
                            keyboardType: const TextInputType.numberWithOptions(
                                decimal: true),
                            inputFormatters: [
                              FilteringTextInputFormatter.allow(
                                  RegExp(r'^\d+\.?\d{0,2}'))
                            ],
                            style: TextStyle(
                                color: textColor,
                                fontWeight: FontWeight.w700,
                                fontSize: 14),
                            decoration: InputDecoration(
                              hintText: 'e.g. 500',
                              filled: true,
                              fillColor: fieldFill,
                              prefixText: 'PKR ',
                              prefixStyle: TextStyle(
                                  color: AppColors.textMuted,
                                  fontWeight: FontWeight.w600),
                              border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide: BorderSide.none),
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 14),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(width: 12),

                    // ── Seat count dropdown ──────────────────────────────
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _SectionLabel('SEATS', isDark: isDark),
                        const SizedBox(height: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 2),
                          decoration: BoxDecoration(
                            color: fieldFill,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<int>(
                              value: _seats,
                              dropdownColor: isDark
                                  ? AppColors.darkCard
                                  : Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                                color: textColor,
                              ),
                              icon: Icon(
                                Icons.keyboard_arrow_down_rounded,
                                color: AppColors.textMuted,
                                size: 18,
                              ),
                              // Fixed-width items so label never clips
                              items: [1, 2, 3, 4].map((n) {
                                return DropdownMenuItem<int>(
                                  value: n,
                                  child: SizedBox(
                                    width: 70,
                                    child: Row(
                                      children: [
                                        Icon(
                                          Icons.airline_seat_recline_normal_rounded,
                                          size: 15,
                                          color: n == _seats
                                              ? AppColors.maroon
                                              : AppColors.textMuted,
                                        ),
                                        const SizedBox(width: 5),
                                        Text(
                                          '$n seat${n > 1 ? 's' : ''}',
                                          overflow: TextOverflow.visible,
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              }).toList(),
                              onChanged: (v) {
                                if (v != null) setState(() => _seats = v);
                              },
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ).animate().fadeIn(delay: 220.ms).slideY(begin: 0.1),

                const SizedBox(height: 20),

                // ── D. Pink Ride toggle (only for Female drivers) ──────────
                StreamBuilder<DocumentSnapshot>(
                  stream: AuthService().currentUid != null
                      ? DatabaseService()
                          .streamUserData(AuthService().currentUid!)
                      : null,
                  builder: (context, snap) {
                    final data = snap.hasData && snap.data!.exists
                        ? snap.data!.data() as Map<String, dynamic>
                        : <String, dynamic>{};
                    final gender = (data['gender'] as String? ?? '').toLowerCase();
                    final isFemale = gender == 'female';

                    if (!isFemale) return const SizedBox.shrink();

                    return Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: _isPinkRide
                            ? AppColors.pink.withValues(alpha: 0.1)
                            : fieldFill,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: _isPinkRide
                              ? AppColors.pink
                              : Colors.transparent,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.female_rounded,
                              color: _isPinkRide
                                  ? AppColors.pink
                                  : AppColors.textMuted,
                              size: 22),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Pink Ride',
                                    style: GoogleFonts.plusJakartaSans(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w800,
                                        color: textColor)),
                                Text('Female passengers only',
                                    style: GoogleFonts.plusJakartaSans(
                                        fontSize: 11,
                                        color: AppColors.textMuted,
                                        fontWeight: FontWeight.w500)),
                              ],
                            ),
                          ),
                          Switch(
                            value: _isPinkRide,
                            onChanged: (v) =>
                                setState(() => _isPinkRide = v),
                            activeThumbColor: Colors.white,
                            activeTrackColor: AppColors.pink,
                            inactiveTrackColor: AppColors.darkBorder,
                          ),
                        ],
                      ),
                    ).animate().fadeIn(delay: 260.ms).slideY(begin: 0.1);
                  },
                ),

                const SizedBox(height: 24),

                // ── E. Submit ─────────────────────────────────────────────────
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton.icon(
                    onPressed: _isLoading ? null : _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.maroon,
                      disabledBackgroundColor:
                          AppColors.maroon.withValues(alpha: 0.5),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16)),
                    ),
                    icon: _isLoading
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.drive_eta_rounded, size: 20),
                    label: Text(
                      _isLoading ? 'Offering Ride…' : 'Offer Ride',
                      style: GoogleFonts.plusJakartaSans(
                          fontWeight: FontWeight.w800, fontSize: 15),
                    ),
                  ),
                ).animate().fadeIn(delay: 300.ms).slideY(begin: 0.2),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Section label helper ─────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String text;
  final bool isDark;
  const _SectionLabel(this.text, {required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: GoogleFonts.plusJakartaSans(
        fontSize: 10,
        fontWeight: FontWeight.w800,
        color: AppColors.textMuted,
        letterSpacing: 1.5,
      ),
    );
  }
}

// ── Photon autocomplete field ─────────────────────────────────────────────────

class _AutoField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final IconData icon;
  final Color iconColor;
  final Color fieldFill;
  final Color textColor;
  final bool isDark;
  final List<String> suggestions;
  final ValueChanged<String> onChanged;
  final ValueChanged<String> onSelected;

  const _AutoField({
    required this.controller,
    required this.hint,
    required this.icon,
    required this.iconColor,
    required this.fieldFill,
    required this.textColor,
    required this.isDark,
    required this.suggestions,
    required this.onChanged,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        TextField(
          controller: controller,
          onChanged: onChanged,
          style: TextStyle(
              color: textColor, fontWeight: FontWeight.w600, fontSize: 14),
          decoration: InputDecoration(
            hintText: hint,
            filled: true,
            fillColor: fieldFill,
            prefixIcon: Icon(icon, size: 18, color: iconColor),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            suffixIcon: controller.text.isNotEmpty
                ? IconButton(
                    icon: Icon(Icons.clear_rounded,
                        size: 16, color: AppColors.textMuted),
                    onPressed: () {
                      controller.clear();
                      onChanged('');
                    },
                  )
                : null,
          ),
        ),
        if (suggestions.isNotEmpty)
          Container(
            margin: const EdgeInsets.only(top: 4),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkCard : Colors.white,
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withValues(alpha: 0.15),
                    blurRadius: 12,
                    offset: const Offset(0, 4))
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: suggestions.asMap().entries.map((e) {
                final isLast = e.key == suggestions.length - 1;
                return InkWell(
                  onTap: () => onSelected(e.value),
                  borderRadius: BorderRadius.vertical(
                    top: e.key == 0
                        ? const Radius.circular(14)
                        : Radius.zero,
                    bottom: isLast
                        ? const Radius.circular(14)
                        : Radius.zero,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 11),
                    child: Row(
                      children: [
                        Icon(Icons.location_on_rounded,
                            size: 14,
                            color: AppColors.blue.withValues(alpha: 0.7)),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            e.value,
                            style: GoogleFonts.plusJakartaSans(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: textColor),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ).animate().fadeIn(duration: 180.ms).slideY(begin: -0.05),
      ],
    );
  }
}
