import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/kitchen_provider.dart';
import '../../models/kitchen.dart';
import 'kitchen_detail_screen.dart';

class KitchenListScreen extends StatefulWidget {
  const KitchenListScreen({super.key});

  @override
  State<KitchenListScreen> createState() => _KitchenListScreenState();
}

class _KitchenListScreenState extends State<KitchenListScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<KitchenProvider>().loadKitchens();
    });
  }

  void _showAddKitchenDialog() {
    final nameController = TextEditingController();
    final addressController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add Kitchen'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: 'Kitchen Name',
                hintText: 'e.g., Home Kitchen',
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: addressController,
              decoration: const InputDecoration(
                labelText: 'Address (optional)',
              ),
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
              if (nameController.text.isNotEmpty) {
                await context.read<KitchenProvider>().createKitchen(
                      nameController.text,
                      address: addressController.text,
                    );
                if (ctx.mounted) Navigator.pop(ctx);
              }
            },
            child: const Text('Add'),
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
        title: const Text('My Kitchens'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: _showAddKitchenDialog,
          ),
        ],
      ),
      body: Consumer<KitchenProvider>(
        builder: (context, provider, _) {
          if (provider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (provider.kitchens.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.kitchen_outlined,
                      size: 80, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  Text('No kitchens yet',
                      style: theme.textTheme.titleLarge),
                  const SizedBox(height: 8),
                  Text('Tap + to add your first kitchen',
                      style: TextStyle(color: Colors.grey[600])),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () => provider.loadKitchens(),
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: provider.kitchens.length,
              itemBuilder: (context, index) {
                final kitchen = provider.kitchens[index];
                return _KitchenCard(kitchen: kitchen);
              },
            ),
          );
        },
      ),
    );
  }
}

class _KitchenCard extends StatelessWidget {
  final Kitchen kitchen;

  const _KitchenCard({required this.kitchen});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: CircleAvatar(
          backgroundColor: theme.colorScheme.primaryContainer,
          child: Icon(
            Icons.kitchen,
            color: theme.colorScheme.primary,
          ),
        ),
        title: Text(
          kitchen.name,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        subtitle: kitchen.address != null
            ? Text(kitchen.address!, maxLines: 1)
            : null,
        trailing: const Icon(Icons.chevron_right),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => KitchenDetailScreen(kitchen: kitchen),
            ),
          );
        },
      ),
    );
  }
}