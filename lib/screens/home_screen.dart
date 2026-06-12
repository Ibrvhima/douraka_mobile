import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/api_client.dart';
import '../models/prestataire.dart';
import '../theme.dart';
import '../widgets/appbar_actions.dart';
import 'detail_prestataire_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  final _api           = ApiClient();
  final _searchCtrl    = TextEditingController();

  List<Prestataire> _tous       = [];
  List<Prestataire> _filtres    = [];
  List<dynamic>     _categories = [];

  int?      _categorieActive;
  bool      _chargement = true;
  bool      _erreur     = false;
  DateTime? _dernierChargement;
  String    _prenom     = '';

  // ── Icônes modernes par catégorie ─────────────────────────────────────────
  static const Map<String, IconData> _iconeCategorie = {
    'plombier':      Icons.plumbing,
    'électricien':   Icons.electrical_services,
    'electricien':   Icons.electrical_services,
    'maçon':         Icons.construction,
    'macon':         Icons.construction,
    'menuisier':     Icons.handyman,
    'peintre':       Icons.format_paint,
    'climatisation': Icons.ac_unit,
    'jardinage':     Icons.yard,
    'nettoyage':     Icons.cleaning_services,
    'informatique':  Icons.computer,
    'déménagement':  Icons.local_shipping,
    'demenagement':  Icons.local_shipping,
  };

  static IconData _iconeParNom(String nom) {
    final cle = nom.toLowerCase().trim();
    return _iconeCategorie[cle] ?? Icons.home_repair_service_rounded;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _charger();
    _searchCtrl.addListener(_filtrer);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      final maintenant = DateTime.now();
      final tropTot = _dernierChargement != null &&
          maintenant.difference(_dernierChargement!).inMinutes < 2;
      if (!tropTot) _charger();
    }
  }

  Future<void> _charger() async {
    _dernierChargement = DateTime.now();
    setState(() { _chargement = true; _erreur = false; });
    try {
      final resultats = await Future.wait([
        _api.getPrestataires(),
        _api.getCategories(),
      ]);

      final liste = resultats[0]
          .map((j) => Prestataire.fromJson(Map<String, dynamic>.from(j as Map)))
          .toList();

      if (!mounted) return;

      setState(() {
        _tous       = liste;
        _categories = resultats[1];
        _chargement = false;
      });

      _filtrer();
      _chargerProfil(); // salutation en arrière-plan

    } catch (e) {
      debugPrint('Erreur chargement: $e');
      if (!mounted) return;
      setState(() { _chargement = false; _erreur = true; });
    }
  }

  Future<void> _chargerProfil() async {
    try {
      final profil = await _api.getMonProfil();
      if (!mounted) return;
      setState(() => _prenom = profil['prenom']?.toString() ?? '');
    } catch (_) {}
  }

  void _filtrer() {
    final q = _searchCtrl.text.toLowerCase();
    setState(() {
      _filtres = _tous.where((p) {
        final matchRecherche = q.isEmpty ||
            p.nomComplet.toLowerCase().contains(q) ||
            (p.categorie?.toLowerCase().contains(q) ?? false) ||
            (p.quartier?.toLowerCase().contains(q) ?? false);
        final matchCategorie = _categorieActive == null ||
            p.categorieId == _categorieActive;
        return matchRecherche && matchCategorie;
      }).toList();
    });
  }

  void _selectionnerCategorie(int? id) {
    _categorieActive = id;
    _filtrer();
  }

  int? _toInt(dynamic val) {
    if (val == null) return null;
    if (val is int) return val;
    return int.tryParse(val.toString());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _searchCtrl.dispose();
    super.dispose();
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

            // ── AppBar ────────────────────────────────────────────────────
            SliverAppBar(
              pinned: true,
              backgroundColor: Colors.white,
              elevation: 0,
              toolbarHeight: 56,
              title: Row(
                children: [
                  Container(
                    width: 32, height: 32,
                    decoration: BoxDecoration(
                      color: kOrange,
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: const Icon(Icons.location_on, color: Colors.white, size: 18),
                  ),
                  const SizedBox(width: 8),
                  const Text('DouraKa',
                      style: TextStyle(fontSize: 21, fontWeight: FontWeight.w800, color: kTextPrimary)),
                ],
              ),
              actions: const [AppBarActions()],
            ),

            // ── Salutation personnalisée ──────────────────────────────────
            SliverToBoxAdapter(
              child: Container(
                color: Colors.white,
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _prenom.isNotEmpty
                          ? 'Bonjour, $_prenom 👋'
                          : 'Bonjour 👋',
                      style: const TextStyle(
                          fontSize: 22, fontWeight: FontWeight.w800, color: kTextPrimary),
                    ),
                    const SizedBox(height: 2),
                    const Text('Trouve un artisan de confiance à Conakry',
                        style: TextStyle(fontSize: 13, color: kTextGray)),
                  ],
                ),
              ),
            ),

            // ── Barre de recherche ────────────────────────────────────────
            SliverToBoxAdapter(
              child: Container(
                color: Colors.white,
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
                child: TextField(
                  controller: _searchCtrl,
                  decoration: InputDecoration(
                    hintText: 'Plombier, électricien, peintre…',
                    hintStyle: const TextStyle(fontSize: 13, color: kTextGray),
                    prefixIcon: const Icon(Icons.search_rounded, size: 20, color: kTextGray),
                    suffixIcon: _searchCtrl.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.cancel_rounded, size: 18, color: kTextGray),
                            onPressed: () { _searchCtrl.clear(); _filtrer(); },
                          )
                        : null,
                    contentPadding: const EdgeInsets.symmetric(vertical: 10),
                    filled: true,
                    fillColor: kBackground,
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                    enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                    focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(color: kOrange, width: 1.5)),
                  ),
                ),
              ),
            ),

            // ── Filtres catégories avec icônes ────────────────────────────
            if (_categories.isNotEmpty)
              SliverToBoxAdapter(
                child: SizedBox(
                  height: 46,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    children: [
                      _CategorieChip(
                        label: 'Tous',
                        icone: Icons.apps_rounded,
                        active: _categorieActive == null,
                        onTap: () => _selectionnerCategorie(null),
                      ),
                      for (final cat in _categories)
                        _CategorieChip(
                          label: cat['nom']?.toString() ?? '',
                          icone: _iconeParNom(cat['nom']?.toString() ?? ''),
                          active: _categorieActive == _toInt(cat['id']),
                          onTap: () => _selectionnerCategorie(_toInt(cat['id'])),
                        ),
                    ],
                  ),
                ),
              ),

            // ── Contenu ───────────────────────────────────────────────────
            if (_chargement)
              const SliverFillRemaining(
                child: _SkeletonListe(),
              )
            else if (_erreur)
              SliverFillRemaining(child: _EtatErreur(onRetry: _charger))
            else if (_filtres.isEmpty)
              SliverFillRemaining(
                child: _EtatVide(avecFiltre: _categorieActive != null || _searchCtrl.text.isNotEmpty),
              )
            else ...[
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
                sliver: SliverToBoxAdapter(
                  child: Text(
                    '${_filtres.length} prestataire${_filtres.length > 1 ? 's' : ''} disponible${_filtres.length > 1 ? 's' : ''}',
                    style: const TextStyle(fontSize: 13, color: kTextGray, fontWeight: FontWeight.w500),
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (_, i) => _CartePrestataire(prestataire: _filtres[i]),
                    childCount: _filtres.length,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ── Chip de catégorie avec icône ──────────────────────────────────────────
class _CategorieChip extends StatelessWidget {
  final String    label;
  final IconData  icone;
  final bool      active;
  final VoidCallback onTap;

  const _CategorieChip({
    required this.label,
    required this.icone,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(right: 8, bottom: 2),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: active ? kOrange : Colors.white,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: active ? kOrange : kBorder),
          boxShadow: active
              ? [BoxShadow(color: kOrange.withValues(alpha: 0.25), blurRadius: 8, offset: const Offset(0, 2))]
              : [],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icone, size: 14, color: active ? Colors.white : kTextGray),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: active ? Colors.white : kTextGray,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Carte d'un prestataire ────────────────────────────────────────────────
class _CartePrestataire extends StatelessWidget {
  final Prestataire prestataire;
  const _CartePrestataire({required this.prestataire});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => DetailPrestataireScreen(uuid: prestataire.uuid)),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 12, offset: const Offset(0, 3)),
          ],
        ),
        child: Row(
          children: [
            _Avatar(initiales: prestataire.initiales, photo: prestataire.photo),
            const SizedBox(width: 12),

            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          prestataire.nomComplet,
                          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: kTextPrimary),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (prestataire.badgeVerifie) ...[
                        const SizedBox(width: 4),
                        const Icon(Icons.verified_rounded, color: kOrange, size: 15),
                      ],
                    ],
                  ),
                  if (prestataire.categorie != null)
                    Text(prestataire.categorie!,
                        style: const TextStyle(fontSize: 12, color: kOrange, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 5),
                  Row(
                    children: [
                      if (prestataire.quartier != null) ...[
                        const Icon(Icons.place_outlined, size: 12, color: kTextGray),
                        const SizedBox(width: 2),
                        Flexible(
                          child: Text(prestataire.quartier!,
                              style: const TextStyle(fontSize: 11, color: kTextGray),
                              overflow: TextOverflow.ellipsis),
                        ),
                        const SizedBox(width: 8),
                      ],
                      if (prestataire.noteMoyenne != null && prestataire.noteMoyenne! > 0) ...[
                        const Icon(Icons.star_rounded, size: 12, color: kYellow),
                        const SizedBox(width: 2),
                        Text(prestataire.noteMoyenne!.toStringAsFixed(1),
                            style: const TextStyle(fontSize: 11, color: kTextGray, fontWeight: FontWeight.w600)),
                      ],
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(width: 8),

            // Avis + flèche (remplace le badge "Disponible" redondant)
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (prestataire.nbAvis > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF9C3),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '${prestataire.nbAvis} avis',
                      style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: kYellow),
                    ),
                  )
                else
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(
                      color: kOrangeLight,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text('Nouveau',
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: kOrange)),
                  ),
                const SizedBox(height: 8),
                const Icon(Icons.chevron_right_rounded, size: 18, color: kTextGray),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ── Avatar ────────────────────────────────────────────────────────────────
