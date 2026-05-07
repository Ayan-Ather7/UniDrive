import 'dart:async';
import 'dart:convert';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:http/http.dart' as http;
import '../theme/app_theme.dart';
import 'map_picker_screen.dart';

// ── Ride type model ──────────────────────────────────────────────────────────

enum _RideType { mini, ac, premium }

extension _RideTypeX on _RideType {
  String get label => switch (this) {
        _RideType.mini    => 'Mini Drive',
        _RideType.ac      => 'A/C Drive',
        _RideType.premium => 'Premium Drive',
      };

  IconData get icon => switch (this) {
        _RideType.mini    => Icons.directions_car_outlined,
        _RideType.ac      => Icons.ac_unit_rounded,
        _RideType.premium => Icons.star_outline_rounded,
      };

  String get sub => switch (this) {
        _RideType.mini    => 'Budget friendly',
        _RideType.ac      => 'Air conditioned',
        _RideType.premium => 'Top-rated',
      };
}

// ── Sheet ────────────────────────────────────────────────────────────────────

class SearchFilterSheet extends StatefulWidget {
  final VoidCallback onFindRides;
  const SearchFilterSheet({super.key, required this.onFindRides});

  @override
  State<SearchFilterSheet> createState() => _SearchFilterSheetState();
}

class _SearchFilterSheetState extends State<SearchFilterSheet> {
  bool _pinkRide   = false;
  double _timeSlider = 0.25;
  _RideType _rideType = _RideType.ac;

  final _pickupCtrl = TextEditingController();
  final _destCtrl   = TextEditingController();

  @override
  void dispose() {
    _pickupCtrl.dispose();
    _destCtrl.dispose();
    super.dispose();
  }

  String get _timeLabel {
    if (_timeSlider <= 0.05) return 'Now';
    final mins = (_timeSlider * 60).round();
    if (mins >= 58) return '1 HR';
    return 'In $mins mins';
  }

  @override
  Widget build(BuildContext context) {
    final isDark      = Theme.of(context).brightness == Brightness.dark;
    final bg          = isDark
        ? AppColors.darkBg.withValues(alpha: 0.90)
        : Colors.white.withValues(alpha: 0.96);
    final textColor   = isDark ? AppColors.textPrimaryDark : AppColors.textPrimary;
    final fieldFill   = isDark
        ? AppColors.darkSurface.withValues(alpha: 0.6)
        : AppColors.bgGrey;

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          decoration: BoxDecoration(
            color: bg,
            border: Border(top: BorderSide(color: Colors.white.withValues(alpha: 0.1))),
          ),
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
                20, 12, 20, MediaQuery.of(context).viewInsets.bottom + 20),
            child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Handle
              Center(
                child: Container(
                  width: 44, height: 4,
                  decoration: BoxDecoration(
                      color: isDark ? AppColors.darkBorder : const Color(0xFFE5E7EB),
                      borderRadius: BorderRadius.circular(2)),
                ),
              ),
              const SizedBox(height: 20),

              // ── A. Location fields with connecting line ────────────────
              _LocationFields(
                pickupCtrl: _pickupCtrl,
                destCtrl: _destCtrl,
                isDark: isDark,
                fieldFill: fieldFill,
                textColor: textColor,
              ).animate().fadeIn(delay: 80.ms).slideY(begin: 0.1),

              const SizedBox(height: 20),

