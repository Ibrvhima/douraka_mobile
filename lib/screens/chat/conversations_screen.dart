import 'package:flutter/material.dart';
import '../../core/api_client.dart';
import '../../core/token_storage.dart';
import '../../models/conversation.dart';
import '../../theme.dart';
import '../../widgets/appbar_actions.dart';
import 'chat_screen.dart';

// Liste des conversations de l'utilisateur connecté
// Accessible depuis l'onglet "Messages" du shell client ou prestataire

class ConversationsScreen extends StatefulWidget {
  const ConversationsScreen({super.key});

  @override
  State<ConversationsScreen> createState() => _ConversationsScreenState();
}

class _ConversationsScreenState extends State<ConversationsScreen> {
  final _api          = ApiClient();
  List<Conversation>  _conversations = [];
  bool                _chargement    = true;
  bool                _erreur        = false;
  String              _role          = 'client';

  @override
  void initState() {
    super.initState();
    _charger();
  }

  Future<void> _charger() async {
    setState(() { _chargement = true; _erreur = false; });
    try {
      final role  = await TokenStorage.lireRole() ?? 'client';
      final liste = await _api.getConversations();
      if (!mounted) return;
      setState(() {
        _role = role;
        _conversations = liste
            .map((j) => Conversation.fromJson(Map<String, dynamic>.from(j)))
            .toList();
        _chargement = false;
      });
    } catch (e) {
      debugPrint('Erreur conversations: $e');
      if (!mounted) return;
      setState(() { _chargement = false; _erreur = true; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBackground,
      appBar: AppBar(
        title: const Text('Messages'),
        actions: [
          const AppBarActions(showChat: false),
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _charger,
            tooltip: 'Actualiser',
          ),
        ],
      ),
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
                const Text('Problème de connexion', style: TextStyle(color: kTextGray)),
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

    if (_conversations.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          SizedBox(
            height: MediaQuery.of(context).size.height * 0.7,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: const [
                Icon(Icons.chat_bubble_outline_rounded, size: 60, color: kBorder),
                SizedBox(height: 14),
                Text('Aucune conversation',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: kTextGray)),
                SizedBox(height: 6),
                Text('Tes échanges avec les prestataires\napparaîtront ici',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 13, color: kTextGray)),
              ],
            ),
          ),
        ],
      );
    }

    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: _conversations.length,
      itemBuilder: (_, i) => _CarteConversation(
        conv:    _conversations[i],
        role:    _role,
        onTap:   () => _ouvrirChat(_conversations[i]),
        onRetour: _charger,
      ),
    );
  }

  Future<void> _ouvrirChat(Conversation conv) async {
    // Détermine l'autre personne selon le rôle
    final autre = _role == 'client' ? conv.prestataire : conv.client;

    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) => ChatScreen(
          convId:               conv.id,
          autrePersonneNom:     autre.nomComplet,
          autrePersonneInitiales: autre.initiales,
        ),
      ),
    );
    // Recharge après retour (marquer comme lus)
    if (mounted) _charger();
  }
}

// ── Carte d'une conversation ────────────────────────────────────────────────
class _CarteConversation extends StatelessWidget {
  final Conversation conv;
  final String       role;
  final VoidCallback onTap;
  final VoidCallback onRetour;

  const _CarteConversation({
    required this.conv,
    required this.role,
    required this.onTap,
    required this.onRetour,
  });

  @override
  Widget build(BuildContext context) {
    final autre   = role == 'client' ? conv.prestataire : conv.client;
    final hasUnread = conv.nonLus > 0;

    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: hasUnread ? kOrangeLight.withValues(alpha: 0.3) : Colors.white,
          border: Border(bottom: BorderSide(color: kBorder, width: 0.5)),
        ),
        child: Row(
          children: [
            // Avatar
            Container(
              width: 50, height: 50,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [kOrange, kOrangeDark],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  autre.initiales.isEmpty ? '?' : autre.initiales,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),

            // Contenu
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          autre.nomComplet,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: hasUnread ? FontWeight.w700 : FontWeight.w600,
                            color: kTextPrimary,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (conv.derniereDateFormatee.isNotEmpty)
                        Text(
                          conv.derniereDateFormatee,
                          style: TextStyle(
                            fontSize: 11,
                            color: hasUnread ? kOrange : kTextGray,
                            fontWeight: hasUnread ? FontWeight.w600 : FontWeight.w400,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          conv.dernierContenu ?? 'Démarrer la conversation…',
                          style: TextStyle(
                            fontSize: 13,
                            color: hasUnread ? kTextPrimary : kTextGray,
                            fontWeight: hasUnread ? FontWeight.w500 : FontWeight.w400,
                          ),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                      ),
                      if (hasUnread)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: kOrange,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '${conv.nonLus}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                    ],
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
