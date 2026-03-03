// ╔══════════════════════════════════════════════════════════════╗
// ║       TOPTOPGO — APPLICATION CHAUFFEUR                      ║
// ║       Point d'entrée — main.dart                           ║
// ╚══════════════════════════════════════════════════════════════╝
//
// pubspec.yaml dependencies:
//   http: ^1.2.0
//   shared_preferences: ^2.2.2

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'core/constants/colors.dart';
import 'screens/splash_screen.dart';

// ✅ AJOUT PUSHER
import 'core/services/pusher_service.dart';

void main() async {

  WidgetsFlutterBinding.ensureInitialized();

  // ✅ INITIALISATION PUSHER
  await PusherService.init();


  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ),
  );

  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);


  runApp(const TopTopGoApp());
}



class TopTopGoApp extends StatelessWidget {
  const TopTopGoApp({super.key});

  @override
  Widget build(BuildContext context) {

    return MaterialApp(

      title: 'TopTopGo Chauffeur',

      debugShowCheckedModeBanner: false,

      theme: ThemeData(

        brightness: Brightness.dark,

        scaffoldBackgroundColor: C.bg,

        primaryColor: C.orange,

        fontFamily: 'Roboto',

        colorScheme: const ColorScheme.dark(
          primary: C.orange,
          secondary: C.blue,
          surface: C.card,
        ),

        inputDecorationTheme: InputDecorationTheme(

          filled: true,

          fillColor: C.surface,

          contentPadding:
              const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 16),

          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: C.border),
          ),

          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: C.border),
          ),

          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(
              color: C.orange,
              width: 2,
            ),
          ),

          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(
              color: C.error,
            ),
          ),

          labelStyle: const TextStyle(color: C.muted),

          hintStyle: const TextStyle(
            color: C.muted,
            fontSize: 14,
          ),
        ),
      ),

      home: const SplashScreen(),
    );
  }
}