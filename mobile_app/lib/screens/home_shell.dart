import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/cart_provider.dart';
import 'cart/cart_screen.dart';
import 'dashboard/dashboard_screen.dart';
import 'devices/devices_screen.dart';
import 'profile/profile_screen.dart';

/// 4-tab shell (Dashboard/My Devices/Cart/Profile), mirroring the web app's
/// tab-toggle SPA structure via an IndexedStack so tab state persists across
/// switches.
///
/// Each tab screen owns its own Scaffold/AppBar (e.g. DevicesScreen's claim
/// button, Cart's checkout button) — this shell only supplies the shared
/// bottom navigation bar around them.
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

  static const _screens = [
    DashboardScreen(),
    DevicesScreen(),
    CartScreen(),
    ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final pendingCount = context.watch<CartProvider>().pending.length;

    return Scaffold(
      body: IndexedStack(index: _index, children: _screens),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: [
          const NavigationDestination(icon: Icon(Icons.dashboard), label: 'Dashboard'),
          const NavigationDestination(icon: Icon(Icons.devices), label: 'My Devices'),
          NavigationDestination(
            icon: pendingCount > 0
                ? Badge(label: Text('$pendingCount'), child: const Icon(Icons.shopping_cart))
                : const Icon(Icons.shopping_cart),
            label: 'Cart',
          ),
          const NavigationDestination(icon: Icon(Icons.person), label: 'Profile'),
        ],
      ),
    );
  }
}
