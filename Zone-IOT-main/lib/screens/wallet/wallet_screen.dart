import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/wallet_provider.dart';
import '../../models/wallet.dart';

class WalletScreen extends StatefulWidget {
  const WalletScreen({super.key});

  @override
  State<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends State<WalletScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<WalletProvider>().loadWallet();
    });
  }

  void _showTopupDialog() {
    final amountController = TextEditingController();
    final descriptionController = TextEditingController();
    final presetAmounts = [100.0, 200.0, 500.0, 1000.0, 2000.0, 5000.0];

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Add Funds'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Quick amounts:',
                style: TextStyle(fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: presetAmounts.map((amount) {
                  return ActionChip(
                    label: Text('₹${amount.toInt()}'),
                    onPressed: () {
                      amountController.text = amount.toInt().toString();
                      setDialogState(() {});
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: amountController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Amount (₹)',
                  prefixText: '₹ ',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: descriptionController,
                decoration: const InputDecoration(
                  labelText: 'Description (optional)',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            FilledButton.icon(
              onPressed: () async {
                final amount = double.tryParse(amountController.text);
                if (amount == null || amount <= 0) return;

                final provider = ctx.read<WalletProvider>();
                final success = await provider.topup(
                  amount,
                  description: descriptionController.text.isNotEmpty
                      ? descriptionController.text
                      : null,
                );

                if (ctx.mounted) {
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(this.context).showSnackBar(
                    SnackBar(
                      content: Text(
                        success
                            ? '₹${amount.toStringAsFixed(2)} added to wallet!'
                            : 'Top-up failed: ${provider.error ?? "Unknown error"}',
                      ),
                      backgroundColor: success ? Colors.green : Colors.red,
                    ),
                  );
                }
              },
              icon: const Icon(Icons.payment),
              label: const Text('Add Funds'),
            ),
          ],
        ),
      ),
    );
  }

  void _showAutoTopupDialog() {
    final thresholdController = TextEditingController();
    final amountController = TextEditingController();
    final wallet = context.read<WalletProvider>().wallet;

    if (wallet.autoTopupThreshold != null) {
      thresholdController.text = wallet.autoTopupThreshold!.toStringAsFixed(0);
    }
    if (wallet.autoTopupAmount != null) {
      amountController.text = wallet.autoTopupAmount!.toStringAsFixed(0);
    }

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Auto Top-Up'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Automatically add funds when balance drops below a threshold.',
              style: TextStyle(fontSize: 13, color: Colors.grey),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: thresholdController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Threshold (₹)',
                hintText: 'e.g. 500',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: amountController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Top-up Amount (₹)',
                hintText: 'e.g. 2000',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Leave both empty to disable auto top-up',
              style: TextStyle(fontSize: 12, color: Colors.grey[500]),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              final threshold = double.tryParse(thresholdController.text);
              final amount = double.tryParse(amountController.text);

              final provider = ctx.read<WalletProvider>();
              final success = await provider.updateAutoTopup(
                threshold: threshold,
                amount: amount,
              );

              if (ctx.mounted) {
                Navigator.pop(ctx);
                ScaffoldMessenger.of(this.context).showSnackBar(
                  SnackBar(
                    content: Text(
                      success
                          ? 'Auto top-up settings saved'
                          : 'Failed to save settings',
                    ),
                  ),
                );
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Wallet'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: _showAutoTopupDialog,
            tooltip: 'Auto Top-Up',
          ),
        ],
      ),
      body: Consumer<WalletProvider>(
        builder: (context, provider, _) {
          if (provider.isLoading && provider.wallet.id == 0) {
            return const Center(child: CircularProgressIndicator());
          }

          final wallet = provider.wallet;

          return RefreshIndicator(
            onRefresh: () => provider.loadWallet(),
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Balance Card
                Card(
                  elevation: 2,
                  child: Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          theme.colorScheme.primary,
                          theme.colorScheme.primary.withOpacity(0.8),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      children: [
                        Text(
                          'Wallet Balance',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.9),
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          wallet.formattedBalance,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 36,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            onPressed: _showTopupDialog,
                            icon: const Icon(Icons.add),
                            label: const Text('Add Funds'),
                            style: FilledButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor: theme.colorScheme.primary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 8),

                // Auto Top-Up indicator
                if (wallet.autoTopupThreshold != null &&
                    wallet.autoTopupAmount != null)
                  Card(
                    child: ListTile(
                      leading: Icon(
                        Icons.autorenew,
                        color: theme.colorScheme.primary,
                      ),
                      title: const Text('Auto Top-Up Active'),
                      subtitle: Text(
                        'Adds ₹${wallet.autoTopupAmount!.toStringAsFixed(0)} when balance < ₹${wallet.autoTopupThreshold!.toStringAsFixed(0)}',
                      ),
                      trailing: IconButton(
                        icon: const Icon(Icons.edit_outlined),
                        onPressed: _showAutoTopupDialog,
                      ),
                    ),
                  ),
                const SizedBox(height: 16),

                // Transactions Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Recent Transactions',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    TextButton.icon(
                      onPressed: () => provider.loadWallet(),
                      icon: const Icon(Icons.refresh, size: 18),
                      label: const Text('Refresh'),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                if (provider.transactions.isEmpty)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        children: [
                          Icon(
                            Icons.account_balance_wallet_outlined,
                            size: 48,
                            color: Colors.grey[400],
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'No transactions yet',
                            style: TextStyle(color: Colors.grey[600]),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Add funds to get started',
                            style: TextStyle(
                              color: Colors.grey[500],
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  ...provider.transactions.map(
                    (tx) => _TransactionTile(transaction: tx),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _TransactionTile extends StatelessWidget {
  final WalletTransaction transaction;

  const _TransactionTile({required this.transaction});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: transaction.isCredit
              ? Colors.green[50]
              : Colors.orange[50],
          child: Icon(
            transaction.isCredit ? Icons.arrow_downward : Icons.arrow_upward,
            color: transaction.isCredit ? Colors.green : Colors.orange,
            size: 20,
          ),
        ),
        title: Text(
          transaction.description ?? (transaction.isCredit ? 'Top-up' : 'Order Payment'),
          style: const TextStyle(fontWeight: FontWeight.w500),
        ),
        subtitle: Text(
          _formatDate(transaction.createdAt),
          style: TextStyle(fontSize: 12, color: Colors.grey[500]),
        ),
        trailing: Text(
          transaction.formattedAmount,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: transaction.isCredit ? Colors.green : Colors.red,
            fontSize: 15,
          ),
        ),
      ),
    );
  }

  String _formatDate(String dateStr) {
    try {
      final date = DateTime.parse(dateStr);
      final now = DateTime.now();
      final diff = now.difference(date);

      if (diff.inMinutes < 1) return 'Just now';
      if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
      if (diff.inHours < 24) return '${diff.inHours}h ago';
      if (diff.inDays < 7) return '${diff.inDays}d ago';
      return '${date.day}/${date.month}/${date.year}';
    } catch (e) {
      return dateStr;
    }
  }
}