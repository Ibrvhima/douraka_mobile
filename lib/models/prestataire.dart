import '../core/constantes.dart';

// Représente un artisan/prestataire tel que renvoyé par le PrestataireSerializer.
// Côté Django, le profil prestataire est un modèle séparé lié à User via OneToOne,
// ce qui explique qu'on doive aller chercher nom/prenom dans le sous-objet 'user'.
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
    // Le serializer imbrique les infos user dans 'user' et la catégorie dans 'categorie'.
    // On cast prudemment en Map (pas as Map<String,dynamic>) pour éviter
    // un crash si le backend renvoie un null ou un id entier à la place de l'objet.
    final user = json['user'] is Map ? json['user'] as Map : {};
    final cat  = json['categorie'] is Map ? json['categorie'] as Map : null;

    return Prestataire(
      id:           json['id'] is int ? json['id'] : int.tryParse(json['id'].toString()) ?? 0,
      uuid:         json['uuid']?.toString()          ?? '',
      nom:          user['nom']?.toString()            ?? '',
      prenom:       user['prenom']?.toString()         ?? '',
      categorie:    cat?['nom']?.toString(),
      // On extrait l'id catégorie pour pouvoir filtrer la liste sans comparer des strings
      categorieId:  cat != null
                      ? (cat['id'] is int
                          ? cat['id'] as int
                          : int.tryParse(cat['id']?.toString() ?? ''))
                      : null,
      quartier:     json['quartier']?.toString(),
      description:  json['description']?.toString(),
      telephone:    json['telephone']?.toString(),
      // La photo peut être sur le profil prestataire ou sur l'user — on prend
      // celle du profil en priorité, sinon on tombe sur celle de l'user.
      photo:        normaliserUrlPhoto(json['photo']?.toString() ?? user['photo']?.toString()),
      disponible:   json['disponible']                 == true,
      badgeVerifie: json['badge_verifie']              == true,
      // note_moyenne sort du serializer comme string décimal ("4.50") ou comme
      // number selon la version Django REST — double.tryParse gère les deux.
      noteMoyenne:  json['note_moyenne'] != null
                      ? double.tryParse(json['note_moyenne'].toString())
                      : null,
      // Django utilise 'nombre_avis' (SerializerMethodField) mais certaines
      // vues plus anciennes renvoyaient 'nb_avis' — on garde les deux clés
      // le temps que tout soit migré.
      nbAvis:       (json['nombre_avis'] ?? json['nb_avis'] ?? 0) is int
                      ? (json['nombre_avis'] ?? json['nb_avis'] ?? 0) as int
                      : int.tryParse((json['nombre_avis'] ?? json['nb_avis'] ?? 0).toString()) ?? 0,
    );
  }

  String get nomComplet => '$nom $prenom'.trim();

  // Initiales pour l'avatar (ex: "AD" pour "Amadou Diallo")
  String get initiales {
    final n = nom.isNotEmpty ? nom[0].toUpperCase() : '';
    final p = prenom.isNotEmpty ? prenom[0].toUpperCase() : '';
    return '$n$p';
  }
}
