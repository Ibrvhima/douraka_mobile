import 'package:flutter/material.dart';
import '../core/token_storage.dart';
import '../theme.dart';
import 'onboarding_screen.dart';
import 'shell_screen.dart';
import 'prestataire/shell_prestataire_screen.dart';
import 'admin/shell_admin_screen.dart';

// Premier écran que l'utilisateur voit au lancement de DouraKa.
// Le principe est simple : on affiche le logo avec une petite animation sympa,
// on lit le token JWT en local (zéro appel réseau à ce stade),
// puis on route vers le bon écran selon le rôle stocké.
// Pourquoi pas d'appel API ici ? Parce qu'on veut que le splash soit instantané
// même avec un mauvais réseau — la vérification du token se fera plus tard.

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {

  // On utilise deux contrôleurs séparés pour décaler les animations dans le temps :
  // le logo apparaît d'abord, puis le texte suit avec 300ms de retard.
  // Avec un seul contrôleur + Interval on aurait pu faire pareil, mais deux contrôleurs
  // c'est plus lisible et plus facile à ajuster indépendamment.
  late final AnimationController _logoCtrl;
  late final AnimationController _texteCtrl;

  late final Animation<double> _logoScale;   // élasticité au pop-in du logo
  late final Animation<double> _logoFade;    // fondu sur la première moitié de l'anim
  late final Animation<double> _texteFade;   // le texte apparaît en douceur
  late final Animation<Offset>  _texteGlisse; // et monte légèrement depuis le bas

  @override
  void initState() {
    super.initState();

    // Logo : 600ms avec un rebond élastique pour donner du caractère.
    // elasticOut c'est exagéré mais ça donne une impression de vivacité —
    // trop rigide et le splash paraît cheap.
    _logoCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _logoScale = Tween<double>(begin: 0.6, end: 1.0).animate(
      CurvedAnimation(parent: _logoCtrl, curve: Curves.elasticOut),
    );
    // Le fondu ne couvre que la première moitié de l'animation via Interval.
    // Comme ça le logo est déjà opaque quand il finit de rebondir.
    _logoFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _logoCtrl, curve: const Interval(0.0, 0.5)),
    );

    // Texte : démarre APRÈS que le logo a fini son animation (whenComplete ci-dessous).
    // Un glissement léger vers le haut + fondu — classique mais efficace.
    _texteCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _texteFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _texteCtrl, curve: Curves.easeOut),
    );
    _texteGlisse = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _texteCtrl, curve: Curves.easeOut));

    // Chaîne des animations : logo d'abord, texte ensuite.
    // whenComplete garantit qu'on attend vraiment la fin du logo avant de lancer le texte.
    _logoCtrl.forward().whenComplete(() {
      _texteCtrl.forward();
    });

    // 1800ms au total avant de router — assez pour voir l'animation complète
    // sans que l'utilisateur ait l'impression d'attendre inutilement.
    Future.delayed(const Duration(milliseconds: 1800), _rediriger);
  }

  // Logique de routing post-splash.
  // On lit d'abord le token, puis seulement si token présent on lit le rôle.
  // Les deux reads sont asynchrones (stockage sécurisé local) mais ultra rapides,
  // donc pas besoin de spinner supplémentaire — le CircularProgressIndicator du bas suffit.
  Future<void> _rediriger() async {
    // Guard classique : si le widget a été détruit pendant le délai (edge case
    // possible si l'utilisateur force-quit), on ne fait rien.
    if (!mounted) return;

    final token = await TokenStorage.lire();
    if (!mounted) return;

    // Pas de token = première installation ou l'utilisateur s'est déconnecté manuellement.
    // Dans ce cas on montre l'onboarding, jamais directement le login,
    // pour que les nouveaux utilisateurs comprennent ce qu'est l'appli.
    if (token == null) {
      _aller(const OnboardingScreen());
      return;
    }

    // Token présent : on lit le rôle stocké localement pour éviter un appel réseau.
    // Le rôle est sauvegardé au moment du login/register, donc c'est fiable tant
    // que l'utilisateur ne change pas de rôle (ce qui n'est pas possible dans l'appli).
    final role = await TokenStorage.lireRole();
    if (!mounted) return;

    final Widget destination;
    switch (role) {
      case 'prestataire':
        destination = const ShellPrestataireScreen();
      case 'admin':
        destination = const ShellAdminScreen();
      default:
        // Si le rôle est null ou inconnu, on envoie vers le shell client.
        // Vaut mieux atterrir quelque part de fonctionnel que crasher.
        destination = const ShellScreen();
    }

    _aller(destination);
  }

  // Transition en fondu vers l'écran cible.
  // PageRouteBuilder plutôt que MaterialPageRoute pour contrôler exactement
  // la durée et le type de transition — le fondu est plus doux que le slide par défaut.
  void _aller(Widget ecran) {
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        pageBuilder:         (_, _, _) => ecran,
        transitionDuration:  const Duration(milliseconds: 400),
        transitionsBuilder:  (_, anim, _, child) =>
            FadeTransition(opacity: anim, child: child),
      ),
    );
  }

  @override
  void dispose() {
    // Toujours disposer les AnimationControllers pour éviter les fuites mémoire.
    // Flutter ne le fait pas automatiquement même si le widget est détruit.
    _logoCtrl.dispose();
    _texteCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Dégradé orange diagonal — on utilise kOrange et kOrangeDark du theme
      // plutôt que des valeurs hardcodées pour rester cohérent avec le reste de l'appli.
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end:   Alignment.bottomRight,
            colors: [kOrange, kOrangeDark],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [

              // ── Bloc central : logo + nom + tagline ────────────────────────
              // Expanded + Center pour centrer parfaitement quelle que soit
              // la hauteur de l'écran (petits iPhones vs grands Androids).
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [

                      // Le logo utilise ScaleTransition + FadeTransition en même temps.
                      // On les empile plutôt que d'utiliser AnimatedBuilder pour rester
                      // déclaratif et éviter des rebuilds manuels.
                      ScaleTransition(
                        scale: _logoScale,
                        child: FadeTransition(
                          opacity: _logoFade,
                          child: Container(
                            width: 90, height: 90,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(26),
                              // Ombre portée pour décoller le logo du fond dégradé
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.2),
                                  blurRadius: 24,
                                  offset: const Offset(0, 10),
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.location_on_rounded,
                              color: kOrange,
                              size: 50,
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 28),

                      // SlideTransition + FadeTransition sur le texte.
                      // L'offset de départ (0, 0.3) est relatif à la taille du widget,
                      // donc ça reste proportionnel quelle que soit la taille d'écran.
                      SlideTransition(
                        position: _texteGlisse,
                        child: FadeTransition(
                          opacity: _texteFade,
                          child: const Column(
                            children: [
                              Text(
                                'DouraKa',
                                style: TextStyle(
                                  color:       Colors.white,
                                  fontSize:    38,
                                  fontWeight:  FontWeight.w800,
                                  letterSpacing: -0.5,
                                ),
                              ),
                              SizedBox(height: 8),
                              Text(
                                'Trouve un artisan de confiance\nà Conakry, Guinée',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color:    Colors.white70,
                                  fontSize: 14,
                                  height:   1.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // ── Indicateur discret en bas ──────────────────────────────────
              // Un petit spinner blanc semi-transparent pour signaler qu'il se passe
              // quelque chose (lecture du token) sans être intrusif.
              // La version "v1.0.0" en bas sert aussi de debug rapide sur les retours terrain.
              Padding(
                padding: const EdgeInsets.only(bottom: 48),
                child: Column(
                  children: [
                    const SizedBox(
                      width: 20, height: 20,
                      child: CircularProgressIndicator(
                        color:       Colors.white54,
                        strokeWidth: 2,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'v1.0.0',
                      style: TextStyle(
                        color:    Colors.white.withValues(alpha: 0.4),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),

            ],
          ),
        ),
      ),
    );
  }
}
