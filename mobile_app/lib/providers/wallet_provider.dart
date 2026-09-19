import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../models/wallet_transaction.dart';
import '../services/wallet_service.dart';

class WalletProvider extends ChangeNotifier {
  final WalletService walletService;

  WalletProvider({required this.walletService});

  // Mirrors frontend/js/profile.js: a 400 means the Zoho wallet feature
  // itself is turned off server-side, not a real error — hide the section
  // rather than showing an error for a feature that isn't enabled.
  bool isEnabled = true;
  bool isLoading = false;
  String? error;
  double balance = 0;
  List<WalletTransaction> transactions = [];

  Future<void> load() async {
    isLoading = true;
    error = null;
    notifyListeners();

    try {
      balance = await walletService.getBalance();
      isEnabled = true;
      transactions = await walletService.getTransactions();
    } on DioException catch (e) {
      if (e.response?.statusCode == 400) {
        isEnabled = false;
      } else {
        error = 'Failed to load wallet';
      }
    } catch (_) {
      error = 'Failed to load wallet';
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<String?> topup(double amount) async {
    try {
      balance = await walletService.topup(amount);
      transactions = await walletService.getTransactions();
      notifyListeners();
      return null;
    } catch (_) {
      return 'Failed to add credit';
    }
  }
}
