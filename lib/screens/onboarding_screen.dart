import 'package:flutter/material.dart';
import '../core/token_storage.dart';
import '../theme.dart';
import 'login_screen.dart';

// Onboarding affiché une seule fois : à la première installation,

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _pageCtrl   = PageController();
  int   _pageActuel = 0;

  // Garde contre le double-tap rapide sur "Commencer" ou "Passer".
  bool  _navigue    = false;

  Future<void> _terminer() async {
    if (_navigue) return;
    _navigue = true;

    // On mémorise que l'onboarding a été vu AVANT de naviguer.
    await TokenStorage.marquerOnboardingVu();
    if (!mounted) return;

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
    );
  }

  void _suivant() {
    if (_navigue) return;

    if (_pageActuel < 2) {
      // On utilise nextPage() plutôt que animateToPage() pour rester déclaratif :
      _pageCtrl.nextPage(
        duration: const Duration(milliseconds: 350),
        curve:    Curves.easeInOut,
      );
    } else {
      // Dernière slide → on valide l'onboarding et on va au login
      _terminer();
    }
  }

  @override
  void dispose() {
    _pageCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final estDernier = _pageActuel == 2;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [

            // ── Bouton "Passer" (coin haut droit) ────────────────────────────
            Align(
              alignment: Alignment.topRight,
              child: Padding(
                padding: const EdgeInsets.only(top: 8, right: 8),
                child: AnimatedOpacity(
                  opacity:  estDernier ? 0 : 1,
                  duration: const Duration(milliseconds: 200),
                  child: TextButton(
                    onPressed: estDernier ? null : _terminer,
                    child: const Text(
                      'Passer',
                      style: TextStyle(
                        color:      kTextGray,
                        fontSize:   14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              ),
            ),

            // ── Les 3 slides ──────────────────────────────────────────────────
           
            Expanded(
              child: PageView(
                controller:    _pageCtrl,
                onPageChanged: (i) => setState(() => _pageActuel = i),
                children: const [
                  _Slide1Bienvenue(),
                  _Slide2Prestataires(),
                  _Slide3Etapes(),
                ],
              ),
            ),

            // ── Indicateur de progression (dots) ──────────────────────────────
            // AnimatedContainer sur la largeur : le dot actif s'étire en pill (24px)
            // et les autres restent ronds (8px). Effet simple, très lisible.
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(3, (i) {
                final actif = i == _pageActuel;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  margin:   const EdgeInsets.symmetric(horizontal: 4),
                  width:    actif ? 24 : 8,
                  height:   8,
                  decoration: BoxDecoration(
                    color:        actif ? kOrange : kBorder,
                    borderRadius: BorderRadius.circular(4),
                  ),
                );
              }),
            ),

            const SizedBox(height: 28),

            // ── Bouton principal ───────────────────────────────────────────────
            // Le label change dynamiquement : "Suivant" sur les slides 1 et 2,
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: SizedBox(
                width:  double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _suivant,
                  child: Text(
                    estDernier ? 'Commencer' : 'Suivant',
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 28),
          ],
        ),
      ),
    );
  }
}


class _Slide1Bienvenue extends StatefulWidget {
  const _Slide1Bienvenue();

  @override
  State<_Slide1Bienvenue> createState() => _Slide1BienvenueState();
}

class _Slide1BienvenueState extends State<_Slide1Bienvenue>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double>   _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync:    this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true); // boucle infinie en aller-retour
    _scale = Tween<double>(begin: 0.95, end: 1.05).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          
          ScaleTransition(
            scale: _scale,
            child: SizedBox(
              width: 240, height: 240,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  _Cercle(220, kOrange.withValues(alpha: 0.06)),
                  _Cercle(170, kOrange.withValues(alpha: 0.11)),
                  _Cercle(120, kOrange.withValues(alpha: 0.18)),
                  // Logo central avec dégradé + ombre orange pour le faire "flotter"
                  Container(
                    width: 90, height: 90,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [kOrange, kOrangeDark],
                        begin:  Alignment.topLeft,
                        end:    Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(26),
                      boxShadow: [
                        BoxShadow(
                          color:      kOrange.withValues(alpha: 0.4),
                          blurRadius: 24,
                          offset:     const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: const Icon(Icons.location_on_rounded,
                        color: Colors.white, size: 48),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 40),

          const Text(
            'Bienvenue sur DouraKa',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize:   26,
              fontWeight: FontWeight.w800,
              color:      kTextPrimary,
              height:     1.2,
            ),
          ),
          const SizedBox(height: 14),
          const Text(
            'La plateforme qui connecte les clients avec des prestataires de confiance à Conakry.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 15, color: kTextGray, height: 1.6),
          ),
        ],
      ),
    );
  }
}


class _Slide2Prestataires extends StatelessWidget {
  const _Slide2Prestataires();

  @override
  Widget build(BuildContext context) {
    // Liste des services hard-codée pour l'onboarding — c'est de la vitrine,
    // pas de la data dynamique. Pas besoin d'appel API ici.
    const services = [
      _Service(Icons.plumbing_rounded,      'Plombier',      Color(0xFF3B82F6)),
      _Service(Icons.electrical_services,   'Électricien',   Color(0xFFF59E0B)),
      _Service(Icons.construction_rounded,  'Maçon',         Color(0xFF10B981)),
      _Service(Icons.format_paint_rounded,  'Peintre',       Color(0xFFEC4899)),
      _Service(Icons.ac_unit_rounded,       'Climatisation', Color(0xFF6366F1)),
      _Service(Icons.computer_rounded,      'Informatique',  Color(0xFF14B8A6)),
      _Service(Icons.local_laundry_service, 'Nettoyage',     Color(0xFFF97316)),
      _Service(Icons.yard_rounded,          'Jardinage',     Color(0xFF22C55E)),
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Wrap(
            spacing:    16,
            runSpacing: 16,
            alignment:  WrapAlignment.center,
            children: services.map((s) => _CarteService(service: s)).toList(),
          ),

          const SizedBox(height: 40),

          const Text(
            'Des professionnels vérifiés',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize:   26,
              fontWeight: FontWeight.w800,
              color:      kTextPrimary,
              height:     1.2,
            ),
          ),
          const SizedBox(height: 14),
          const Text(
            'Plombiers, électriciens, maçons, peintres… trouvez l\'expert qu\'il vous faut, près de chez vous.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 15, color: kTextGray, height: 1.6),
          ),
        ],
      ),
    );
  }
}

