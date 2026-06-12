// Modèle de conversation (liée à une demande)
// Chaque demande peut avoir exactement une conversation entre client et prestataire

class UserMin {
  final int    id;
  final String nom;
  final String prenom;
  final String? photo;

  const UserMin({
    required this.id,
    required this.nom,
    required this.prenom,
    this.photo,
  });

  factory UserMin.fromJson(Map<String, dynamic> j) => UserMin(
    id:     (j['id'] as num?)?.toInt() ?? 0,
    nom:    j['nom']    as String? ?? '',
    prenom: j['prenom'] as String? ?? '',
    photo:  j['photo']  as String?,
  );

  String get nomComplet => '$prenom $nom'.trim();

  String get initiales {
    final p = prenom.isNotEmpty ? prenom[0].toUpperCase() : '';
    final n = nom.isNotEmpty    ? nom[0].toUpperCase()    : '';
    return '$p$n';
  }
}

class Conversation {
  final int     id;
  final int     demandeId;
  final UserMin client;
  final UserMin prestataire;
  final DateTime createdAt;

  // Dernier message (champs issus du sérialiseur Django)
  final String? dernierContenu;
  final String? dernierDateEnvoi;
  final String? dernierExpediteur;

  final int nonLus;

  const Conversation({
    required this.id,
    required this.demandeId,
    required this.client,
    required this.prestataire,
    required this.createdAt,
    this.dernierContenu,
    this.dernierDateEnvoi,
    this.dernierExpediteur,
    required this.nonLus,
  });

  factory Conversation.fromJson(Map<String, dynamic> j) {
    final dm = j['dernier_message'] as Map<String, dynamic>?;

    // demande peut être un int ou un objet
    int demandeId = 0;
    final dem = j['demande'];
    if (dem is int) {
      demandeId = dem;
    } else if (dem is Map) {
      demandeId = (dem['id'] as num?)?.toInt() ?? 0;
    }

    return Conversation(
      id:          (j['id'] as num).toInt(),
      demandeId:   demandeId,
      client:      UserMin.fromJson(j['client']      as Map<String, dynamic>),
      prestataire: UserMin.fromJson(j['prestataire'] as Map<String, dynamic>),
      createdAt:   DateTime.tryParse(j['created_at'] as String? ?? '') ?? DateTime.now(),
      dernierContenu:    dm?['contenu']    as String?,
      dernierDateEnvoi:  dm?['date_envoi'] as String?,
      dernierExpediteur: dm?['expediteur'] as String?,
      nonLus:      (j['non_lus'] as num?)?.toInt() ?? 0,
    );
  }

  // Formate l'heure/date du dernier message pour l'affichage
  String get derniereDateFormatee {
    if (dernierDateEnvoi == null) return '';
    final date  = DateTime.tryParse(dernierDateEnvoi!)?.toLocal();
    if (date == null) return '';
    final now   = DateTime.now();
    final aujd  = DateTime(now.year, now.month, now.day);
    final hier  = aujd.subtract(const Duration(days: 1));
    final dDate = DateTime(date.year, date.month, date.day);
    final h = date.hour.toString().padLeft(2, '0');
    final m = date.minute.toString().padLeft(2, '0');
    if (dDate == aujd) return '$h:$m';
    if (dDate == hier) return 'Hier';
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}';
  }
}
