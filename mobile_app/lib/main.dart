import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'config/theme.dart';
import 'providers/auth_provider.dart';
import 'providers/cart_provider.dart';
import 'providers/devices_provider.dart';
import 'providers/profile_provider.dart';
import 'providers/wallet_provider.dart';
import 'screens/auth/welcome_screen.dart';
import 'screens/home_shell.dart';
import 'services/api_client.dart';
import 'services/auth_service.dart';
import 'services/cart_service.dart';
import 'services/demo_service.dart';
import 'services/device_service.dart';
import 'services/profile_service.dart';
import 'services/reading_service.dart';
import 'services/token_storage.dart';
import 'services/wallet_service.dart';

void main() {
  runApp(const SmartKitchenApp());
}

class SmartKitchenApp extends StatefulWidget {
  const SmartKitchenApp({super.key});

  @override
  State<SmartKitchenApp> createState() => _SmartKitchenAppState();
}

class _SmartKitchenAppState extends State<SmartKitchenApp> {
  late final ApiClient _apiClient;
  late final AuthProvider _authProvider;
  late final ProfileProvider _profileProvider;
  late final DevicesProvider _devicesProvider;
  late final CartProvider _cartProvider;
  late final DeviceService _deviceService;
  late final ReadingService _readingService;
  late final CartService _cartService;
  late final DemoService _demoService;
  late final WalletProvider _walletProvider;

  @override
  void initState() {
    super.initState();
    final tokenStorage = TokenStorage();

    // onAuthExpired only reads _authProvider when actually invoked (after a
    // failed token refresh), by which point it's already assigned below —
    // capturing it here just defers the read, it doesn't evaluate it now.
    _apiClient = ApiClient(
      tokenStorage: tokenStorage,
      onAuthExpired: () => _authProvider.logout(),
    );
    _authProvider = AuthProvider(
      authService: AuthService(_apiClient.dio),
      tokenStorage: tokenStorage,
    );
    _profileProvider = ProfileProvider(profileService: ProfileService(_apiClient.dio));
    _deviceService = DeviceService(_apiClient.dio);
    _readingService = ReadingService(_apiClient.dio);
    _cartService = CartService(_apiClient.dio);
    _demoService = DemoService(_apiClient.dio);
    _devicesProvider = DevicesProvider(deviceService: _deviceService);
    _cartProvider = CartProvider(cartService: _cartService);
    _walletProvider = WalletProvider(walletService: WalletService(_apiClient.dio));

    _authProvider.bootstrap();
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: _authProvider),
        ChangeNotifierProvider.value(value: _profileProvider),
        ChangeNotifierProvider.value(value: _devicesProvider),
        ChangeNotifierProvider.value(value: _cartProvider),
        ChangeNotifierProvider.value(value: _walletProvider),
        Provider.value(value: _deviceService),
        Provider.value(value: _readingService),
        Provider.value(value: _cartService),
        Provider.value(value: _demoService),
      ],
      child: MaterialApp(
        title: 'Smart Kitchen',
        theme: AppTheme.light,
        darkTheme: AppTheme.dark,
        home: Consumer<AuthProvider>(
          builder: (context, auth, _) {
            switch (auth.status) {
              case AuthStatus.unknown:
                return const Scaffold(body: Center(child: CircularProgressIndicator()));
              case AuthStatus.authenticated:
                return const HomeShell();
              case AuthStatus.unauthenticated:
                return const WelcomeScreen();
            }
          },
        ),
      ),
    );
  }
}
