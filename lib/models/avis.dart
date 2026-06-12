// Représente un avis laissé par un client sur un prestataire après une demande terminée.
// Le serializer Django aplatit client_nom et client_prenom directement (SerializerMethodField)
// plutôt que d'imbriquer un objet user — ça simplifie la lecture ici.

class Avis {
  final int    id;
  final int    note;        // 1 à 5 étoiles, validé côté Django aussi
  final String commentaire;
  final String clientNom;
  final String clientPrenom;
  final String date;
  // Ces deux champs sont optionnels selon le contexte d'appel :
  // quand on fetch les avis d'un prestataire, on n'a pas forcément besoin
  // de re-exposer l'id de la demande associée.
  final int?   prestataireId;
  final int?   demandeId;

  Avis({
    required this.id,
    required this.note,
    required this.commentaire,
    required this.clientNom,
    required this.clientPrenom,
    required this.date,
    this.prestataireId,
    this.demandeId,
  });

  factory Avis.fromJson(Map<String, dynamic> json) {
    return Avis(
      // Même précaution int/string que partout ailleurs — DRF peut varier
      // selon si on est dans un ViewSet imbriqué ou un endpoint direct.
      id:           json['id'] is int ? json['id'] as int : int.tryParse(json['id']?.toString() ?? '') ?? 0,
      note:         json['note'] is int ? json['note'] as int : int.tryParse(json['note']?.toString() ?? '') ?? 0,
      commentaire:  json['commentaire']?.toString() ?? '',
      // client_nom et client_prenom sont des champs calculés côté serializer,
      // pas des relations imbriquées — d'où le snake_case direct.
      clientNom:    json['client_nom']?.toString() ?? '',
      clientPrenom: json['client_prenom']?.toString() ?? '',
      date:         json['date']?.toString() ?? '',
      // prestataire et demande sont renvoyés comme entiers (PK), pas comme objets
      prestataireId: json['prestataire'] is int
          ? json['prestataire'] as int
          : int.tryParse(json['prestataire']?.toString() ?? ''),
      demandeId: json['demande'] is int
          ? json['demande'] as int
          : int.tryParse(json['demande']?.toString() ?? ''),
    );
  }

  // Initiales pour l'avatar dans la liste des avis
  String get initiales {
    final n = clientNom.isNotEmpty ? clientNom[0].toUpperCase() : '';
    final p = clientPrenom.isNotEmpty ? clientPrenom[0].toUpperCase() : '';
    return '$n$p';
  }

  String get nomComplet => '$clientNom $clientPrenom'.trim();

  // Même logique de formatage que Demande — toLocal() important car Django
  // stocke en UTC et nos utilisateurs sont en GMT+0 (Conakry)
  String get dateFormatee {
    try {
      final dt = DateTime.parse(date).toLocal();
      const mois = ['jan', 'fév', 'mar', 'avr', 'mai', 'juin',
                    'juil', 'août', 'sep', 'oct', 'nov', 'déc'];
      return '${dt.day} ${mois[dt.month - 1]} ${dt.year}';
    } catch (_) {
      return date;
    }
  }
}
