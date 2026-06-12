// Modèle de message dans une conversation
// Distinct du modèle Notification pour éviter toute confusion

class MessageChat {
  final int     id;          // ID réel du serveur (ou négatif si message en cours d'envoi)
  final int     expediteurId;
  final String  expediteurNom;
  final String  expediteurPrenom;
  final String  contenu;
  final DateTime dateEnvoi;
  final bool    lu;
  final bool    isTemp;      // true = envoyé localement, pas encore confirmé

  const MessageChat({
    required this.id,
    required this.expediteurId,
    required this.expediteurNom,
    required this.expediteurPrenom,
    required this.contenu,
    required this.dateEnvoi,
    required this.lu,
    this.isTemp = false,
  });

  factory MessageChat.fromJson(Map<String, dynamic> j) {
    final exp = j['expediteur'] as Map<String, dynamic>? ?? {};
    return MessageChat(
      id:               (j['id'] as num).toInt(),
      expediteurId:     (exp['id'] as num?)?.toInt() ?? 0,
      expediteurNom:    exp['nom']    as String? ?? '',
      expediteurPrenom: exp['prenom'] as String? ?? '',
      contenu:          j['contenu']  as String? ?? '',
      dateEnvoi:        DateTime.tryParse(j['date_envoi'] as String? ?? '')?.toLocal()
                        ?? DateTime.now(),
      lu:               j['lu'] as bool? ?? false,
    );
  }

  String get heureFormatee {
    final h = dateEnvoi.hour.toString().padLeft(2, '0');
    final m = dateEnvoi.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }
}
