import 'package:flutter/material.dart';

// Nécessaire pour naviguer depuis ApiClient (couche service, pas de BuildContext)
// Injecté dans MaterialApp.navigatorKey
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
