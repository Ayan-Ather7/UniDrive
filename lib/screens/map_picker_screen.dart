import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' as mbx;
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart' as geo;
import '../theme/app_theme.dart';

class MapPickerScreen extends StatefulWidget {
  const MapPickerScreen({super.key});

  @override
  State<MapPickerScreen> createState() => _MapPickerScreenState();
}

class _MapPickerScreenState extends State<MapPickerScreen> {
  mbx.MapboxMap? _mapboxMap;
  String _currentHoveredAddress = 'Finding location...';
  double? _currentLat;
  double? _currentLng;
  bool _isMoving = false;
  Timer? _idleTimer;
  bool _isGeocoding = false;

  @override
  void dispose() {
    _idleTimer?.cancel();
    super.dispose();
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
      // Ignore
    }
  }

  void _onCameraMove() {
    _idleTimer?.cancel();
    if (!_isMoving) {
      if (mounted) {
        setState(() {
          _isMoving = true;
          _currentHoveredAddress = 'Moving...';
        });
      }
    }
    
    // Start idle timer
    _idleTimer = Timer(const Duration(milliseconds: 600), () {
      _onCameraIdle();
    });
  }

  Future<void> _onCameraIdle() async {
    final mapbox = _mapboxMap;
    if (mapbox == null || !mounted) return;

    if (mounted) {
      setState(() {
        _isMoving = false;
        _isGeocoding = true;
        _currentHoveredAddress = 'Loading...';
      });
    }

    try {
      final cam = await mapbox.getCameraState();
      final center = cam.center;
      final lng = center.coordinates.lng;
      final lat = center.coordinates.lat;
      
      _currentLat = lat as double;
      _currentLng = lng as double;

      final uri = Uri.parse(
          'https://photon.komoot.io/reverse?lon=$lng&lat=$lat&limit=1');
      final res = await http.get(uri).timeout(const Duration(seconds: 5));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        final feats = (data['features'] as List?) ?? [];
        if (feats.isNotEmpty) {
          final p = (feats.first as Map)['properties'] as Map<String, dynamic>;
          final parts = [p['name'], p['street'], p['city']]
              .where((e) => e != null && (e as String).isNotEmpty)
              .join(', ');
          if (mounted) {
            setState(() {
              _currentHoveredAddress = parts.isNotEmpty ? parts : 'Unknown Location';
            });
          }
        } else {
          if (mounted) setState(() => _currentHoveredAddress = 'Unknown Location');
        }
      } else {
        if (mounted) setState(() => _currentHoveredAddress = 'Failed to get location');
      }
    } catch (_) {
      if (mounted) setState(() => _currentHoveredAddress = 'Failed to get location');
    } finally {
      if (mounted) setState(() => _isGeocoding = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBg : AppColors.lightBg,
      body: Stack(
        children: [
          // 1. Map Layer
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
                _flyToUserLocation();
              },
              onCameraChangeListener: (_) => _onCameraMove(),
              styleUri: isDark
                  ? mbx.MapboxStyles.DARK
                  : mbx.MapboxStyles.MAPBOX_STREETS,
            ),
          ),
          
          // 2. Center Pin & Bubble Overlay
          Align(
            alignment: Alignment.center,
            child: IgnorePointer(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    margin: const EdgeInsets.only(bottom: 6),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.darkCard.withValues(alpha: 0.95) : Colors.white.withValues(alpha: 0.95),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.1),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (_isGeocoding)
                          const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.blue),
                          )
                        else
                          const Icon(Icons.place_rounded, size: 16, color: AppColors.maroon),
                        const SizedBox(width: 8),
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 200),
                          child: Text(
                            _currentHoveredAddress,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(
                    Icons.location_pin,
                    size: 44,
                    color: AppColors.maroon,
                  ),
                  const SizedBox(height: 44), // Offset to put the tip of the pin at exact center
                ],
              ),
            ),
          ),

          // 3. Top Back Button
          Positioned(
            top: MediaQuery.of(context).padding.top + 16,
            left: 16,
            child: GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkCard : Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 10),
                  ],
                ),
                child: Icon(Icons.arrow_back_ios_new_rounded, size: 18, color: isDark ? Colors.white : Colors.black),
              ),
            ),
          ),

          // 4. Confirm Location Button
          Positioned(
            bottom: 30,
            left: 20,
            right: 20,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.blue,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 4,
              ),
              onPressed: _isGeocoding || _isMoving || _currentLat == null
                  ? null
                  : () {
                      Navigator.pop(context, {
                        'address': _currentHoveredAddress,
                        'lat': _currentLat,
                        'lng': _currentLng,
                      });
                    },
              child: Text(
                'Confirm Location',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