              // ── B. Ride type cards ────────────────────────────────────
              Text('RIDE TYPE',
                  style: GoogleFonts.plusJakartaSans(
                      fontSize: 10, fontWeight: FontWeight.w800,
                      color: AppColors.textMuted, letterSpacing: 1.5)),
              const SizedBox(height: 10),
              Row(
                children: _RideType.values.map((type) {
                  final selected = _rideType == type;
                  return Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(
                          right: type != _RideType.premium ? 8 : 0),
                      child: GestureDetector(
                        onTap: () => setState(() => _rideType = type),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 250),
                          curve: Curves.easeOutCubic,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            color: selected
                                ? AppColors.navy.withValues(alpha: 0.12)
                                : fieldFill,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: selected
                                  ? AppColors.blue.withValues(alpha: 0.7)
                                  : Colors.transparent,
                              width: 1.5,
                            ),
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(type.icon,
                                  size: 26,
                                  color: selected ? AppColors.blue : AppColors.textMuted),
                              const SizedBox(height: 6),
                              Text(type.label,
                                  style: GoogleFonts.plusJakartaSans(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w800,
                                      color: selected ? AppColors.blue : textColor)),
                              Text(type.sub,
                                  style: GoogleFonts.plusJakartaSans(
                                      fontSize: 10,
                                      color: AppColors.textMuted,
                                      fontWeight: FontWeight.w500)),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ).animate().fadeIn(delay: 160.ms).slideY(begin: 0.1),

              const SizedBox(height: 20),

              // ── C. Pink Ride toggle (unchanged) ───────────────────────
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: _pinkRide
                      ? AppColors.pink.withValues(alpha: 0.1)
                      : fieldFill,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: _pinkRide
                        ? AppColors.pink
                        : Colors.transparent,
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 40, height: 40,
                      decoration: BoxDecoration(
                        color: _pinkRide
                            ? AppColors.pink.withValues(alpha: 0.2)
                            : isDark ? AppColors.darkSurface : Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: _pinkRide
                            ? [BoxShadow(color: AppColors.pink.withValues(alpha: 0.2), blurRadius: 10)]
                            : null,
                      ),
                      child: Icon(Icons.female_rounded,
                          color: _pinkRide ? AppColors.pink : AppColors.textMuted, size: 22),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Pink Ride',
                              style: GoogleFonts.plusJakartaSans(
                                  color: textColor, fontWeight: FontWeight.w800, fontSize: 14)),
                          Text('Verified Female Drivers Only',
                              style: GoogleFonts.plusJakartaSans(
                                  color: AppColors.textMuted, fontSize: 11, fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ),
                    Switch(
                      value: _pinkRide,
                      onChanged: (v) => setState(() => _pinkRide = v),
                      activeThumbColor: Colors.white,
                      activeTrackColor: AppColors.pink,
                      inactiveTrackColor: AppColors.darkBorder,
                    ),
                  ],
                ),
              ).animate().fadeIn(delay: 240.ms).slideY(begin: 0.1),

              const SizedBox(height: 20),

              // ── C. Departure time (unchanged) ─────────────────────────
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Departure Time',
                      style: GoogleFonts.plusJakartaSans(
                          color: textColor, fontWeight: FontWeight.w800, fontSize: 14)),
                  Text(_timeLabel,
                      style: GoogleFonts.plusJakartaSans(
                          color: AppColors.cyan, fontWeight: FontWeight.w800, fontSize: 14)),
                ],
              ).animate().fadeIn(delay: 300.ms),
              Slider(
                value: _timeSlider,
                min: 0, max: 1,
                activeColor: AppColors.cyan,
                inactiveColor: AppColors.darkBorder,
                onChanged: (v) => setState(() => _timeSlider = v),
              ).animate().fadeIn(delay: 340.ms),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('NOW', style: GoogleFonts.plusJakartaSans(
                      fontSize: 10, color: AppColors.textMuted, fontWeight: FontWeight.w700)),
                  Text('1 HR', style: GoogleFonts.plusJakartaSans(
                      fontSize: 10, color: AppColors.textMuted, fontWeight: FontWeight.w700)),
                ],
              ).animate().fadeIn(delay: 360.ms),

              const SizedBox(height: 20),

              // ── CTA ───────────────────────────────────────────────────
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: widget.onFindRides,
                  child: Text('Find Available Rides',
                      style: GoogleFonts.plusJakartaSans(
                          fontWeight: FontWeight.w800, fontSize: 15, letterSpacing: 0.5)),
                ),
              ).animate().fadeIn(delay: 420.ms).slideY(begin: 0.2),
            ],
          ),
        ),
      ),
    ),
  );
  }
}

// ── Location fields with Photon autocomplete ────────────────────────────────

class _LocationFields extends StatefulWidget {
  final TextEditingController pickupCtrl;
  final TextEditingController destCtrl;
  final bool isDark;
  final Color fieldFill;
  final Color textColor;

