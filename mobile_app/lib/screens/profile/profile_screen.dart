import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/user_profile.dart';
import '../../models/wallet_transaction.dart';
import '../../providers/auth_provider.dart';
import '../../providers/profile_provider.dart';
import '../../providers/wallet_provider.dart';
import '../../widgets/app_toast.dart';
import '../../widgets/loading_error_view.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ProfileProvider>().load();
      context.read<WalletProvider>().load();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Logout',
            onPressed: () => context.read<AuthProvider>().logout(),
          ),
        ],
      ),
      body: Consumer<ProfileProvider>(
        builder: (context, profileProvider, _) {
          return LoadingErrorView(
            isLoading: profileProvider.isLoading,
            error: profileProvider.error,
            onRetry: () => profileProvider.load(),
            child: profileProvider.profile == null
                ? const SizedBox.shrink()
                : _ProfileFields(profile: profileProvider.profile!),
          );
        },
      ),
    );
  }
}

class _ProfileFields extends StatelessWidget {
  final UserProfile profile;

  const _ProfileFields({required this.profile});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Center(
          child: Column(
            children: [
              const CircleAvatar(radius: 40, child: Icon(Icons.person, size: 40)),
              const SizedBox(height: 12),
              Text(profile.name, style: Theme.of(context).textTheme.titleLarge),
              Text(profile.email, style: TextStyle(color: Colors.grey.shade600)),
            ],
          ),
        ),
        const SizedBox(height: 24),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _ProfileRow(label: 'Phone', value: profile.phone ?? 'N/A'),
                _ProfileRow(label: 'Role', value: profile.role),
                _ProfileRow(label: 'Household', value: profile.household?.name ?? 'N/A'),
                _ProfileRow(label: 'User ID', value: profile.userId, isMono: true),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        const _WalletSection(),
      ],
    );
  }
}

class _WalletSection extends StatefulWidget {
  const _WalletSection();

  @override
  State<_WalletSection> createState() => _WalletSectionState();
}

class _WalletSectionState extends State<_WalletSection> {
  final _amountController = TextEditingController();
  bool _isSubmitting = false;

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _handleTopup() async {
    final amount = double.tryParse(_amountController.text);
    if (amount == null || amount <= 0) {
      showAppToast(context, 'Enter a valid positive amount', isError: true);
      return;
    }

    setState(() => _isSubmitting = true);
    final error = await context.read<WalletProvider>().topup(amount);
    if (!mounted) return;
    setState(() => _isSubmitting = false);

    if (error == null) {
      final balance = context.read<WalletProvider>().balance;
      showAppToast(context, '₹${amount.toStringAsFixed(2)} added — new balance ₹${balance.toStringAsFixed(2)}');
      _amountController.clear();
    } else {
      showAppToast(context, error, isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<WalletProvider>(
      builder: (context, wallet, _) {
        // Wallet not enabled server-side (400) — hide the section entirely,
        // same behavior as frontend/js/profile.js's loadWallet().
        if (!wallet.isEnabled) return const SizedBox.shrink();
        if (wallet.isLoading && wallet.transactions.isEmpty) {
          return const Padding(
            padding: EdgeInsets.all(24),
            child: Center(child: CircularProgressIndicator()),
          );
        }

        return Column(
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.account_balance_wallet, color: Theme.of(context).colorScheme.primary),
                            const SizedBox(width: 8),
                            const Text('Zoho Wallet', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                          ],
                        ),
                        Text(
                          '₹${wallet.balance.toStringAsFixed(2)}',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Prepaid credit applied automatically to future orders when it fully covers the total.',
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _amountController,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            decoration: const InputDecoration(
                              hintText: 'Amount to add',
                              border: OutlineInputBorder(),
                              isDense: true,
                              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton.icon(
                          onPressed: _isSubmitting ? null : _handleTopup,
                          icon: _isSubmitting
                              ? const SizedBox(
                                  width: 14,
                                  height: 14,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                )
                              : const Icon(Icons.add, size: 18),
                          label: const Text('Add Credit'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.receipt_long, color: Theme.of(context).colorScheme.primary),
                        const SizedBox(width: 8),
                        const Text('Payment History', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (wallet.transactions.isEmpty)
                      Text('No transactions yet.', style: TextStyle(color: Colors.grey.shade500))
                    else
                      ...wallet.transactions.map((tx) => _TransactionRow(tx: tx)),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _TransactionRow extends StatelessWidget {
  final WalletTransaction tx;

  const _TransactionRow({required this.tx});

  @override
  Widget build(BuildContext context) {
    final color = tx.isCredit ? Colors.green.shade600 : Colors.red.shade600;
    final sign = tx.isCredit ? '+' : '-';
    final dateStr = _formatDate(tx.date);
    final subtitle = [?tx.number, ?dateStr].join(' • ');

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(tx.isCredit ? Icons.arrow_downward : Icons.arrow_upward, color: color, size: 18),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(tx.description, style: const TextStyle(fontWeight: FontWeight.w500)),
                if (subtitle.isNotEmpty)
                  Text(subtitle, style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
              ],
            ),
          ),
          Text(
            '$sign₹${tx.amount.toStringAsFixed(2)}',
            style: TextStyle(fontWeight: FontWeight.w600, color: color),
          ),
        ],
      ),
    );
  }

  static String? _formatDate(String? isoDate) {
    if (isoDate == null) return null;
    final parsed = DateTime.tryParse(isoDate);
    if (parsed == null) return isoDate;
    return '${parsed.year}-${parsed.month.toString().padLeft(2, '0')}-${parsed.day.toString().padLeft(2, '0')}';
  }
}

class _ProfileRow extends StatelessWidget {
  final String label;
  final String value;
  final bool isMono;

  const _ProfileRow({required this.label, required this.value, this.isMono = false});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(label, style: TextStyle(color: Colors.grey.shade600)),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(fontFamily: isMono ? 'monospace' : null, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }
}
