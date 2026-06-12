import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/api_client.dart';
import '../models/notification.dart';
import '../theme.dart';
import '../widgets/appbar_actions.dart';

// Écran des notifications — liste des alertes reçues automatiquement
// lors des événements liés aux demandes : nouvelle demande acceptée/refusée,
// devis reçu, service terminé, avis laissé, etc.
//
// Les notifications sont chargées à l'ouverture et peuvent être rafraîchies
// manuellement (pull-to-refresh ou bouton). Pas de WebSocket ici —
// le polling à la demande est suffisant pour ce cas d'usage.

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final _api = ApiClient();

  List<AppNotification> _notifications = [];
  bool _chargement = true;
  bool _erreur     = false;

  @override
  void initState() {
    super.initState();
    _charger();
  }

  Future<void> _charger() async {
    // On reset les deux flags à chaque appel pour gérer correctement le cas
    // où l'utilisateur appuie sur "Réessayer" après une erreur.
    setState(() { _chargement = true; _erreur = false; });
    try {
      final donnees = await _api.getNotifications();
      if (!mounted) return;
      setState(() {
        // La réponse API est une List<dynamic> — on convertit explicitement
        // chaque entrée en Map<String, dynamic> pour que fromJson soit type-safe.
        _notifications = donnees
            .map((j) => AppNotification.fromJson(Map<String, dynamic>.from(j)))
            .toList();
        _chargement = false;
      });
    } catch (e) {
      // On log en debug pour faciliter le diagnostic sans exposer l'erreur à l'utilisateur.
      debugPrint('Erreur notifications: $e');
      if (!mounted) return;
      setState(() { _chargement = false; _erreur = true; });
    }
  }

  Future<void> _marquerToutesLues() async {
    try {
      await _api.marquerToutesNotificationsLues();
      if (!mounted) return;

      // On met à jour la liste localement plutôt que de recharger depuis l'API.
      // C'est plus rapide et évite un aller-retour réseau pour une opération
      // dont on connaît déjà le résultat attendu.
      // On reconstruit chaque AppNotification avec lu: true car le modèle est immutable.
      setState(() {
        _notifications = _notifications
            .map((n) => AppNotification(
                  id: n.id, titre: n.titre, message: n.message,
                  lu: true, createdAt: n.createdAt))
            .toList();
      });
    } catch (_) {
      // On avale l'erreur silencieusement : si le marquage échoue côté serveur,
      // au pire l'utilisateur reverra les notifications comme non-lues au prochain chargement.
      // Pas critique — pas de feedback d'erreur pour cette action.
    }
  }

  // Getter pour le nombre de notifications non lues.
  // Utilisé pour afficher/masquer le bouton "Tout lire" dans l'AppBar.
  int get _nombreNonLues => _notifications.where((n) => !n.lu).length;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBackground,
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          // AppBarActions commun à plusieurs écrans — on désactive l'icône notif
          // ici pour éviter la récursion (on est déjà sur l'écran notifications).
          const AppBarActions(showNotification: false),

          // "Tout lire" apparaît seulement s'il y a des non-lues.
          // Inutile de l'afficher si tout est déjà lu — ça évite une action sans effet.
          if (_nombreNonLues > 0)
            TextButton(
              onPressed: _marquerToutesLues,
              child: const Text('Tout lire',
                  style: TextStyle(color: kOrange, fontSize: 13, fontWeight: FontWeight.w600)),
            ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _charger,
            tooltip: 'Actualiser',
          ),
        ],
      ),
      // RefreshIndicator pour le pull-to-refresh natif.
      // Doit envelopper un scrollable — on s'assure que tous les états
      // (chargement, erreur, vide, liste) utilisent un ListView pour ça.
      body: RefreshIndicator(
        color: kOrange,
        onRefresh: _charger,
        child: _construireContenu(),
      ),
    );
  }

  Widget _construireContenu() {
    if (_chargement) {
      return const Center(child: CircularProgressIndicator(color: kOrange));
    }

    if (_erreur) {
      // On enveloppe dans un ListView même pour l'état d'erreur.
      // Sans ça, RefreshIndicator ne peut pas déclencher le pull-to-refresh
      // car il n'a pas de scrollable enfant.
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          SizedBox(
            height: MediaQuery.of(context).size.height * 0.7,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.wifi_off_rounded, size: 52, color: kBorder),
                const SizedBox(height: 12),
                const Text('Problème de connexion',
                    style: TextStyle(color: kTextGray)),
                const SizedBox(height: 16),
                TextButton.icon(
                  onPressed: _charger,
                  icon: const Icon(Icons.refresh, color: kOrange),
                  label: const Text('Réessayer', style: TextStyle(color: kOrange)),
                ),
              ],
            ),
          ),
        ],
      );
    }

    if (_notifications.isEmpty) {
      // Même chose pour l'état vide — ListView pour que le pull-to-refresh fonctionne.
      // AlwaysScrollableScrollPhysics force le scroll même quand le contenu
      // ne dépasse pas la hauteur de l'écran.
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          SizedBox(
            height: MediaQuery.of(context).size.height * 0.7,
            child: const Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.notifications_none_rounded, size: 60, color: kBorder),
                SizedBox(height: 14),
                Text('Aucune notification',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: kTextGray)),
                SizedBox(height: 6),
                Text('Tu seras notifié des mises à jour de tes demandes',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 13, color: kTextGray)),
              ],
            ),
          ),
        ],
      );
    }

    // Liste des notifications avec gestion du tap pour marquer comme lu.
    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: _notifications.length,
      itemBuilder: (_, i) => _CarteNotification(
        notif: _notifications[i],
        onTap: () async {
          // On ne fait l'appel API que si la notification n'est pas déjà lue —
          // pas besoin de taper le réseau inutilement.
          if (!_notifications[i].lu) {
            await _api.marquerNotificationLue(_notifications[i].id);
            if (mounted) {
              setState(() {
                // Même pattern qu'en haut : reconstruction immutable de l'objet
                // avec lu: true pour refléter le changement sans rechargement API.
                final n = _notifications[i];
                _notifications[i] = AppNotification(
                  id: n.id, titre: n.titre, message: n.message,
                  lu: true, createdAt: n.createdAt,
                );
              });
            }
          }
        },
      ),
    );
  }
}

