import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';

import 'art.dart';
import 'home_screen.dart';
import 'sign_in_screen.dart';
import 'theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp();
  } catch (_) {
    runApp(const SetupNeededApp());
    return;
  }
  FirebaseDatabase.instance.setPersistenceEnabled(true);
  await GoogleSignIn.instance.initialize();
  runApp(const DuetApp());
}

class SetupNeededApp extends StatelessWidget {
  const SetupNeededApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Duet',
      theme: buildTheme(Brightness.light),
      darkTheme: buildTheme(Brightness.dark),
      home: const Scaffold(
        body: SafeArea(
          child: MascotMessage(
            mascot: 'mascot_shocked',
            title: 'Firebase is not set up',
            body:
                'This build has no google-services.json. Follow the setup '
                'steps in the README, then build the app again.',
          ),
        ),
      ),
    );
  }
}

class DuetApp extends StatelessWidget {
  const DuetApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Duet',
      theme: buildTheme(Brightness.light),
      darkTheme: buildTheme(Brightness.dark),
      home: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }
          final user = snapshot.data;
          return user == null
              ? const SignInScreen()
              : HomeScreen(key: ValueKey(user.uid), user: user);
        },
      ),
    );
  }
}
