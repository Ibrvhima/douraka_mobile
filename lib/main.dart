import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'theme.dart';
import 'core/navigation.dart';
import 'screens/splash_screen.dart';
import 'screens/login_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ),
  );
  runApp(const DouraKaApp());
}

class DouraKaApp extends StatelessWidget {
  const DouraKaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Douraka',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(),
      navigatorKey: navigatorKey,
      home: const SplashScreen(),
      routes: {
        // Route nommée pour que l'intercepteur 401 puisse rediriger sans contexte
        '/login': (_) => const LoginScreen(),
      },
    );
  }
}
