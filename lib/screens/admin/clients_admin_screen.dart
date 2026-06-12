import 'package:flutter/material.dart';
import '../../core/api_client.dart';
import '../../theme.dart';

// ADMIN — liste des clients inscrits sur la plateforme

class ClientsAdminScreen extends StatefulWidget {
  const ClientsAdminScreen({super.key});

  @override
  State<ClientsAdminScreen> createState() => _ClientsAdminScreenState();
}

class _ClientsAdminScreenState extends State<ClientsAdminScreen> {
  final _api     = ApiClient();
  List<dynamic> _clients     = [];
  List<dynamic> _filtres     = [];
  bool          _chargement  = true;
  bool          _erreur      = false;

  final _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _charger();
    _searchCtrl.addListener(_filtrer);
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _charger() async {
    setState(() { _chargement = true; _erreur = false; });
    try {
      final data = await _api.getClientsAdmin();
      if (!mounted) return;
      setState(() {
        _clients    = data;
        _chargement = false;
      });
      _filtrer();
    } catch (e) {
      debugPrint('Erreur clients admin: $e');
      if (!mounted) return;
      setState(() { _chargement = false; _erreur = true; });
    }
  }

  void _filtrer() {
    final q = _searchCtrl.text.toLowerCase();
    setState(() {
      _filtres = _clients.where((c) {
        final nom    = '${c['nom'] ?? ''} ${c['prenom'] ?? ''}'.toLowerCase();
        final email  = (c['email'] ?? '').toString().toLowerCase();
        return q.isEmpty || nom.contains(q) || email.contains(q);
      }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBackground,
      appBar: AppBar(
        title: Text('Clients (${_clients.length})'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh_rounded), onPressed: _charger),
        ],
      ),
      body: Column(
        children: [
          // Barre de recherche
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: TextField(
              controller: _searchCtrl,
              decoration: InputDecoration(
                hintText: 'Rechercher un client…',
                hintStyle: const TextStyle(fontSize: 13, color: kTextGray),
                prefixIcon: const Icon(Icons.search, size: 20, color: kTextGray),
                suffixIcon: _searchCtrl.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.close, size: 18, color: kTextGray),
                        onPressed: () { _searchCtrl.clear(); _filtrer(); })
                    : null,
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
                filled: true, fillColor: kBackground,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
            ),
          ),

          // Liste
          Expanded(
            child: _chargement
                ? const Center(child: CircularProgressIndicator(color: kOrange))
                : _erreur
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.wifi_off_rounded, size: 52, color: kBorder),
                            const SizedBox(height: 12),
                            const Text('Problème de connexion', style: TextStyle(color: kTextGray)),
                            const SizedBox(height: 16),
                            TextButton.icon(onPressed: _charger,
                                icon: const Icon(Icons.refresh, color: kOrange),
                                label: const Text('Réessayer', style: TextStyle(color: kOrange))),
                          ],
                        ),
                      )
                    : _filtres.isEmpty
                        ? const Center(child: Text('Aucun client trouvé', style: TextStyle(color: kTextGray)))
                        : RefreshIndicator(
                            color: kOrange,
                            onRefresh: _charger,
                            child: ListView.builder(
                              padding: const EdgeInsets.all(12),
                              itemCount: _filtres.length,
                              itemBuilder: (_, i) => _CarteClient(
                                data: Map<String, dynamic>.from(_filtres[i])),
                            ),
                          ),
          ),
        ],
      ),
    );
  }
}

// ── Carte client ──────────────────────────────────────────────────────────
class _CarteClient extends StatelessWidget {
  final Map<String, dynamic> data;

  const _CarteClient({required this.data});

  @override
  Widget build(BuildContext context) {
    final nom      = '${data['nom'] ?? ''} ${data['prenom'] ?? ''}'.trim();
    final email    = data['email']?.toString() ?? '';
    final telephone = data['telephone']?.toString();
    final initiales = nom.isNotEmpty
        ? nom.split(' ').map((w) => w.isEmpty ? '' : w[0]).take(2).join('').toUpperCase()
        : '?';

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 6)],
      ),
      child: Row(
        children: [
          Container(
            width: 42, height: 42,
            decoration: const BoxDecoration(color: kOrangeLight, shape: BoxShape.circle),
            child: Center(child: Text(initiales,
                style: const TextStyle(color: kOrange, fontWeight: FontWeight.w700, fontSize: 15))),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(nom.isEmpty ? 'Client' : nom,
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: kTextPrimary)),
                Text(email, style: const TextStyle(fontSize: 12, color: kTextGray)),
                if (telephone != null && telephone.isNotEmpty)
                  Text(telephone, style: const TextStyle(fontSize: 12, color: kTextGray)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(color: kOrangeLight, borderRadius: BorderRadius.circular(10)),
            child: const Text('Client', style: TextStyle(fontSize: 11, color: kOrange, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}
