import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:dio/dio.dart';
import '../../core/api_client.dart';
import '../../models/demande.dart';
import '../../theme.dart';
import '../../widgets/appbar_actions.dart';
import '../chat/chat_screen.dart';

// Écran PRESTATAIRE — liste des demandes reçues de clients
// Actions : accepter, refuser, terminer, envoyer un devis

class DemandesRecuesScreen extends StatefulWidget {
  const DemandesRecuesScreen({super.key});

  @override
  State<DemandesRecuesScreen> createState() => _DemandesRecuesScreenState();
}

class _DemandesRecuesScreenState extends State<DemandesRecuesScreen>
    with SingleTickerProviderStateMixin {

  final _api    = ApiClient();
  List<Demande> _demandes   = [];
  bool          _chargement = true;
  bool          _erreur     = false;

  late TabController _tabCtrl;

  // Les 4 onglets — même structure que côté client pour la cohérence
  static const _onglets = [
    (label: 'Toutes',     statut: ''),
    (label: 'En attente', statut: 'en_attente'),
    (label: 'En cours',   statut: 'acceptee'),
    (label: 'Terminées',  statut: 'terminee'),
  ];

  // Filtre les demandes selon l'onglet actif
  List<Demande> _filtreParOnglet(String statut) {
    if (statut.isEmpty) return _demandes;
    // "En cours" regroupe les demandes acceptées et en cours de traitement
    if (statut == 'acceptee') {
      return _demandes.where((d) => d.statut == 'acceptee' || d.statut == 'en_cours').toList();
    }
    return _demandes.where((d) => d.statut == statut).toList();
  }

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: _onglets.length, vsync: this);
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
      final donnees = await _api.getMesDemandes(); // filtre par rôle côté Django
      if (!mounted) return;
      setState(() {
        _demandes = donnees
            .map((j) => Demande.fromJson(Map<String, dynamic>.from(j)))
            .toList();
        _chargement = false;
      });
    } catch (e) {
      debugPrint('Erreur demandes reçues: $e');
      if (!mounted) return;
      setState(() { _chargement = false; _erreur = true; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBackground,
      appBar: AppBar(
        title: const Text('Demandes reçues'),
        actions: [
          const AppBarActions(),
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _charger,
            tooltip: 'Actualiser',
          ),
        ],
        bottom: TabBar(
          controller: _tabCtrl,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          labelColor: kOrange,
          unselectedLabelColor: kTextGray,
          indicatorColor: kOrange,
          dividerColor: kBorder,
          labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          tabs: _onglets.map((o) {
            final count = _filtreParOnglet(o.statut).length;
            return Tab(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(o.label),
                  // Badge avec le nombre de demandes dans cet onglet
                  if (!_chargement && count > 0) ...[
                    const SizedBox(width: 5),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                      decoration: BoxDecoration(
                        color: kOrangeLight,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text('$count',
                          style: const TextStyle(fontSize: 10, color: kOrange, fontWeight: FontWeight.w700)),
                    ),
                  ],
                ],
              ),
            );
          }).toList(),
        ),
      ),
      body: TabBarView(
        controller: _tabCtrl,
        children: _onglets.map((o) => _ListeDemandes(
          demandes:     _filtreParOnglet(o.statut),
          chargement:   _chargement,
          erreur:       _erreur,
          onRetry:      _charger,
          api:          _api,
          onActionDone: _charger,
        )).toList(),
      ),
    );
  }

}

// ── Liste filtrée par onglet — réutilisée pour chaque tab ─────────────────
class _ListeDemandes extends StatelessWidget {
  final List<Demande> demandes;
  final bool          chargement;
  final bool          erreur;
  final VoidCallback  onRetry;
  final ApiClient     api;
  final VoidCallback  onActionDone;

  const _ListeDemandes({
    required this.demandes,
    required this.chargement,
    required this.erreur,
    required this.onRetry,
    required this.api,
    required this.onActionDone,
  });

