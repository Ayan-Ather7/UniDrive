import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' as mbx;
import 'package:geolocator/geolocator.dart' as geo;
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart';

import '../theme/app_theme.dart';
import '../models/driver_model.dart';
import '../services/database_service.dart';
import '../services/auth_service.dart';
import '../core/constants.dart';

// ─────────────────────────────────────────────────────────────────────────────
// ActiveRideScreen — Task 3 implementation
//
// Live features:
//   • GPS stream via geo.Geolocator.getPositionStream() (alias: geo)
//   • Writes own position to Firestore `locations/{uid}` on every fix
//   • Streams the driver's live position from `locations/{driverId}`
//     and updates a cyan PointAnnotation marker
//   • Reads pickup / destination coordinates from the `rides/{id}` doc
//     and places green (pickup) / red (destination) markers
//   • Calls Mapbox Directions API and draws the route as a PolylineAnnotation
//   • Mapbox is imported with alias `mbx` to avoid Position collision with geo
// ─────────────────────────────────────────────────────────────────────────────

class ActiveRideScreen extends StatefulWidget {
  final DriverModel driver;
  const ActiveRideScreen({super.key, required this.driver});
  @override
  State<ActiveRideScreen> createState() => _ActiveRideScreenState();
}

class _ActiveRideScreenState extends State<ActiveRideScreen> {
  // ── Map references ────────────────────────────────────────────────────────
  mbx.MapboxMap? _mapboxMap;
  mbx.PointAnnotationManager? _pointManager;
  mbx.PolylineAnnotationManager? _polylineManager;
  mbx.PointAnnotation? _driverMarker; // updated as driver moves

  // ── Streams & timers ──────────────────────────────────────────────────────
  StreamSubscription<geo.Position>? _gpsSub;
  StreamSubscription<DocumentSnapshot>? _driverLocationSub;
  Timer? _etaTimer;

  // ── State ──────────────────────────────────────────────────────────────────
  bool _mapReady = false;
  int _etaMinutes = 0;
  final _db = DatabaseService();
  late final String _uid;

