import 'package:flutter/material.dart';
import '../../core/api_client.dart';
import '../../theme.dart';

// ADMIN — vue globale de toutes les demandes de la plateforme

class DemandesAdminScreen extends StatefulWidget {
  const DemandesAdminScreen({super.key});

  @override
  State<DemandesAdminScreen> createState() => _DemandesAdminScreenState();
}

class _DemandesAdminScreenState extends State<DemandesAdminScreen>
    with SingleTickerProviderStateMixin {
  final _api      = ApiClient();
  List<dynamic>  _demandes   = [];
  bool           _chargement = true;
  bool           _erreur     = false;
  String?        _filtreStatut;

  late final TabController _tabCtrl;

  static const _statuts = [null, 'en_attente', 'acceptee', 'terminee', 'annulee'];

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 5, vsync: this);
    _tabCtrl.addListener(() {
      if (!_tabCtrl.indexIsChanging) {
        setState(() => _filtreStatut = _statuts[_tabCtrl.index]);
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
      final data = await _api.getDemandesAdmin(statut: _filtreStatut);
      if (!mounted) return;
      setState(() { _demandes = data; _chargement = false; });
    } catch (e) {
      debugPrint('Erreur demandes admin: $e');
      if (!mounted) return;
      setState(() { _chargement = false; _erreur = true; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBackground,
      appBar: AppBar(
        title: const Text('Toutes les demandes'),
        bottom: TabBar(
          controller: _tabCtrl,
          indicatorColor: kOrange,
          labelColor: kOrange,
          unselectedLabelColor: kTextGray,
          isScrollable: true,
          tabs: const [
            Tab(text: 'Toutes'),
            Tab(text: 'En attente'),
            Tab(text: 'Acceptées'),
            Tab(text: 'Terminées'),
            Tab(text: 'Annulées'),
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
              : _demandes.isEmpty
                  ? const Center(child: Text('Aucune demande', style: TextStyle(color: kTextGray)))
                  : RefreshIndicator(
                      color: kOrange,
                      onRefresh: _charger,
                      child: ListView.builder(
                        padding: const EdgeInsets.all(12),
                        itemCount: _demandes.length,
                        itemBuilder: (_, i) => _CarteDemandeAdmin(
                          data: Map<String, dynamic>.from(_demandes[i])),
                      ),
                    ),
    );
  }
}

// ── Carte demande admin ───────────────────────────────────────────────────
class _CarteDemandeAdmin extends StatelessWidget {
  final Map<String, dynamic> data;

  const _CarteDemandeAdmin({required this.data});

  Color get _couleurStatut {
    switch (data['statut']?.toString()) {
      case 'acceptee':   return kGreen;
      case 'en_cours':   return kGreen;
      case 'refusee':    return kRed;
      case 'annulee':    return kRed;
      case 'terminee':   return kTextGray;
      default:           return kYellow;
    }
  }

  Color get _bgStatut {
    switch (data['statut']?.toString()) {
      case 'acceptee':   return kGreenLight;
      case 'en_cours':   return kGreenLight;
      case 'refusee':    return kRedLight;
      case 'annulee':    return kRedLight;
      case 'terminee':   return const Color(0xFFF3F4F6);
      default:           return const Color(0xFFFEF9C3);
    }
  }

  @override
  Widget build(BuildContext context) {
    final clientInfo   = data['client_info'] is Map ? data['client_info'] as Map : {};
    final prestaInfo   = data['prestataire_info'] is Map ? data['prestataire_info'] as Map : {};
    final prestaUser   = prestaInfo['user'] is Map ? prestaInfo['user'] as Map : {};
    final categorie    = prestaInfo['categorie'] is Map
        ? (prestaInfo['categorie'] as Map)['nom']?.toString()
        : null;

    final clientNom  = '${clientInfo['nom'] ?? ''} ${clientInfo['prenom'] ?? ''}'.trim();
    final prestaNom  = '${prestaUser['nom'] ?? ''} ${prestaUser['prenom'] ?? ''}'.trim();
    final statut     = data['statut_display']?.toString() ?? data['statut']?.toString() ?? '';
    final desc       = data['description']?.toString() ?? '';

    // Formatage date
    String dateStr = '';
    try {
      final dt = DateTime.parse(data['date_creation']?.toString() ?? '').toLocal();
      const mois = ['jan', 'fév', 'mar', 'avr', 'mai', 'juin',
                    'juil', 'août', 'sep', 'oct', 'nov', 'déc'];
      dateStr = '${dt.day} ${mois[dt.month - 1]} ${dt.year}';
    } catch (_) {}

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 6)],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Client : $clientNom',
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: kTextPrimary)),
                      Text('Prestataire : $prestaNom${categorie != null ? ' ($categorie)' : ''}',
                          style: const TextStyle(fontSize: 12, color: kTextGray)),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(color: _bgStatut, borderRadius: BorderRadius.circular(10)),
                  child: Text(statut,
                      style: TextStyle(fontSize: 11, color: _couleurStatut, fontWeight: FontWeight.w600)),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(desc, maxLines: 2, overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 13, color: kTextGray)),
            if (dateStr.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(dateStr, style: const TextStyle(fontSize: 11, color: kBorder)),
              ),
          ],
        ),
      ),
    );
  }
}