  @override
  Widget build(BuildContext context) {
    if (chargement) {
      return const Center(child: CircularProgressIndicator(color: kOrange));
    }

    if (erreur) {
      return Center(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          const Icon(Icons.wifi_off_rounded, size: 52, color: kBorder),
          const SizedBox(height: 12),
          const Text('Problème de connexion', style: TextStyle(color: kTextGray)),
          const SizedBox(height: 16),
          TextButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh, color: kOrange),
            label: const Text('Réessayer', style: TextStyle(color: kOrange)),
          ),
        ]),
      );
    }

    if (demandes.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Container(
              width: 72, height: 72,
              decoration: const BoxDecoration(color: kOrangeLight, shape: BoxShape.circle),
              child: const Icon(Icons.inbox_outlined, size: 34, color: kOrange),
            ),
            const SizedBox(height: 16),
            const Text('Aucune demande ici',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: kTextPrimary)),
            const SizedBox(height: 6),
            const Text(
              'Active ta disponibilité et\nles clients pourront te contacter',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: kTextGray, height: 1.5),
            ),
          ]),
        ),
      );
    }

    return RefreshIndicator(
      color: kOrange,
      onRefresh: () async => onRetry(),
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        itemCount: demandes.length,
        itemBuilder: (_, i) => _CarteDemande(
          demande:      demandes[i],
          api:          api,
          onActionDone: onActionDone,
        ),
      ),
    );
  }
}

// ── Carte demande côté prestataire ────────────────────────────────────────
class _CarteDemande extends StatelessWidget {
  final Demande      demande;
  final ApiClient    api;
  final VoidCallback onActionDone;

  const _CarteDemande({required this.demande, required this.api, required this.onActionDone});

  Color get _couleurStatut {
    switch (demande.statut) {
      case 'acceptee':  return kGreen;
      case 'en_cours':  return kGreen;
      case 'refusee':   return kRed;
      case 'annulee':   return kRed;
      case 'terminee':  return kTextGray;
      default:          return kYellow;
    }
  }

  Color get _bgStatut {
    switch (demande.statut) {
      case 'acceptee':  return kGreenLight;
      case 'en_cours':  return kGreenLight;
      case 'refusee':   return kRedLight;
      case 'annulee':   return kRedLight;
      case 'terminee':  return const Color(0xFFF3F4F6);
      default:          return const Color(0xFFFEF9C3);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Column(
        children: [
          // En-tête : client + statut
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
            child: Row(
              children: [
                Container(
                  width: 40, height: 40,
                  decoration: const BoxDecoration(color: kOrangeLight, shape: BoxShape.circle),
                  child: Center(
                    child: Text(
                      _initialesClient(),
                      style: const TextStyle(color: kOrange, fontWeight: FontWeight.w700, fontSize: 14),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(demande.clientNomComplet,
                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: kTextPrimary)),
                      const Text('Client', style: TextStyle(fontSize: 12, color: kTextGray)),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(color: _bgStatut, borderRadius: BorderRadius.circular(20)),
                  child: Text(demande.statutLabel,
                      style: TextStyle(fontSize: 11, color: _couleurStatut, fontWeight: FontWeight.w600)),
                ),
              ],
            ),
          ),

          const Divider(height: 1, color: kBorder),

          // Contenu demande
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (demande.titre != null && demande.titre!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text(demande.titre!,
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: kTextPrimary)),
                  ),
                Text(demande.description,
                    maxLines: 3, overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 13, color: kTextGray)),
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Icon(Icons.calendar_today_outlined, size: 12, color: kTextGray),
                    const SizedBox(width: 4),
                    Text(demande.dateFormatee, style: const TextStyle(fontSize: 11, color: kTextGray)),
                    if (demande.adresse != null) ...[
                      const SizedBox(width: 8),
                      const Icon(Icons.place_outlined, size: 12, color: kTextGray),
                      const SizedBox(width: 2),
                      Flexible(child: Text(demande.adresse!,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 11, color: kTextGray))),
                    ],
                    if (demande.urgence) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(color: kRedLight, borderRadius: BorderRadius.circular(8)),
                        child: const Text('Urgent', style: TextStyle(fontSize: 10, color: kRed, fontWeight: FontWeight.w600)),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),

          // ── Bouton messagerie ────────────────────────────────────────────
          if (demande.statut != 'en_attente') ...[
            const Divider(height: 1, color: kBorder),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              child: SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.chat_bubble_outline_rounded,
                      size: 16, color: kOrange),
                  label: const Text('Messagerie',
                      style: TextStyle(color: kOrange, fontSize: 12)),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: kOrange),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: () => _ouvrirChat(context),
                ),
              ),
            ),
          ],

          // ── Actions prestataire ──────────────────────────────────────────
          if (demande.statut == 'en_attente') ...[
            const Divider(height: 1, color: kBorder),
            _ActionsEnAttente(demande: demande, api: api, onActionDone: onActionDone),
          ],

          if (demande.statut == 'acceptee' || demande.statut == 'en_cours') ...[
            const Divider(height: 1, color: kBorder),
            _ActionsEnCours(demande: demande, api: api, onActionDone: onActionDone),
          ],
        ],
      ),
    );
  }

  Future<void> _ouvrirChat(BuildContext context) async {
    try {
      final conv = await api.ouvrirConversation(demande.id);
      if (!context.mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ChatScreen(
            convId: (conv['id'] as num).toInt(),
            autrePersonneNom: demande.clientNomComplet,
            autrePersonneInitiales: _initialesClient(),
          ),
        ),
      );
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Impossible d\'ouvrir la messagerie'),
            backgroundColor: kRed,
          ),
        );
      }
    }
  }

  String _initialesClient() {
    final n = (demande.clientNom?.isNotEmpty == true) ? demande.clientNom![0].toUpperCase() : '';
    final p = (demande.clientPrenom?.isNotEmpty == true) ? demande.clientPrenom![0].toUpperCase() : '';
    return '$n$p';
  }
}