  // ─────────────────────────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    mbx.MapboxOptions.setAccessToken(kMapboxPublicToken);
    _uid = AuthService().currentUid ?? '';
    _etaMinutes = widget.driver.etaMinutes;
    _startEtaCountdown();
    _startGpsStream();
  }

  @override
  void dispose() {
    _gpsSub?.cancel();
    _driverLocationSub?.cancel();
    _etaTimer?.cancel();
    super.dispose();
  }

  // ── ETA countdown ─────────────────────────────────────────────────────────
  void _startEtaCountdown() {
    _etaTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted && _etaMinutes > 0) {
        setState(() => _etaMinutes--);
      }
    });
  }

  // ── GPS stream ────────────────────────────────────────────────────────────
  Future<void> _startGpsStream() async {
    final serviceOn = await geo.Geolocator.isLocationServiceEnabled();
    if (!serviceOn) return;

    var perm = await geo.Geolocator.checkPermission();
    if (perm == geo.LocationPermission.denied) {
      perm = await geo.Geolocator.requestPermission();
    }
    if (perm == geo.LocationPermission.denied ||
        perm == geo.LocationPermission.deniedForever) {
      return;
    }

    _gpsSub = geo.Geolocator.getPositionStream(
      locationSettings: const geo.LocationSettings(
        accuracy: geo.LocationAccuracy.high,
        distanceFilter: 5, // metres between updates
      ),
    ).listen((pos) async {
      // 1. Write own location to Firestore
      if (_uid.isNotEmpty) {
        await _db.updateUserLocation(_uid, pos.latitude, pos.longitude);
      }
      // 2. Keep camera centred on user (smooth fly)
      _mapboxMap?.flyTo(
        mbx.CameraOptions(
          center: mbx.Point(
              coordinates: mbx.Position(pos.longitude, pos.latitude)),
          zoom: 15.5,
        ),
        mbx.MapAnimationOptions(duration: 600),
      );
    });
  }

  // ── Other-party location stream ───────────────────────────────────────────
  void _startDriverLocationStream() {
    final driverId = widget.driver.driverId;
    if (driverId.isEmpty) return;

    _driverLocationSub =
        _db.streamUserLocation(driverId).listen((snap) async {
      if (!snap.exists || !_mapReady) return;
      final data = snap.data() as Map<String, dynamic>?;
      if (data == null) return;
      final lat = (data['lat'] as num?)?.toDouble();
      final lng = (data['lng'] as num?)?.toDouble();
      if (lat == null || lng == null) return;
      await _updateDriverMarker(lat, lng);
    });
  }

  // ── Map created ───────────────────────────────────────────────────────────
  Future<void> _onMapCreated(mbx.MapboxMap map) async {
    _mapboxMap = map;

    // Disable UI chrome
    map.compass.updateSettings(mbx.CompassSettings(enabled: false));
    map.scaleBar.updateSettings(mbx.ScaleBarSettings(enabled: false));
    map.logo.updateSettings(mbx.LogoSettings(enabled: false));
    map.attribution
        .updateSettings(mbx.AttributionSettings(enabled: false));

    // Show user's location puck
    map.location.updateSettings(mbx.LocationComponentSettings(
      enabled: true,
      pulsingEnabled: true,
      puckBearingEnabled: true,
    ));

    // Initial camera — Karachi centre until GPS kicks in
    map.setCamera(mbx.CameraOptions(
      center: mbx.Point(coordinates: mbx.Position(67.0650, 24.8500)),
      zoom: 13.0,
    ));

    // Annotation managers (created once, reused)
    _pointManager =
        await map.annotations.createPointAnnotationManager();
    _polylineManager =
        await map.annotations.createPolylineAnnotationManager();

    _mapReady = true;

    // Kick off Firestore streams now that map is ready
    _startDriverLocationStream();
    await _loadRideRoute();
  }

  // ── Load pickup / destination from Firestore ride doc ────────────────────
  Future<void> _loadRideRoute() async {
    try {
      final snap = await FirebaseFirestore.instance
          .collection('rides')
          .doc(widget.driver.id)
          .get();
      if (!snap.exists) return;
      final d = snap.data()!;

      final oLat = (d['origin']?['lat'] as num?)?.toDouble();
      final oLng = (d['origin']?['lng'] as num?)?.toDouble();
      final dLat = (d['destination']?['lat'] as num?)?.toDouble();
      final dLng = (d['destination']?['lng'] as num?)?.toDouble();

      if (oLat != null && oLng != null) {
        await _addStaticMarker(oLat, oLng, AppColors.success); // green = pickup
      }
      if (dLat != null && dLng != null) {
        await _addStaticMarker(dLat, dLng, AppColors.maroonLight); // red = destination
      }
      if (oLat != null && oLng != null && dLat != null && dLng != null) {
        await _drawRoute(oLng, oLat, dLng, dLat);
      }
    } catch (_) {
      // Ride doc missing or coords absent — map still works without route
    }
  }

  // ── Helpers: marker images ────────────────────────────────────────────────

  /// Renders a white-ringed coloured circle as a PNG Uint8List.
  Future<Uint8List> _makeCirclePng(Color fill, {int size = 36}) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    // White border
    canvas.drawCircle(
        Offset(size / 2, size / 2), size / 2, Paint()..color = Colors.white);
    // Coloured fill
    canvas.drawCircle(Offset(size / 2, size / 2), size / 2 - 3,
        Paint()..color = fill);
    final picture = recorder.endRecording();
    final img = await picture.toImage(size, size);
    final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
    return bytes!.buffer.asUint8List();
  }

  Future<void> _addStaticMarker(
      double lat, double lng, Color color) async {
    final mgr = _pointManager;
    if (mgr == null) return;
    final img = await _makeCirclePng(color);
    await mgr.create(mbx.PointAnnotationOptions(
      geometry: mbx.Point(coordinates: mbx.Position(lng, lat)),
      image: img,
      iconSize: 1.0,
    ));
  }

  Future<void> _updateDriverMarker(double lat, double lng) async {
    final mgr = _pointManager;
    if (mgr == null) return;
    // Delete old marker before adding the new one
    if (_driverMarker != null) {
      await mgr.delete(_driverMarker!);
      _driverMarker = null;
    }
    final img = await _makeCirclePng(AppColors.cyan);
    _driverMarker = await mgr.create(mbx.PointAnnotationOptions(
      geometry: mbx.Point(coordinates: mbx.Position(lng, lat)),
      image: img,
      iconSize: 1.0,
    ));
  }

  // ── Mapbox Directions polyline ────────────────────────────────────────────
  Future<void> _drawRoute(
      double oLng, double oLat, double dLng, double dLat) async {
    try {
      final uri = Uri.parse(
        'https://api.mapbox.com/directions/v5/mapbox/driving/'
        '${oLng.toStringAsFixed(6)},${oLat.toStringAsFixed(6)};'
        '${dLng.toStringAsFixed(6)},${dLat.toStringAsFixed(6)}'
        '?geometries=geojson&overview=full'
        '&access_token=$kMapboxPublicToken',
      );
      final res =
          await http.get(uri).timeout(const Duration(seconds: 10));
      if (res.statusCode != 200) return;

      final body = jsonDecode(res.body) as Map<String, dynamic>;
      final routes = body['routes'] as List?;
      if (routes == null || routes.isEmpty) return;

      final rawCoords =
          routes[0]['geometry']['coordinates'] as List;
      final coords = rawCoords
          .map((c) => mbx.Position(
              (c[0] as num).toDouble(), (c[1] as num).toDouble()))
          .toList();

      final mgr = _polylineManager;
      if (mgr == null) return;

      await mgr.create(mbx.PolylineAnnotationOptions(
        geometry: mbx.LineString(coordinates: coords),
        lineColor: AppColors.blue.toARGB32(),
        lineWidth: 4.5,
        lineOpacity: 0.88,
      ));
    } catch (_) {
      // Network / parse error — ride continues without polyline overlay
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
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
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.darkCard.withValues(alpha: 0.72),
                border: Border.all(
                    color: Colors.white.withValues(alpha: 0.1)),
              ),
              child: IconButton(
                icon: const Icon(Icons.close_rounded,
                    color: Colors.white),
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16, top: 8),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: AppColors.darkCard.withValues(alpha: 0.72),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                    color: Colors.white.withValues(alpha: 0.1)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                        color: AppColors.success,
                        shape: BoxShape.circle),
                  ).animate(onPlay: (c) => c.repeat(reverse: true))
                      .scale(duration: 800.ms),
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
          ).animate().fadeIn(delay: 200.ms).slideY(begin: -0.2),
        ],
      ),
      body: Stack(
        children: [
          // ── Map ──────────────────────────────────────────────────────
          mbx.MapWidget(
            onMapCreated: _onMapCreated,
            styleUri: mbx.MapboxStyles.DARK,
          ).animate().fadeIn(duration: 600.ms),

          // ── SOS FAB ──────────────────────────────────────────────────
          Positioned(
            left: 20,
            bottom: 240,
            child: FloatingActionButton(
              heroTag: 'sos',
              backgroundColor: AppColors.maroonLight,
              onPressed: () {},
              elevation: 4,
              child: const Icon(Icons.warning_amber_rounded,
                  color: Colors.white),
            ).animate().fadeIn(delay: 400.ms).slideX(begin: -0.2),
          ),

          // ── Chat FAB ─────────────────────────────────────────────────
          Positioned(
            right: 20,
            bottom: 240,
            child: FloatingActionButton(
              heroTag: 'chat',
              backgroundColor: AppColors.blue,
              onPressed: () =>
                  Navigator.pushNamed(context, '/chat'),
              elevation: 4,
              child: const Icon(Icons.chat_bubble_rounded,
                  color: Colors.white),
            ).animate().fadeIn(delay: 400.ms).slideX(begin: 0.2),
          ),

          // ── Map legend ───────────────────────────────────────────────
          Positioned(
            left: 20,
            top: 100,
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.darkCard.withValues(alpha: 0.78),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                    color: Colors.white.withValues(alpha: 0.08)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _LegendDot(AppColors.success, 'Pickup'),
                  const SizedBox(height: 6),
                  _LegendDot(AppColors.maroonLight, 'Destination'),
                  const SizedBox(height: 6),
                  _LegendDot(AppColors.cyan, 'Driver'),
                ],
              ),
            ).animate().fadeIn(delay: 500.ms),
          ),

          // ── Bottom Info Card ──────────────────────────────────────────
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.darkBg.withValues(alpha: 0.88),
                borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(32)),
                border: Border(
                    top: BorderSide(
                        color: Colors.white.withValues(alpha: 0.08))),
              ),
              padding:
                  const EdgeInsets.fromLTRB(28, 28, 28, 40),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Stats row
                  Row(
                    mainAxisAlignment:
                        MainAxisAlignment.spaceEvenly,
                    children: [
                      _Stat('ETA',
                          '${_etaMinutes > 0 ? _etaMinutes : '<1'} min',
                          AppColors.cyan),
                      Container(
                          width: 1,
                          height: 40,
                          color: AppColors.darkBorder),
                      _Stat(
                          'Fare',
                          'PKR ${widget.driver.farePerPerson.toStringAsFixed(0)}',
                          AppColors.orange),
                      Container(
                          width: 1,
                          height: 40,
                          color: AppColors.darkBorder),
                      _Stat(
                          'To',
                          widget.driver.to.isNotEmpty
                              ? widget.driver.to
                              : 'Campus',
                          AppColors.success),
                    ],
                  ).animate().fadeIn(delay: 600.ms),
                  const SizedBox(height: 28),

                  // Driver info row
                  Row(
                    children: [
                      Container(
                        width: 58,
                        height: 58,
                        decoration: BoxDecoration(
                          color: AppColors.darkSurface,
                          shape: BoxShape.circle,
                          border: Border.all(
                              color: AppColors.cyan, width: 2),
                        ),
                        child: const Icon(Icons.person_rounded,
                            color: AppColors.textMuted, size: 30),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment:
                              CrossAxisAlignment.start,
                          children: [
                            Text(widget.driver.name,
                                style: GoogleFonts.plusJakartaSans(
                                    fontSize: 19,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.white)),
                            const SizedBox(height: 4),
                            Row(children: [
                              Text(
                                  '${widget.driver.carModel} · ',
                                  style: GoogleFonts.plusJakartaSans(
                                      fontSize: 13,
                                      color: AppColors.textMuted)),
                              const Icon(Icons.star_rounded,
                                  size: 13,
                                  color: AppColors.orange),
                              Text(' ${widget.driver.rating}',
                                  style: GoogleFonts.plusJakartaSans(
                                      fontSize: 13,
                                      color: Colors.white,
                                      fontWeight: FontWeight.w700)),
                            ]),
                          ],
                        ),
                      ),
                      // Plate pill
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 7),
                        decoration: BoxDecoration(
                          color: AppColors.blue
                              .withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                              color: AppColors.blue
                                  .withValues(alpha: 0.3)),
                        ),
                        child: Text(widget.driver.licensePlate,
                            style: GoogleFonts.plusJakartaSans(
                                color: AppColors.cyan,
                                fontWeight: FontWeight.w800,
                                fontSize: 12,
                                letterSpacing: 1)),
                      ),
                    ],
                  ).animate().fadeIn(delay: 700.ms).slideY(begin: 0.2),
                ],
              ),
            ).animate().slideY(
                begin: 1.0,
                duration: 600.ms,
                curve: Curves.easeOutExpo),
          ),
        ],
      ),
    );
  }
}

// ── Small helpers ─────────────────────────────────────────────────────────────

class _Stat extends StatelessWidget {
  final String label, val;
  final Color color;
  const _Stat(this.label, this.val, this.color);
  @override
  Widget build(BuildContext context) => Column(
        children: [
          Text(label,
              style: GoogleFonts.plusJakartaSans(
                  color: AppColors.textMuted,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1)),
          const SizedBox(height: 6),
          Text(val,
              style: GoogleFonts.plusJakartaSans(
                  color: color,
                  fontWeight: FontWeight.w800,
                  fontSize: 15)),
        ],
      );
}

class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;
  const _LegendDot(this.color, this.label);
  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                  color: color, shape: BoxShape.circle)),
          const SizedBox(width: 8),
          Text(label,
              style: GoogleFonts.plusJakartaSans(
                  color: AppColors.textMuted,
                  fontSize: 11,
                  fontWeight: FontWeight.w600)),
        ],
      );
}