// Simple data class pour structurer chaque service — pas besoin d'un vrai modèle
// avec fromJson ici, c'est uniquement pour l'onboarding.
class _Service {
  final IconData icone;
  final String   nom;
  final Color    couleur;
  const _Service(this.icone, this.nom, this.couleur);
}

class _CarteService extends StatelessWidget {
  final _Service service;
  const _CarteService({required this.service});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Fond coloré semi-transparent + bordure légère : évite d'avoir
        // des icônes qui "flottent" dans le vide tout en restant léger visuellement.
        Container(
          width:  60, height: 60,
          decoration: BoxDecoration(
            color:         service.couleur.withValues(alpha: 0.12),
            borderRadius:  BorderRadius.circular(16),
            border: Border.all(
                color: service.couleur.withValues(alpha: 0.3), width: 1.5),
          ),
          child: Icon(service.icone, color: service.couleur, size: 28),
        ),
        const SizedBox(height: 6),
        Text(service.nom,
            style: const TextStyle(
                fontSize: 10, color: kTextGray, fontWeight: FontWeight.w500)),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// SLIDE 3 — Les 3 étapes avec ligne de connexion verticale
//
// Pattern "stepper maison" : chaque étape a une icône ronde + une ligne qui
// relie à la suivante. On évite le Stepper de Material qui est trop rigide
// et difficile à styler pour ce cas précis.
// ═══════════════════════════════════════════════════════════════════════════
class _Slide3Etapes extends StatelessWidget {
  const _Slide3Etapes();

  @override
  Widget build(BuildContext context) {
    const etapes = [
      _Etape(Icons.search_rounded, 'Cherchez',
          'Trouvez le bon prestataire par catégorie ou quartier'),
      _Etape(Icons.send_rounded, 'Demandez',
          'Envoyez votre demande en quelques secondes'),
      _Etape(Icons.handshake_rounded, 'Recevez',
          'Obtenez un devis et profitez du service'),
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // List.generate avec index permet de savoir si on est à la dernière étape
          // pour ne pas afficher la ligne de connexion après la dernière icône.
          ...List.generate(etapes.length, (i) {
            final e        = etapes[i];
            final derniere = i == etapes.length - 1;
            return _LigneEtape(etape: e, derniere: derniere);
          }),

          const SizedBox(height: 40),

          const Text(
            'Simple en 3 étapes',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize:   26,
              fontWeight: FontWeight.w800,
              color:      kTextPrimary,
              height:     1.2,
            ),
          ),
          const SizedBox(height: 14),
          const Text(
            'Cherchez un prestataire, envoyez votre demande et recevez un devis. Tout depuis votre téléphone.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 15, color: kTextGray, height: 1.6),
          ),
        ],
      ),
    );
  }
}

class _Etape {
  final IconData icone;
  final String   titre;
  final String   detail;
  const _Etape(this.icone, this.titre, this.detail);
}

class _LigneEtape extends StatelessWidget {
  final _Etape etape;
  final bool   derniere;
  const _LigneEtape({required this.etape, required this.derniere});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Colonne gauche : icône + ligne de connexion vers le bas.
        // La ligne est un dégradé qui s'efface vers le bas pour donner
        // un effet de continuité douce entre les étapes.
        Column(
          children: [
            Container(
              width: 48, height: 48,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [kOrange, kOrangeDark],
                  begin:  Alignment.topLeft,
                  end:    Alignment.bottomRight,
                ),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color:      kOrange.withValues(alpha: 0.3),
                    blurRadius: 10,
                    offset:     const Offset(0, 4),
                  ),
                ],
              ),
              child: Icon(etape.icone, color: Colors.white, size: 22),
            ),
            // Ligne de connexion uniquement entre les étapes, jamais après la dernière
            if (!derniere)
              Container(
                width: 2, height: 36,
                margin: const EdgeInsets.symmetric(vertical: 4),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin:  Alignment.topCenter,
                    end:    Alignment.bottomCenter,
                    colors: [
                      kOrange.withValues(alpha: 0.5),
                      kOrange.withValues(alpha: 0.1),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(1),
                ),
              ),
          ],
        ),

        const SizedBox(width: 16),

        // Texte à droite de l'icône, aligné sur le haut de l'icône (padding top: 10)
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(etape.titre,
                    style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: kTextPrimary)),
                const SizedBox(height: 3),
                Text(etape.detail,
                    style: const TextStyle(
                        fontSize: 12, color: kTextGray, height: 1.4)),
                // Espace sous le texte seulement si ce n'est pas la dernière étape,
                
                if (!derniere) const SizedBox(height: 12),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ── Widget utilitaire : cercle décoratif ─────────────────────────────────
class _Cercle extends StatelessWidget {
  final double taille;
  final Color  couleur;
  const _Cercle(this.taille, this.couleur);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: taille, height: taille,
      decoration: BoxDecoration(color: couleur, shape: BoxShape.circle),
    );
  }
}