// ── Actions sur une demande en attente ────────────────────────────────────
class _ActionsEnAttente extends StatefulWidget {
  final Demande      demande;
  final ApiClient    api;
  final VoidCallback onActionDone;

  const _ActionsEnAttente({required this.demande, required this.api, required this.onActionDone});

  @override
  State<_ActionsEnAttente> createState() => _ActionsEnAttenteState();
}

class _ActionsEnAttenteState extends State<_ActionsEnAttente> {
  bool _chargement = false;

  Future<void> _executer(Future<void> Function() action) async {
    setState(() => _chargement = true);
    try {
      await action();
      widget.onActionDone();
    } on DioException catch (e) {
      final msg = (e.response?.data is Map)
          ? (e.response!.data as Map)['detail']?.toString() ?? 'Erreur'
          : 'Erreur lors de l\'action';
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg), backgroundColor: kRed),
        );
      }
    } finally {
      if (mounted) setState(() => _chargement = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          // Boutons Accepter / Refuser
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.check_rounded, size: 16),
                  label: const Text('Accepter', style: TextStyle(fontSize: 13)),
                  onPressed: _chargement ? null : () {
                      HapticFeedback.mediumImpact();
                      _executer(() => widget.api.accepterDemande(widget.demande.id));
                    },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: kGreen,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.close_rounded, size: 16, color: kRed),
                  label: const Text('Refuser', style: TextStyle(color: kRed, fontSize: 13)),
                  onPressed: _chargement ? null : () {
                      HapticFeedback.lightImpact();
                      _executer(() => widget.api.refuserDemande(widget.demande.id));
                    },
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: kRed),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Bouton envoyer un devis
          if (!widget.demande.hasDevis)
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                icon: const Icon(Icons.receipt_outlined, size: 16, color: kOrange),
                label: const Text('Envoyer un devis', style: TextStyle(color: kOrange, fontSize: 13)),
                onPressed: _chargement ? null : () => _ouvrirDevis(context),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: kOrange),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ),
          if (_chargement)
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: LinearProgressIndicator(color: kOrange, backgroundColor: kOrangeLight),
            ),
        ],
      ),
    );
  }

  void _ouvrirDevis(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _FormulaireDevis(
        api: widget.api,
        demandeId: widget.demande.id,
        clientNom: widget.demande.clientNomComplet,
        onEnvoi: widget.onActionDone,
      ),
    );
  }
}

// ── Actions sur une demande acceptée/en cours ─────────────────────────────
class _ActionsEnCours extends StatefulWidget {
  final Demande      demande;
  final ApiClient    api;
  final VoidCallback onActionDone;

  const _ActionsEnCours({required this.demande, required this.api, required this.onActionDone});

  @override
  State<_ActionsEnCours> createState() => _ActionsEnCoursState();
}

class _ActionsEnCoursState extends State<_ActionsEnCours> {
  bool _chargement = false;

  Future<void> _terminer() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Marquer comme terminée', style: TextStyle(fontWeight: FontWeight.w700)),
        content: const Text('Confirmes-tu que la prestation est terminée ?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Non', style: TextStyle(color: kTextGray))),
          TextButton(onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Oui, terminer',
                  style: TextStyle(color: kGreen, fontWeight: FontWeight.w600))),
        ],
      ),
    );

    if (ok != true) return;
    setState(() => _chargement = true);
    try {
      await widget.api.terminerDemande(widget.demande.id);
      if (mounted) widget.onActionDone();
    } on DioException catch (e) {
      final msg = (e.response?.data is Map)
          ? (e.response!.data as Map)['detail']?.toString() ?? 'Erreur'
          : 'Erreur';
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg), backgroundColor: kRed));
      }
    } finally {
      if (mounted) setState(() => _chargement = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          icon: const Icon(Icons.task_alt_rounded, size: 16),
          label: _chargement
              ? const SizedBox(width: 16, height: 16,
                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
              : const Text('Marquer comme terminée'),
          onPressed: _chargement ? null : _terminer,
          style: ElevatedButton.styleFrom(
            backgroundColor: kGreen,
            padding: const EdgeInsets.symmetric(vertical: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        ),
      ),
    );
  }
}

