import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:dio/dio.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:share_plus/share_plus.dart';
import '../core/api_client.dart';
import '../models/prestataire.dart';
import '../models/avis.dart';
import '../models/demande.dart';
import '../theme.dart';
import '../widgets/appbar_actions.dart';

class DetailPrestataireScreen extends StatefulWidget {
  final String uuid;

  const DetailPrestataireScreen({super.key, required this.uuid});

  @override
  State<DetailPrestataireScreen> createState() =>
      _DetailPrestataireScreenState();
}

class _DetailPrestataireScreenState extends State<DetailPrestataireScreen> {
  final _api = ApiClient();
  late Future<Prestataire> _futurPrestataire;

  @override
  void initState() {
    super.initState();
    _futurPrestataire = _charger();
  }

  Future<Prestataire> _charger() async {
    final json = await _api.getPrestataire(widget.uuid);
    // Map.from() convertit les nested Map<dynamic,dynamic> en Map<String,dynamic>
    return Prestataire.fromJson(Map<String, dynamic>.from(json));
  }

  // Partage le profil du prestataire via le système natif (WhatsApp, SMS, etc.)
  void _partagerPrestataire(Prestataire p) {
    final categorie = p.categorie != null ? ' — ${p.categorie}' : '';
    final quartier  = p.quartier  != null ? ' à ${p.quartier}, Conakry' : '';
    final note      = p.noteMoyenne != null && p.noteMoyenne! > 0
        ? ' ⭐ ${p.noteMoyenne!.toStringAsFixed(1)}/5'
        : '';

    final message = '👷 ${p.nomComplet}$categorie$quartier$note\n\n'
        'Retrouve ce prestataire sur DouraKa — '
        'l\'app qui connecte artisans et clients à Conakry 🇬🇳';

    Share.share(message);
  }

  // Lance un appel téléphonique vers le numéro du prestataire
  // url_launcher ouvre l'application téléphone native du téléphone
  Future<void> _appeler(BuildContext ctx, String telephone) async {
    // Nettoie le numéro : retire les espaces pour l'URI tel:
    final numero = telephone.replaceAll(' ', '');
    final uri    = Uri(scheme: 'tel', path: numero);

    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else if (ctx.mounted) {
      ScaffoldMessenger.of(ctx).showSnackBar(
        SnackBar(
          content: Text('Impossible d\'appeler $telephone'),
          backgroundColor: kRed,
        ),
      );
    }
  }

