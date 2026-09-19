import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/cart_item.dart';
import '../../providers/cart_provider.dart';
import '../../providers/devices_provider.dart';
import '../../widgets/app_toast.dart';
import '../../widgets/loading_error_view.dart';

class CartScreen extends StatefulWidget {
  const CartScreen({super.key});

  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  bool _isCheckingOut = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<CartProvider>().load();
    });
  }

  Future<void> _handleCheckout() async {
    setState(() => _isCheckingOut = true);
    final error = await context.read<CartProvider>().checkout();
    if (!mounted) return;
    setState(() => _isCheckingOut = false);
    if (error == null) {
      showAppToast(context, 'Cart checked out — containers restocked!');
      // Checkout now restocks containers immediately server-side, so refresh
      // DevicesProvider the same way _handleDeliver does, or the fill level
      // won't visibly update until the user navigates away and back.
      context.read<DevicesProvider>().load();
    } else {
      showAppToast(context, error, isError: true);
    }
  }

  Future<void> _handleDeliver(String cartItemId) async {
    final error = await context.read<CartProvider>().deliver(cartItemId);
    if (!mounted) return;
    if (error == null) {
      showAppToast(context, 'Delivered! Container restocked.');
      // A delivery changes the container's reading — DevicesProvider is a
      // single shared instance across tabs, so this also refreshes what
      // Dashboard shows without any extra plumbing.
      context.read<DevicesProvider>().load();
    } else {
      showAppToast(context, error, isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Auto-Reorder Cart')),
      body: Consumer<CartProvider>(
        builder: (context, cartProvider, _) {
          return LoadingErrorView(
            isLoading: cartProvider.isLoading && cartProvider.items.isEmpty,
            error: cartProvider.error,
            onRetry: () => cartProvider.load(),
            child: RefreshIndicator(
              onRefresh: () => cartProvider.load(),
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Align(
                    alignment: Alignment.centerRight,
                    child: FilledButton.icon(
                      icon: _isCheckingOut
                          ? const SizedBox(
                              height: 16,
                              width: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.shopping_cart_checkout),
                      label: const Text('Checkout'),
                      onPressed: (cartProvider.pending.isEmpty || _isCheckingOut) ? null : _handleCheckout,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text('Pending', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  cartProvider.pending.isEmpty
                      ? _EmptySection(
                          emoji: '🛒',
                          title: 'Your Cart is Empty',
                          message:
                              "Items will be added automatically when a container's reading drops below its reorder level.",
                        )
                      : Column(
                          children: cartProvider.pending.map((item) => _CartItemTile(item: item)).toList(),
                        ),
                  const SizedBox(height: 24),
                  Text('Placed Orders', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  cartProvider.placed.isEmpty
                      ? const _EmptySection(message: 'No orders placed yet.')
                      : Column(
                          children: cartProvider.placed
                              .map((item) => _CartItemTile(item: item, onDeliver: () => _handleDeliver(item.cartItemId)))
                              .toList(),
                        ),
                  const SizedBox(height: 24),
                  Text('Delivered', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  cartProvider.delivered.isEmpty
                      ? const _EmptySection(message: 'No deliveries completed yet.')
                      : Column(
                          children: cartProvider.delivered.map((item) => _CartItemTile(item: item)).toList(),
                        ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _CartItemTile extends StatelessWidget {
  final CartItem item;
  final VoidCallback? onDeliver;

  const _CartItemTile({required this.item, this.onDeliver});

  @override
  Widget build(BuildContext context) {
    final (emoji, label, color) = switch (item.status) {
      CartItemStatus.pendingCart => ('📦', 'Pending', const Color(0xFFF59E0B)),
      CartItemStatus.placed => ('🚚', 'Placed', const Color(0xFF3B82F6)),
      CartItemStatus.delivered => ('✅', 'Delivered', const Color(0xFF10B981)),
    };

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Text(emoji, style: const TextStyle(fontSize: 28)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item.itemName, style: const TextStyle(fontWeight: FontWeight.w600)),
                  Text('Quantity: ${item.quantity}', style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                  // Checkout now restocks immediately, so new orders never
                  // carry an estimated_delivery — this branch only fires for
                  // legacy 'placed' rows from before that change.
                  if (item.estimatedDelivery != null)
                    Text(
                      'Delivering by ${item.estimatedDelivery}',
                      style: const TextStyle(fontSize: 12, color: Color(0xFF3B82F6)),
                    ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(color: color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(999)),
                  child: Text(label, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600)),
                ),
                if (onDeliver != null) ...[
                  const SizedBox(height: 8),
                  FilledButton(
                    style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4)),
                    onPressed: onDeliver,
                    child: const Text('Mark Delivered', style: TextStyle(fontSize: 12)),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptySection extends StatelessWidget {
  final String? emoji;
  final String? title;
  final String message;

  const _EmptySection({this.emoji, this.title, required this.message});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Column(
        children: [
          if (emoji != null) Text(emoji!, style: const TextStyle(fontSize: 40)),
          if (title != null) ...[
            const SizedBox(height: 8),
            Text(title!, style: const TextStyle(fontWeight: FontWeight.bold)),
          ],
          const SizedBox(height: 4),
          Text(message, textAlign: TextAlign.center, style: TextStyle(color: Colors.grey.shade600)),
        ],
      ),
    );
  }
}
