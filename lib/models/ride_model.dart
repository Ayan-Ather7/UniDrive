enum RideStatus { upcoming, active, completed, cancelled }

class RideModel {
  final String id;
  final String driverId;
  final String driverName;
  final String from;
  final String to;
  final String date;
  final String time;
  final double fare;
  final RideStatus status;
  final double rating;

  const RideModel({
    required this.id,
    required this.driverId,
    required this.driverName,
    required this.from,
    required this.to,
    required this.date,
    required this.time,
    required this.fare,
    required this.status,
    this.rating = 0.0,
  });
}
