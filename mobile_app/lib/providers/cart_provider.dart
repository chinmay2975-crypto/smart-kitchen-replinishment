import 'package:flutter/foundation.dart';

import '../models/cart_item.dart';
import '../services/cart_service.dart';

class CartProvider extends ChangeNotifier {
  final CartService cartService;

  CartProvider({required this.cartService});

  List<CartItem> items = [];
  bool isLoading = false;
  String? error;

  List<CartItem> get pending =>
      items.where((i) => i.status == CartItemStatus.pendingCart).toList();
  List<CartItem> get placed => items.where((i) => i.status == CartItemStatus.placed).toList();
  List<CartItem> get delivered =>
      items.where((i) => i.status == CartItemStatus.delivered).toList();

  Future<void> load() async {
    isLoading = true;
    error = null;
    notifyListeners();

    try {
      items = await cartService.list();
    } catch (_) {
      error = 'Failed to load cart';
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<String?> checkout() async {
    try {
      await cartService.checkout();
      await load();
      return null;
    } catch (_) {
      return 'Checkout failed';
    }
  }

  Future<String?> deliver(String cartItemId) async {
    try {
      await cartService.deliver(cartItemId);
      await load();
      return null;
    } catch (_) {
      return 'Failed to mark delivered';
    }
  }
}
