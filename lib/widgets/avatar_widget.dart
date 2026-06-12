import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../core/api_client.dart';
import '../theme.dart';

// Widget avatar réutilisable — affiche la photo de profil ou les initiales,
// avec un bouton caméra en bas-droite pour changer la photo.
// Utilisé dans ProfilScreen (client) et ProfilPrestataireScreen (prestataire).

class AvatarWidget extends StatefulWidget {
  final String?      photoUrl;
  final String       initiales;
  final ApiClient    api;
  final VoidCallback onPhotoChanged;

  const AvatarWidget({
    required this.initiales,
    required this.api,
    required this.onPhotoChanged,
    this.photoUrl,
    super.key,
  });

  @override
  State<AvatarWidget> createState() => _AvatarWidgetState();
}

class _AvatarWidgetState extends State<AvatarWidget> {
  bool _uploading = false;

  // Ouvre un bottom sheet pour choisir la source de l'image
  Future<void> _choisirPhoto() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Poignée
              Container(
                width: 36, height: 4,
                decoration: BoxDecoration(
                  color: kBorder, borderRadius: BorderRadius.circular(2)),
              ),
              const SizedBox(height: 16),
              const Text(
                'Changer la photo de profil',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: kTextPrimary),
              ),
              const SizedBox(height: 12),
              ListTile(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                leading: Container(
                  width: 40, height: 40,
                  decoration: const BoxDecoration(color: kOrangeLight, shape: BoxShape.circle),
                  child: const Icon(Icons.photo_library_outlined, color: kOrange),
                ),
                title: const Text('Galerie de photos',
                    style: TextStyle(fontWeight: FontWeight.w600)),
                onTap: () => Navigator.pop(ctx, ImageSource.gallery),
              ),
              ListTile(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                leading: Container(
                  width: 40, height: 40,
                  decoration: const BoxDecoration(color: kOrangeLight, shape: BoxShape.circle),
                  child: const Icon(Icons.camera_alt_outlined, color: kOrange),
                ),
                title: const Text('Prendre une photo',
                    style: TextStyle(fontWeight: FontWeight.w600)),
                onTap: () => Navigator.pop(ctx, ImageSource.camera),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );

    if (source == null || !mounted) return;

    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: source,
      maxWidth: 800,
      maxHeight: 800,
      imageQuality: 85,
    );

    if (picked == null || !mounted) return;

    setState(() => _uploading = true);

    try {
      final resultat = await widget.api.uploadPhoto(File(picked.path));
      debugPrint('Photo uploadée → ${resultat['photo']}');

      // Vider le cache réseau Flutter pour que la nouvelle photo s'affiche immédiatement
      if (widget.photoUrl != null) {
        PaintingBinding.instance.imageCache.evict(
          NetworkImage(widget.photoUrl!),
        );
      }

      widget.onPhotoChanged();
    } catch (e) {
      debugPrint('Erreur upload photo: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Impossible d\'envoyer la photo : $e'),
            backgroundColor: kRed,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 96, height: 96,
      child: Stack(
        children: [
          // ── Cercle avatar ────────────────────────────────────────────────
          Container(
            width: 96, height: 96,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [kOrange, kOrangeDark],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: kOrange.withValues(alpha: 0.3),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: _uploading
                ? const Padding(
                    padding: EdgeInsets.all(28),
                    child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2.5),
                  )
                : (widget.photoUrl != null && widget.photoUrl!.isNotEmpty)
                    ? ClipOval(
                        child: Image.network(
                          // Paramètre v= pour contourner le cache CDN/réseau après upload
                          widget.photoUrl!.contains('?')
                              ? widget.photoUrl!
                              : '${widget.photoUrl}?v=${DateTime.now().millisecondsSinceEpoch}',
                          width: 96, height: 96,
                          fit: BoxFit.cover,
                          loadingBuilder: (ctx, child, progress) => progress == null
                              ? child
                              : const Center(
                                  child: CircularProgressIndicator(
                                      color: Colors.white, strokeWidth: 2)),
                          errorBuilder: (context, error, _) {
                            debugPrint('Erreur chargement photo: $error');
                            return _initiales();
                          },
                        ),
                      )
                    : _initiales(),
          ),

          // ── Bouton caméra (overlay bas-droite) ────────────────────────
          Positioned(
            right: 0, bottom: 0,
            child: GestureDetector(
              onTap: _uploading ? null : _choisirPhoto,
              child: Container(
                width: 30, height: 30,
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  border: Border.all(color: kOrange, width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.12),
                      blurRadius: 4,
                    ),
                  ],
                ),
                child: const Icon(Icons.camera_alt, size: 15, color: kOrange),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _initiales() {
    return Center(
      child: Text(
        widget.initiales.isEmpty ? '?' : widget.initiales,
        style: const TextStyle(
            color: Colors.white, fontSize: 30, fontWeight: FontWeight.w700),
      ),
    );
  }
}
