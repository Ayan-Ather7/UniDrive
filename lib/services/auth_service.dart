import 'package:firebase_auth/firebase_auth.dart';
import 'database_service.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final DatabaseService _db = DatabaseService();

  Stream<User?> get userStream => _auth.authStateChanges();
  String? get currentUid => _auth.currentUser?.uid;

  Future<UserCredential?> registerUser({
    required String email,
    required String password,
    required String name,
    required String gender,
    required DateTime dob,
  }) async {
    try {
      final trimmedEmail = email.trim().toLowerCase();
      final isValidUniEmail = trimmedEmail.endsWith('.edu.pk') || trimmedEmail.endsWith('.edu');
      if (!trimmedEmail.contains('@') || !isValidUniEmail) {
        throw Exception('Only valid university emails (.edu.pk or .edu) are allowed.');
      }
      
      UserCredential credential = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      await credential.user?.sendEmailVerification();
      if (credential.user != null) {
        await _db.createUserDocument(
          uid: credential.user!.uid,
          email: email.trim(),
          name: name.trim(),
          gender: gender,
          dob: dob,
        );
      }
      return credential;
    } catch (e) {
      throw Exception('Registration failed: ${e.toString()}');
    }
  }

  Future<UserCredential> login({required String email, required String password}) async {
    return await _auth.signInWithEmailAndPassword(email: email, password: password);
  }

  Future<void> logout() async {
    await _auth.signOut();
  }
}