class _Avatar extends StatelessWidget {
  final String  initiales;
  final String? photo;
  const _Avatar({required this.initiales, this.photo});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 54, height: 54,
      decoration: const BoxDecoration(color: kOrangeLight, shape: BoxShape.circle),
      clipBehavior: Clip.antiAlias,
      child: photo != null && photo!.isNotEmpty
          ? Image.network(
              photo!,
              fit: BoxFit.cover,
              errorBuilder: (context, error, _) => _Initiales(initiales: initiales),
            )
          : _Initiales(initiales: initiales),
    );
  }
}

class _Initiales extends StatelessWidget {
  final String initiales;
  const _Initiales({required this.initiales});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        initiales.isEmpty ? '?' : initiales,
        style: const TextStyle(color: kOrange, fontWeight: FontWeight.w700, fontSize: 18),
      ),
    );
  }
}

// ── Skeleton loading ──────────────────────────────────────────────────────
class _SkeletonListe extends StatelessWidget {
  const _SkeletonListe();

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      physics: const NeverScrollableScrollPhysics(),
      itemCount: 5,
      itemBuilder: (context, _) => const _SkeletonCarte(),
    );
  }
}

class _SkeletonCarte extends StatefulWidget {
  const _SkeletonCarte();
  @override
  State<_SkeletonCarte> createState() => _SkeletonCarteState();
}

