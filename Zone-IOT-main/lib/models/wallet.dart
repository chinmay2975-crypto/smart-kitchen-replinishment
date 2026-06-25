import 'dart:convert';

class WalletTransaction {
  final int id;
  final int walletId;
  final String type; // 'credit' or 'debit'
  final double amount;
  final double balanceBefore;
  final double balanceAfter;
  final String? description;
  final String? referenceType;
  final int? referenceId;
  final String status;
  final String createdAt;

  WalletTransaction({
    required this.id,
    required this.walletId,
    required this.type,
    required this.amount,
    required this.balanceBefore,
    required this.balanceAfter,
    this.description,
    this.referenceType,
    this.referenceId,
    required this.status,
    required this.createdAt,
  });

  factory WalletTransaction.fromJson(Map<String, dynamic> json) {
    return WalletTransaction(
      id: json['id'] ?? 0,
      walletId: json['wallet_id'] ?? 0,
      type: json['type'] ?? 'credit',
      amount: (json['amount'] ?? 0).toDouble(),
      balanceBefore: (json['balance_before'] ?? 0).toDouble(),
      balanceAfter: (json['balance_after'] ?? 0).toDouble(),
      description: json['description'],
      referenceType: json['reference_type'],
      referenceId: json['reference_id'],
      status: json['status'] ?? 'completed',
      createdAt: json['created_at'] ?? '',
    );
  }

  bool get isCredit => type == 'credit';
  bool get isDebit => type == 'debit';

  String get formattedAmount {
    final prefix = isCredit ? '+' : '-';
    return '$prefix₹${amount.toStringAsFixed(2)}';
  }
}

class Wallet {
  final int id;
  final double balance;
  final String currency;
  final double? autoTopupThreshold;
  final double? autoTopupAmount;
  final String createdAt;
  final String updatedAt;

  Wallet({
    required this.id,
    required this.balance,
    required this.currency,
    this.autoTopupThreshold,
    this.autoTopupAmount,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Wallet.fromJson(Map<String, dynamic> json) {
    return Wallet(
      id: json['id'] ?? 0,
      balance: (json['balance'] ?? 0).toDouble(),
      currency: json['currency'] ?? 'INR',
      autoTopupThreshold: json['auto_topup_threshold']?.toDouble(),
      autoTopupAmount: json['auto_topup_amount']?.toDouble(),
      createdAt: json['created_at'] ?? '',
      updatedAt: json['updated_at'] ?? '',
    );
  }

  String get formattedBalance => '₹${balance.toStringAsFixed(2)}';
}