import 'package:flutter/material.dart';
import '../../theme.dart';
import 'dashboard_prestataire_screen.dart';
import 'demandes_recues_screen.dart';
import 'profil_prestataire_screen.dart';

// Shell PRESTATAIRE — 3 onglets : Tableau de bord, Demandes, Mon profil
// Messages et Notifications accessibles via les icônes du header

class ShellPrestataireScreen extends StatefulWidget {
  const ShellPrestataireScreen({super.key});

  @override
  State<ShellPrestataireScreen> createState() => _ShellPrestataireScreenState();
}

class _ShellPrestataireScreenState extends State<ShellPrestataireScreen> {
  int _ongletActif = 0;

  static const List<Widget> _ecrans = [
    DashboardPrestataireScreen(),
    DemandesRecuesScreen(),
    ProfilPrestataireScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _ongletActif, children: _ecrans),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _ongletActif,
        onDestinationSelected: (i) => setState(() => _ongletActif = i),
        backgroundColor: Colors.white,
        indicatorColor: kOrangeLight,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        destinations: const [
          NavigationDestination(
            icon:         Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard, color: kOrange),
            label: 'Tableau de bord',
          ),
          NavigationDestination(
            icon:         Icon(Icons.assignment_outlined),
            selectedIcon: Icon(Icons.assignment, color: kOrange),
            label: 'Demandes',
          ),
          NavigationDestination(
            icon:         Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person, color: kOrange),
            label: 'Mon profil',
          ),
        ],
      ),
    );
  }
}
