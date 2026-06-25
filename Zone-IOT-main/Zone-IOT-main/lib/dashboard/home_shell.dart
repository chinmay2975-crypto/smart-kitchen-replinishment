import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'bloc/dashboard_bloc.dart';
import 'bloc/dashboard_event.dart';
import 'bloc/dashboard_state.dart';

import '../../auth/repository/auth_repository.dart';
import '../../auth/screens/opening_page.dart';

import 'devices/screens/devices_page.dart';
import 'profile/screens/profile_page.dart';
import 'wallet/screens/wallet_page.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int index = 0;

  final pages = const [DevicesPage(), WalletPage(), ProfilePage()];

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => DashboardBloc(AuthRepository())..add(DashboardStarted()),
      child: BlocListener<DashboardBloc, DashboardState>(
        listener: (context, state) {
          if (state is DashboardUnauthenticated) {
            Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(builder: (_) => const OpeningPage()),
              (_) => false,
            );
          }
        },
        child: Scaffold(
          body: pages[index],
          bottomNavigationBar: BottomNavigationBar(
            currentIndex: index,
            onTap: (i) => setState(() => index = i),
            items: const [
              BottomNavigationBarItem(
                icon: Icon(Icons.medical_services),
                label: "Devices",
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.account_balance_wallet),
                label: "Wallet",
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.person),
                label: "Profile",
              ),
            ],
          ),
        ),
      ),
    );
  }
}
