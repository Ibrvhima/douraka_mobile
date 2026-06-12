import 'package:flutter/material.dart';
import '../../theme.dart';
import 'dashboard_admin_screen.dart';
import 'prestataires_admin_screen.dart';
import 'clients_admin_screen.dart';
import 'demandes_admin_screen.dart';

// Shell de l'espace ADMIN
// 4 onglets : Statistiques, Prestataires, Clients, Demandes

class ShellAdminScreen extends StatefulWidget {
  const ShellAdminScreen({super.key});

  @override
  State<ShellAdminScreen> createState() => _ShellAdminScreenState();
}

class _ShellAdminScreenState extends State<ShellAdminScreen> {
  int _ongletActif = 0;

  final List<Widget> _ecrans = const [
    DashboardAdminScreen(),
    PrestatairesAdminScreen(),
    ClientsAdminScreen(),
    DemandesAdminScreen(),
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
            icon:         Icon(Icons.bar_chart_outlined),
            selectedIcon: Icon(Icons.bar_chart, color: kOrange),
            label: 'Stats',
          ),
          NavigationDestination(
            icon:         Icon(Icons.handyman_outlined),
            selectedIcon: Icon(Icons.handyman, color: kOrange),
            label: 'Prestataires',
          ),
          NavigationDestination(
            icon:         Icon(Icons.people_outline_rounded),
            selectedIcon: Icon(Icons.people_rounded, color: kOrange),
            label: 'Clients',
          ),
          NavigationDestination(
            icon:         Icon(Icons.assignment_outlined),
            selectedIcon: Icon(Icons.assignment, color: kOrange),
            label: 'Demandes',
          ),
        ],
      ),
    );
  }
}
