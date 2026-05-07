import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'firebase_options.dart';

import 'theme/app_theme.dart';
import 'models/driver_model.dart';
import 'screens/welcome_screen.dart';
import 'screens/login_screen.dart';
import 'screens/register_screen.dart';
import 'screens/verify_identity_screen.dart';
import 'screens/home_screen.dart';
import 'screens/ride_match_screen.dart';
import 'screens/accepted_ride_screen.dart';
import 'screens/active_ride_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/chat_screen.dart';
import 'screens/driver_dashboard_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(statusBarColor: Colors.transparent),
  );
  runApp(const UniDriveApp());
}

class UniDriveApp extends StatefulWidget {
  const UniDriveApp({super.key});

  // ignore: library_private_types_in_public_api
  static _UniDriveAppState? of(BuildContext context) =>
      context.findAncestorStateOfType<_UniDriveAppState>();

  @override
  State<UniDriveApp> createState() => _UniDriveAppState();
}

class _UniDriveAppState extends State<UniDriveApp> {
  ThemeMode _themeMode = ThemeMode.dark;

  void toggleTheme() => setState(() {
    _themeMode =
    _themeMode == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
  });

  bool get isDark => _themeMode == ThemeMode.dark;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'UniDrive',
      debugShowCheckedModeBanner: false,
      themeMode: _themeMode,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      // Named routes used by the rest of the app
      routes: {
        '/welcome': (_) => const WelcomeScreen(),
        '/login': (_) => const LoginScreen(),
        '/register': (_) => const RegisterScreen(),
        '/verify': (_) => const VerifyIdentityScreen(),
        '/home': (_) => const HomeScreen(),
        '/matches': (_) => const RideMatchScreen(),
        '/accepted': (_) => const AcceptedRideScreen(),
        '/active': (ctx) => ActiveRideScreen(
            driver: ModalRoute.of(ctx)!.settings.arguments as DriverModel),
        '/profile': (_) => const ProfileScreen(),
        '/chat': (_) => const ChatScreen(),
        '/driver-dashboard': (ctx) => DriverDashboardScreen(
            rideId: ModalRoute.of(ctx)!.settings.arguments as String),
      },
      // Auth gate: skip welcome/login if a session already exists
      home: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }
          if (snapshot.hasData && snapshot.data != null) {
            return const HomeScreen();
          }
          return const WelcomeScreen();
        },
      ),
    );
  }
}