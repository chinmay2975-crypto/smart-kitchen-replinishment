import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/kitchen.dart';
import '../../models/container.dart';
import '../../providers/container_provider.dart';
import '../../widgets/container_status_card.dart';

class KitchenDetailScreen extends StatefulWidget {
  final Kitchen kitchen;

  const KitchenDetailScreen({super.key, required this.kitchen});

  @override
  State<KitchenDetailScreen> createState() => _KitchenDetailScreenState();
}

class _KitchenDetailScreenState extends State<KitchenDetailScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ContainerProvider>().loadContainers(widget.kitchen.id);
    });
  }

  void _showAddContainerDialog() {
    final labelController = TextEditingController();
    final capacityController = TextEditingController(text: '1.0');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add Container'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: labelController,
              decoration: const InputDecoration(
                labelText: 'Container Label',
                hintText: 'e.g., Rice Container',
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: capacityController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Capacity (kg)',
                hintText: '1.0',
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
              if (labelController.text.isNotEmpty) {
                await context.read<ContainerProvider>().createContainer(
                      widget.kitchen.id,
                      labelController.text,
                      capacityKg: double.tryParse(capacityController.text) ?? 1.0,
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
        title: Text(widget.kitchen.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: _showAddContainerDialog,
          ),
        ],
      ),
      body: Consumer<ContainerProvider>(
        builder: (context, provider, _) {
          if (provider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (provider.containers.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.inventory_2_outlined,
                      size: 80, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  Text('No containers yet',
                      style: theme.textTheme.titleLarge),
                  const SizedBox(height: 8),
                  Text('Tap + to add your first container',
                      style: TextStyle(color: Colors.grey[600])),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () =>
                provider.loadContainers(widget.kitchen.id),
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: provider.containers.length,
              itemBuilder: (context, index) {
                final container = provider.containers[index];
                return ContainerStatusCard(container: container);
              },
            ),
          );
        },
      ),
    );
  }
}