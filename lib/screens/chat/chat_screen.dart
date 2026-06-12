import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:dio/dio.dart';

import '../../core/api_client.dart';
import '../../core/constantes.dart';
import '../../core/token_storage.dart';
import '../../models/message_chat.dart';
import '../../theme.dart';

class ChatScreen extends StatefulWidget {
  final int    convId;
  final String autrePersonneNom;
  final String autrePersonneInitiales;

  const ChatScreen({
    required this.convId,
    required this.autrePersonneNom,
    required this.autrePersonneInitiales,
    super.key,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _api        = ApiClient();
  final _ctrl       = TextEditingController();
  final _scrollCtrl = ScrollController();

  List<MessageChat> _messages    = [];
  bool              _chargement  = true;
  bool              _enviando    = false;
  int               _monId       = 0;
  WebSocket?        _ws;
  Timer?            _pollingTimer;
  bool              _wsConnected = false;

  @override
  void initState() {
    super.initState();
    _initialiser();
  }

  Future<void> _initialiser() async {
    // Récupère l'ID connecté pour distinguer mes messages des autres
    try {
      final profil = await _api.getMonProfil();
      _monId = (profil['id'] as num?)?.toInt() ?? 0;
    } catch (_) {}

    await _chargerMessages(scrollToBottom: true);
    if (!mounted) return;
    _connecterWS();

    // Polling toutes les 5 s en secours si le WS tombe
    _pollingTimer = Timer.periodic(
      const Duration(seconds: 5),
      (_) => _chargerMessages(),
    );
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    _ws?.close();
    _ctrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _chargerMessages({bool scrollToBottom = false}) async {
    try {
      final donnees = await _api.getMessages(widget.convId);
      if (!mounted) return;

      final liste = donnees
          .map((j) => MessageChat.fromJson(Map<String, dynamic>.from(j)))
          .toList();

      setState(() {
        // Conserve les messages temporaires (envoi en cours) pour éviter le flash
        final temps = _messages.where((m) => m.isTemp).toList();
        _messages = [...liste, ...temps];
        _chargement = false;
      });

      if (scrollToBottom) _scrollToBottom();
    } catch (e) {
      if (!mounted) return;
      setState(() => _chargement = false);
    }
  }

  Future<void> _connecterWS() async {
    try {
      final token = await TokenStorage.lire();
      if (token == null) return;

      _ws = await WebSocket.connect(
        '$wsUrl/ws/chat/${widget.convId}/?token=$token',
      ).timeout(const Duration(seconds: 10));

      if (!mounted) { _ws?.close(); return; }
      setState(() => _wsConnected = true);

      _ws!.listen(
        (data) {
          if (!mounted) return;
          try {
            final parsed = jsonDecode(data as String) as Map<String, dynamic>;
            if (parsed['type'] == 'message') {
              final msg = MessageChat.fromJson(
                  parsed['message'] as Map<String, dynamic>);
              // N'ajoute que les messages des autres — les miens sont déjà dans la liste
              if (msg.expediteurId != _monId &&
                  !_messages.any((m) => m.id == msg.id)) {
                setState(() => _messages.add(msg));
                _scrollToBottom();
              }
            }
          } catch (_) {}
        },
        onError: (_) {
          if (mounted) setState(() => _wsConnected = false);
        },
        onDone: () {
          if (mounted) setState(() => _wsConnected = false);
        },
      );
    } catch (_) {
      if (mounted) setState(() => _wsConnected = false);
    }
  }

  Future<void> _envoyer() async {
    final texte = _ctrl.text.trim();
    if (texte.isEmpty || _enviando) return;

    _ctrl.clear();

    // Affichage optimiste : on ajoute le message localement avant la réponse API
    final tempId = -DateTime.now().millisecondsSinceEpoch;
    final tempMsg = MessageChat(
      id:               tempId,
      expediteurId:     _monId,
      expediteurNom:    '',
      expediteurPrenom: '',
      contenu:          texte,
      dateEnvoi:        DateTime.now(),
      lu:               false,
      isTemp:           true,
    );

    setState(() {
      _messages.add(tempMsg);
      _enviando = true;
    });
    _scrollToBottom();

    try {
      final result = await _api.envoyerMessage(widget.convId, texte);
      final realMsg = MessageChat.fromJson(
          Map<String, dynamic>.from(result));
      if (!mounted) return;
      setState(() {
        final idx = _messages.indexWhere((m) => m.id == tempId);
        if (idx != -1) _messages[idx] = realMsg;
      });
    } on DioException catch (e) {
      if (!mounted) return;
      setState(() => _messages.removeWhere((m) => m.id == tempId));
      String msg = 'Impossible d\'envoyer le message';
      if (e.response?.data is Map) {
        msg = (e.response!.data as Map)['contenu']?.toString() ??
              (e.response!.data as Map)['detail']?.toString() ?? msg;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg), backgroundColor: kRed),
      );
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F2F5),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 1,
        titleSpacing: 0,
        title: Row(
          children: [
            Container(
              width: 38, height: 38,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [kOrange, kOrangeDark],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  widget.autrePersonneInitiales.isEmpty
                      ? '?' : widget.autrePersonneInitiales,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.autrePersonneNom,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: kTextPrimary,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    _wsConnected ? 'En ligne' : 'Hors ligne',
                    style: TextStyle(
                      fontSize: 11,
                      color: _wsConnected ? kGreen : kTextGray,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: _chargement
                ? const Center(
                    child: CircularProgressIndicator(color: kOrange))
                : _messages.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: const [
                            Icon(Icons.chat_bubble_outline_rounded,
                                size: 48, color: kBorder),
                            SizedBox(height: 12),
                            Text('Aucun message pour l\'instant',
                                style: TextStyle(color: kTextGray, fontSize: 14)),
                            SizedBox(height: 6),
                            Text('Envoie le premier message !',
                                style: TextStyle(color: kTextGray, fontSize: 12)),
                          ],
                        ),
                      )
                    : ListView.builder(
                        controller: _scrollCtrl,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 16),
                        itemCount: _messages.length,
                        itemBuilder: (_, i) {
                          final msg     = _messages[i];
                          final isMine  = msg.expediteurId == _monId ||
                              (msg.isTemp && msg.expediteurId == _monId) ||
                              (msg.isTemp && _monId == 0);
                          final showDate = i == 0 ||
                              !_memJour(_messages[i - 1].dateEnvoi,
                                  msg.dateEnvoi);
                          return Column(
                            children: [
                              if (showDate) _SeparateurDate(date: msg.dateEnvoi),
                              _BulleMEssage(
                                msg:    msg,
                                isMine: isMine,
                              ),
                            ],
                          );
                        },
                      ),
          ),

          Container(
            color: Colors.white,
            padding: EdgeInsets.only(
              left: 12, right: 8, top: 8,
              bottom: MediaQuery.of(context).padding.bottom + 8,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: Container(
                    constraints: const BoxConstraints(maxHeight: 120),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF0F2F5),
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: TextField(
                      controller: _ctrl,
                      maxLines: null,
                      textInputAction: TextInputAction.newline,
                      style: const TextStyle(fontSize: 14, color: kTextPrimary),
                      decoration: const InputDecoration(
                        hintText: 'Écrire un message…',
                        hintStyle: TextStyle(color: kTextGray, fontSize: 14),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(
                            horizontal: 16, vertical: 10),
                      ),
                      onSubmitted: (_) => _envoyer(),
                    ),
                  ),
                ),
                const SizedBox(width: 8),

                GestureDetector(
                  onTap: _enviando ? null : _envoyer,
                  child: Container(
                    width: 44, height: 44,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [kOrange, kOrangeDark],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: kOrange.withValues(alpha: 0.4),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: _enviando
                        ? const Padding(
                            padding: EdgeInsets.all(12),
                            child: CircularProgressIndicator(
                                color: Colors.white, strokeWidth: 2),
                          )
                        : const Icon(Icons.send_rounded,
                            color: Colors.white, size: 20),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  bool _memJour(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}

class _BulleMEssage extends StatelessWidget {
  final MessageChat msg;
  final bool        isMine;

  const _BulleMEssage({required this.msg, required this.isMine});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: EdgeInsets.only(
          top: 3, bottom: 3,
          left:  isMine ? 48 : 0,
          right: isMine ? 0  : 48,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isMine ? kOrange : Colors.white,
          borderRadius: BorderRadius.only(
            topLeft:     const Radius.circular(18),
            topRight:    const Radius.circular(18),
            bottomLeft:  Radius.circular(isMine ? 18 : 4),
            bottomRight: Radius.circular(isMine ? 4  : 18),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 4,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment:
              isMine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              msg.contenu,
              style: TextStyle(
                fontSize: 14,
                color: isMine ? Colors.white : kTextPrimary,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  msg.heureFormatee,
                  style: TextStyle(
                    fontSize: 10,
                    color: isMine
                        ? Colors.white.withValues(alpha: 0.75)
                        : kTextGray,
                  ),
                ),
                if (isMine) ...[
                  const SizedBox(width: 4),
                  Icon(
                    msg.isTemp
                        ? Icons.access_time_rounded
                        : msg.lu
                            ? Icons.done_all_rounded
                            : Icons.check_rounded,
                    size: 12,
                    color: Colors.white.withValues(alpha: 0.75),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SeparateurDate extends StatelessWidget {
  final DateTime date;
  const _SeparateurDate({required this.date});

  String get _label {
    final now   = DateTime.now();
    final aujd  = DateTime(now.year, now.month, now.day);
    final hier  = aujd.subtract(const Duration(days: 1));
    final d     = DateTime(date.year, date.month, date.day);
    if (d == aujd) return 'Aujourd\'hui';
    if (d == hier) return 'Hier';
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          const Expanded(child: Divider(color: kBorder)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(
              _label,
              style: const TextStyle(
                fontSize: 11,
                color: kTextGray,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const Expanded(child: Divider(color: kBorder)),
        ],
      ),
    );
  }
}
