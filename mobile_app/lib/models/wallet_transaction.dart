class WalletTransaction {
  final String type; // "credit" (top-up) or "debit" (wallet-paid checkout)
  final double amount;
  final String? date;
  final String? number;
  final String description;

  WalletTransaction({
    required this.type,
    required this.amount,
    required this.date,
    required this.number,
    required this.description,
  });

  bool get isCredit => type == 'credit';

  factory WalletTransaction.fromJson(Map<String, dynamic> json) {
    return WalletTransaction(
      type: json['type'] as String,
      amount: (json['amount'] as num).toDouble(),
      date: json['date'] as String?,
      number: json['number'] as String?,
      description: json['description'] as String,
    );
  }
}
