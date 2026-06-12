import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:dio/dio.dart';
import '../../core/api_client.dart';
import '../../core/token_storage.dart';
import '../../models/prestataire.dart';
import '../../theme.dart';
import '../../widgets/appbar_actions.dart';
import '../../widgets/avatar_widget.dart';
import '../login_screen.dart';

// Écran PRESTATAIRE — profil professionnel
// Permet de modifier les infos, toggler la disponibilité, se déconnecter

class ProfilPrestataireScreen extends StatefulWidget {
  const ProfilPrestataireScreen({super.key});

  @override
  State<ProfilPrestataireScreen> createState() => _ProfilPrestataireScreenState();
}

class _ProfilPrestataireScreenState extends State<ProfilPrestataireScreen> {
  final _api = ApiClient();
  late Future<Prestataire> _futurProfil;

  @override
  void initState() {
    super.initState();
    _futurProfil = _charger();
  }

  Future<Prestataire> _charger() async {
    final json = await _api.getMonProfilPrestataire();
    return Prestataire.fromJson(Map<String, dynamic>.from(json));
  }

  void _recharger() => setState(() { _futurProfil = _charger(); });

  Future<void> _toggleDisponibilite(Prestataire p) async {
    try {
      await _api.mettreAJourProfilPrestataire(p.uuid, {'disponible': !p.disponible});
      _recharger();
    } on DioException catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Impossible de modifier la disponibilité'),
              backgroundColor: kRed),
        );
      }
    }
  }

  Future<void> _seDeconnecter() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Déconnexion', style: TextStyle(fontWeight: FontWeight.w700)),
        content: const Text('Es-tu sûr de vouloir te déconnecter ?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Annuler', style: TextStyle(color: kTextGray))),
          TextButton(onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Déconnecter',
                  style: TextStyle(color: kRed, fontWeight: FontWeight.w600))),
        ],
      ),
    );

    if (ok == true && mounted) {
      await TokenStorage.supprimer();
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        PageRouteBuilder(
          pageBuilder: (_, _, _) => const LoginScreen(),
          transitionDuration: const Duration(milliseconds: 300),
          transitionsBuilder: (_, anim, _, child) => FadeTransition(opacity: anim, child: child),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBackground,
      appBar: AppBar(
        title: const Text('Mon profil professionnel'),
        actions: [
          const AppBarActions(),
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _recharger,
          ),
        ],
      ),
      body: FutureBuilder<Prestataire>(
        future: _futurProfil,
        builder: (_, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: kOrange));
          }
          if (snap.hasError) {
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

          final p = snap.data!;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                const SizedBox(height: 8),

                // ── Avatar et nom ───────────────────────────────────────────
                AvatarWidget(
                  photoUrl:       p.photo,
                  initiales:      p.initiales,
                  api:            _api,
                  onPhotoChanged: _recharger,
                ),
                const SizedBox(height: 12),

                Text(p.nomComplet,
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: kTextPrimary)),
                const SizedBox(height: 4),
                if (p.categorie != null)
                  Text(p.categorie!, style: const TextStyle(fontSize: 13, color: kOrange, fontWeight: FontWeight.w500)),

                const SizedBox(height: 16),

                // ── Toggle disponibilité ─────────────────────────────────────
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 8)],
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 40, height: 40,
                        decoration: BoxDecoration(
                          color: p.disponible ? kGreenLight : kRedLight,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.circle, size: 16, color: p.disponible ? kGreen : kRed),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(p.disponible ? 'Disponible' : 'Indisponible',
                                style: TextStyle(
                                    fontSize: 14, fontWeight: FontWeight.w700,
                                    color: p.disponible ? kGreen : kRed)),
                            Text(p.disponible
                                ? 'Les clients peuvent vous contacter'
                                : 'Vous n\'apparaissez pas dans les résultats',
                                style: const TextStyle(fontSize: 12, color: kTextGray)),
                          ],
                        ),
                      ),
                      Switch(
                        value: p.disponible,
                        onChanged: (_) {
                          HapticFeedback.selectionClick();
                          _toggleDisponibilite(p);
                        },
                        activeThumbColor: kGreen,
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 14),

                // ── Infos et statistiques ────────────────────────────────────
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 8)],
                  ),
                  child: Column(
                    children: [
                      if (p.quartier != null)
                        _LigneInfo(icon: Icons.place_outlined, label: 'Quartier', valeur: '${p.quartier}, Conakry'),
                      if (p.telephone != null) ...[
                        const Divider(height: 1, indent: 52, color: kBorder),
                        _LigneInfo(icon: Icons.phone_outlined, label: 'Téléphone', valeur: p.telephone!),
                      ],
                      if (p.noteMoyenne != null) ...[
                        const Divider(height: 1, indent: 52, color: kBorder),
                        _LigneInfo(
                          icon: Icons.star_rounded,
                          label: 'Note moyenne',
                          valeur: '${p.noteMoyenne!.toStringAsFixed(1)} / 5',
                        ),
                      ],
                      if (p.badgeVerifie) ...[
                        const Divider(height: 1, indent: 52, color: kBorder),
                        _LigneInfo(icon: Icons.verified_rounded, label: 'Statut', valeur: 'Prestataire certifié ✓'),
                      ],
                    ],
                  ),
                ),

                const SizedBox(height: 14),

                // ── Description ──────────────────────────────────────────────
                if (p.description != null && p.description!.isNotEmpty)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 8)],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('À propos',
                            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: kTextPrimary)),
                        const SizedBox(height: 8),
                        Text(p.description!,
                            style: const TextStyle(fontSize: 13, color: kTextGray, height: 1.5)),
                      ],
                    ),
                  ),

                const SizedBox(height: 14),

                // ── Bouton modifier profil ───────────────────────────────────
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
                    onPressed: () => _ouvrirEdition(context, p),
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
                const Text('DouraKa v1.0.0', style: TextStyle(fontSize: 11, color: kBorder)),
              ],
            ),
          );
        },
      ),
    );
  }

  void _ouvrirEdition(BuildContext context, Prestataire p) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _FormulaireEdition(api: _api, prestataire: p, onSave: _recharger),
    );
  }
}

