// Notification système générée automatiquement par le backend lors d'événements métier
// (demande acceptée, devis reçu, avis posté, etc.).
// On a nommé la classe AppNotification pour éviter le conflit avec
// dart:core Notification qui existe dans certains contextes Flutter.

class AppNotification {
  final int    id;
  final String titre;
  final String message;
  // lu est mis à jour via PATCH /notifications/{id}/marquer_lu/ — pas besoin
  // d'un modèle mutable ici, on recharge la liste après l'action.
  final bool   lu;
  final String createdAt;

  AppNotification({
    required this.id,
    required this.titre,
    required this.message,
    required this.lu,
    required this.createdAt,
  });

  factory AppNotification.fromJson(Map<String, dynamic> json) {
    return AppNotification(
      id:        json['id'] is int ? json['id'] as int : int.tryParse(json['id']?.toString() ?? '') ?? 0,
      titre:     json['titre']?.toString() ?? '',
      message:   json['message']?.toString() ?? '',
      // On compare strictement à true — json['lu'] peut être null si le champ
      // est absent du payload, auquel qu'on considère non lu par défaut.
      lu:        json['lu'] == true,
      createdAt: json['created_at']?.toString() ?? '',
    );
  }

  // Affichage relatif pour les notifications récentes, absolu au-delà de 7 jours —
  // même logique que la plupart des apps de messagerie.
  String get dateFormatee {
    try {
      final dt = DateTime.parse(createdAt).toLocal();
      final now = DateTime.now();
      final diff = now.difference(dt);

      if (diff.inMinutes < 1)  return 'À l\'instant';
      if (diff.inMinutes < 60) return 'Il y a ${diff.inMinutes} min';
      if (diff.inHours < 24)   return 'Il y a ${diff.inHours}h';
      if (diff.inDays < 7)     return 'Il y a ${diff.inDays} jour${diff.inDays > 1 ? 's' : ''}';

      // Au-delà d'une semaine, la date exacte est plus parlante
      const mois = ['jan', 'fév', 'mar', 'avr', 'mai', 'juin',
                    'juil', 'août', 'sep', 'oct', 'nov', 'déc'];
      return '${dt.day} ${mois[dt.month - 1]} ${dt.year}';
    } catch (_) {
      return createdAt;
    }
  }
}