  const _LocationFields({
    required this.pickupCtrl,
    required this.destCtrl,
    required this.isDark,
    required this.fieldFill,
    required this.textColor,
  });

  @override
  State<_LocationFields> createState() => _LocationFieldsState();
}

class _LocationFieldsState extends State<_LocationFields> {
  List<String> _pickupSuggestions = [];
  List<String> _destSuggestions   = [];
  Timer? _pickupDebounce;
  Timer? _destDebounce;

  Future<List<String>> _photonSearch(String query) async {
    if (query.trim().length < 3) return [];
    try {
      final uri = Uri.parse(
          'https://photon.komoot.io/api/?q=${Uri.encodeComponent(query)}&limit=5');
      final res = await http.get(uri).timeout(const Duration(seconds: 5));
      if (res.statusCode != 200) return [];
      final json   = jsonDecode(res.body) as Map<String, dynamic>;
      final feats  = (json['features'] as List?) ?? [];
      return feats.map((f) {
        final p = (f as Map)['properties'] as Map<String, dynamic>;
        final parts = [
          p['name'], p['street'], p['city'], p['country'],
        ].where((e) => e != null && (e as String).isNotEmpty).toList();
        return parts.join(', ');
      }).toList();
    } catch (_) {
      return [];
    }
  }

  void _onPickupChanged(String val) {
    _pickupDebounce?.cancel();
    _pickupDebounce = Timer(const Duration(milliseconds: 400), () async {
      final results = await _photonSearch(val);
      if (mounted) setState(() => _pickupSuggestions = results);
    });
  }

  void _onDestChanged(String val) {
    _destDebounce?.cancel();
    _destDebounce = Timer(const Duration(milliseconds: 400), () async {
      final results = await _photonSearch(val);
      if (mounted) setState(() => _destSuggestions = results);
    });
  }