  // Ouvre le formulaire de demande dans une feuille du bas (bottom sheet)
  // C'est le pattern natif mobile pour les formulaires contextuels
  void _ouvrirFormulaireDedemande(BuildContext ctx, Prestataire p) {
    showModalBottomSheet(
      context: ctx,
      isScrollControlled: true, // permet de remplir l'écran si nécessaire
      backgroundColor: Colors.transparent,
      builder: (_) => _FormulaireDedemande(api: _api, prestataire: p),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBackground,
      body: FutureBuilder<Prestataire>(
        future: _futurPrestataire,
        builder: (ctx, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
                child: CircularProgressIndicator(color: kOrange));
          }
          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 48, color: kTextGray),
                  const SizedBox(height: 12),
                  Text('${snapshot.error}',
                      style: const TextStyle(color: kTextGray)),
                ],
              ),
            );
          }

          final p = snapshot.data!;

          return Stack(
            children: [
              // Contenu scrollable
              CustomScrollView(
                slivers: [
                  // ── En-tête avec dégradé orange ─────────────────────────
                  SliverAppBar(
                    expandedHeight: 200,
                    pinned: true,
                    backgroundColor: kOrange,
                    leading: IconButton(
                      icon: const Icon(Icons.arrow_back_ios_new_rounded,
                          color: Colors.white),
                      onPressed: () => Navigator.pop(context),
                    ),
                    actions: [
                      // Bouton partager — envoie le lien du prestataire par WhatsApp, SMS…
                      IconButton(
                        icon: const Icon(Icons.share_rounded, color: Colors.white),
                        tooltip: 'Partager',
                        onPressed: () => _partagerPrestataire(p),
                      ),
                      const AppBarActions(iconColor: Colors.white),
                    ],
                    flexibleSpace: FlexibleSpaceBar(
                      background: Container(
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [kOrange, kOrangeDark],
                          ),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const SizedBox(height: 40),
                            // Avatar
                            Container(
                              width: 72,
                              height: 72,
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.2),
                                shape: BoxShape.circle,
                                border: Border.all(
                                    color: Colors.white, width: 2),
                              ),
                              child: p.photo != null &&
                                      p.photo!.startsWith('http')
                                  ? ClipOval(
                                      child: Image.network(p.photo!,
                                          fit: BoxFit.cover,
                                          errorBuilder: (context, error, _) =>
                                              _initialesWidget(p.initiales)),
                                    )
                                  : _initialesWidget(p.initiales),
                            ),
                            const SizedBox(height: 10),
                            // Nom
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  p.nomComplet,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 18,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                if (p.badgeVerifie) ...[
                                  const SizedBox(width: 6),
                                  const Icon(Icons.verified_rounded,
                                      color: Colors.white, size: 18),
                                ],
                              ],
                            ),
                            if (p.categorie != null)
                              Text(
                                p.categorie!,
                                style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.85),
                                    fontSize: 13),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // ── Corps ────────────────────────────────────────────────
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // ── Infos rapides ─────────────────────────────
                          Row(
                            children: [
                              // Disponibilité
                              _InfoBadge(
                                icon: Icons.circle,
                                label: p.disponible
                                    ? 'Disponible'
                                    : 'Indisponible',
                                color: p.disponible ? kGreen : kRed,
                                bg: p.disponible ? kGreenLight : kRedLight,
                              ),
                              const SizedBox(width: 8),
                              // Note
                              if (p.noteMoyenne != null)
                                _InfoBadge(
                                  icon: Icons.star_rounded,
                                  label:
                                      '${p.noteMoyenne!.toStringAsFixed(1)}/5',
                                  color: kYellow,
                                  bg: const Color(0xFFFEF9C3),
                                ),
                            ],
                          ),

                          const SizedBox(height: 16),

                          // ── Carte infos de contact ─────────────────────
                          _Section(
                            titre: 'Informations',
                            child: Column(
                              children: [
                                if (p.quartier != null)
                                  _LigneInfo(
                                    icon: Icons.place_outlined,
                                    texte: '${p.quartier}, Conakry',
                                  ),
                                if (p.telephone != null)
                                  _LigneInfo(
                                    icon: Icons.phone_outlined,
                                    texte: p.telephone!,
                                  ),
                                if (p.categorie != null)
                                  _LigneInfo(
                                    icon: Icons.work_outline_rounded,
                                    texte: p.categorie!,
                                  ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 12),

                          // ── Description ──────────────────────────────
                          if (p.description != null &&
                              p.description!.isNotEmpty)
                            _Section(
                              titre: 'À propos',
                              child: Text(
                                p.description!,
                                style: const TextStyle(
                                    fontSize: 14,
                                    color: kTextGray,
                                    height: 1.5),
                              ),
                            ),

                          const SizedBox(height: 12),

                          // ── Section avis ──────────────────────────────
                          _SectionAvis(
                            prestataireId:   p.id,
                            prestataireUuid: widget.uuid,
                            nbAvis:          p.nbAvis,
                          ),

                          // Espace pour que le bouton fixe ne cache pas le contenu
                          const SizedBox(height: 80),
                        ],
                      ),
                    ),
                  ),
                ],
              ),

              // ── Boutons fixes en bas ─────────────────────────────────────
              // Appeler + Envoyer une demande — safe area pour barre de gestes
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Container(
                  padding: EdgeInsets.fromLTRB(
                    16,
                    12,
                    16,
                    16 + MediaQuery.of(ctx).padding.bottom,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.08),
                        blurRadius: 12,
                        offset: const Offset(0, -3),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      // Bouton Appeler — visible seulement si le prestataire a un numéro
                      if (p.telephone != null && p.telephone!.isNotEmpty) ...[
                        OutlinedButton.icon(
                          icon: const Icon(Icons.phone_rounded, size: 18, color: kGreen),
                          label: const Text('Appeler',
                              style: TextStyle(color: kGreen, fontWeight: FontWeight.w600)),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: kGreen, width: 1.5),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 18),
                          ),
                          onPressed: () => _appeler(ctx, p.telephone!),
                        ),
                        const SizedBox(width: 10),
                      ],
                      // Bouton Demande — désactivé si prestataire indisponible
                      Expanded(
                        child: ElevatedButton.icon(
                          icon: const Icon(Icons.send_rounded, size: 18),
                          label: Text(p.disponible ? 'Envoyer une demande' : 'Non disponible'),
                          onPressed: p.disponible
                              ? () {
                                  HapticFeedback.mediumImpact();
                                  _ouvrirFormulaireDedemande(ctx, p);
                                }
                              : null,
                          style: p.disponible
                              ? null
                              : ElevatedButton.styleFrom(backgroundColor: kBorder),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _initialesWidget(String initiales) {
    return Center(
      child: Text(
        initiales.isEmpty ? '?' : initiales,
        style: const TextStyle(
            color: Colors.white, fontSize: 26, fontWeight: FontWeight.w700),
      ),
    );
  }
}

// ── Badge d'info (disponibilité, note) ───────────────────────────────────
class _InfoBadge extends StatelessWidget {
  final IconData icon;
  final String   label;
  final Color    color;
  final Color    bg;

  const _InfoBadge({
    required this.icon,
    required this.label,
    required this.color,
    required this.bg,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(label,
              style: TextStyle(
                  fontSize: 12, color: color, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

// ── Section avec titre et contenu ────────────────────────────────────────
class _Section extends StatelessWidget {
  final String titre;
  final Widget child;

  const _Section({required this.titre, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            titre,
            style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: kTextPrimary),
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}

// ── Ligne d'info avec icône ───────────────────────────────────────────────
class _LigneInfo extends StatelessWidget {
  final IconData icon;
  final String   texte;

  const _LigneInfo({required this.icon, required this.texte});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(icon, size: 16, color: kOrange),
          const SizedBox(width: 10),
          Expanded(
            child: Text(texte,
                style: const TextStyle(fontSize: 13, color: kTextGray)),
          ),
        ],
      ),
    );
  }
}

// ── Bottom sheet : formulaire de demande enrichi ─────────────────────────
// Le client peut préciser un titre, son adresse et marquer l'urgence.
// Tous ces champs sont transmis à l'API Django qui les stocke.
class _FormulaireDedemande extends StatefulWidget {
  final ApiClient   api;
  final Prestataire prestataire;

  const _FormulaireDedemande({required this.api, required this.prestataire});

  @override
  State<_FormulaireDedemande> createState() => _FormulaireDedemendeState();
}

class _FormulaireDedemendeState extends State<_FormulaireDedemande> {
  final _titreCtrl       = TextEditingController();
  final _descriptionCtrl = TextEditingController();
  final _adresseCtrl     = TextEditingController();

  bool   _urgence = false; // demande urgente → prestataire averti en priorité
  bool   _envoi   = false;
  bool   _succes  = false;
  String _erreur  = '';

  @override
  void dispose() {
    // Libérer les contrôleurs dès que le bottom sheet se ferme
    _titreCtrl.dispose();
    _descriptionCtrl.dispose();
    _adresseCtrl.dispose();
    super.dispose();
  }

  Future<void> _envoyer() async {
    // La description est le seul champ obligatoire
    if (_descriptionCtrl.text.trim().isEmpty) {
      setState(() => _erreur = 'Décris ce dont tu as besoin');
      return;
    }

    setState(() { _envoi = true; _erreur = ''; });

    try {
      await widget.api.envoyerDemande(
        prestataireId: widget.prestataire.id,
        description:   _descriptionCtrl.text.trim(),
        // Champs optionnels — on n'envoie que s'ils sont remplis
        titre:   _titreCtrl.text.trim().isEmpty   ? null : _titreCtrl.text.trim(),
        adresse: _adresseCtrl.text.trim().isEmpty ? null : _adresseCtrl.text.trim(),
        urgence: _urgence,
      );

      setState(() { _succes = true; _envoi = false; });

      // Fermeture automatique 2s après le succès — l'utilisateur voit le ✓
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) Navigator.pop(context);
      });

    } on DioException catch (e) {
      // On extrait le message d'erreur de la réponse Django si disponible
      String msg = 'Erreur lors de l\'envoi';
      if (e.response?.data is Map) {
        msg = (e.response!.data as Map).values.first?.toString() ?? msg;
      } else if (e.type == DioExceptionType.connectionError) {
        msg = 'Pas de connexion réseau';
      }
      setState(() { _erreur = msg; _envoi = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      // SingleChildScrollView pour que le formulaire ne soit pas coupé
      // quand le clavier est ouvert sur les petits écrans
      child: SingleChildScrollView(
        padding: EdgeInsets.only(
          left: 20, right: 20, top: 20,
          bottom: MediaQuery.of(context).viewInsets.bottom + 28,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            // Poignée de glissement
            Center(
              child: Container(
                width: 36, height: 4,
                decoration: BoxDecoration(
                  color: kBorder,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 18),

            // En-tête
            Row(
              children: [
                Container(
                  width: 40, height: 40,
                  decoration: const BoxDecoration(color: kOrangeLight, shape: BoxShape.circle),
                  child: const Icon(Icons.send_rounded, color: kOrange, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Demande à ${widget.prestataire.nomComplet}',
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: kTextPrimary),
                        overflow: TextOverflow.ellipsis,
                      ),
                      const Text('Il te répondra dans les plus brefs délais',
                          style: TextStyle(fontSize: 12, color: kTextGray)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // ── Message de succès ────────────────────────────────────────
            if (_succes)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: kGreenLight, borderRadius: BorderRadius.circular(14)),
                child: const Row(
                  children: [
                    Icon(Icons.check_circle_rounded, color: kGreen, size: 22),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Demande envoyée avec succès !\nLe prestataire va te contacter bientôt.',
                        style: TextStyle(color: kGreen, fontSize: 13, height: 1.5),
                      ),
                    ),
                  ],
                ),
              )

            // ── Formulaire ───────────────────────────────────────────────
            else ...[

              // Titre de la demande (optionnel mais aide le prestataire)
              const Text('Objet', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: kTextPrimary)),
              const SizedBox(height: 8),
              TextField(
                controller: _titreCtrl,
                textInputAction: TextInputAction.next,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  hintText: 'Ex: Fuite d\'eau, prise électrique, peinture…',
                  prefixIcon: Icon(Icons.title_rounded, size: 20, color: kTextGray),
                ),
              ),
              const SizedBox(height: 14),

              // Description détaillée — champ obligatoire
              const Text('Description *', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: kTextPrimary)),
              const SizedBox(height: 4),
              const Text('Explique le problème en détail', style: TextStyle(fontSize: 12, color: kTextGray)),
              const SizedBox(height: 8),
              TextField(
                controller: _descriptionCtrl,
                maxLines: 4,
                textCapitalization: TextCapitalization.sentences,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  hintText: 'Ex: J\'ai une fuite sous l\'évier de la cuisine, l\'eau coule depuis ce matin. Besoin d\'une intervention rapide.',
                ),
              ),
              const SizedBox(height: 14),

              // Adresse (optionnelle — utile pour les déplacements)
              const Text('Adresse d\'intervention', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: kTextPrimary)),
              const SizedBox(height: 8),
              TextField(
                controller: _adresseCtrl,
                textInputAction: TextInputAction.done,
                textCapitalization: TextCapitalization.sentences,
                onSubmitted: (_) => _envoyer(),
                decoration: const InputDecoration(
                  hintText: 'Quartier, rue, bâtiment… (optionnel)',
                  prefixIcon: Icon(Icons.place_outlined, size: 20, color: kTextGray),
                ),
              ),
              const SizedBox(height: 16),

              // Toggle urgence — fond rouge si activé
              GestureDetector(
                onTap: () => setState(() => _urgence = !_urgence),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: _urgence ? kRedLight : kBackground,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: _urgence ? kRed : kBorder),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.bolt_rounded, color: _urgence ? kRed : kTextGray, size: 22),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Demande urgente',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: _urgence ? kRed : kTextPrimary,
                                )),
                            Text(
                              _urgence
                                  ? 'Le prestataire est averti en priorité'
                                  : 'Coche si tu as besoin d\'une intervention rapide',
                              style: TextStyle(fontSize: 11, color: _urgence ? kRed : kTextGray),
                            ),
                          ],
                        ),
                      ),
                      Switch(
                        value: _urgence,
                        onChanged: (v) => setState(() => _urgence = v),
                        activeThumbColor: kRed,
                      ),
                    ],
                  ),
                ),
              ),

              // Message d'erreur
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

              // Bouton d'envoi
              ElevatedButton.icon(
                onPressed: _envoi ? null : _envoyer,
                icon: _envoi
                    ? const SizedBox(
                        width: 18, height: 18,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Icon(Icons.send_rounded, size: 18),
                label: Text(_envoi ? 'Envoi en cours…' : 'Envoyer la demande'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ── Section avis du prestataire ───────────────────────────────────────────
class _SectionAvis extends StatefulWidget {
  final int    prestataireId;
  final String prestataireUuid;
  final int    nbAvis;

  const _SectionAvis({
    required this.prestataireId,
    required this.prestataireUuid,
    required this.nbAvis,
  });

  @override
  State<_SectionAvis> createState() => _SectionAvisState();
}

class _SectionAvisState extends State<_SectionAvis> {
  final _api             = ApiClient();
  List<Avis> _avis       = [];
  bool       _chargement = true;
  bool       _tousAffiches = false;   // "Voir tous" expand
  Demande?   _demandeEligible;

  @override
  void initState() {
    super.initState();
    _charger();
    _chargerDemandeEligible(); // cherche si le client peut laisser un avis
  }

  Future<void> _charger() async {
    try {
      final data = await _api.getAvis(widget.prestataireId);
      if (!mounted) return;
      setState(() {
        _avis       = data.map((j) => Avis.fromJson(Map<String, dynamic>.from(j))).toList();
        _chargement = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _chargement = false);
    }
  }

  // Charge les demandes du client et cherche une demande terminée
  // pour ce prestataire qui n'a pas encore d'avis
  Future<void> _chargerDemandeEligible() async {
    try {
      final donnees = await _api.getMesDemandes();
      if (!mounted) return;
      final demandes = donnees
          .map((j) => Demande.fromJson(Map<String, dynamic>.from(j as Map)))
          .toList();
      final eligibles = demandes.where(
        (d) => d.prestataireUuid == widget.prestataireUuid && d.peutLaisserAvis,
      ).toList();
      if (mounted) {
        setState(() =>
            _demandeEligible = eligibles.isNotEmpty ? eligibles.first : null);
      }
    } catch (_) {
      // Silencieux — pas de token (prestataire/admin) ou pas de demandes
    }
  }

  void _ouvrirFormulaireAvis() {
    if (_demandeEligible == null) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _FormulaireAvis(
        api:       _api,
        demandeId: _demandeEligible!.id,
        onSuccess: () {
          // Cache le bouton + rafraîchit la liste
          setState(() => _demandeEligible = null);
          _charger();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_chargement) {
      return const SizedBox(
        height: 60,
        child: Center(child: CircularProgressIndicator(color: kOrange, strokeWidth: 2)),
      );
    }

    return _Section(
      titre: 'Avis (${_avis.length})',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Bannière "Laisser un avis" si demande éligible ─────────────
          if (_demandeEligible != null) ...[
            GestureDetector(
              onTap: _ouvrirFormulaireAvis,
              child: Container(
                margin: const EdgeInsets.only(bottom: 14),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: kOrangeLight,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: kOrange.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 36, height: 36,
                      decoration: const BoxDecoration(
                        color: kOrange, shape: BoxShape.circle),
                      child: const Icon(Icons.star_rounded,
                          color: Colors.white, size: 20),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Laisser un avis',
                              style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: kTextPrimary)),
                          SizedBox(height: 2),
                          Text('Tu as fait appel à ce prestataire — partage ton expérience',
                              style: TextStyle(fontSize: 11, color: kTextGray)),
                        ],
                      ),
                    ),
                    const Icon(Icons.chevron_right_rounded, color: kOrange),
                  ],
                ),
              ),
            ),
          ],

          // ── Liste des avis ─────────────────────────────────────────────
          if (_avis.isEmpty)
            const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Text('Aucun avis pour l\'instant',
                    style: TextStyle(fontSize: 13, color: kTextGray)),
              ),
            )
          else ...[
            ...(_tousAffiches ? _avis : _avis.take(3)).map((a) => _CarteAvis(avis: a)),
            if (_avis.length > 3)
              TextButton(
                onPressed: () => setState(() => _tousAffiches = !_tousAffiches),
                child: Text(
                  _tousAffiches ? 'Réduire' : 'Voir les ${_avis.length} avis',
                  style: const TextStyle(color: kOrange, fontWeight: FontWeight.w600, fontSize: 13),
                ),
              ),
          ],
        ],
      ),
    );
  }
}

