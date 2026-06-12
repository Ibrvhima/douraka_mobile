import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import '../../core/api_client.dart';
import '../../theme.dart';

// ADMIN — gestion des prestataires : approuver, certifier, désactiver

class PrestatairesAdminScreen extends StatefulWidget {
  const PrestatairesAdminScreen({super.key});

  @override
  State<PrestatairesAdminScreen> createState() => _PrestatairesAdminScreenState();
}

class _PrestatairesAdminScreenState extends State<PrestatairesAdminScreen>
    with SingleTickerProviderStateMixin {
  final _api = ApiClient();

  List<dynamic> _prestataires = [];
  bool          _chargement   = true;
  bool          _erreur       = false;
  bool?         _filtreApprouve; // null = tous, true = approuvés, false = en attente

  late final TabController _tabCtrl;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 3, vsync: this);
    _tabCtrl.addListener(() {
      if (!_tabCtrl.indexIsChanging) {
        setState(() {
          _filtreApprouve = [null, true, false][_tabCtrl.index];
        });
        _charger();
      }
    });
    _charger();
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  Future<void> _charger() async {
    setState(() { _chargement = true; _erreur = false; });
    try {
      final data = await _api.getPrestatairesAdmin(approuve: _filtreApprouve);
      if (!mounted) return;
      setState(() { _prestataires = data; _chargement = false; });
    } catch (e) {
      debugPrint('Erreur admin prestataires: $e');
      if (!mounted) return;
      setState(() { _chargement = false; _erreur = true; });
    }
  }

  Future<void> _mettreAJour(int pk, Map<String, dynamic> data) async {
    try {
      await _api.mettreAJourPrestataireAdmin(pk, data);
      await _charger();
    } on DioException catch (e) {
      final msg = (e.response?.data is Map)
          ? (e.response!.data as Map)['detail']?.toString() ?? 'Erreur'
          : 'Erreur';
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg), backgroundColor: kRed));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBackground,
      appBar: AppBar(
        title: const Text('Prestataires'),
        bottom: TabBar(
          controller: _tabCtrl,
          indicatorColor: kOrange,
          labelColor: kOrange,
          unselectedLabelColor: kTextGray,
          tabs: const [
            Tab(text: 'Tous'),
            Tab(text: 'Approuvés'),
            Tab(text: 'En attente'),
          ],
        ),
        actions: [
          IconButton(icon: const Icon(Icons.refresh_rounded), onPressed: _charger),
        ],
      ),
      body: _chargement
          ? const Center(child: CircularProgressIndicator(color: kOrange))
          : _erreur
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.wifi_off_rounded, size: 52, color: kBorder),
                      const SizedBox(height: 12),
                      const Text('Problème de connexion', style: TextStyle(color: kTextGray)),
                      const SizedBox(height: 16),
                      TextButton.icon(onPressed: _charger,
                          icon: const Icon(Icons.refresh, color: kOrange),
                          label: const Text('Réessayer', style: TextStyle(color: kOrange))),
                    ],
                  ),
                )
              : _prestataires.isEmpty
                  ? const Center(child: Text('Aucun prestataire', style: TextStyle(color: kTextGray)))
                  : RefreshIndicator(
                      color: kOrange,
                      onRefresh: _charger,
                      child: ListView.builder(
                        padding: const EdgeInsets.all(12),
                        itemCount: _prestataires.length,
                        itemBuilder: (_, i) => _CartePrestataireAdmin(
                          data: Map<String, dynamic>.from(_prestataires[i]),
                          onUpdate: _mettreAJour,
                        ),
                      ),
                    ),
    );
  }
}

// ── Carte prestataire admin ───────────────────────────────────────────────
class _CartePrestataireAdmin extends StatelessWidget {
  final Map<String, dynamic> data;
  final Future<void> Function(int pk, Map<String, dynamic> update) onUpdate;

  const _CartePrestataireAdmin({required this.data, required this.onUpdate});

