import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'firebase_options.dart';
import 'screens/auth_gate.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  if (kIsWeb) {
    try {
      await FirebaseAuth.instance.setPersistence(Persistence.LOCAL);
    } catch (_) {
      // Firebase Auth still restores sessions with its platform default if this is unavailable.
    }
  }
  runApp(const PawnTrackRoot());
}

class PawnTrackRoot extends StatelessWidget {
  const PawnTrackRoot({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Last Resort Pawnshop',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: const Color(0xff2563eb),
        scaffoldBackgroundColor: const Color(0xfff7f9fc),
      ),
      home: const AuthGate(),
    );
  }
}
