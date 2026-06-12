# Douraka — Application Mobile

> **"Douraka"** signifie *trouver* en langue locale guinéenne.  
> L'app connecte clients et prestataires de services à Conakry, Guinée 🇬🇳

---

## Présentation

Douraka est une application mobile Flutter qui permet aux habitants de Conakry de trouver rapidement un artisan de confiance (plombier, électricien, maçon, peintre…) et de gérer leurs demandes de service de bout en bout.

Côté prestataire, l'app permet de recevoir et gérer les demandes clients, envoyer des devis et communiquer en temps réel.

---

## Fonctionnalités

### Client
- Recherche de prestataires par catégorie et quartier
- Envoi de demandes avec titre, description, adresse et flag urgence
- Suivi des demandes par statut (En attente / En cours / Terminées)
- Chat en temps réel avec le prestataire
- Notation et avis après service
- Notifications push

### Prestataire
- Tableau de bord avec statistiques (demandes reçues, acceptées, terminées)
- Gestion des demandes avec onglets par statut
- Envoi de devis
- Toggle disponibilité on/off
- Profil professionnel avec photo

### Admin (web)
- Validation / rejet des comptes prestataires
- Statistiques globales de la plateforme
- Gestion des utilisateurs et demandes

---

## Stack technique

| Couche | Technologie |
|--------|-------------|
| Mobile | Flutter 3.x / Dart |
| Backend | Django 4.2 + Django REST Framework |
| Base de données | MySQL 8 |
| Auth | JWT (SimpleJWT) |
| Chat | WebSocket (Django Channels) + polling fallback |
| Stockage fichiers | Django Media (Render) |
| Déploiement backend | Render.com |

---

## Installation

### Prérequis

- Flutter SDK ≥ 3.10
- Dart ≥ 3.10
- Android Studio ou VS Code
- Un émulateur ou un téléphone physique

### Cloner et lancer

```bash
git clone https://github.com/Ibrvhima/douraka_mobile.git
cd douraka_mobile
flutter pub get
flutter run
```

> ⚠️ Le backend tourne sur Render free tier. Il peut mettre **30 à 50 secondes** à répondre au premier appel après une période d'inactivité (cold start). C'est normal.

---

## Configuration

Le backend est déjà configuré et déployé. Les URLs sont dans `lib/core/constantes.dart` :

```dart
const String baseUrl = 'https://douraka-backend.onrender.com';
const String apiUrl  = '$baseUrl/api';
const String wsUrl   = 'wss://douraka-backend.onrender.com';
```

Si tu veux faire tourner le backend en local, clone le repo backend et configure un `.env` avec tes variables MySQL.

---

## Structure du projet

```
lib/
├── core/           # ApiClient, TokenStorage, constantes, navigation
├── models/         # Demande, Prestataire, Utilisateur, Message, etc.
├── screens/
│   ├── admin/      # Écrans admin (stats, prestataires, clients)
│   ├── chat/       # Chat en temps réel
│   ├── prestataire/ # Dashboard, demandes reçues, profil pro
│   └── ...         # Login, register, home, profil client, etc.
├── widgets/        # AvatarWidget, AppBarActions (réutilisables)
└── theme.dart      # Couleurs, typographie (Poppins)
```

---

## Comptes de test

| Rôle | Email | Mot de passe |
|------|-------|--------------|
| Client | *(créer un compte)* | — |
| Prestataire | *(créer un compte)* | — |
| Admin | *(contacter le mainteneur)* | — |

---

## Ce qui reste à faire

- [ ] Notifications push (Firebase FCM) quand l'app est fermée
- [ ] Hébergement des médias sur Cloudinary (photos stables en prod)
- [ ] Pagination de la liste des prestataires
- [ ] Tests unitaires et widget tests
- [ ] Publication Play Store / App Store

---

## Auteur

Projet développé dans le cadre d'un projet académique.  
Backend repo : [groupe3-services](https://github.com/Ibrvhima/groupe3-services)

---

## Licence

Usage académique — pas de licence open source pour l'instant.
