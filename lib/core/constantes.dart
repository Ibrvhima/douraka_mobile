// Backend hébergé sur Render (plan gratuit).
// À savoir : le cold start peut prendre 30–50 secondes après inactivité.
// Les timeouts dans ApiClient sont calibrés pour absorber ça sans
// bloquer l'interface trop longtemps.
const String baseUrl = 'https://douraka-backend.onrender.com';
const String apiUrl  = '$baseUrl/api';

// WebSocket séparé de apiUrl : Django Channels tourne sur le même hôte
// mais n'est pas sous le préfixe /api — le routing ASGI est différent.
const String wsUrl   = 'wss://douraka-backend.onrender.com';

// Django peut renvoyer les URLs de photos sous trois formes selon la config
// MEDIA_URL et selon qu'on est en dev ou en prod sur Render.
// Cette fonction centralise la normalisation pour ne pas éparpiller
// des if(startsWith('http')) partout dans les widgets.
String? normaliserUrlPhoto(String? url) {
  if (url == null || url.isEmpty) return null;
  if (url.startsWith('http'))  return url;
  if (url.startsWith('/'))     return '$baseUrl$url';
  return '$baseUrl/media/$url';
}
