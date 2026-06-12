import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import '../core/api_client.dart';
import '../models/demande.dart';
import '../theme.dart';
import '../widgets/appbar_actions.dart';
import 'chat/chat_screen.dart';

// Espace CLIENT — liste de ses demandes envoyées
// Actions possibles : voir devis, accepter/refuser devis, laisser un avis, annuler

class MesDemandesScreen extends StatefulWidget {
  const MesDemandesScreen({super.key});

  @override
  State<MesDemandesScreen> createState() => _MesDemandesScreenState();
}

class _MesDemandesScreenState extends State<MesDemandesScreen>
    with SingleTickerProviderStateMixin {
  final _api = ApiClient();
  List<Demande> _demandes   = [];
  bool          _chargement = true;
  bool          _erreur     = false;
  late TabController _tabCtrl;

  static const _onglets = [
    (label: 'Toutes',    statut: ''),
    (label: 'En attente', statut: 'en_attente'),
    (label: 'En cours',  statut: 'acceptee'),
    (label: 'Terminées', statut: 'terminee'),
  ];

  List<Demande> _filtreParOnglet(String statut) {
    if (statut.isEmpty) return _demandes;
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
      final donnees = await _api.getMesDemandes();
      if (!mounted) return;
      setState(() {
        _demandes = donnees
            .map((j) => Demande.fromJson(Map<String, dynamic>.from(j)))
            .toList();
        _chargement = false;
      });
    } catch (e) {
      debugPrint('Erreur chargement demandes: $e');
      if (!mounted) return;
      setState(() { _chargement = false; _erreur = true; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBackground,
      appBar: AppBar(
        title: const Text('Mes demandes'),
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
                  if (!_chargement && count > 0) ...[
                    const SizedBox(width: 5),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                      decoration: BoxDecoration(color: kOrangeLight, borderRadius: BorderRadius.circular(10)),
                      child: Text('$count', style: const TextStyle(fontSize: 10, color: kOrange, fontWeight: FontWeight.w700)),
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
          demandes: _filtreParOnglet(o.statut),
          chargement: _chargement,
          erreur: _erreur,
          onRetry: _charger,
          api: _api,
          onActionDone: _charger,
        )).toList(),
      ),
    );
  }

}

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
          TextButton.icon(onPressed: onRetry,
              icon: const Icon(Icons.refresh, color: kOrange),
              label: const Text('Réessayer', style: TextStyle(color: kOrange))),
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
              child: const Icon(Icons.assignment_outlined, size: 34, color: kOrange),
            ),
            const SizedBox(height: 16),
            const Text('Aucune demande ici',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: kTextPrimary)),
            const SizedBox(height: 6),
            const Text('Cherche un prestataire sur l\'accueil\net envoie ta première demande',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: kTextGray, height: 1.5)),
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
        itemBuilder: (_, i) => _CarteDemande(demande: demandes[i], api: api, onActionDone: onActionDone),
      ),
    );
  }
}

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

  IconData get _iconeStatut {
    switch (demande.statut) {
      case 'acceptee':  return Icons.check_circle_outline_rounded;
      case 'en_cours':  return Icons.handyman_outlined;
      case 'refusee':   return Icons.cancel_outlined;
      case 'annulee':   return Icons.cancel_outlined;
      case 'terminee':  return Icons.task_alt_rounded;
      default:          return Icons.access_time_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 8, offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
            child: Row(
              children: [
                Container(
                  width: 40, height: 40,
                  decoration: const BoxDecoration(color: kOrangeLight, shape: BoxShape.circle),
                  child: Center(
                    child: Text(
                      _initiales(demande.prestataireNom, demande.prestatairePrenom),
                      style: const TextStyle(color: kOrange, fontWeight: FontWeight.w700, fontSize: 14),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(demande.prestataireNomComplet,
                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: kTextPrimary)),
                      if (demande.categorieNom != null)
                        Text(demande.categorieNom!,
                            style: const TextStyle(fontSize: 12, color: kOrange, fontWeight: FontWeight.w500)),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(color: _bgStatut, borderRadius: BorderRadius.circular(20)),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(_iconeStatut, size: 11, color: _couleurStatut),
                      const SizedBox(width: 4),
                      Text(demande.statutLabel,
                          style: TextStyle(fontSize: 11, color: _couleurStatut, fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const Divider(height: 1, color: kBorder),

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
                    maxLines: 2, overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 13, color: kTextGray)),
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Icon(Icons.calendar_today_outlined, size: 12, color: kTextGray),
                    const SizedBox(width: 4),
                    Text(demande.dateFormatee, style: const TextStyle(fontSize: 11, color: kTextGray)),
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

          if (demande.hasDevis && demande.devis != null) ...[
            const Divider(height: 1, color: kBorder),
            _SectionDevis(demande: demande, api: api, onActionDone: onActionDone),
          ],

          if (demande.statut != 'annulee' && demande.statut != 'en_attente') ...[
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

          if (demande.peutLaisserAvis || demande.peutAnnuler) ...[
            const Divider(height: 1, color: kBorder),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: Row(
                children: [
                  if (demande.peutLaisserAvis)
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.star_outline_rounded, size: 16, color: kOrange),
                        label: const Text('Laisser un avis',
                            style: TextStyle(color: kOrange, fontSize: 12)),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: kOrange),
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        onPressed: () => _ouvrirFormulaireAvis(context, api),
                      ),
                    ),
                  if (demande.peutLaisserAvis && demande.peutAnnuler)
                    const SizedBox(width: 8),
                  if (demande.peutAnnuler)
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.cancel_outlined, size: 16, color: kRed),
                        label: const Text('Annuler', style: TextStyle(color: kRed, fontSize: 12)),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: kRed),
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        onPressed: () => _confirmerAnnulation(context, api),
                      ),
                    ),
                ],
              ),
            ),
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
            autrePersonneNom: demande.prestataireNomComplet,
            autrePersonneInitiales:
                _initiales(demande.prestataireNom, demande.prestatairePrenom),
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

  void _ouvrirFormulaireAvis(BuildContext context, ApiClient api) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _FormulaireAvis(api: api, demande: demande, onEnvoi: onActionDone),
    );
  }

  Future<void> _confirmerAnnulation(BuildContext context, ApiClient api) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Annuler la demande',
            style: TextStyle(fontWeight: FontWeight.w700)),
        content: const Text('Veux-tu vraiment annuler cette demande ?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Non', style: TextStyle(color: kTextGray))),
          TextButton(onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Oui, annuler',
                  style: TextStyle(color: kRed, fontWeight: FontWeight.w600))),
        ],
      ),
    );
    if (ok == true) {
      try {
        await api.annulerDemande(demande.id);
        onActionDone();
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Impossible d\'annuler cette demande'),
                backgroundColor: kRed),
          );
        }
      }
    }
  }

  String _initiales(String? nom, String? prenom) {
    final n = nom?.isNotEmpty == true ? nom![0].toUpperCase() : '';
    final p = prenom?.isNotEmpty == true ? prenom![0].toUpperCase() : '';
    return '$n$p';
  }
}

