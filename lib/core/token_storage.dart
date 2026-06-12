import 'package:flutter_secure_storage/flutter_secure_storage.dart';

// Gère la sauvegarde sécurisée du token JWT ET du rôle utilisateur.
// flutter_secure_storage utilise Keychain (iOS) / Keystore (Android).
// Le rôle est stocké pour éviter un appel API au démarrage.

class TokenStorage {
  static const _storage        = FlutterSecureStorage();
  static const _cleToken       = 'token_jwt';
  static const _cleRole        = 'role_utilisateur'; // 'client' | 'prestataire' | 'admin'
  static const _cleOnboarding  = 'onboarding_vu';    // flag : l'intro a-t-elle été montrée ?

  // ── Token JWT ──────────────────────────────────────────────────────────────

  static Future<void> sauvegarder(String token) =>
      _storage.write(key: _cleToken, value: token);

  static Future<String?> lire() => _storage.read(key: _cleToken);

  // ── Rôle utilisateur ───────────────────────────────────────────────────────

  static Future<void> sauvegarderRole(String role) =>
      _storage.write(key: _cleRole, value: role);

  static Future<String?> lireRole() => _storage.read(key: _cleRole);

  // ── Suppression (déconnexion) ──────────────────────────────────────────────
  // Supprime les deux clés en même temps

  static Future<void> supprimer() async {
    await Future.wait([
      _storage.delete(key: _cleToken),
      _storage.delete(key: _cleRole),
    ]);
  }

  // ── Vérification rapide de connexion ──────────────────────────────────────

  static Future<bool> estConnecte() async {
    final token = await lire();
    return token != null && token.isNotEmpty;
  }

  // ── Onboarding ─────────────────────────────────────────────────────────────
  // Retourne true si l'utilisateur a déjà vu l'écran d'introduction

  static Future<bool> onboardingVu() async {
    final val = await _storage.read(key: _cleOnboarding);
    return val == 'true';
  }

  static Future<void> marquerOnboardingVu() =>
      _storage.write(key: _cleOnboarding, value: 'true');
}
