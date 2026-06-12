import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'theme.dart';
import 'core/navigation.dart';
import 'screens/splash_screen.dart';
import 'screens/login_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // Portrait uniquement — le layout n'est pas conçu pour le paysage,
  // inutile de laisser Flutter gérer deux orientations.
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

  // Barre de statut transparente avec icônes sombres.
  // Le fond de l'app étant clair, Brightness.light rendrait les icônes invisibles.
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
      title: 'DouraKa',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(),
      // navigatorKey partagé avec ApiClient pour les redirections 401 hors-contexte widget
      navigatorKey: navigatorKey,
      home: const SplashScreen(),
      routes: {
        // Route nommée pour que l'intercepteur Dio puisse y pousser sans dépendre du contexte
        '/login': (_) => const LoginScreen(),
      },
    );
  }
}
