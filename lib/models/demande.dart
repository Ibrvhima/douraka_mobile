// Représente une demande de service envoyée par un client à un prestataire.
// La structure JSON suit le DemandeSerializer Django, qui embarque deux sous-objets :
// 'prestataire_info' (le profil artisan complet) et 'client_info' (les infos du demandeur).
// Cette double inclusion évite des appels supplémentaires côté mobile.

class Demande {
  final int     id;
  final String  description;
  final String? titre;
  // Statut brut (snake_case) — on s'en sert pour la logique métier
  final String  statut;
  // Libellé lisible venant de get_statut_display() Django — utile pour l'affichage
  final String? statutDisplay;
  final String  createdAt;

  // Infos extraites de prestataire_info — on les aplatit ici pour ne pas
  // avoir à naviguer dans des maps imbriquées partout dans l'UI
  final String? prestataireNom;
  final String? prestatairePrenom;
  final String? categorieNom;
  final String? prestataireUuid;
  final int?    prestataireId;

  // Infos client issues de client_info — utilisées principalement côté prestataire
  // pour savoir qui a fait la demande sans appel supplémentaire
  final String? clientNom;
  final String? clientPrenom;
  final int?    clientId;

  // Le devis est embarqué directement dans la réponse quand il existe,
  // ce qui permet d'afficher son montant sans endpoint séparé
  final bool   hasAvis;
  final bool   hasDevis;
  final Map<String, dynamic>? devis;

  final String? adresse;
  final bool    urgence;

  Demande({
    required this.id,
    required this.description,
    this.titre,
    required this.statut,
    this.statutDisplay,
    required this.createdAt,
    this.prestataireNom,
    this.prestatairePrenom,
    this.categorieNom,
    this.prestataireUuid,
    this.prestataireId,
    this.clientNom,
    this.clientPrenom,
    this.clientId,
    this.hasAvis = false,
    this.hasDevis = false,
    this.devis,
    this.adresse,
    this.urgence = false,
  });

  factory Demande.fromJson(Map<String, dynamic> json) {
    // prestataire_info est un objet imbriqué — on vérifie que c'est bien un Map
    // avant de le lire, car certains endpoints allégés renvoient juste l'id entier.
    final prestaInfo = json['prestataire_info'];
    String? nom, prenom, categorie, uuid;
    int? prestId;

    if (prestaInfo is Map) {
      // nom/prenom vivent dans le sous-objet 'user' du profil prestataire
      final user = prestaInfo['user'];
      if (user is Map) {
        nom    = user['nom']?.toString();
        prenom = user['prenom']?.toString();
      }
      final cat = prestaInfo['categorie'];
      if (cat is Map) categorie = cat['nom']?.toString();
      uuid   = prestaInfo['uuid']?.toString();
      prestId = prestaInfo['id'] is int
          ? prestaInfo['id'] as int
          : int.tryParse(prestaInfo['id']?.toString() ?? '');
    }

    // client_info suit la même structure — on l'exploite surtout dans la vue prestataire
    final clientInfo = json['client_info'];
    String? clientNom, clientPrenom;
    int? clientId;
    if (clientInfo is Map) {
      clientNom    = clientInfo['nom']?.toString();
      clientPrenom = clientInfo['prenom']?.toString();
      clientId     = clientInfo['id'] is int
          ? clientInfo['id'] as int
          : int.tryParse(clientInfo['id']?.toString() ?? '');
    }

    // Le devis est optionnel — on fait un Map.from pour avoir un vrai
    // Map<String,dynamic> typé plutôt que de garder le _InternalLinkedHashMap de dart:convert
    final devisRaw = json['devis'];
    Map<String, dynamic>? devis;
    if (devisRaw is Map) {
      devis = Map<String, dynamic>.from(devisRaw);
    }

    return Demande(
      id: json['id'] is int
          ? json['id'] as int
          : int.tryParse(json['id']?.toString() ?? '') ?? 0,
      description:       json['description']?.toString() ?? '',
      titre:             json['titre']?.toString(),
      statut:            json['statut']?.toString() ?? 'en_attente',
      statutDisplay:     json['statut_display']?.toString(),
      // Le serializer Django utilise 'date_creation' (champ du modèle),
      // pas 'created_at' — on accepte les deux pour rester compatible
      // avec d'éventuels endpoints plus anciens.
      createdAt:         json['date_creation']?.toString() ??
                         json['created_at']?.toString() ?? '',
      prestataireNom:    nom,
      prestatairePrenom: prenom,
      categorieNom:      categorie,
      prestataireUuid:   uuid,
      prestataireId:     prestId,
      clientNom:         clientNom,
      clientPrenom:      clientPrenom,
      clientId:          clientId,
      hasAvis:           json['has_avis'] == true,
      hasDevis:          json['has_devis'] == true,
      devis:             devis,
      adresse:           json['adresse']?.toString(),
      urgence:           json['urgence'] == true,
    );
  }

  // Priorité au libellé Django (get_statut_display) qui est déjà localisé ;
  // le switch ne sert que de filet de sécurité si statutDisplay est absent.
  String get statutLabel {
    if (statutDisplay != null && statutDisplay!.isNotEmpty) return statutDisplay!;
    switch (statut) {
      case 'acceptee':   return 'Acceptée';
      case 'refusee':    return 'Refusée';
      case 'terminee':   return 'Terminée';
      case 'annulee':    return 'Annulée';
      case 'en_cours':   return 'En cours';
      default:           return 'En attente';
    }
  }

  // Fallback explicite pour éviter un champ vide dans l'UI si le prestataire n'est pas chargé
  String get prestataireNomComplet {
    final n = prestataireNom ?? '';
    final p = prestatairePrenom ?? '';
    final nom = '$n $p'.trim();
    return nom.isEmpty ? 'Prestataire' : nom;
  }

  String get clientNomComplet {
    final n = clientNom ?? '';
    final p = clientPrenom ?? '';
    final nom = '$n $p'.trim();
    return nom.isEmpty ? 'Client' : nom;
  }

  // On parse la date ISO 8601 renvoyée par Django et on la convertit
  // en heure locale avant de formater — important pour les utilisateurs en GMT
  String get dateFormatee {
    try {
      final dt = DateTime.parse(createdAt).toLocal();
      const mois = ['jan', 'fév', 'mar', 'avr', 'mai', 'juin',
                    'juil', 'août', 'sep', 'oct', 'nov', 'déc'];
      return '${dt.day} ${mois[dt.month - 1]} ${dt.year}';
    } catch (_) {
      return createdAt;
    }
  }

  // Une demande refusée, terminée ou annulée ne peut plus être annulée
  bool get peutAnnuler =>
      statut == 'en_attente' || statut == 'acceptee';

  // L'avis n'est possible qu'une seule fois par demande terminée — has_avis
  // vient du serializer pour éviter un appel supplémentaire
  bool get peutLaisserAvis => statut == 'terminee' && !hasAvis;
}
