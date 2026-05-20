import 'package:cloud_firestore/cloud_firestore.dart';
import 'ride_model.dart';

// ─────────────────────────────────────────────────────────────────────────────
// RideRole — whether the user was driving or riding
// ─────────────────────────────────────────────────────────────────────────────

enum RideRole { driver, passenger }

// ─────────────────────────────────────────────────────────────────────────────
// RideHistoryEntry — unified model for the history screen
// Constructed either from a 'rides' doc (driver) or from a 'bookings' doc
// combined with its parent 'rides' doc (passenger).
// ─────────────────────────────────────────────────────────────────────────────

class RideHistoryEntry {
  final String id;
  final String from;
  final String to;
  final DateTime departureTime;
  final double fare;
  final RideStatus status;
  final RideRole role;

  const RideHistoryEntry({
    required this.id,
    required this.from,
    required this.to,
    required this.departureTime,
    required this.fare,
    required this.status,
    required this.role,
  });

  // ── Formatted helpers ──────────────────────────────────────────────────────

  String get formattedDate {
    final d = departureTime;
    return '${d.day.toString().padLeft(2, '0')}/'
        '${d.month.toString().padLeft(2, '0')}/'
        '${d.year}';
  }

  String get formattedTime {
    final d = departureTime;
    return '${d.hour.toString().padLeft(2, '0')}:'
        '${d.minute.toString().padLeft(2, '0')}';
  }

  // ── Factories ──────────────────────────────────────────────────────────────

  /// Builds an entry from a Firestore 'rides' doc where the user is the driver.
  static RideHistoryEntry? fromDriverRide(
      String id, Map<String, dynamic> data) {
    try {
      final ts = data['departureTime'];
      final dept = ts is Timestamp ? ts.toDate() : DateTime.now();
      return RideHistoryEntry(
        id: id,
        from: (data['origin'] as Map<String, dynamic>?)?['address']
                as String? ??
            'Unknown Origin',
        to: (data['destination'] as Map<String, dynamic>?)?['address']
                as String? ??
            'Unknown Destination',
        departureTime: dept,
        fare:
            (data['currentFarePerPassenger'] as num?)?.toDouble() ?? 0.0,
        status: data['status'] == 'Completed'
            ? RideStatus.completed
            : RideStatus.cancelled,
        role: RideRole.driver,
      );
    } catch (_) {
      return null;
    }
  }

  /// Builds an entry from a 'bookings' doc + its parent 'rides' doc,
  /// used when the user was a passenger.
  static RideHistoryEntry? fromPassengerBooking(
    String bookingId,
    Map<String, dynamic> bookingData,
    Map<String, dynamic> rideData,
  ) {
    try {
      final ts = rideData['departureTime'];
      final dept = ts is Timestamp ? ts.toDate() : DateTime.now();
      final bStatus = bookingData['status'] as String? ?? '';
      return RideHistoryEntry(
        id: bookingId,
        from: (rideData['origin'] as Map<String, dynamic>?)?['address']
                as String? ??
            'Unknown Origin',
        to: (rideData['destination'] as Map<String, dynamic>?)?['address']
                as String? ??
            'Unknown Destination',
        departureTime: dept,
        fare:
            (rideData['currentFarePerPassenger'] as num?)?.toDouble() ?? 0.0,
        status: bStatus == 'Completed'
            ? RideStatus.completed
            : RideStatus.cancelled,
        role: RideRole.passenger,
      );
    } catch (_) {
      return null;
    }
  }
}
