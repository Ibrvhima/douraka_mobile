import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import '../core/api_client.dart';
import '../core/token_storage.dart';
import '../theme.dart';
import 'shell_screen.dart';
import 'register_screen.dart';
import 'prestataire/shell_prestataire_screen.dart';
import 'admin/shell_admin_screen.dart';

// Écran de connexion DouraKa.
// Pas de Form/GlobalKey ici — on préfère une validation manuelle simple
// plutôt que le système de validation de Flutter qui ajoute de la complexité
// pour un formulaire aussi court (2 champs).

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailCtrl    = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _api          = ApiClient();

  bool   _loading         = false;
  bool   _passwordVisible = false;
  String _erreur          = ''; // chaîne vide = pas d'erreur affichée

  Future<void> _seConnecter() async {
    // Validation légère côté client avant de taper dans le réseau.
    // On vérifie juste que les champs ne sont pas vides — la vraie validation
    // (format email, mot de passe valide) est faite côté serveur.
    if (_emailCtrl.text.trim().isEmpty || _passwordCtrl.text.isEmpty) {
      setState(() => _erreur = 'Remplis tous les champs');
      return;
    }

    setState(() { _loading = true; _erreur = ''; });

    try {
      // _api.login() fait l'appel HTTP ET sauvegarde le token + le rôle en local.
      // On ne récupère pas de valeur de retour ici — on lit directement depuis
      // le stockage local juste après pour être sûr d'avoir les données persistées.
      await _api.login(_emailCtrl.text.trim(), _passwordCtrl.text);

      if (!mounted) return;

      // Lecture du rôle depuis le stockage sécurisé plutôt que depuis la réponse HTTP.
      // Ça garantit qu'on route à partir des mêmes données qu'au prochain démarrage.
      final role = await TokenStorage.lireRole();
      _allerVersBonShell(role);

    } on DioException catch (e) {
      if (!mounted) return;
      setState(() {
        // On distingue les erreurs métier (400 = mauvais credentials) des erreurs réseau
        // pour donner un message utile à l'utilisateur plutôt qu'un "Erreur inconnue".
        if (e.response?.statusCode == 400) {
          _erreur = 'Email ou mot de passe incorrect';
        } else if (e.type == DioExceptionType.connectionTimeout ||
                   e.type == DioExceptionType.receiveTimeout) {
          _erreur = 'Connexion lente, réessaie dans un moment';
        } else {
          _erreur = 'Problème de connexion, vérifie ton réseau';
        }
        _loading = false;
      });
    } finally {
      // Le finally s'exécute même en cas de succès. On remet _loading à false
      // au cas où la navigation n'aurait pas encore eu lieu (widget encore monté).
      if (mounted) setState(() => _loading = false);
    }
  }

  // Routing post-login selon le rôle.
  // Même logique que dans le splash : on centralise ici pour ne pas dupliquer
  // le switch/case partout dans l'app. Si on ajoute un rôle demain,
  // c'est juste ici qu'il faut mettre à jour.
  void _allerVersBonShell(String? role) {
    Widget destination;
    if (role == 'prestataire') {
      destination = const ShellPrestataireScreen();
    } else if (role == 'admin') {
      destination = const ShellAdminScreen();
    } else {
      // Client par défaut — couvre aussi le cas null (role non défini)
      destination = const ShellScreen();
    }

    // Transition en fondu : pushReplacement pour vider la back stack.
    // L'utilisateur ne doit pas pouvoir revenir au login avec le bouton retour
    // une fois connecté.
    Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        pageBuilder: (_, _, _) => destination,
        transitionDuration: const Duration(milliseconds: 350),
        transitionsBuilder: (_, anim, _, child) =>
            FadeTransition(opacity: anim, child: child),
      ),
    );
  }

  @override
  void dispose() {
    // Sans dispose(), les contrôleurs restent en mémoire après la navigation.
    // Flutter detecte les leaks en debug mais en production ça accumule silencieusement.
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      // SingleChildScrollView pour que le formulaire reste accessible
      // quand le clavier s'ouvre sur les petits écrans.
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 52),

              // ── En-tête : logo + accroche ──────────────────────────────────
              // On répète le logo ici (déjà vu dans le splash) pour ancrer
              // visuellement la marque — les utilisateurs qui arrivent directement
              // sur le login (deep link, redémarrage) ne voient pas le splash.
              Center(
                child: Column(
                  children: [
                    Container(
                      width: 68,
                      height: 68,
                      decoration: BoxDecoration(
                        color: kOrange,
                        borderRadius: BorderRadius.circular(18),
                        boxShadow: [
                          BoxShadow(
                            color: kOrange.withValues(alpha: 0.3),
                            blurRadius: 16,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: const Icon(Icons.location_on, color: Colors.white, size: 36),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'DouraKa',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        color: kTextPrimary,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Connecte-toi pour continuer',
                      style: TextStyle(fontSize: 14, color: kTextGray),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 44),

              // ── Champ Email ────────────────────────────────────────────────
              const Text('Email',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: kTextPrimary)),
              const SizedBox(height: 8),
              TextField(
                controller: _emailCtrl,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next, // "Suivant" au lieu de "OK" sur le clavier
                decoration: const InputDecoration(
                  hintText: 'ton@email.com',
                  prefixIcon: Icon(Icons.email_outlined, size: 20, color: kTextGray),
                ),
              ),

              const SizedBox(height: 18),

              // ── Champ Mot de passe ─────────────────────────────────────────
              const Text('Mot de passe',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: kTextPrimary)),
              const SizedBox(height: 8),
              TextField(
                controller: _passwordCtrl,
                obscureText: !_passwordVisible,
                textInputAction: TextInputAction.done,
                // onSubmitted permet de valider avec la touche "Entrée" du clavier —
                // UX importante sur mobile, beaucoup d'utilisateurs ne cherchent pas le bouton.
                onSubmitted: (_) => _seConnecter(),
                decoration: InputDecoration(
                  hintText: '••••••••',
                  prefixIcon: const Icon(Icons.lock_outline, size: 20, color: kTextGray),
                  // Toggle visibilité du mot de passe — standard iOS/Android
                  suffixIcon: IconButton(
                    icon: Icon(
                      _passwordVisible ? Icons.visibility_off : Icons.visibility,
                      size: 20, color: kTextGray,
                    ),
                    onPressed: () =>
                        setState(() => _passwordVisible = !_passwordVisible),
                  ),
                ),
              ),

              // ── Message d'erreur ───────────────────────────────────────────
              // Affiché conditionnellement via spread operator — quand _erreur est vide
              // on n'insère rien dans le Column, pas de SizedBox vide inutile.
              if (_erreur.isNotEmpty) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: kRedLight,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline, size: 16, color: kRed),
                      const SizedBox(width: 8),
                      Expanded(child: Text(_erreur,
                          style: const TextStyle(fontSize: 13, color: kRed))),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 28),

              // ── Bouton de connexion ────────────────────────────────────────
              // onPressed: null désactive le bouton pendant le chargement —
              // Flutter gère automatiquement le style "disabled" via le theme.
              ElevatedButton(
                onPressed: _loading ? null : _seConnecter,
                child: _loading
                    ? const SizedBox(width: 22, height: 22,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                    : const Text('Se connecter'),
              ),

              const SizedBox(height: 24),

              // ── Lien vers l'inscription ────────────────────────────────────
              // push() et non pushReplacement() : l'utilisateur doit pouvoir
              // revenir au login depuis l'écran d'inscription avec le bouton retour.
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text("Pas encore de compte ?",
                      style: TextStyle(fontSize: 13, color: kTextGray)),
                  TextButton(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const RegisterScreen()),
                    ),
                    child: const Text("S'inscrire",
                        style: TextStyle(
                            fontSize: 13,
                            color: kOrange,
                            fontWeight: FontWeight.w600)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
