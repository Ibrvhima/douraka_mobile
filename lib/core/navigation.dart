import 'package:flutter/material.dart';

// On a besoin d'accéder au Navigator depuis ApiClient (couche service),
// qui n'a pas de BuildContext. La solution standard Flutter : une GlobalKey
// instanciée ici et injectée dans MaterialApp.navigatorKey.
//
// NOTE : une seule instance doit exister dans toute l'app — ne pas en recréer
// une dans les tests sans réinitialiser ApiClient en conséquence.
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
