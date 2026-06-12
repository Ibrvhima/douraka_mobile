// Backend Render free tier — cold start possible après inactivité (~30-50s)
// Les timeouts dans ApiClient sont calibrés pour ça
const String baseUrl = 'https://douraka-backend.onrender.com';
const String apiUrl  = '$baseUrl/api';
const String wsUrl   = 'wss://douraka-backend.onrender.com';

// Django peut renvoyer les URLs de photo sous plusieurs formes selon la config MEDIA_URL
// On normalise tout ici pour ne pas avoir à gérer ça dans chaque widget
String? normaliserUrlPhoto(String? url) {
  if (url == null || url.isEmpty) return null;
  if (url.startsWith('http'))  return url;
  if (url.startsWith('/'))     return '$baseUrl$url';
  return '$baseUrl/media/$url';
}