class _SkeletonCarteState extends State<_SkeletonCarte> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double>   _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200))..repeat(reverse: true);
    _anim = Tween<double>(begin: 0.3, end: 0.7).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (context, _) => Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8)],
        ),
        child: Row(
          children: [
            _bloc(54, 54, radius: 27, opacity: _anim.value),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _bloc(120, 14, opacity: _anim.value),
                  const SizedBox(height: 7),
                  _bloc(80, 11, opacity: _anim.value * 0.7),
                  const SizedBox(height: 7),
                  _bloc(100, 10, opacity: _anim.value * 0.5),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _bloc(double w, double h, {double radius = 8, double opacity = 0.5}) {
    return Container(
      width: w, height: h,
      decoration: BoxDecoration(
        color: Colors.grey.withValues(alpha: opacity),
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}

// ── État vide amélioré ────────────────────────────────────────────────────
class _EtatVide extends StatelessWidget {
  final bool avecFiltre;
  const _EtatVide({this.avecFiltre = false});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 84, height: 84,
              decoration: const BoxDecoration(color: kOrangeLight, shape: BoxShape.circle),
              child: const Icon(Icons.search_off_rounded, size: 40, color: kOrange),
            ),
            const SizedBox(height: 20),
            const Text('Aucun prestataire trouvé',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: kTextPrimary)),
            const SizedBox(height: 8),
            Text(
              avecFiltre
                  ? 'Essaie sans filtre de catégorie\nou cherche dans un autre quartier'
                  : 'Aucun artisan n\'est disponible\npour l\'instant. Reviens bientôt !',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13, color: kTextGray, height: 1.6),
            ),
          ],
        ),
      ),
    );
  }
}

// ── État erreur ───────────────────────────────────────────────────────────
class _EtatErreur extends StatelessWidget {
  final VoidCallback onRetry;
  const _EtatErreur({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 84, height: 84,
              decoration: const BoxDecoration(color: Color(0xFFF3F4F6), shape: BoxShape.circle),
              child: const Icon(Icons.wifi_off_rounded, size: 40, color: kTextGray),
            ),
            const SizedBox(height: 20),
            const Text('Problème de connexion',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: kTextPrimary)),
            const SizedBox(height: 8),
            const Text('Vérifie ta connexion internet\net réessaie',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: kTextGray, height: 1.6)),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Réessayer'),
              style: ElevatedButton.styleFrom(minimumSize: const Size(160, 48)),
            ),
          ],
        ),
      ),
    );
  }
}
