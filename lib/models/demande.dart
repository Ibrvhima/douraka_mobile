// Le DemandeSerializer Django embarque prestataire_info et client_info en sous-objets
// pour éviter des appels supplémentaires côté mobile. On aplatit ici pour ne pas
// naviguer dans des maps imbriquées dans toute l'UI.

class Demande {
  final int     id;
  final String  description;
  final String? titre;
  // statut sans accent côté Django — 'acceptee' et pas 'acceptée', vérifié dans les migrations
  final String  statut;
  final String? statutDisplay;
  final String  createdAt;

  final String? prestataireNom;
  final String? prestatairePrenom;
  final String? categorieNom;
  final String? prestataireUuid;
  final int?    prestataireId;

  // Infos client issues de client_info — utiles côté prestataire sans appel supplémentaire
  final String? clientNom;
  final String? clientPrenom;
  final int?    clientId;

  // Le devis est embarqué directement dans la réponse quand il existe
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
    // prestataire_info est un objet imbriqué — certains endpoints allégés renvoient juste l'id entier
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

    // Map.from pour avoir un vrai Map<String,dynamic> typé
    // plutôt que le _InternalLinkedHashMap de dart:convert
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
      // Le serializer utilise 'date_creation' — on accepte 'created_at' aussi
      // pour rester compatible avec d'éventuels anciens endpoints.
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

  // Priorité au libellé Django (get_statut_display) déjà localisé ;
  // le switch ne sert que de filet si statutDisplay est absent.
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

  // Django renvoie ISO 8601 — on convertit en heure locale avant de formater
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

  bool get peutAnnuler =>
      statut == 'en_attente' || statut == 'acceptee';

  // has_avis vient du serializer pour éviter un appel supplémentaire
  bool get peutLaisserAvis => statut == 'terminee' && !hasAvis;
}
