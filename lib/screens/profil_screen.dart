import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import '../core/api_client.dart';
import '../core/token_storage.dart';
import '../models/utilisateur.dart';
import '../theme.dart';
import '../widgets/appbar_actions.dart';
import '../widgets/avatar_widget.dart';
import 'login_screen.dart';

// Espace CLIENT — profil personnel
// Affiche les infos + permet de les modifier + déconnexion

class ProfilScreen extends StatefulWidget {
  const ProfilScreen({super.key});

  @override
  State<ProfilScreen> createState() => _ProfilScreenState();
}

class _ProfilScreenState extends State<ProfilScreen> {
  final _api = ApiClient();
  late Future<Utilisateur> _futurProfil;

  @override
  void initState() {
    super.initState();
    _futurProfil = _charger();
  }

  Future<Utilisateur> _charger() async {
    final json = await _api.getMonProfil();
    return Utilisateur.fromJson(Map<String, dynamic>.from(json));
  }

  void _recharger() => setState(() { _futurProfil = _charger(); });

  // void _modifierPhoto() async {
  //   // TODO: déplacer la logique upload ici depuis AvatarWidget ?
  // }

  Future<void> _seDeconnecter() async {
    final confirme = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Déconnexion', style: TextStyle(fontWeight: FontWeight.w700)),
        content: const Text('Es-tu sûr de vouloir te déconnecter ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annuler', style: TextStyle(color: kTextGray)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Déconnecter',
                style: TextStyle(color: kRed, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );

    if (confirme == true && mounted) {
      await TokenStorage.supprimer();
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        PageRouteBuilder(
          pageBuilder: (_, _, _) => const LoginScreen(),
          transitionDuration: const Duration(milliseconds: 300),
          transitionsBuilder: (_, anim, _, child) =>
              FadeTransition(opacity: anim, child: child),
        ),
      );
    }
  }

  void _ouvrirEdition(Utilisateur user) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _FormulaireEditionProfil(
        api: _api,
        utilisateur: user,
        onSave: _recharger,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBackground,
      appBar: AppBar(
        title: const Text('Mon profil'),
        actions: const [AppBarActions()],
      ),
      body: FutureBuilder<Utilisateur>(
        future: _futurProfil,
        builder: (_, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: kOrange));
          }
          if (snap.hasError) {
            debugPrint('Erreur profil: ${snap.error}');
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.person_off_outlined, size: 48, color: kBorder),
                  const SizedBox(height: 12),
                  const Text('Impossible de charger le profil',
                      style: TextStyle(color: kTextGray)),
                  const SizedBox(height: 16),
                  TextButton.icon(
                    onPressed: _recharger,
                    icon: const Icon(Icons.refresh, color: kOrange),
                    label: const Text('Réessayer', style: TextStyle(color: kOrange)),
                  ),
                ],
              ),
            );
          }

          final user = snap.data!;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                const SizedBox(height: 12),

                AvatarWidget(
                  photoUrl:       user.photo,
                  initiales:      user.initiales,
                  api:            _api,
                  onPhotoChanged: _recharger,
                ),

                const SizedBox(height: 14),

                Text(user.nomComplet,
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: kTextPrimary)),
                const SizedBox(height: 4),
                Text(user.email, style: const TextStyle(fontSize: 13, color: kTextGray)),
                const SizedBox(height: 8),

                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(color: kOrangeLight, borderRadius: BorderRadius.circular(20)),
                  child: Text(
                    user.role == 'prestataire' ? 'Prestataire' : 'Client',
                    style: const TextStyle(fontSize: 12, color: kOrange, fontWeight: FontWeight.w600),
                  ),
                ),

                const SizedBox(height: 28),

                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 8, offset: const Offset(0, 2)),
                    ],
                  ),
                  child: Column(
                    children: [
                      _LigneInfo(
                        icon: Icons.person_outline_rounded,
                        label: 'Nom complet',
                        valeur: user.nomComplet,
                      ),
                      const Divider(height: 1, indent: 52, color: kBorder),
                      _LigneInfo(
                        icon: Icons.email_outlined,
                        label: 'Email',
                        valeur: user.email,
                      ),
                      if (user.telephone != null) ...[
                        const Divider(height: 1, indent: 52, color: kBorder),
                        _LigneInfo(
                          icon: Icons.phone_outlined,
                          label: 'Téléphone',
                          valeur: user.telephone!,
                        ),
                      ],
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.edit_outlined, color: kOrange, size: 18),
                    label: const Text('Modifier mon profil',
                        style: TextStyle(color: kOrange, fontSize: 14)),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: kOrange),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    onPressed: () => _ouvrirEdition(user),
                  ),
                ),

                const SizedBox(height: 10),

                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.logout_rounded, color: kRed),
                    label: const Text('Se déconnecter',
                        style: TextStyle(color: kRed, fontSize: 14)),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: kRed),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    onPressed: _seDeconnecter,
                  ),
                ),

                const SizedBox(height: 12),

                const Text('DouraKa v1.0.0',
                    style: TextStyle(fontSize: 11, color: kBorder)),
              ],
            ),
          );
        },
      ),
    );
  }

}

