import 'dart:io';
import 'package:dio/dio.dart';
import 'constantes.dart';
import 'navigation.dart';
import 'token_storage.dart';

// On centralise tous les appels Dio ici plutôt que de laisser chaque écran
// gérer son propre token et ses propres erreurs.

class ApiClient {
  // Render free tier : cold start ~30-50s, requêtes normales ~2-5s.
  // 15s connexion + 20s réception, c'est le compromis pour éviter des timeouts
  // intempestifs sans bloquer l'UI trop longtemps.
  final Dio _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 20),
    ),
  );

  ApiClient() {
    // Quand le JWT expire, Django renvoie 401. On efface le token localement
    // et on redirige vers /login en vidant toute la pile (pushNamedAndRemoveUntil)
    // pour qu'il soit impossible de revenir en arrière.
    _dio.interceptors.add(InterceptorsWrapper(
      onError: (DioException error, ErrorInterceptorHandler handler) async {
        if (error.response?.statusCode == 401) {
          await TokenStorage.supprimer();
          // navigatorKey permet d'agir sur le Navigator sans BuildContext —
          // c'est le seul endroit dans l'app où on s'en sert directement.
          navigatorKey.currentState?.pushNamedAndRemoveUntil(
            '/login',
            (route) => false,
          );
        }
        handler.next(error);
      },
    ));
  }

  Future<Options> _auth() async {
    final token = await TokenStorage.lire();
    return Options(headers: {'Authorization': 'Bearer $token'});
  }

  // Django pagine certains endpoints ({ count, results: [...] }) et d'autres
  // retournent des listes directes. On normalise ici pour que les appelants
  // n'aient pas à s'en préoccuper.
  List<dynamic> _extraireListe(dynamic data) {
    if (data is Map) {
      final results = data['results'];
      return results is List ? results : [];
    }
    if (data is List) return data;
    return [];
  }

  // Le register renvoie directement access + user comme le login,
  // donc on peut connecter l'utilisateur immédiatement après inscription.
  // Pour un compte prestataire, passer aussi : categorie_id, quartier,
  // description, telephone_pro — le serializer Django gère les deux cas.
  Future<Map<String, dynamic>> register(Map<String, dynamic> data) async {
    final rep = await _dio.post('$apiUrl/users/register/', data: data);
    await TokenStorage.sauvegarder(rep.data['access']);
    await TokenStorage.sauvegarderRole(rep.data['user']['role']);
    return rep.data;
  }

  Future<Map<String, dynamic>> login(String email, String password) async {
    final rep = await _dio.post(
      '$apiUrl/users/login/',
      data: {'email': email, 'password': password},
    );
    await TokenStorage.sauvegarder(rep.data['access']);
    await TokenStorage.sauvegarderRole(rep.data['user']['role']);
    return rep.data;
  }

  // Pas d'appel API : on supprime juste le token local.
  // Le JWT reste techniquement valide jusqu'à expiration côté serveur,
  // mais ça suffit pour notre modèle de sécurité actuel.
  Future<void> deconnexion() => TokenStorage.supprimer();

  Future<void> demanderReinitialisationMdp(String email) async {
    await _dio.post('$apiUrl/users/password-reset/', data: {'email': email});
  }

  Future<Map<String, dynamic>> getMonProfil() async {
    final rep = await _dio.get('$apiUrl/users/me/', options: await _auth());
    return rep.data;
  }

  // On utilise PATCH et non PUT pour ne passer que les champs modifiés.
  Future<Map<String, dynamic>> mettreAJourProfil(Map<String, dynamic> data) async {
    final rep = await _dio.patch(
      '$apiUrl/users/me/',
      data: data,
      options: await _auth(),
    );
    return rep.data;
  }

  // Nom de fichier avec timestamp pour forcer Django à créer un nouveau fichier
  // plutôt qu'écraser le précédent sans invalider le cache CDN.
  Future<Map<String, dynamic>> uploadPhoto(File imageFile) async {
    final token    = await TokenStorage.lire();
    final ext      = imageFile.path.split('.').last.toLowerCase();
    final filename = 'photo_${DateTime.now().millisecondsSinceEpoch}.$ext';
    final formData = FormData.fromMap({
      'photo': await MultipartFile.fromFile(
        imageFile.path,
        filename: filename,
      ),
    });
    final rep = await _dio.patch(
      '$apiUrl/users/me/',
      data: formData,
      options: Options(headers: {'Authorization': 'Bearer $token'}),
    );
    return rep.data;
  }

  // Pas d'auth — la liste des catégories est publique.
  Future<List<dynamic>> getCategories() async {
    final rep = await _dio.get('$apiUrl/categories/');
    return _extraireListe(rep.data);
  }

  Future<List<dynamic>> getPrestataires({int? categorieId, String? quartier}) async {
    final rep = await _dio.get(
      '$apiUrl/prestataires/',
      queryParameters: {
        if (categorieId != null) 'categorie': categorieId, // ignore: use_null_aware_elements
        if (quartier != null && quartier.isNotEmpty) 'quartier': quartier,
      },
    );
    return _extraireListe(rep.data);
  }

  Future<Map<String, dynamic>> getPrestataire(String uuid) async {
    final rep = await _dio.get('$apiUrl/prestataires/$uuid/');
    return rep.data;
  }

  // Endpoint dédié pour que le prestataire connecté accède à son propre profil
  // sans connaître son UUID d'avance (récupéré depuis le token côté Django).
  Future<Map<String, dynamic>> getMonProfilPrestataire() async {
    final rep = await _dio.get(
      '$apiUrl/prestataires/me/',
      options: await _auth(),
    );
    return rep.data;
  }

  Future<Map<String, dynamic>> mettreAJourProfilPrestataire(
      String uuid, Map<String, dynamic> data) async {
    final rep = await _dio.patch(
      '$apiUrl/prestataires/$uuid/',
      data: data,
      options: await _auth(),
    );
    return rep.data;
  }

  // ATTENTION : Django attend l'id entier (PrimaryKeyRelatedField) et non l'UUID.
  // Le profil prestataire expose l'UUID mais la demande veut l'int pk.
  Future<void> envoyerDemande({
    required int    prestataireId,
    required String description,
    String?         titre,
    String?         adresse,
    bool            urgence = false,
  }) async {
    await _dio.post(
      '$apiUrl/demandes/',
      data: {
        'prestataire': prestataireId,
        'description': description,
        if (titre   != null && titre.isNotEmpty)   'titre':   titre,
        if (adresse != null && adresse.isNotEmpty) 'adresse': adresse,
        'urgence': urgence,
      },
      options: await _auth(),
    );
  }

  // Django filtre selon le rôle du token :
  // client → ses demandes envoyées ; prestataire → demandes reçues.
  // Un seul endpoint, deux comportements.
  Future<List<dynamic>> getMesDemandes() async {
    final rep = await _dio.get('$apiUrl/demandes/', options: await _auth());
    return _extraireListe(rep.data);
  }

  Future<Map<String, dynamic>> getDemande(int id) async {
    final rep = await _dio.get('$apiUrl/demandes/$id/', options: await _auth());
    return rep.data;
  }

  Future<Map<String, dynamic>> getStatsDemandes() async {
    final rep = await _dio.get('$apiUrl/demandes/stats/', options: await _auth());
    return rep.data;
  }

  // Les transitions d'état sont validées côté Django — on ne les reduplique pas ici.
  Future<void> accepterDemande(int id) async {
    await _dio.post('$apiUrl/demandes/$id/accepter/', options: await _auth());
  }

  Future<void> refuserDemande(int id) async {
    await _dio.post('$apiUrl/demandes/$id/refuser/', options: await _auth());
  }

  Future<void> terminerDemande(int id) async {
    await _dio.post('$apiUrl/demandes/$id/terminer/', options: await _auth());
  }

  Future<void> annulerDemande(int id) async {
    await _dio.post('$apiUrl/demandes/$id/annuler/', options: await _auth());
  }

  // Lecture publique — pas besoin de token pour voir les avis sur une fiche prestataire.
  Future<List<dynamic>> getAvis(int prestataireId) async {
    final rep = await _dio.get(
      '$apiUrl/avis/',
      queryParameters: {'prestataire': prestataireId},
    );
    return _extraireListe(rep.data);
  }

  // Django impose que la demande soit au statut "terminée" et appartienne
  // au client connecté — sinon on reçoit un 400.
  Future<void> laisserAvis({
    required int    demandeId,
    required int    note,
    required String commentaire,
  }) async {
    await _dio.post(
      '$apiUrl/avis/',
      data: {
        'demande':     demandeId,
        'note':        note,
        'commentaire': commentaire,
      },
      options: await _auth(),
    );
  }

  Future<List<dynamic>> getMesDevis() async {
    final rep = await _dio.get('$apiUrl/devis/', options: await _auth());
    return _extraireListe(rep.data);
  }

  // Le délai est en texte libre ("3 jours", "1 semaine"…) — pas de format date
  // imposé au stade MVP. À reconsidérer si on ajoute un calendrier.
  Future<void> creerDevis({
    required int    demandeId,
    required String montant,
    required String description,
    String?         delai,
  }) async {
    await _dio.post(
      '$apiUrl/devis/',
      data: {
        'demande':     demandeId,
        'montant':     montant,
        'description': description,
        if (delai != null && delai.isNotEmpty) 'delai': delai,
      },
      options: await _auth(),
    );
  }

  Future<void> accepterDevis(int id) async {
    await _dio.post('$apiUrl/devis/$id/accepter/', options: await _auth());
  }

  Future<void> refuserDevis(int id) async {
    await _dio.post('$apiUrl/devis/$id/refuser/', options: await _auth());
  }

  Future<List<dynamic>> getNotifications() async {
    final rep = await _dio.get('$apiUrl/notifications/', options: await _auth());
    return _extraireListe(rep.data);
  }

  Future<void> marquerToutesNotificationsLues() async {
    await _dio.post('$apiUrl/notifications/lire/', options: await _auth());
  }

  Future<void> marquerNotificationLue(int id) async {
    await _dio.post('$apiUrl/notifications/$id/lire/', options: await _auth());
  }

  // On utilise REST pour l'historique et WebSocket (wsUrl) pour le temps réel.
  // Ces endpoints HTTP servent surtout au chargement initial.

  Future<List<dynamic>> getConversations() async {
    final rep = await _dio.get('$apiUrl/chat/conversations/', options: await _auth());
    return _extraireListe(rep.data);
  }

  // Idempotent côté Django : si une conversation existe déjà pour cette demande,
  // on la retourne simplement. Évite les doublons.
  Future<Map<String, dynamic>> ouvrirConversation(int demandeId) async {
    final rep = await _dio.post(
      '$apiUrl/chat/conversations/ouvrir/',
      data: {'demande_id': demandeId},
      options: await _auth(),
    );
    return rep.data;
  }

  // L'appel GET marque aussi les messages comme lus côté Django —
  // pas besoin d'un deuxième appel "marquer lu" séparé.
  Future<List<dynamic>> getMessages(int convId) async {
    final rep = await _dio.get(
      '$apiUrl/chat/conversations/$convId/messages/',
      options: await _auth(),
    );
    return _extraireListe(rep.data);
  }

  Future<Map<String, dynamic>> envoyerMessage(int convId, String contenu) async {
    final rep = await _dio.post(
      '$apiUrl/chat/conversations/$convId/messages/envoyer/',
      data: {'contenu': contenu},
      options: await _auth(),
    );
    return rep.data;
  }

  // Ces endpoints sont protégés côté Django par is_staff —
  // le rôle est vérifié par le token, pas par l'app Flutter.

  Future<Map<String, dynamic>> getStatsAdmin() async {
    final rep = await _dio.get('$apiUrl/admin/stats/', options: await _auth());
    return rep.data;
  }

  // approuve=false → liste d'attente ; approuve=true → prestataires actifs
  Future<List<dynamic>> getPrestatairesAdmin({bool? approuve}) async {
    final rep = await _dio.get(
      '$apiUrl/admin/prestataires/',
      queryParameters: {
        if (approuve != null) 'approuve': approuve.toString(),
      },
      options: await _auth(),
    );
    return _extraireListe(rep.data);
  }

  // Sert à valider un prestataire (approuve=true), retirer le badge,
  // ou désactiver le compte sans le supprimer.
  Future<void> mettreAJourPrestataireAdmin(
      int pk, Map<String, dynamic> data) async {
    await _dio.patch(
      '$apiUrl/admin/prestataires/$pk/',
      data: data,
      options: await _auth(),
    );
  }

  Future<List<dynamic>> getClientsAdmin() async {
    final rep = await _dio.get('$apiUrl/admin/clients/', options: await _auth());
    return _extraireListe(rep.data);
  }

  // Suppression définitive — pas de soft delete. Django cascade sur les
  // demandes/avis liés, prévoir une confirmation côté UI.
  Future<void> supprimerUtilisateur(int pk) async {
    await _dio.delete('$apiUrl/admin/users/$pk/', options: await _auth());
  }

  Future<List<dynamic>> getDemandesAdmin({String? statut}) async {
    final rep = await _dio.get(
      '$apiUrl/admin/demandes/',
      queryParameters: {
        if (statut != null && statut.isNotEmpty) 'statut': statut,
      },
      options: await _auth(),
    );
    return _extraireListe(rep.data);
  }
}