// ── Carte d'un avis ───────────────────────────────────────────────────────
class _CarteAvis extends StatelessWidget {
  final Avis avis;

  const _CarteAvis({required this.avis});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Avatar client
          Container(
            width: 34, height: 34,
            decoration: const BoxDecoration(color: kOrangeLight, shape: BoxShape.circle),
            child: Center(child: Text(avis.initiales,
                style: const TextStyle(color: kOrange, fontWeight: FontWeight.w700, fontSize: 13))),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(child: Text(avis.nomComplet,
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: kTextPrimary))),
                    // Étoiles
                    Row(
                      children: List.generate(5, (i) => Icon(
                        i < avis.note ? Icons.star_rounded : Icons.star_outline_rounded,
                        size: 13, color: kYellow,
                      )),
                    ),
                  ],
                ),
                if (avis.commentaire.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 3),
                    child: Text(avis.commentaire,
                        style: const TextStyle(fontSize: 12, color: kTextGray, height: 1.4)),
                  ),
                Padding(
                  padding: const EdgeInsets.only(top: 3),
                  child: Text(avis.dateFormatee,
                      style: const TextStyle(fontSize: 11, color: kBorder)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Bottom sheet : formulaire d'avis ──────────────────────────────────────
class _FormulaireAvis extends StatefulWidget {
  final ApiClient api;
  final int       demandeId;
  final VoidCallback onSuccess;

  const _FormulaireAvis({
    required this.api,
    required this.demandeId,
    required this.onSuccess,
  });

  @override
  State<_FormulaireAvis> createState() => _FormulaireAvisState();
}

class _FormulaireAvisState extends State<_FormulaireAvis> {
  final _commentaireCtrl = TextEditingController();
  int    _note      = 0;   // 0 = aucune étoile sélectionnée
  bool   _envoi     = false;
  String _erreur    = '';

  @override
  void dispose() {
    _commentaireCtrl.dispose();
    super.dispose();
  }

  Future<void> _envoyer() async {
    if (_note == 0) {
      setState(() => _erreur = 'Sélectionne une note de 1 à 5 étoiles');
      return;
    }

    setState(() { _envoi = true; _erreur = ''; });

    try {
      await widget.api.laisserAvis(
        demandeId:    widget.demandeId,
        note:         _note,
        commentaire:  _commentaireCtrl.text.trim(),
      );
      if (mounted) {
        Navigator.pop(context);
        widget.onSuccess();
      }
    } on DioException catch (e) {
      String msg = 'Erreur lors de l\'envoi';
      if (e.response?.data is Map) {
        final d = e.response!.data as Map;
        msg = d['detail']?.toString() ??
            d['non_field_errors']?.toString() ??
            d.values.firstWhere((v) => v != null, orElse: () => null)?.toString() ??
            msg;
      }
      if (mounted) setState(() { _erreur = msg; _envoi = false; });
    } finally {
      // Remet _envoi à false uniquement si pas déjà fait par le catch
      if (mounted && _envoi) setState(() => _envoi = false);
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
          // Poignée de glissement
          Center(
            child: Container(
              width: 36, height: 4,
              decoration: BoxDecoration(
                  color: kBorder, borderRadius: BorderRadius.circular(2)),
            ),
          ),
          const SizedBox(height: 16),

          const Text('Laisser un avis',
              style: TextStyle(
                  fontSize: 16, fontWeight: FontWeight.w700, color: kTextPrimary)),
          const SizedBox(height: 4),
          const Text('Ton avis aide la communauté à trouver les meilleurs prestataires',
              style: TextStyle(fontSize: 12, color: kTextGray)),
          const SizedBox(height: 20),

          // ── Sélection des étoiles ────────────────────────────────────
          const Text('Note *',
              style: TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w600, color: kTextPrimary)),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(5, (i) {
              final etoile = i + 1;
              return GestureDetector(
                onTap: () => setState(() => _note = etoile),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: Icon(
                    etoile <= _note
                        ? Icons.star_rounded
                        : Icons.star_outline_rounded,
                    size: 38,
                    color: etoile <= _note ? kYellow : kBorder,
                  ),
                ),
              );
            }),
          ),
          if (_note > 0) ...[
            const SizedBox(height: 6),
            Center(
              child: Text(
                ['', 'Très mauvais', 'Mauvais', 'Correct', 'Bien', 'Excellent'][_note],
                style: const TextStyle(
                    fontSize: 13, color: kOrange, fontWeight: FontWeight.w600),
              ),
            ),
          ],

          const SizedBox(height: 16),

          // ── Commentaire ──────────────────────────────────────────────
          const Text('Commentaire',
              style: TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w600, color: kTextPrimary)),
          const SizedBox(height: 8),
          TextField(
            controller: _commentaireCtrl,
            maxLines: 3,
            textInputAction: TextInputAction.done,
            decoration: const InputDecoration(
              hintText: 'Décris ton expérience avec ce prestataire…',
            ),
          ),

          // ── Message d'erreur ─────────────────────────────────────────
          if (_erreur.isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                  color: kRedLight, borderRadius: BorderRadius.circular(10)),
              child: Row(
                children: [
                  const Icon(Icons.error_outline, size: 15, color: kRed),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(_erreur,
                        style: const TextStyle(fontSize: 12, color: kRed)),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 20),

          // ── Bouton Publier ───────────────────────────────────────────
          ElevatedButton(
            onPressed: _envoi ? null : _envoyer,
            child: _envoi
                ? const SizedBox(
                    width: 22, height: 22,
                    child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2.5))
                : const Text('Publier mon avis'),
          ),
        ],
      ),
    );
  }
}
