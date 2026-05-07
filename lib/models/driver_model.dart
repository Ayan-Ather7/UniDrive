class DriverModel {
  final String id;
  final String driverId;
  final String name;
  final String avatarUrl;
  final String carModel;
  final String carColor;
  final String licensePlate;
  final double rating;
  final int matchPercent;
  final double perHeadFare;
  final int availableSeats;
  final int occupiedSeats; // How many seats are already taken
  final String from;
  final String to;
  final String departureTime;
  final bool isVerified;
  final bool isPinkRide;
  final int etaMinutes;
  final String university;
  final String gender;
  final int avatarSeed;

  const DriverModel({
    required this.id,
    required this.name,
    required this.avatarUrl,
    required this.carModel,
    required this.carColor,
    required this.licensePlate,
    required this.rating,
    required this.matchPercent,
    required this.perHeadFare,
    required this.availableSeats,
    this.occupiedSeats = 0,
    required this.from,
    required this.to,
    required this.departureTime,
    required this.isVerified,
    required this.isPinkRide,
    required this.etaMinutes,
    this.university = 'Bahria University Karachi',
    this.gender = 'male',
    this.avatarSeed = 1,
    this.driverId = '',
  });

  /// Fare per person = totalFare / (occupiedSeats + 1 for the requesting passenger)
  /// If no one is sharing yet, the full fare is shown. Otherwise it decreases.
  double get farePerPerson {
    final sharing = occupiedSeats + 1; // +1 for the new passenger
    return (perHeadFare / sharing).roundToDouble();
  }
}