class _LigneInfo extends StatelessWidget {
  final IconData icon;
  final String   label;
  final String   valeur;

  const _LigneInfo({required this.icon, required this.label, required this.valeur});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Container(
            width: 36, height: 36,
            decoration: const BoxDecoration(color: kOrangeLight, shape: BoxShape.circle),
            child: Icon(icon, size: 17, color: kOrange),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(
                    fontSize: 11, color: kTextGray, fontWeight: FontWeight.w500)),
                const SizedBox(height: 2),
                Text(valeur, overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 13, color: kTextPrimary, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FormulaireEditionProfil extends StatefulWidget {
  final ApiClient    api;
  final Utilisateur  utilisateur;
  final VoidCallback onSave;

  const _FormulaireEditionProfil({
    required this.api,
    required this.utilisateur,
    required this.onSave,
  });

  @override
  State<_FormulaireEditionProfil> createState() => _FormulaireEditionProfilState();
}

class _FormulaireEditionProfilState extends State<_FormulaireEditionProfil> {
  late final TextEditingController _nomCtrl;
  late final TextEditingController _prenomCtrl;
  late final TextEditingController _telCtrl;

  bool   _sauvegarde = false;
  String _erreur     = '';

  @override
  void initState() {
    super.initState();
    _nomCtrl    = TextEditingController(text: widget.utilisateur.nom);
    _prenomCtrl = TextEditingController(text: widget.utilisateur.prenom);
    _telCtrl    = TextEditingController(text: widget.utilisateur.telephone ?? '');
  }

  @override
  void dispose() {
    _nomCtrl.dispose();
    _prenomCtrl.dispose();
    _telCtrl.dispose();
    super.dispose();
  }

  Future<void> _sauvegarder() async {
    if (_nomCtrl.text.trim().isEmpty || _prenomCtrl.text.trim().isEmpty) {
      setState(() => _erreur = 'Le nom et le prénom sont obligatoires');
      return;
    }

    setState(() { _sauvegarde = true; _erreur = ''; });

    try {
      await widget.api.mettreAJourProfil({
        'nom':       _nomCtrl.text.trim(),
        'prenom':    _prenomCtrl.text.trim(),
        'telephone': _telCtrl.text.trim(),
      });
      widget.onSave();
      if (mounted) Navigator.pop(context);
    } on DioException catch (e) {
      String msg = 'Erreur lors de la sauvegarde';
      if (e.response?.data is Map) {
        final d = e.response!.data as Map;
        msg = d['detail']?.toString() ??
            d.values.firstWhere((v) => v != null, orElse: () => null)?.toString() ??
            msg;
      }
      if (mounted) setState(() { _erreur = msg; _sauvegarde = false; });
    } finally {
      if (mounted) setState(() => _sauvegarde = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        left: 20, right: 20, top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 36, height: 4,
              decoration: BoxDecoration(color: kBorder, borderRadius: BorderRadius.circular(2)),
            ),
          ),
          const SizedBox(height: 16),

          const Text('Modifier mon profil',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: kTextPrimary)),
          const SizedBox(height: 4),
          // L'email n'est pas modifiable — il sert d'identifiant de compte
          const Text('L\'email ne peut pas être modifié',
              style: TextStyle(fontSize: 12, color: kTextGray)),
          const SizedBox(height: 20),

          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Nom *', style: TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w600, color: kTextPrimary)),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _nomCtrl,
                      textInputAction: TextInputAction.next,
                      textCapitalization: TextCapitalization.words,
                      decoration: const InputDecoration(hintText: 'Diallo'),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Prénom *', style: TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w600, color: kTextPrimary)),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _prenomCtrl,
                      textInputAction: TextInputAction.next,
                      textCapitalization: TextCapitalization.words,
                      decoration: const InputDecoration(hintText: 'Mamadou'),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          const Text('Téléphone', style: TextStyle(
              fontSize: 13, fontWeight: FontWeight.w600, color: kTextPrimary)),
          const SizedBox(height: 8),
          TextField(
            controller: _telCtrl,
            keyboardType: TextInputType.phone,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _sauvegarder(),
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.phone_outlined, size: 20, color: kTextGray),
              hintText: '+224 622 000 000',
            ),
          ),

          if (_erreur.isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(color: kRedLight, borderRadius: BorderRadius.circular(10)),
              child: Row(
                children: [
                  const Icon(Icons.error_outline, size: 15, color: kRed),
                  const SizedBox(width: 8),
                  Expanded(child: Text(_erreur, style: const TextStyle(fontSize: 12, color: kRed))),
                ],
              ),
            ),
          ],

          const SizedBox(height: 20),

          ElevatedButton(
            onPressed: _sauvegarde ? null : _sauvegarder,
            child: _sauvegarde
                ? const SizedBox(
                    width: 22, height: 22,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                : const Text('Sauvegarder les modifications'),
          ),
        ],
      ),
    );
  }
}