// ── Déduction de l'icône à partir du titre ────────────────────────────────
// On parse le titre en lowercase pour être insensible à la casse.
// C'est du pattern matching sur du texte libre — fragile si les titres changent côté serveur,
// mais suffisant pour l'instant. À remplacer par un champ "type" dans le modèle si on
// a besoin de plus de robustesse.
IconData _iconeNotif(String titre) {
  final t = titre.toLowerCase();
  if (t.contains('devis'))    return Icons.request_quote_rounded;
  if (t.contains('accept'))   return Icons.check_circle_rounded;
  if (t.contains('refus') || t.contains('rejet')) return Icons.cancel_rounded;
  if (t.contains('termin'))   return Icons.task_alt_rounded;
  if (t.contains('avis') || t.contains('note'))   return Icons.star_rounded;
  if (t.contains('demand'))   return Icons.assignment_rounded;
  if (t.contains('message'))  return Icons.chat_rounded;
  return Icons.notifications_rounded; // fallback générique
}

// ── Couleur de l'icône selon le type et l'état lu/non-lu ─────────────────
// Les notifications lues passent en gris — signal visuel clair que c'est "traité".
Color _couleurNotif(String titre, bool lu) {
  if (lu) return kTextGray;
  final t = titre.toLowerCase();
  if (t.contains('accept') || t.contains('termin')) return kGreen;
  if (t.contains('refus') || t.contains('rejet'))   return kRed;
  if (t.contains('avis'))   return kYellow;
  return kOrange; // couleur par défaut pour les notifications non lues
}

// ── Couleur de fond de l'icône ────────────────────────────────────────────
// Version claire de la couleur principale pour ne pas agresser l'oeil.
// Les notifications lues ont un fond neutre (kBackground) pour se fondre dans la liste.
Color _bgNotif(String titre, bool lu) {
  if (lu) return kBackground;
  final t = titre.toLowerCase();
  if (t.contains('accept') || t.contains('termin')) return kGreenLight;
  if (t.contains('refus') || t.contains('rejet'))   return kRedLight;
  if (t.contains('avis'))   return const Color(0xFFFEF9C3); // jaune très clair
  return kOrangeLight;
}

// ── Carte d'une notification individuelle ────────────────────────────────
class _CarteNotification extends StatelessWidget {
  final AppNotification notif;
  final VoidCallback    onTap;

  const _CarteNotification({required this.notif, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () {
        // Retour haptique léger sur les notifications non lues.
        // Donne un feedback physique que "quelque chose se passe" quand on tape.
        // On ne fait pas de haptic sur les lues car l'action n'a pas d'effet visible.
        if (!notif.lu) HapticFeedback.lightImpact();
        onTap();
      },
      child: Container(
        // Fond légèrement orangé pour les non-lues, transparent pour les lues.
        // On évite un fond blanc pur qui ferait disparaître la différence visuelle.
        color: notif.lu ? Colors.transparent : kOrangeLight.withValues(alpha: 0.4),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Icône dynamique dans un cercle coloré selon le type de notification
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: _bgNotif(notif.titre, notif.lu),
                shape: BoxShape.circle,
              ),
              child: Icon(
                _iconeNotif(notif.titre),
                size: 20,
                color: _couleurNotif(notif.titre, notif.lu),
              ),
            ),
            const SizedBox(width: 12),

            // Contenu textuel + indicateur point orange pour les non-lues
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          notif.titre,
                          style: TextStyle(
                            fontSize: 14,
                            // Titre en gras si non lue, semi-gras si lue.
                            // Même convention que les clients mail natifs.
                            fontWeight: notif.lu ? FontWeight.w500 : FontWeight.w700,
                            color: kTextPrimary,
                          ),
                        ),
                      ),
                      // Petit point orange : indicateur discret mais très lisible
                      // que la notification n'a pas encore été vue.
                      if (!notif.lu)
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: kOrange,
                            shape: BoxShape.circle,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    notif.message,
                    style: const TextStyle(fontSize: 13, color: kTextGray, height: 1.4),
                  ),
                  const SizedBox(height: 4),
                  // Date formatée via le getter du modèle — la logique de formatage
                  // reste dans le modèle, pas ici.
                  Text(
                    notif.dateFormatee,
                    style: const TextStyle(fontSize: 11, color: kBorder),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
