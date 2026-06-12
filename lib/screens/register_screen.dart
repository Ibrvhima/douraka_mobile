import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import '../core/api_client.dart';
import '../core/token_storage.dart';
import '../theme.dart';
import 'shell_screen.dart';
import 'prestataire/shell_prestataire_screen.dart';

// Écran d'inscription — un seul écran pour deux rôles : client et prestataire.
// Le formulaire est "progressive disclosure" : les champs pro (catégorie, quartier,
// description) apparaissent uniquement quand on sélectionne le rôle prestataire.
// Ça évite d'avoir deux screens séparés à maintenir pour une logique très similaire.

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _api = ApiClient();

  // Un contrôleur par champ — pas de Map ni de liste pour rester explicite.
  // C'est plus de code mais nettement plus lisible au moment du débogage.
  final _nomCtrl         = TextEditingController();
  final _prenomCtrl      = TextEditingController();
  final _emailCtrl       = TextEditingController();
  final _telCtrl         = TextEditingController();
  final _passwordCtrl    = TextEditingController();
  final _quartierCtrl    = TextEditingController();
  final _descCtrl        = TextEditingController();

  String _role              = 'client'; // valeur par défaut : client
  bool   _passwordVisible   = false;
  bool   _loading           = false;
  String _erreur            = '';

  // Les catégories sont chargées depuis l'API au montage du widget.
  // En cas d'échec (réseau KO), la liste reste vide et le dropdown est simplement vide —
  // l'utilisateur ne peut pas valider sans catégorie, ce qui l'invite à réessayer.
  List<dynamic> _categories    = [];
  int?          _categorieId;

  @override
  void initState() {
    super.initState();
    _chargerCategories();
  }

  Future<void> _chargerCategories() async {
    try {
      final cats = await _api.getCategories();
      // Guard monté : si l'utilisateur quitte l'écran pendant le chargement,
      // le setState planterait sans ce check.
      if (mounted) setState(() => _categories = cats);
    } catch (_) {
      // On avale silencieusement l'erreur ici — le dropdown sera juste vide.
      // On ne montre pas de message d'erreur pour les catégories car c'est un
      // détail secondaire qui ne bloque que les prestataires.
    }
  }

  Future<void> _sInscrire() async {
    // Validation côté client : on couvre les cas les plus évidents
    // avant de faire un appel réseau inutile.
    if (_nomCtrl.text.trim().isEmpty   ||
        _prenomCtrl.text.trim().isEmpty ||
        _emailCtrl.text.trim().isEmpty  ||
        _passwordCtrl.text.isEmpty) {
      setState(() => _erreur = 'Remplis tous les champs obligatoires');
      return;
    }
    if (_passwordCtrl.text.length < 8) {
      setState(() => _erreur = 'Le mot de passe doit faire au moins 8 caractères');
      return;
    }
    // La catégorie est obligatoire pour un prestataire — bloquant.
    if (_role == 'prestataire' && _categorieId == null) {
      setState(() => _erreur = 'Choisis ta catégorie de service');
      return;
    }

    setState(() { _loading = true; _erreur = ''; });

    try {
      // Construction du payload avec spread conditionnel : les champs pro
      // ne sont inclus dans la Map que si le rôle est prestataire.
      // Propre et lisible — pas besoin de construire deux Maps différentes.
      final data = <String, dynamic>{
        'nom':       _nomCtrl.text.trim(),
        'prenom':    _prenomCtrl.text.trim(),
        'email':     _emailCtrl.text.trim(),
        'telephone': _telCtrl.text.trim(),
        'password':  _passwordCtrl.text,
        'role':      _role,
        if (_role == 'prestataire') ...{
          'categorie_id': _categorieId,
          'quartier':     _quartierCtrl.text.trim(),
          'description':  _descCtrl.text.trim(),
        },
      };

      // register() fait l'appel HTTP + sauvegarde token et rôle en local,
      // comme login() — comportement uniforme pour simplifier le routing après.
      await _api.register(data);

      if (!mounted) return;

      // On lit le rôle depuis le stockage local plutôt que depuis le paramètre _role
      // pour être cohérent avec ce que le serveur a réellement enregistré.
      final role = await TokenStorage.lireRole();
      if (!mounted) return;

      // pushReplacement + fondu : on vide la stack (login + register) pour que
      // le bouton retour ne ramène pas sur des écrans d'auth.
      Navigator.pushReplacement(
        context,
        PageRouteBuilder(
          pageBuilder: (_, _, _) =>
              role == 'prestataire' ? const ShellPrestataireScreen() : const ShellScreen(),
          transitionDuration: const Duration(milliseconds: 350),
          transitionsBuilder: (_, anim, _, child) =>
              FadeTransition(opacity: anim, child: child),
        ),
      );

    } on DioException catch (e) {
      // Gestion des erreurs API : on tente d'extraire le premier message
      // du dictionnaire d'erreurs Django (ex: {"email": ["Cet email existe déjà."]}).
      // C'est un parsing un peu défensif mais Django renvoie des structures variables
      // selon la vue — firstWhere avec orElse évite les exceptions en cascade.
      String msg = 'Erreur lors de l\'inscription';
      if (e.response?.data is Map) {
        final data = e.response!.data as Map;
        final first = data.values.firstWhere(
          (v) => v != null,
          orElse: () => null,
        );
        if (first is List && first.isNotEmpty) {
          msg = first[0].toString();
        } else if (first != null) {
          msg = first.toString();
        }
      } else if (e.type == DioExceptionType.connectionTimeout ||
                 e.type == DioExceptionType.receiveTimeout) {
        msg = 'Connexion lente, réessaie dans un moment';
      }
      if (mounted) setState(() => _erreur = msg);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    // On dispose tous les contrôleurs — ils sont tous instanciés dans ce State
    // donc c'est ici qu'on a la responsabilité de les libérer.
    _nomCtrl.dispose();
    _prenomCtrl.dispose();
    _emailCtrl.dispose();
    _telCtrl.dispose();
    _passwordCtrl.dispose();
    _quartierCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: kTextPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Créer un compte',
            style: TextStyle(color: kTextPrimary, fontWeight: FontWeight.w700)),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 16),

              // ── Sélection du rôle ────────────────────────────────────────
              // Deux boutons toggle plutôt qu'un DropdownButton ou des Radio —
              // plus visuel et plus explicite pour un choix binaire aussi important.
              // Le rôle conditionne tout le reste du formulaire.
              const Text('Je suis…',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: kTextPrimary)),
              const SizedBox(height: 8),
              Row(
                children: [
                  _BoutonRole(
                    label: 'Client',
                    icon: Icons.person_outline_rounded,
                    actif: _role == 'client',
                    onTap: () => setState(() => _role = 'client'),
                  ),
                  const SizedBox(width: 10),
                  _BoutonRole(
                    label: 'Prestataire',
                    icon: Icons.work_outline_rounded,
                    actif: _role == 'prestataire',
                    onTap: () => setState(() => _role = 'prestataire'),
                  ),
                ],
              ),

              const SizedBox(height: 20),

              // ── Champs communs (tous les rôles) ──────────────────────────
              // Nom et Prénom côte à côte en Row pour gagner de la place verticale
              // sur les petits écrans — ils sont courts et vont bien ensemble.
              Row(
                children: [
                  Expanded(child: _Champ(label: 'Nom',    ctrl: _nomCtrl,    hint: 'Diallo')),
                  const SizedBox(width: 10),
                  Expanded(child: _Champ(label: 'Prénom', ctrl: _prenomCtrl, hint: 'Ibrahim')),
                ],
              ),
              const SizedBox(height: 14),
              _Champ(label: 'Email', ctrl: _emailCtrl, hint: 'ton@email.com',
                  type: TextInputType.emailAddress,
                  prefixIcon: Icons.email_outlined),
              const SizedBox(height: 14),
              _Champ(label: 'Téléphone', ctrl: _telCtrl, hint: '+224 622 000 000',
                  type: TextInputType.phone,
                  prefixIcon: Icons.phone_outlined),
              const SizedBox(height: 14),

              // ── Mot de passe ─────────────────────────────────────────────
              // TextInputAction change selon le rôle : "next" si prestataire
              // (il y a d'autres champs après), "done" si client (dernier champ).
              const Text('Mot de passe',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: kTextPrimary)),
              const SizedBox(height: 8),
              TextField(
                controller: _passwordCtrl,
                obscureText: !_passwordVisible,
                textInputAction: _role == 'prestataire'
                    ? TextInputAction.next
                    : TextInputAction.done,
                // onSubmitted uniquement pour le client : pour le prestataire
                // on ne déclenche pas encore l'inscription car il reste des champs à remplir.
                onSubmitted: _role == 'client' ? (_) => _sInscrire() : null,
                decoration: InputDecoration(
                  hintText: '8 caractères minimum',
                  prefixIcon: const Icon(Icons.lock_outline, size: 20, color: kTextGray),
                  suffixIcon: IconButton(
                    icon: Icon(_passwordVisible ? Icons.visibility_off : Icons.visibility,
                        size: 20, color: kTextGray),
                    onPressed: () => setState(() => _passwordVisible = !_passwordVisible),
                  ),
                ),
              ),

              // ── Section prestataire (apparaît conditionnellement) ────────
              // if + spread operator : quand _role == 'client', ces widgets
              // n'existent pas du tout dans l'arbre — pas juste cachés, vraiment absents.
              // Ça évite que le clavier "saute" vers des champs invisibles.
              if (_role == 'prestataire') ...[
                const SizedBox(height: 20),
                // Séparateur visuel pour distinguer les infos perso des infos pro
                const Divider(color: kBorder),
                const SizedBox(height: 12),
                const Text('Infos professionnelles',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: kTextPrimary)),
                const SizedBox(height: 14),

                // ── Dropdown des catégories ──────────────────────────────
                // Les IDs viennent de l'API et peuvent être des int ou des String
                // selon la version du backend — on cast prudemment avec int.tryParse
                // pour éviter un crash si le type change côté serveur.
                const Text('Catégorie de service *',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: kTextPrimary)),
                const SizedBox(height: 8),
                Container(
                  decoration: BoxDecoration(
                    color: kBackground,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: DropdownButtonFormField<int>(
                    initialValue: _categorieId,
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.work_outline_rounded, size: 20, color: kTextGray),
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                    ),
                    hint: const Text('Choisir…', style: TextStyle(color: kTextGray)),
                    items: _categories.map((cat) {
                      // Cast défensif : l'API retourne parfois des int, parfois des String.
                      // int.tryParse ?? 0 donne un fallback non null pour éviter les items null dans le dropdown.
                      final id = cat['id'] is int
                          ? cat['id'] as int
                          : int.tryParse(cat['id']?.toString() ?? '') ?? 0;
                      return DropdownMenuItem<int>(
                        value: id,
                        child: Text(cat['nom']?.toString() ?? ''),
                      );
                    }).toList(),
                    onChanged: (val) => setState(() => _categorieId = val),
                  ),
                ),
                const SizedBox(height: 14),
                _Champ(label: 'Quartier', ctrl: _quartierCtrl, hint: 'Kaloum, Matam…',
                    prefixIcon: Icons.place_outlined),
                const SizedBox(height: 14),

                // ── Description des services ─────────────────────────────
                // maxLines: 3 pour un textarea raisonnable — assez pour une description
                // courte, pas assez pour que les gens écrivent un roman.
                const Text('Description de vos services',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: kTextPrimary)),
                const SizedBox(height: 8),
                TextField(
                  controller: _descCtrl,
                  maxLines: 3,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _sInscrire(),
                  decoration: const InputDecoration(
                    hintText: 'Décris tes compétences et ton expérience…',
                  ),
                ),
              ],

              // ── Bloc d'erreur ────────────────────────────────────────────
              // Même pattern que le login : spread conditionnel pour ne pas
              // insérer de SizedBox vide quand il n'y a pas d'erreur.
              if (_erreur.isNotEmpty) ...[
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(color: kRedLight, borderRadius: BorderRadius.circular(10)),
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

              const SizedBox(height: 24),

              // ── Bouton de validation ─────────────────────────────────────
              // Le bouton est pleine largeur — standard pour les CTA primaires sur mobile.
              // Disabled pendant le loading pour éviter la double soumission.
              ElevatedButton(
                onPressed: _loading ? null : _sInscrire,
                child: _loading
                    ? const SizedBox(width: 22, height: 22,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                    : const Text('Créer mon compte'),
              ),

              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Widget champ de formulaire réutilisable ────────────────────────────────
// Extrait ici parce que le même pattern label + TextField se répète 5 fois.
// On aurait pu utiliser un TextFormField dans un Form, mais on a choisi
// de gérer la validation manuellement pour rester simple et flexible.
class _Champ extends StatelessWidget {
  final String label;
  final TextEditingController ctrl;
  final String hint;
  final TextInputType type;
  final IconData? prefixIcon;

  const _Champ({
    required this.label,
    required this.ctrl,
    required this.hint,
    this.type = TextInputType.text,
    this.prefixIcon,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(
            fontSize: 13, fontWeight: FontWeight.w600, color: kTextPrimary)),
        const SizedBox(height: 8),
        TextField(
          controller: ctrl,
          keyboardType: type,
          textInputAction: TextInputAction.next, // avance au prochain champ
          decoration: InputDecoration(
            hintText: hint,
            prefixIcon: prefixIcon != null
                ? Icon(prefixIcon, size: 20, color: kTextGray)
                : null,
          ),
        ),
      ],
    );
  }
}

// ── Bouton de sélection du rôle (Client / Prestataire) ───────────────────
// AnimatedContainer pour la transition de couleur — plus fluide qu'un setState
// brut qui ferait un changement instantané. 200ms c'est la durée idéale :
// assez rapide pour être réactif, assez lent pour être visible.
class _BoutonRole extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool actif;
  final VoidCallback onTap;

  const _BoutonRole({
    required this.label,
    required this.icon,
    required this.actif,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: actif ? kOrange : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: actif ? kOrange : kBorder),
          ),
          child: Column(
            children: [
              Icon(icon, size: 24, color: actif ? Colors.white : kTextGray),
              const SizedBox(height: 4),
              Text(label,
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: actif ? Colors.white : kTextGray)),
            ],
          ),
        ),
      ),
    );
  }
}