  @override
  Widget build(BuildContext context) {
    final user     = data['user'] is Map ? data['user'] as Map : {};
    final categorie = data['categorie'] is Map ? (data['categorie'] as Map)['nom']?.toString() : null;
    final nom      = '${user['nom'] ?? ''} ${user['prenom'] ?? ''}'.trim();
    final initiales = nom.isNotEmpty ? nom.split(' ').map((w) => w.isEmpty ? '' : w[0]).take(2).join('').toUpperCase() : '?';
    final pk       = data['id'] is int ? data['id'] as int : int.tryParse(data['id']?.toString() ?? '') ?? 0;
    final approuve = data['approuve'] == true;
    final verifie  = data['badge_verifie'] == true;
    final disponible = data['disponible'] == true;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 6)],
      ),
      child: Column(
        children: [
          // Infos prestataire
          Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Container(
                  width: 42, height: 42,
                  decoration: const BoxDecoration(color: kOrangeLight, shape: BoxShape.circle),
                  child: Center(child: Text(initiales,
                      style: const TextStyle(color: kOrange, fontWeight: FontWeight.w700, fontSize: 15))),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(nom.isEmpty ? 'Prestataire' : nom,
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: kTextPrimary)),
                      if (categorie != null)
                        Text(categorie, style: const TextStyle(fontSize: 12, color: kOrange, fontWeight: FontWeight.w500)),
                      if (data['quartier'] != null)
                        Text(data['quartier'].toString(),
                            style: const TextStyle(fontSize: 12, color: kTextGray)),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    _Badge(label: approuve ? 'Approuvé' : 'En attente',
                        couleur: approuve ? kGreen : kYellow,
                        bg: approuve ? kGreenLight : const Color(0xFFFEF9C3)),
                    if (verifie)
                      const Padding(
                        padding: EdgeInsets.only(top: 4),
                        child: Row(children: [
                          Icon(Icons.verified_rounded, size: 12, color: kOrange),
                          SizedBox(width: 4),
                          Text('Certifié', style: TextStyle(fontSize: 11, color: kOrange, fontWeight: FontWeight.w600)),
                        ]),
                      ),
                  ],
                ),
              ],
            ),
          ),

          const Divider(height: 1, color: kBorder),

          // Actions admin
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                // Approuver / Désapprouver
                _BoutonAction(
                  label: approuve ? 'Désapprouver' : 'Approuver',
                  icone: approuve ? Icons.cancel_outlined : Icons.check_circle_outline,
                  couleur: approuve ? kRed : kGreen,
                  onTap: () => onUpdate(pk, {'approuve': !approuve}),
                ),
                // Certifier / Retirer certif
                _BoutonAction(
                  label: verifie ? 'Retirer certif.' : 'Certifier',
                  icone: verifie ? Icons.remove_circle_outline_rounded : Icons.verified_rounded,
                  couleur: verifie ? kTextGray : kOrange,
                  onTap: () => onUpdate(pk, {'badge_verifie': !verifie}),
                ),
                // Disponibilité
                _BoutonAction(
                  label: disponible ? 'Rendre indispo.' : 'Rendre dispo.',
                  icone: disponible ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                  couleur: disponible ? kRed : kGreen,
                  onTap: () => onUpdate(pk, {'disponible': !disponible}),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  final String label;
  final Color  couleur;
  final Color  bg;

  const _Badge({required this.label, required this.couleur, required this.bg});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(10)),
      child: Text(label, style: TextStyle(fontSize: 11, color: couleur, fontWeight: FontWeight.w600)),
    );
  }
}

class _BoutonAction extends StatelessWidget {
  final String   label;
  final IconData icone;
  final Color    couleur;
  final VoidCallback onTap;

  const _BoutonAction({required this.label, required this.icone, required this.couleur, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: couleur.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: couleur.withValues(alpha: 0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icone, size: 14, color: couleur),
            const SizedBox(width: 4),
            Text(label, style: TextStyle(fontSize: 12, color: couleur, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}