  @override
  void dispose() {
    _pickupDebounce?.cancel();
    _destDebounce?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Connector column ──────────────────────────────────────────
          SizedBox(
            width: 28,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 12, height: 12,
                  decoration: BoxDecoration(
                    color: AppColors.success,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                    boxShadow: [BoxShadow(color: AppColors.success.withValues(alpha: 0.4), blurRadius: 6)],
                  ),
                ),
                Expanded(
                  child: CustomPaint(
                    painter: _DashedLinePainter(
                        color: widget.isDark ? AppColors.darkBorder : const Color(0xFFD1D5DB)),
                  ),
                ),
                Container(
                  width: 12, height: 12,
                  decoration: BoxDecoration(
                    color: AppColors.blue,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                    boxShadow: [BoxShadow(color: AppColors.blue.withValues(alpha: 0.4), blurRadius: 6)],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),

          // ── Fields column ─────────────────────────────────────────────
          Expanded(
            child: Column(
              children: [
                _PhotonField(
                  controller: widget.pickupCtrl,
                  hint: 'Pickup location',
                  suggestions: _pickupSuggestions,
                  isDark: widget.isDark,
                  fieldFill: widget.fieldFill,
                  textColor: widget.textColor,
                  onChanged: _onPickupChanged,
                  onSelected: (val) {
                    widget.pickupCtrl.text = val;
                    setState(() => _pickupSuggestions = []);
                  },
                ),
                const SizedBox(height: 8),
                _PhotonField(
                  controller: widget.destCtrl,
                  hint: 'Where are you going?',
                  suggestions: _destSuggestions,
                  isDark: widget.isDark,
                  fieldFill: widget.fieldFill,
                  textColor: widget.textColor,
                  onChanged: _onDestChanged,
                  onSelected: (val) {
                    widget.destCtrl.text = val;
                    setState(() => _destSuggestions = []);
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Single autocomplete field (Overlay-based) ────────────────────────────────
//
// Uses a CompositedTransformFollower so the suggestion list always appears
// directly under the TextField, even inside a modal bottom sheet.

class _PhotonField extends StatefulWidget {
  final TextEditingController controller;
  final String hint;
  final List<String> suggestions;
  final bool isDark;
  final Color fieldFill;
  final Color textColor;
  final ValueChanged<String> onChanged;
  final ValueChanged<String> onSelected;

  const _PhotonField({
    required this.controller,
    required this.hint,
    required this.suggestions,
    required this.isDark,
    required this.fieldFill,
    required this.textColor,
    required this.onChanged,
    required this.onSelected,
  });

  @override
  State<_PhotonField> createState() => _PhotonFieldState();
}

class _PhotonFieldState extends State<_PhotonField> {
  final _layerLink = LayerLink();
  OverlayEntry? _overlayEntry;

  @override
  void didUpdateWidget(_PhotonField old) {
    super.didUpdateWidget(old);
    // Rebuild overlay whenever suggestion list changes
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _overlayEntry?.markNeedsBuild();
    });
  }

  @override
  void dispose() {
    _removeOverlay();
    super.dispose();
  }

  void _removeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  void _showOverlay() {
    _removeOverlay();
    _overlayEntry = OverlayEntry(builder: (_) {
      final sugg = widget.suggestions;
      final dropBg = widget.isDark ? AppColors.darkCard : Colors.white;
      if (sugg.isEmpty) return const SizedBox.shrink();
      return Positioned(
        width: 280,
        child: CompositedTransformFollower(
          link: _layerLink,
          showWhenUnlinked: false,
          offset: const Offset(0, 50),
          child: Material(
            elevation: 8,
            borderRadius: BorderRadius.circular(14),
            color: dropBg,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: sugg.asMap().entries.map((entry) {
                final isFirst = entry.key == 0;
                final isLast  = entry.key == sugg.length - 1;
                return InkWell(
                  onTap: () {
                    widget.onSelected(entry.value);
                    _removeOverlay();
                  },
                  borderRadius: BorderRadius.vertical(
                    top:    isFirst ? const Radius.circular(14) : Radius.zero,
                    bottom: isLast  ? const Radius.circular(14) : Radius.zero,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    child: Row(
                      children: [
                        Icon(Icons.location_on_rounded, size: 15,
                            color: AppColors.blue.withValues(alpha: 0.7)),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            entry.value,
                            style: GoogleFonts.plusJakartaSans(
                                fontSize: 13, fontWeight: FontWeight.w600,
                                color: widget.textColor),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ),
      );
    });
    Overlay.of(context).insert(_overlayEntry!);
  }

  @override
  Widget build(BuildContext context) {
    // Show/hide overlay based on current suggestion list
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.suggestions.isNotEmpty) {
        _showOverlay();
      } else {
        _removeOverlay();
      }
    });

    return CompositedTransformTarget(
      link: _layerLink,
      child: TextField(
        controller: widget.controller,
        onChanged: widget.onChanged,
        style: TextStyle(
            color: widget.textColor, fontWeight: FontWeight.w600, fontSize: 14),
        decoration: InputDecoration(
          hintText: widget.hint,
          filled: true,
          fillColor: widget.fieldFill,
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide.none),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          suffixIcon: widget.controller.text.isNotEmpty
              ? IconButton(
                  icon: Icon(Icons.clear_rounded,
                      size: 16, color: AppColors.textMuted),
                  onPressed: () {
                    widget.controller.clear();
                    widget.onChanged('');
                    _removeOverlay();
                  },
                )
              : IconButton(
                  icon: Icon(Icons.map_outlined,
                      size: 18, color: AppColors.textMuted),
                  onPressed: () async {
                    _removeOverlay();
                    final result = await Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const MapPickerScreen()),
                    );
                    if (result != null && result is Map<String, dynamic>) {
                      final address = result['address'] as String;
                      widget.controller.text = address;
                      widget.onSelected(address);
                    }
                  },
                ),
        ),
      ),
    );
  }
}


// ── Dashed line painter ──────────────────────────────────────────────────────

class _DashedLinePainter extends CustomPainter {
  final Color color;
  const _DashedLinePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    const dashHeight = 4.0;
    const dashSpace  = 4.0;
    double startY = 0;
    final cx = size.width / 2;
    while (startY < size.height) {
      canvas.drawLine(Offset(cx, startY), Offset(cx, startY + dashHeight), paint);
      startY += dashHeight + dashSpace;
    }
  }

  @override
  bool shouldRepaint(_DashedLinePainter old) => old.color != color;
}
