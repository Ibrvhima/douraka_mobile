import 'package:flutter/material.dart';
import '../core/api_client.dart';
import '../theme.dart';
import '../screens/chat/conversations_screen.dart';
import '../screens/notifications_screen.dart';

// Widget réutilisable : icônes Messages + Notifications dans toutes les AppBars
// showChat          : false sur l'écran ConversationsScreen (déjà dessus)
// showNotification  : false sur l'écran NotificationsScreen (déjà dessus)
// iconColor         : Colors.white pour les AppBars à fond orange

class AppBarActions extends StatefulWidget {
  final bool  showChat;
  final bool  showNotification;
  final Color iconColor;

  const AppBarActions({
    this.showChat         = true,
    this.showNotification = true,
    this.iconColor        = kTextPrimary,
    super.key,
  });

  @override
  State<AppBarActions> createState() => _AppBarActionsState();
}

class _AppBarActionsState extends State<AppBarActions> {
  final _api    = ApiClient();
  int _chat     = 0;
  int _notif    = 0;

  @override
  void initState() {
    super.initState();
    _chargerBadges();
  }

  Future<void> _chargerBadges() async {
    try {
      final futures = <Future<List<dynamic>>>[];
      if (widget.showNotification) futures.add(_api.getNotifications());
      if (widget.showChat)         futures.add(_api.getConversations());

      final results = await Future.wait(futures);
      if (!mounted) return;

      int i = 0;
      if (widget.showNotification) {
        final notifs = results[i++];
        final n = notifs.where((x) => x['lu'] == false).length;
        setState(() => _notif = n);
      }
      if (widget.showChat) {
        final convs = results[i];
        final n = convs.fold<int>(
            0, (s, c) => s + ((c['non_lus'] as num?)?.toInt() ?? 0));
        setState(() => _chat = n);
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // ── Icône Messages ───────────────────────────────────────────────
        if (widget.showChat)
          IconButton(
            tooltip: 'Messages',
            icon: _chat > 0
                ? Badge(
                    label: Text('$_chat'),
                    backgroundColor: kOrange,
                    child: Icon(Icons.chat_bubble_outline_rounded,
                        color: widget.iconColor),
                  )
                : Icon(Icons.chat_bubble_outline_rounded,
                    color: widget.iconColor),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) => const ConversationsScreen()),
            ),
          ),

        // ── Icône Notifications ──────────────────────────────────────────
        if (widget.showNotification)
          IconButton(
            tooltip: 'Notifications',
            icon: _notif > 0
                ? Badge(
                    label: Text('$_notif'),
                    backgroundColor: kRed,
                    child: Icon(Icons.notifications_outlined,
                        color: widget.iconColor),
                  )
                : Icon(Icons.notifications_outlined,
                    color: widget.iconColor),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) => const NotificationsScreen()),
            ),
          ),
      ],
    );
  }
}
