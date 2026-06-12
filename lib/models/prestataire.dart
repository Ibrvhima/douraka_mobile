import '../core/constantes.dart';

// Côté Django, le profil prestataire est un modèle séparé lié à User via OneToOne,
// d'où le sous-objet 'user' pour nom/prenom.
class Prestataire {
  final int    id;   // PK du profil Prestataire (pas de l'User) — c'est cet id qu'on envoie dans les demandes
  final String uuid;
  final String nom;
  final String prenom;
  final String? categorie;
  final int?    categorieId;
  final String? quartier;
  final String? description;
  final String? telephone;
  final String? photo;
  final bool    disponible;
  final bool    badgeVerifie;
  final double? noteMoyenne;
  final int     nbAvis;

  Prestataire({
    required this.id,
    required this.uuid,
    required this.nom,
    required this.prenom,
    this.categorie,
    this.categorieId,
    this.quartier,
    this.description,
    this.telephone,
    this.photo,
    required this.disponible,
    required this.badgeVerifie,
    this.noteMoyenne,
    this.nbAvis = 0,
  });

  factory Prestataire.fromJson(Map<String, dynamic> json) {
    // Cast prudent en Map (pas as Map<String,dynamic>) — le backend peut renvoyer
    // un null ou un id entier à la place de l'objet si la vue est allégée.
    final user = json['user'] is Map ? json['user'] as Map : {};
    final cat  = json['categorie'] is Map ? json['categorie'] as Map : null;

    return Prestataire(
      id:           json['id'] is int ? json['id'] : int.tryParse(json['id'].toString()) ?? 0,
      uuid:         json['uuid']?.toString()          ?? '',
      nom:          user['nom']?.toString()            ?? '',
      prenom:       user['prenom']?.toString()         ?? '',
      categorie:    cat?['nom']?.toString(),
      // On extrait l'id catégorie pour filtrer la liste sans comparer des strings
      categorieId:  cat != null
                      ? (cat['id'] is int
                          ? cat['id'] as int
                          : int.tryParse(cat['id']?.toString() ?? ''))
                      : null,
      quartier:     json['quartier']?.toString(),
      description:  json['description']?.toString(),
      telephone:    json['telephone']?.toString(),
      // Photo sur le profil prestataire en priorité, sinon celle de l'user
      photo:        normaliserUrlPhoto(json['photo']?.toString() ?? user['photo']?.toString()),
      disponible:   json['disponible']                 == true,
      badgeVerifie: json['badge_verifie']              == true,
      // note_moyenne sort comme string décimal ("4.50") ou comme number selon la version DRF
      noteMoyenne:  json['note_moyenne'] != null
                      ? double.tryParse(json['note_moyenne'].toString())
                      : null,
      // Django utilise 'nombre_avis' mais certaines vues anciennes renvoyaient 'nb_avis'
      nbAvis:       (json['nombre_avis'] ?? json['nb_avis'] ?? 0) is int
                      ? (json['nombre_avis'] ?? json['nb_avis'] ?? 0) as int
                      : int.tryParse((json['nombre_avis'] ?? json['nb_avis'] ?? 0).toString()) ?? 0,
    );
  }

  String get nomComplet => '$nom $prenom'.trim();

  String get initiales {
    final n = nom.isNotEmpty ? nom[0].toUpperCase() : '';
    final p = prenom.isNotEmpty ? prenom[0].toUpperCase() : '';
    return '$n$p';
  }
}
