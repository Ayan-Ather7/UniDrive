import 'package:cloud_firestore/cloud_firestore.dart';

class DatabaseService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<void> createUserDocument({
    required String uid,
    required String email,
    required String name,
    required String gender,
    required DateTime dob,
  }) async {
    await _firestore.collection('users').doc(uid).set({
      'uid': uid,
      'name': name,
      'email': email,
      'gender': gender,
      'dob': Timestamp.fromDate(dob),
      'isVerified': false, // STRICTLY FALSE UNTIL ADMIN APPROVAL
      'idImageUrl': '', 
      'ratingAsDriver': 5.0,
      'ratingAsPassenger': 5.0,
      'currentMode': 'Passenger', 
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> updateUserProfile(String uid, Map<String, dynamic> data) async {
    await _firestore.collection('users').doc(uid).update(data);
  }

  Stream<DocumentSnapshot> streamUserData(String uid) {
    return _firestore.collection('users').doc(uid).snapshots();
  }

  Stream<QuerySnapshot> streamAvailableRides(bool isPinkOnly) {
    Query q = _firestore.collection('rides').where('status', isEqualTo: 'Open');
    if (isPinkOnly) {
      q = q.where('isPinkRide', isEqualTo: true);
    }
    return q.snapshots();
  }

  Stream<QuerySnapshot> streamPastRides() {
    return _firestore.collection('rides')
        .where('status', whereIn: ['Completed', 'Cancelled'])
        .snapshots();
  }

  Future<String> createRide({
    required String driverId,
    required String vehicleId,
    required Map<String, dynamic> origin,
    required Map<String, dynamic> destination,
    required DateTime departureTime,
    required double baseFare,
    required bool isPinkRide,
    required int availableSeats, // driver-selected: 1–4
  }) async {
    DocumentReference rideRef = _firestore.collection('rides').doc();
    await rideRef.set({
      'rideId': rideRef.id,
      'driverId': driverId,
      'vehicleId': vehicleId,
      'origin': origin,
      'destination': destination,
      'departureTime': Timestamp.fromDate(departureTime),
      'baseFare': baseFare,
      'currentFarePerPassenger': baseFare,
      'availableSeats': availableSeats,
      'isPinkRide': isPinkRide,
      'status': 'Open',
      'createdAt': FieldValue.serverTimestamp(),
      // expiresAt = createdAt + 1 hour — used client-side to filter expired rides
      'expiresAt': Timestamp.fromDate(
          DateTime.now().toUtc().add(const Duration(hours: 1))),
    });
    return rideRef.id;
  }

  /// Returns a stream of the driver's currently active (Open) ride, if any.
  Stream<QuerySnapshot> streamActiveDriverRide(String driverId) {
    return _firestore
        .collection('rides')
        .where('driverId', isEqualTo: driverId)
        .where('status', isEqualTo: 'Open')
        .limit(1)
        .snapshots();
  }

  /// Returns a stream of the passenger's active booking, if any.
  Stream<QuerySnapshot> streamActivePassengerBooking(String passengerId) {
    return _firestore
        .collection('bookings')
        .where('passengerId', isEqualTo: passengerId)
        .where('status', whereIn: ['Pending', 'Accepted'])
        .limit(1)
        .snapshots();
  }

  /// Cancel a ride (driver cancels their own open ride).
  Future<void> cancelRide(String rideId) async {
    await _firestore.collection('rides').doc(rideId).update({
      'status': 'Cancelled',
    });
  }

  /// Filter for non-expired rides — client-side companion to Firestore query.
  bool isRideExpired(Map<String, dynamic> data) {
    final expiresAt = data['expiresAt'] as Timestamp?;
    if (expiresAt == null) return false;
    return expiresAt.toDate().isBefore(DateTime.now().toUtc());
  }

  Stream<DocumentSnapshot> streamRide(String rideId) {
    return _firestore.collection('rides').doc(rideId).snapshots();
  }

  Future<void> requestBooking({
    required String rideId,
    required String passengerId,
  }) async {
    DocumentReference bookingRef = _firestore.collection('bookings').doc();
    await bookingRef.set({
      'bookingId': bookingRef.id,
      'rideId': rideId,
      'passengerId': passengerId,
      'status': 'Pending',
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> updateBookingStatus(String bookingId, String newStatus) async {
    await _firestore.collection('bookings').doc(bookingId).update({
      'status': newStatus,
    });
  }

  Stream<QuerySnapshot> streamRideMessages(String rideId, String passengerId) {
    String chatId = '${rideId}_$passengerId';
    return _firestore.collection('chats').doc(chatId).collection('messages').orderBy('timestamp', descending: true).snapshots();
  }

  Future<void> sendMessage({
    required String rideId,
    required String driverId,
    required String passengerId,
    required String senderId,
    required String text,
  }) async {
    String chatId = '${rideId}_$passengerId';
    DocumentReference chatDoc = _firestore.collection('chats').doc(chatId);
    await chatDoc.set({
      'chatId': chatId,
      'rideId': rideId,
      'driverId': driverId,
      'passengerId': passengerId,
      'lastMessage': text,
      'lastUpdated': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    await chatDoc.collection('messages').add({
      'senderId': senderId,
      'text': text,
      'timestamp': FieldValue.serverTimestamp(),
    });
  }

  // ── Vehicle profile ────────────────────────────────────────────────────────

  Future<void> saveVehicleProfile(String uid, {
    required String make,
    required String model,
    required String color,
    required String licensePlate,
  }) async {
    await _firestore.collection('users').doc(uid).update({
      'vehicle': {
        'make': make,
        'model': model,
        'color': color,
        'licensePlate': licensePlate,
      },
    });
  }

  Stream<DocumentSnapshot> streamVehicleProfile(String uid) {
    return _firestore.collection('users').doc(uid).snapshots();
  }

  // ── Payment methods ────────────────────────────────────────────────────────

  Future<void> savePaymentMethod(String uid, Map<String, dynamic> method) async {
    await _firestore
        .collection('users')
        .doc(uid)
        .collection('paymentMethods')
        .add({
      ...method,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Stream<QuerySnapshot> streamPaymentMethods(String uid) {
    return _firestore
        .collection('users')
        .doc(uid)
        .collection('paymentMethods')
        .snapshots();
  }

  // ── Driver dashboard ───────────────────────────────────────────────────────

  /// Live stream of all accepted/pending bookings for a specific ride.
  Stream<QuerySnapshot> streamBookingsForRide(String rideId) {
    return _firestore
        .collection('bookings')
        .where('rideId', isEqualTo: rideId)
        .where('status', whereIn: ['Pending', 'Accepted'])
        .snapshots();
  }

  /// Close the ride offer: sets status to 'InProgress' so no new passengers
  /// can join, but keeps the ride alive for current passengers.
  Future<void> closeRideOffer(String rideId) async {
    await _firestore.collection('rides').doc(rideId).update({
      'status': 'InProgress',
    });
  }
}