// ── Ligne d'info ──────────────────────────────────────────────────────────
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
                Text(label, style: const TextStyle(fontSize: 11, color: kTextGray, fontWeight: FontWeight.w500)),
                const SizedBox(height: 2),
                Text(valeur, overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 13, color: kTextPrimary, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Formulaire d'édition du profil prestataire ────────────────────────────
class _FormulaireEdition extends StatefulWidget {
  final ApiClient    api;
  final Prestataire  prestataire;
  final VoidCallback onSave;

  const _FormulaireEdition({required this.api, required this.prestataire, required this.onSave});

  @override
  State<_FormulaireEdition> createState() => _FormulaireEditionState();
}

class _FormulaireEditionState extends State<_FormulaireEdition> {
  late final TextEditingController _quartierCtrl;
  late final TextEditingController _telCtrl;
  late final TextEditingController _descCtrl;

  bool   _sauvegarde = false;
  String _erreur     = '';

  @override
  void initState() {
    super.initState();
    _quartierCtrl = TextEditingController(text: widget.prestataire.quartier ?? '');
    _telCtrl      = TextEditingController(text: widget.prestataire.telephone ?? '');
    _descCtrl     = TextEditingController(text: widget.prestataire.description ?? '');
  }

  @override
  void dispose() {
    _quartierCtrl.dispose();
    _telCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _sauvegarder() async {
    setState(() { _sauvegarde = true; _erreur = ''; });
    try {
      await widget.api.mettreAJourProfilPrestataire(
        widget.prestataire.uuid,
        {
          'quartier':    _quartierCtrl.text.trim(),
          'telephone':   _telCtrl.text.trim(),
          'description': _descCtrl.text.trim(),
        },
      );
      widget.onSave();
      if (mounted) Navigator.pop(context);
    } on DioException catch (e) {
      final msg = (e.response?.data is Map)
          ? (e.response!.data as Map)['detail']?.toString() ?? 'Erreur'
          : 'Erreur lors de la sauvegarde';
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
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(child: Container(width: 36, height: 4,
                decoration: BoxDecoration(color: kBorder, borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 16),
            const Text('Modifier mon profil',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: kTextPrimary)),
            const SizedBox(height: 16),

            const Text('Quartier', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: kTextPrimary)),
            const SizedBox(height: 8),
            TextField(controller: _quartierCtrl, textInputAction: TextInputAction.next,
                decoration: const InputDecoration(prefixIcon: Icon(Icons.place_outlined, size: 20, color: kTextGray),
                    hintText: 'Kaloum, Matam…')),
            const SizedBox(height: 12),

            const Text('Téléphone', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: kTextPrimary)),
            const SizedBox(height: 8),
            TextField(controller: _telCtrl, keyboardType: TextInputType.phone, textInputAction: TextInputAction.next,
                decoration: const InputDecoration(prefixIcon: Icon(Icons.phone_outlined, size: 20, color: kTextGray),
                    hintText: '+224 622 000 000')),
            const SizedBox(height: 12),

            const Text('Description', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: kTextPrimary)),
            const SizedBox(height: 8),
            TextField(controller: _descCtrl, maxLines: 4, textInputAction: TextInputAction.done,
                onSubmitted: (_) => _sauvegarder(),
                decoration: const InputDecoration(hintText: 'Décris tes compétences et ton expérience…')),

            if (_erreur.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(_erreur, style: const TextStyle(color: kRed, fontSize: 12)),
            ],
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _sauvegarde ? null : _sauvegarder,
              child: _sauvegarde
                  ? const SizedBox(width: 20, height: 20,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Text('Sauvegarder'),
            ),
          ],
        ),
      ),
    );
  }
}