class _SectionDevis extends StatefulWidget {
  final Demande      demande;
  final ApiClient    api;
  final VoidCallback onActionDone;

  const _SectionDevis({required this.demande, required this.api, required this.onActionDone});

  @override
  State<_SectionDevis> createState() => _SectionDevisState();
}

class _SectionDevisState extends State<_SectionDevis> {
  bool _chargement = false;

  Future<void> _action(Future<void> Function() action) async {
    setState(() => _chargement = true);
    try {
      await action();
      if (mounted) widget.onActionDone();
    } on DioException catch (e) {
      String msg = 'Erreur';
      if (e.response?.data is Map) {
        final d = e.response!.data as Map;
        msg = d['detail']?.toString() ?? d.values.first?.toString() ?? 'Erreur';
      }
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
    final devis  = widget.demande.devis!;
    final statut = devis['statut']?.toString() ?? '';
    final montant  = devis['montant']?.toString() ?? '';
    final desc     = devis['description']?.toString() ?? '';
    final devisId  = devis['id'] is int ? devis['id'] as int : int.tryParse(devis['id']?.toString() ?? '') ?? 0;
    final statutLabel = devis['statut_display']?.toString() ?? statut;

    Color couleur;
    switch (statut) {
      case 'accepte':  couleur = kGreen; break;
      case 'refuse':   couleur = kRed;   break;
      default:         couleur = kYellow;
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: kBackground,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: kBorder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.receipt_outlined, size: 16, color: kOrange),
                const SizedBox(width: 6),
                const Text('Devis reçu',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: kTextPrimary)),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: couleur.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(statutLabel,
                      style: TextStyle(fontSize: 11, color: couleur, fontWeight: FontWeight.w600)),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text('Montant : $montant GNF',
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: kTextPrimary)),
            if (desc.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(desc, style: const TextStyle(fontSize: 13, color: kTextGray)),
            ],
            if (devis['delai'] != null) ...[
              const SizedBox(height: 4),
              Text('Délai : ${devis['delai']}',
                  style: const TextStyle(fontSize: 12, color: kTextGray)),
            ],

