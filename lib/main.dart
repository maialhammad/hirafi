
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'screens/login_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  runApp(const HirafiApp());
}

class HirafiApp extends StatelessWidget {
  const HirafiApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Hirafi',
      theme: ThemeData(
        primaryColor: const Color(0xFF245C4F),
        useMaterial3: true,
      ),
      home: const LoginScreen(),
    );
  }
}
