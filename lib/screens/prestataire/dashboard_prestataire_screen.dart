import 'package:flutter/material.dart';
import '../../core/api_client.dart';
import '../../theme.dart';
import '../../widgets/appbar_actions.dart';

// Tableau de bord du prestataire
// Affiche les statistiques de ses demandes (en attente, acceptées, terminées)

class DashboardPrestataireScreen extends StatefulWidget {
  const DashboardPrestataireScreen({super.key});

  @override
  State<DashboardPrestataireScreen> createState() => _DashboardPrestataireScreenState();
}

class _DashboardPrestataireScreenState extends State<DashboardPrestataireScreen> {
  final _api = ApiClient();

  Map<String, dynamic>? _stats;
  bool _chargement = true;
  bool _erreur     = false;

  @override
  void initState() {
    super.initState();
    _charger();
  }

  Future<void> _charger() async {
    setState(() { _chargement = true; _erreur = false; });
    try {
      final stats = await _api.getStatsDemandes();
      if (!mounted) return;
      setState(() { _stats = stats; _chargement = false; });
    } catch (e) {
      debugPrint('Erreur stats: $e'); // TODO: message d'erreur plus précis
      if (!mounted) return;
      setState(() { _chargement = false; _erreur = true; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBackground,
      body: RefreshIndicator(
        color: kOrange,
        onRefresh: _charger,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            // ── AppBar ─────────────────────────────────────────────────────
            SliverAppBar(
              pinned: true,
              backgroundColor: Colors.white,
              elevation: 0,
              title: Row(
                children: [
                  Container(
                    width: 30, height: 30,
                    decoration: BoxDecoration(color: kOrange, borderRadius: BorderRadius.circular(8)),
                    child: const Icon(Icons.location_on, color: Colors.white, size: 17),
                  ),
                  const SizedBox(width: 8),
                  const Text('DouraKa Pro',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: kTextPrimary)),
                ],
              ),
              actions: const [AppBarActions()],
            ),

            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Tableau de bord',
                        style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: kTextPrimary)),
                    const SizedBox(height: 4),
                    const Text('Vue d\'ensemble de tes activités',
                        style: TextStyle(fontSize: 13, color: kTextGray)),
                    const SizedBox(height: 20),

                    if (_chargement)
                      const Center(child: CircularProgressIndicator(color: kOrange))
                    else if (_erreur)
                      Center(
                        child: Column(
                          children: [
                            const Icon(Icons.wifi_off_rounded, size: 48, color: kBorder),
                            const SizedBox(height: 12),
                            const Text('Impossible de charger', style: TextStyle(color: kTextGray)),
                            const SizedBox(height: 12),
                            TextButton.icon(
                              onPressed: _charger,
                              icon: const Icon(Icons.refresh, color: kOrange),
                              label: const Text('Réessayer', style: TextStyle(color: kOrange)),
                            ),
                          ],
                        ),
                      )
                    else if (_stats != null)
                      _GrilleStats(stats: _stats!),

                    const SizedBox(height: 24),

                    // Conseils rapides
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [kOrange, kOrangeDark],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          Text('💡 Conseils',
                              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white)),
                          SizedBox(height: 12),
                          _Conseil(texte: 'Réponds rapidement aux demandes pour augmenter ton taux d\'acceptation'),
                          SizedBox(height: 8),
                          _Conseil(texte: 'Un profil complet avec photo attire plus de clients'),
                          SizedBox(height: 8),
                          _Conseil(texte: 'Active ta disponibilité uniquement quand tu peux travailler'),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Grille des statistiques ───────────────────────────────────────────────
class _GrilleStats extends StatelessWidget {
  final Map<String, dynamic> stats;

  const _GrilleStats({required this.stats});

  @override
  Widget build(BuildContext context) {
    final enAttente = stats['en_attente'] ?? 0;
    final acceptees = stats['acceptees']  ?? 0;
    final terminees = stats['terminees']  ?? 0;
    final total     = stats['total']      ?? 0;

    return Column(
      children: [
        // Grande stat
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 8, offset: const Offset(0, 2))],
          ),
          child: Column(
            children: [
              Text('$total',
                  style: const TextStyle(fontSize: 48, fontWeight: FontWeight.w800, color: kOrange)),
              const Text('Demandes reçues au total',
                  style: TextStyle(fontSize: 13, color: kTextGray)),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: _CarteStatut(
              icone: Icons.access_time_rounded,
              valeur: '$enAttente',
              label: 'En attente',
              couleur: kYellow,
              bg: const Color(0xFFFEF9C3),
            )),
            const SizedBox(width: 10),
            Expanded(child: _CarteStatut(
              icone: Icons.check_circle_outline_rounded,
              valeur: '$acceptees',
              label: 'En cours',
              couleur: kGreen,
              bg: kGreenLight,
            )),
            const SizedBox(width: 10),
            Expanded(child: _CarteStatut(
              icone: Icons.task_alt_rounded,
              valeur: '$terminees',
              label: 'Terminées',
              couleur: kTextGray,
              bg: const Color(0xFFF3F4F6),
            )),
          ],
        ),
      ],
    );
  }
}

class _CarteStatut extends StatelessWidget {
  final IconData icone;
  final String   valeur;
  final String   label;
  final Color    couleur;
  final Color    bg;

  const _CarteStatut({
    required this.icone,
    required this.valeur,
    required this.label,
    required this.couleur,
    required this.bg,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 6)],
      ),
      child: Column(
        children: [
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
            child: Icon(icone, size: 18, color: couleur),
          ),
          const SizedBox(height: 8),
          Text(valeur,
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: couleur)),
          const SizedBox(height: 2),
          Text(label,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 11, color: kTextGray)),
        ],
      ),
    );
  }
}

class _Conseil extends StatelessWidget {
  final String texte;
  const _Conseil({required this.texte});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('→', style: TextStyle(color: Colors.white, fontSize: 13)),
        const SizedBox(width: 8),
        Expanded(child: Text(texte,
            style: const TextStyle(color: Colors.white, fontSize: 13, height: 1.4))),
      ],
    );
  }
}
