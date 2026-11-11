import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:home_widget/home_widget.dart';

import 'art.dart';
import 'drawing.dart';
import 'home_screen.dart';
import 'sign_in_screen.dart';
import 'theme.dart';

// Runs in its own isolate when a push arrives while the app is closed.
@pragma('vm:entry-point')
Future<void> _onBackgroundMessage(RemoteMessage message) async {
  if (message.data['type'] != 'drawing') return;
  await Firebase.initializeApp();
  await syncWidgetFromDatabase();
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp();
  } catch (_) {
    runApp(const SetupNeededApp());
    return;
  }
  FirebaseDatabase.instance.setPersistenceEnabled(true);
  FirebaseMessaging.onBackgroundMessage(_onBackgroundMessage);
  // shortcut: the theme choice lives in the widget plugin's local storage,
  // move it to shared_preferences if more settings need saving
  try {
    themeId.value =
        await HomeWidget.getWidgetData<String>('theme') ?? defaultThemeId;
  } catch (_) {}
  await GoogleSignIn.instance.initialize();
  runApp(const DuetApp());
}

class SetupNeededApp extends StatelessWidget {
  const SetupNeededApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Duet',
      theme: appTheme(defaultThemeId, Brightness.light),
      darkTheme: appTheme(defaultThemeId, Brightness.dark),
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
    return ValueListenableBuilder<String>(
      valueListenable: themeId,
      builder: (context, id, home) => MaterialApp(
        title: 'Duet',
        theme: appTheme(id, Brightness.light),
        darkTheme: appTheme(id, Brightness.dark),
        home: home,
      ),
      child: StreamBuilder<User?>(
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
