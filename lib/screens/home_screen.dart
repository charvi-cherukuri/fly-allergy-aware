import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/app_state.dart';
import 'emergency_screen.dart';
import 'profile_tab_screen.dart';
import 'scanner_screen.dart';
import 'travel_screen.dart';

/// The tab shell.
///
/// Four tabs, in the order the trip happens: Travel is where you choose a
/// flight and then watch the cabin around you, Scan is the thing you do dozens
/// of times a day, Emergency is what you open when something has gone wrong,
/// and Profile holds the allergen list every other screen is computed from.
///
/// Emergency keeps a fixed, memorable position so it can be found without
/// reading the labels — the only state that matters when someone is opening it
/// under stress.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _index = 0;

  static const _tabs = <Widget>[
    TravelScreen(),
    ScannerScreen(),
    EmergencyScreen(),
    ProfileTabScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final app = context.watch<AppState>();

    // A badge on Emergency when an auto-injector has expired or is close to it.
    // Expiry is otherwise silent — nothing tells you but the label.
    final expiring =
        app.epiPens.where((p) => p.isExpired || p.isExpiringSoon).length;

    return Scaffold(
      body: IndexedStack(index: _index, children: _tabs),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        height: 68,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        destinations: [
          const NavigationDestination(
            icon: Icon(Icons.flight_outlined),
            selectedIcon: Icon(Icons.flight_rounded),
            label: 'Travel',
          ),
          const NavigationDestination(
            icon: Icon(Icons.center_focus_weak_rounded),
            selectedIcon: Icon(Icons.center_focus_strong_rounded),
            label: 'Scan',
          ),
          NavigationDestination(
            icon: Badge(
              isLabelVisible: expiring > 0,
              backgroundColor: scheme.error,
              label: Text('$expiring'),
              child: const Icon(Icons.medical_services_outlined),
            ),
            selectedIcon: Badge(
              isLabelVisible: expiring > 0,
              backgroundColor: scheme.error,
              label: Text('$expiring'),
              child: const Icon(Icons.medical_services_rounded),
            ),
            label: 'Emergency',
          ),
          const NavigationDestination(
            icon: Icon(Icons.person_outline_rounded),
            selectedIcon: Icon(Icons.person_rounded),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}
