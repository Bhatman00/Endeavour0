import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'login_screen.dart';
import 'home_screen.dart'; // Imports the new Home Screen

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const EndeavourApp());
}

class EndeavourApp extends StatelessWidget {
  const EndeavourApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.deepPurple,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      // Automatically route user based on Auth State
      home: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snapshot) {
          // Show a loading spinner while checking auth status
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(
              backgroundColor: Color(0xFF0F0F13),
              body: Center(
                child: CircularProgressIndicator(color: Colors.white),
              ),
            );
          }
          // If the user is logged in, send them to the Path Chooser
          if (snapshot.hasData) {
            return const HomeScreen();
          }
          // If the user is NOT logged in, show the Login Screen
          return const LoginScreen();
        },
      ),
    );
  }
}
