import '../core/constantes.dart';

// Représente l'utilisateur connecté — client ou prestataire.
// Ce modèle est utilisé pour stocker les infos de session après login.
class Utilisateur {
  final int    id;
  final String nom;
  final String prenom;
  final String email;
  final String role;
  final String? photo;
  final String? telephone;

  Utilisateur({
    required this.id,
    required this.nom,
    required this.prenom,
    required this.email,
    required this.role,
    this.photo,
    this.telephone,
  });

  factory Utilisateur.fromJson(Map<String, dynamic> json) {
    return Utilisateur(
      // Django renvoie l'id comme int, mais certains endpoints (ex: JWT nested)
      // peuvent le sérialiser en string — on couvre les deux cas proprement.
      id:         json['id'] is int ? json['id'] : int.tryParse(json['id']?.toString() ?? '') ?? 0,
      nom:        json['nom']       ?? '',
      prenom:     json['prenom']    ?? '',
      email:      json['email']     ?? '',
      // Valeur par défaut 'client' si le champ est absent — ce qui n'arrive
      // normalement pas, mais ça évite un crash si le serializer change.
      role:       json['role']      ?? 'client',
      // normaliserUrlPhoto ajoute le base URL si le backend renvoie un chemin relatif
      photo:      normaliserUrlPhoto(json['photo']?.toString()),
      telephone:  json['telephone']?.toString(),
    );
  }

  String get nomComplet => '$nom $prenom'.trim();

  // Pour l'avatar en cas d'absence de photo — ex: "ID" pour Ibrahima Diallo
  String get initiales {
    final n = nom.isNotEmpty    ? nom[0].toUpperCase()    : '';
    final p = prenom.isNotEmpty ? prenom[0].toUpperCase() : '';
    return '$n$p';
  }
}
