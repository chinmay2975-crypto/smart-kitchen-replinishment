import 'package:flutter/foundation.dart';
import '../models/wallet.dart';
import '../services/api_service.dart';
import '../config/api_config.dart';
import 'auth_provider.dart';

class WalletProvider extends ChangeNotifier {
  final ApiService _apiService = ApiService();
  final AuthProvider? _authProvider;

  Wallet _wallet = Wallet(
    id: 0,
    balance: 0.0,
    currency: 'INR',
    createdAt: '',
    updatedAt: '',
  );
  List<WalletTransaction> _transactions = [];
  bool _isLoading = false;
  String? _error;

  WalletProvider([this._authProvider]) {
    if (_authProvider != null) {
      _apiService.setAccessToken(_authProvider!.accessToken);
    }
  }

  Wallet get wallet => _wallet;
  List<WalletTransaction> get transactions => _transactions;
  bool get isLoading => _isLoading;
  String? get error => _error;

  void updateAuth(AuthProvider auth) {
    _apiService.setAccessToken(auth.accessToken);
  }

  Future<void> loadWallet() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await _apiService.get('${ApiConfig.baseUrl}/wallet');

      if (response['status'] == 'OK' && response['wallet'] != null) {
        _wallet = Wallet.fromJson(response['wallet']);
        _transactions = (response['transactions'] as List?)
                ?.map((t) => WalletTransaction.fromJson(t as Map<String, dynamic>))
                .toList() ??
            [];
      } else {
        _error = response['message'] ?? 'Failed to load wallet';
      }
    } catch (e) {
      _error = e.toString();
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<bool> topup(double amount, {String? description}) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await _apiService.post(
        '${ApiConfig.baseUrl}/wallet/topup',
        body: {
          'amount': amount,
          if (description != null) 'description': description,
        },
      );

      if (response['status'] == 'OK') {
        _wallet = Wallet(
          id: _wallet.id,
          balance: (response['balance'] as num).toDouble(),
          currency: response['currency'] ?? 'INR',
          autoTopupThreshold: _wallet.autoTopupThreshold,
          autoTopupAmount: _wallet.autoTopupAmount,
          createdAt: _wallet.createdAt,
          updatedAt: DateTime.now().toIso8601String(),
        );

        if (response['transaction'] != null) {
          _transactions.insert(
            0,
            WalletTransaction.fromJson(response['transaction'] as Map<String, dynamic>),
          );
        }

        _isLoading = false;
        notifyListeners();
        return true;
      } else {
        _error = response['message'] ?? 'Top-up failed';
        _isLoading = false;
        notifyListeners();
        return false;
      }
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> updateAutoTopup({double? threshold, double? amount}) async {
    try {
      final response = await _apiService.put(
        '${ApiConfig.baseUrl}/wallet/auto-topup',
        body: {
          'threshold': threshold,
          'amount': amount,
        },
      );

      if (response['status'] == 'OK') {
        _wallet = Wallet(
          id: _wallet.id,
          balance: _wallet.balance,
          currency: _wallet.currency,
          autoTopupThreshold: threshold,
          autoTopupAmount: amount,
          createdAt: _wallet.createdAt,
          updatedAt: DateTime.now().toIso8601String(),
        );
        notifyListeners();
        return true;
      }
      return false;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }
}