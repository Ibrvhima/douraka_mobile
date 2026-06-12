import 'package:flutter/material.dart';
import '../../core/api_client.dart';
import '../../core/token_storage.dart';
import '../../theme.dart';
import '../login_screen.dart';

// Tableau de bord ADMIN — statistiques globales de la plateforme

class DashboardAdminScreen extends StatefulWidget {
  const DashboardAdminScreen({super.key});

  @override
  State<DashboardAdminScreen> createState() => _DashboardAdminScreenState();
}

class _DashboardAdminScreenState extends State<DashboardAdminScreen> {
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
      final stats = await _api.getStatsAdmin();
      if (!mounted) return;
      setState(() { _stats = stats; _chargement = false; });
    } catch (e) {
      debugPrint('Erreur stats admin: $e');
      if (!mounted) return;
      setState(() { _chargement = false; _erreur = true; });
    }
  }

  Future<void> _seDeconnecter() async {
    await TokenStorage.supprimer();
    if (mounted) {
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
      body: RefreshIndicator(
        color: kOrange,
        onRefresh: _charger,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
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
                  const Text('DouraKa Admin',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: kTextPrimary)),
                ],
              ),
              actions: [
                IconButton(
                  icon: const Icon(Icons.logout_rounded, color: kRed),
                  onPressed: _seDeconnecter,
                  tooltip: 'Déconnexion',
                ),
              ],
            ),

            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Statistiques globales',
                        style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: kTextPrimary)),
                    const SizedBox(height: 4),
                    const Text('Vue d\'ensemble de la plateforme DouraKa',
                        style: TextStyle(fontSize: 13, color: kTextGray)),
                    const SizedBox(height: 20),

                    if (_chargement)
                      const Center(child: Padding(
                        padding: EdgeInsets.all(40),
                        child: CircularProgressIndicator(color: kOrange),
                      ))
                    else if (_erreur)
                      Center(
                        child: Column(
                          children: [
                            const Icon(Icons.wifi_off_rounded, size: 52, color: kBorder),
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
                    else if (_stats != null) ...[
                      // ── Utilisateurs ──────────────────────────────────────
                      _TitreSection(titre: '👥 Utilisateurs', badge: '${_stats!['users']?['total'] ?? 0}'),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(child: _CarteStatAdmin(
                            label: 'Clients', valeur: '${_stats!['users']?['clients'] ?? 0}',
                            icone: Icons.person_outline, couleur: kOrange, bg: kOrangeLight)),
                          const SizedBox(width: 10),
                          Expanded(child: _CarteStatAdmin(
                            label: 'Prestataires', valeur: '${_stats!['users']?['prestataires'] ?? 0}',
                            icone: Icons.work_outline, couleur: kGreen, bg: kGreenLight)),
                        ],
                      ),

                      const SizedBox(height: 20),

                      // ── Prestataires ──────────────────────────────────────
                      _TitreSection(titre: '🔧 Prestataires', badge: '${_stats!['prestataires']?['total'] ?? 0}'),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(child: _CarteStatAdmin(
                            label: 'Disponibles', valeur: '${_stats!['prestataires']?['disponibles'] ?? 0}',
                            icone: Icons.circle, couleur: kGreen, bg: kGreenLight)),
                          const SizedBox(width: 10),
                          Expanded(child: _CarteStatAdmin(
                            label: 'Certifiés', valeur: '${_stats!['prestataires']?['verifies'] ?? 0}',
                            icone: Icons.verified_rounded, couleur: kOrange, bg: kOrangeLight)),
                        ],
                      ),

                      const SizedBox(height: 20),

                      // ── Demandes ──────────────────────────────────────────
                      _TitreSection(titre: '📋 Demandes', badge: '${_stats!['demandes']?['total'] ?? 0}'),
                      const SizedBox(height: 8),
                      GridView.count(
                        crossAxisCount: 2,
                        mainAxisSpacing: 10,
                        crossAxisSpacing: 10,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        childAspectRatio: 2.2,
                        children: [
                          _CarteStatAdmin(
                            label: 'En attente', valeur: '${_stats!['demandes']?['en_attente'] ?? 0}',
                            icone: Icons.access_time_rounded, couleur: kYellow,
                            bg: const Color(0xFFFEF9C3)),
                          _CarteStatAdmin(
                            label: 'Acceptées', valeur: '${_stats!['demandes']?['acceptees'] ?? 0}',
                            icone: Icons.check_circle_outline, couleur: kGreen, bg: kGreenLight),
                          _CarteStatAdmin(
                            label: 'Terminées', valeur: '${_stats!['demandes']?['terminees'] ?? 0}',
                            icone: Icons.task_alt_rounded, couleur: kTextGray,
                            bg: const Color(0xFFF3F4F6)),
                          _CarteStatAdmin(
                            label: 'Catégories', valeur: '${_stats!['categories'] ?? 0}',
                            icone: Icons.category_outlined, couleur: kOrange, bg: kOrangeLight),
                        ],
                      ),
                    ],
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

class _TitreSection extends StatelessWidget {
  final String titre;
  final String badge;

  const _TitreSection({required this.titre, required this.badge});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(titre, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: kTextPrimary)),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(color: kOrangeLight, borderRadius: BorderRadius.circular(10)),
          child: Text(badge, style: const TextStyle(fontSize: 12, color: kOrange, fontWeight: FontWeight.w700)),
        ),
      ],
    );
  }
}

class _CarteStatAdmin extends StatelessWidget {
  final String   label;
  final String   valeur;
  final IconData icone;
  final Color    couleur;
  final Color    bg;

  const _CarteStatAdmin({
    required this.label,
    required this.valeur,
    required this.icone,
    required this.couleur,
    required this.bg,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 6)],
      ),
      child: Row(
        children: [
          Container(
            width: 34, height: 34,
            decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
            child: Icon(icone, size: 16, color: couleur),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(valeur, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: couleur)),
              Text(label, style: const TextStyle(fontSize: 11, color: kTextGray)),
            ],
          ),
        ],
      ),
    );
  }
}