            if (statut == 'en_attente') ...[
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _chargement ? null :
                          () => _action(() => widget.api.accepterDevis(devisId)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: kGreen,
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      child: _chargement
                          ? const SizedBox(width: 16, height: 16,
                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                          : const Text('Accepter', style: TextStyle(fontSize: 13)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _chargement ? null :
                          () => _action(() => widget.api.refuserDevis(devisId)),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: kRed),
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      child: const Text('Refuser', style: TextStyle(color: kRed, fontSize: 13)),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _FormulaireAvis extends StatefulWidget {
  final ApiClient    api;
  final Demande      demande;
  final VoidCallback onEnvoi;

  const _FormulaireAvis({required this.api, required this.demande, required this.onEnvoi});

  @override
  State<_FormulaireAvis> createState() => _FormulaireAvisState();
}

class _FormulaireAvisState extends State<_FormulaireAvis> {
  final _ctrl = TextEditingController();
  int    _note    = 5;
  bool   _envoi   = false;
  bool   _succes  = false;
  String _erreur  = '';

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _envoyer() async {
    if (_ctrl.text.trim().isEmpty) {
      setState(() => _erreur = 'Écris un commentaire');
      return;
    }
    setState(() { _envoi = true; _erreur = ''; });
    try {
      await widget.api.laisserAvis(
        demandeId: widget.demande.id,
        note: _note,
        commentaire: _ctrl.text.trim(),
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
          Center(
            child: Container(width: 36, height: 4,
                decoration: BoxDecoration(color: kBorder, borderRadius: BorderRadius.circular(2))),
          ),
          const SizedBox(height: 16),
          Text('Évaluer ${widget.demande.prestataireNomComplet}',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: kTextPrimary)),
          const SizedBox(height: 4),
          const Text('Partagez votre expérience pour aider les autres clients',
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
                  Expanded(child: Text('Avis envoyé ! Merci pour votre retour.',
                      style: TextStyle(color: kGreen, fontSize: 13))),
                ],
              ),
            )
          else ...[
            const Text('Note', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: kTextPrimary)),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(5, (i) => GestureDetector(
                onTap: () => setState(() => _note = i + 1),
                child: Icon(
                  i < _note ? Icons.star_rounded : Icons.star_outline_rounded,
                  size: 36,
                  color: kYellow,
                ),
              )),
            ),
            const SizedBox(height: 14),
            const Text('Commentaire', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: kTextPrimary)),
            const SizedBox(height: 8),
            TextField(
              controller: _ctrl,
              maxLines: 3,
              textInputAction: TextInputAction.done,
              decoration: const InputDecoration(
                hintText: 'Décrivez votre expérience avec ce prestataire…',
              ),
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
                  : const Text('Envoyer mon avis'),
            ),
          ],
        ],
      ),
    );
  }
}
