import 'package:flutter/material.dart';
import '../theme.dart';
import 'home_screen.dart';
import 'mes_demandes_screen.dart';
import 'profil_screen.dart';

// Shell CLIENT — le conteneur principal de l'app une fois connecté.
// Il gère la barre de navigation du bas et garde les 3 écrans en vie
// simultanément grâce à IndexedStack.
//
// Pourquoi IndexedStack plutôt que reconstruire l'écran à chaque changement d'onglet ?
// Parce qu'on ne veut pas perdre l'état des écrans (scroll, données chargées, etc.)
// quand l'utilisateur navigue entre onglets. IndexedStack garde tous les widgets
// dans l'arbre, seul l'index visible change.

class ShellScreen extends StatefulWidget {
  const ShellScreen({super.key});

  @override
  State<ShellScreen> createState() => _ShellScreenState();
}

class _ShellScreenState extends State<ShellScreen> {
  int _ongletActif = 0; // 0 = Accueil, 1 = Demandes, 2 = Profil

  // Liste statique des écrans — on les instancie une seule fois ici.
  // Si on les créait dans build(), ils seraient reconstruits à chaque changement
  // d'onglet, ce qui annulerait l'intérêt de l'IndexedStack.
  static const List<Widget> _ecrans = [
    HomeScreen(),
    MesDemandesScreen(),
    ProfilScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // IndexedStack affiche l'enfant à l'index _ongletActif
      // et "cache" les autres (ils restent montés mais invisibles).
      body: IndexedStack(index: _ongletActif, children: _ecrans),

      // NavigationBar (Material 3) plutôt que BottomNavigationBar :
      // meilleur support du thème, meilleure lisibilité sur les écrans haute densité.
      // indicatorColor crée le fond coloré derrière l'icône sélectionnée.
      bottomNavigationBar: NavigationBar(
        selectedIndex: _ongletActif,
        onDestinationSelected: (i) => setState(() => _ongletActif = i),
        backgroundColor: Colors.white,
        indicatorColor: kOrangeLight, // halo orange derrière l'icône active
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        destinations: const [
          // selectedIcon différent de icon : l'icône "filled" quand actif,
          // "outlined" sinon — convention Material 3 pour indiquer la sélection.
          NavigationDestination(
            icon:         Icon(Icons.search_outlined),
            selectedIcon: Icon(Icons.search, color: kOrange),
            label: 'Accueil',
          ),
          NavigationDestination(
            icon:         Icon(Icons.assignment_outlined),
            selectedIcon: Icon(Icons.assignment, color: kOrange),
            label: 'Demandes',
          ),
          NavigationDestination(
            icon:         Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person, color: kOrange),
            label: 'Profil',
          ),
        ],
      ),
    );
  }
}
