import 'package:dio/dio.dart';

import '../models/wallet_transaction.dart';

class WalletService {
  final Dio dio;

  WalletService(this.dio);

  Future<double> getBalance() async {
    final response = await dio.get('/api/v1/wallet/balance');
    return (response.data['balance'] as num).toDouble();
  }

  Future<double> topup(double amount, {String? description}) async {
    final response = await dio.post('/api/v1/wallet/topup', data: {
      'amount': amount,
      'description': description,
    });
    return (response.data['new_balance'] as num).toDouble();
  }

  Future<List<WalletTransaction>> getTransactions() async {
    final response = await dio.get('/api/v1/wallet/transactions');
    return (response.data as List<dynamic>)
        .map((e) => WalletTransaction.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}
