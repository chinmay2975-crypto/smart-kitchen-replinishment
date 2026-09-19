enum CartItemStatus { pendingCart, placed, delivered }

CartItemStatus cartItemStatusFromString(String value) {
  switch (value) {
    case 'pending_cart':
      return CartItemStatus.pendingCart;
    case 'placed':
      return CartItemStatus.placed;
    case 'delivered':
      return CartItemStatus.delivered;
    default:
      throw ArgumentError('Unknown cart item status: $value');
  }
}

class CartItem {
  final String cartItemId;
  final String containerId;
  final String itemName;
  final double quantity;
  final CartItemStatus status;
  final String? estimatedDelivery;
  final String createdAt;

  CartItem({
    required this.cartItemId,
    required this.containerId,
    required this.itemName,
    required this.quantity,
    required this.status,
    required this.estimatedDelivery,
    required this.createdAt,
  });

  factory CartItem.fromJson(Map<String, dynamic> json) {
    return CartItem(
      cartItemId: json['cart_item_id'] as String,
      containerId: json['container_id'] as String,
      itemName: json['item_name'] as String,
      quantity: (json['quantity'] as num).toDouble(),
      status: cartItemStatusFromString(json['status'] as String),
      estimatedDelivery: json['estimated_delivery'] as String?,
      createdAt: json['created_at'] as String,
    );
  }
}

class CheckoutResult {
  final String message;
  final int itemsPlaced;
  final String? estimatedDelivery;

  CheckoutResult({
    required this.message,
    required this.itemsPlaced,
    required this.estimatedDelivery,
  });

  factory CheckoutResult.fromJson(Map<String, dynamic> json) {
    return CheckoutResult(
      message: json['message'] as String,
      itemsPlaced: json['items_placed'] as int,
      estimatedDelivery: json['estimated_delivery'] as String?,
    );
  }
}

class DeliverResult {
  final String message;
  final String containerId;
  final double newQuantity;

  DeliverResult({
    required this.message,
    required this.containerId,
    required this.newQuantity,
  });

  factory DeliverResult.fromJson(Map<String, dynamic> json) {
    return DeliverResult(
      message: json['message'] as String,
      containerId: json['container_id'] as String,
      newQuantity: (json['new_quantity'] as num).toDouble(),
    );
  }
}