// ── Formulaire de devis ───────────────────────────────────────────────────
class _FormulaireDevis extends StatefulWidget {
  final ApiClient    api;
  final int          demandeId;
  final String       clientNom;
  final VoidCallback onEnvoi;

  const _FormulaireDevis({
    required this.api,
    required this.demandeId,
    required this.clientNom,
    required this.onEnvoi,
  });

  @override
  State<_FormulaireDevis> createState() => _FormulaireDevisState();
}

class _FormulaireDevisState extends State<_FormulaireDevis> {
  final _montantCtrl = TextEditingController();
  final _descCtrl    = TextEditingController();
  final _delaiCtrl   = TextEditingController();

  bool   _envoi  = false;
  bool   _succes = false;
  String _erreur = '';

  @override
  void dispose() {
    _montantCtrl.dispose();
    _descCtrl.dispose();
    _delaiCtrl.dispose();
    super.dispose();
  }

  Future<void> _envoyer() async {
    if (_montantCtrl.text.trim().isEmpty || _descCtrl.text.trim().isEmpty) {
      setState(() => _erreur = 'Remplis le montant et la description');
      return;
    }
    setState(() { _envoi = true; _erreur = ''; });
    try {
      await widget.api.creerDevis(
        demandeId:   widget.demandeId,
        montant:     _montantCtrl.text.trim(),
        description: _descCtrl.text.trim(),
        delai:       _delaiCtrl.text.trim(),
      );
      setState(() { _succes = true; _envoi = false; });
      widget.onEnvoi();
    } on DioException catch (e) {
      String msg = 'Erreur lors de l\'envoi';
      if (e.response?.data is Map) {
        final d = e.response!.data as Map;
        final first = d['detail'] ?? d.values.firstWhere((v) => v != null, orElse: () => null);
        msg = first is List ? first.first.toString() : first?.toString() ?? msg;
      }
      if (mounted) setState(() { _erreur = msg; _envoi = false; });
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
          Center(child: Container(width: 36, height: 4,
              decoration: BoxDecoration(color: kBorder, borderRadius: BorderRadius.circular(2)))),
          const SizedBox(height: 16),
          Text('Devis pour ${widget.clientNom}',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: kTextPrimary)),
          const SizedBox(height: 4),
          const Text('Le client recevra une notification',
              style: TextStyle(fontSize: 12, color: kTextGray)),
          const SizedBox(height: 16),

          if (_succes)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: kGreenLight, borderRadius: BorderRadius.circular(12)),
              child: const Row(
                children: [
                  Icon(Icons.check_circle_rounded, color: kGreen, size: 20),
                  SizedBox(width: 10),
                  Expanded(child: Text('Devis envoyé ! Le client va le recevoir.',
                      style: TextStyle(color: kGreen, fontSize: 13))),
                ],
              ),
            )
          else ...[
            // Montant
            const Text('Montant (GNF) *',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: kTextPrimary)),
            const SizedBox(height: 8),
            TextField(
              controller: _montantCtrl,
              keyboardType: TextInputType.number,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(hintText: 'Ex: 500000'),
            ),
            const SizedBox(height: 12),

            // Description
            const Text('Description *',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: kTextPrimary)),
            const SizedBox(height: 8),
            TextField(
              controller: _descCtrl,
              maxLines: 3,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(hintText: 'Détails de la prestation proposée…'),
            ),
            const SizedBox(height: 12),

            // Délai
            const Text('Délai estimé',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: kTextPrimary)),
            const SizedBox(height: 8),
            TextField(
              controller: _delaiCtrl,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _envoyer(),
              decoration: const InputDecoration(hintText: 'Ex: 2 jours, 1 semaine…'),
            ),

            if (_erreur.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(_erreur, style: const TextStyle(color: kRed, fontSize: 12)),
            ],
            const SizedBox(height: 14),
            ElevatedButton(
              onPressed: _envoi ? null : _envoyer,
              child: _envoi
                  ? const SizedBox(width: 20, height: 20,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Text('Envoyer le devis'),
            ),
          ],
        ],
      ),
    );
  }
}
