class Order {
  final int id;
  final int userId;
  final int? kitchenId;
  final String marketplace;
  final String? marketplaceOrderId;
  final String status;
  final double? totalAmount;
  final String? createdAt;
  final List<OrderItem>? items;

  Order({
    required this.id,
    required this.userId,
    this.kitchenId,
    this.marketplace = 'amazon',
    this.marketplaceOrderId,
    this.status = 'pending',
    this.totalAmount,
    this.createdAt,
    this.items,
  });

  factory Order.fromJson(Map<String, dynamic> json) {
    return Order(
      id: json['id'] ?? 0,
      userId: json['user_id'] ?? 0,
      kitchenId: json['kitchen_id'],
      marketplace: json['marketplace'] ?? 'amazon',
      marketplaceOrderId: json['marketplace_order_id'],
      status: json['status'] ?? 'pending',
      totalAmount: (json['total_amount'] as num?)?.toDouble(),
      createdAt: json['created_at'],
      items: json['items'] != null
          ? (json['items'] as List).map((i) => OrderItem.fromJson(i)).toList()
          : null,
    );
  }

  String get statusLabel {
    switch (status) {
      case 'pending': return 'Pending';
      case 'approved': return 'Approved';
      case 'placed': return 'Placed on Amazon';
      case 'shipped': return 'Shipped';
      case 'delivered': return 'Delivered';
      case 'cancelled': return 'Cancelled';
      default: return status;
    }
  }
}

class OrderItem {
  final int id;
  final String? itemName;
  final String? sku;
  final double? quantity;
  final double? price;

  OrderItem({
    required this.id,
    this.itemName,
    this.sku,
    this.quantity,
    this.price,
  });

  factory OrderItem.fromJson(Map<String, dynamic> json) {
    return OrderItem(
      id: json['id'] ?? 0,
      itemName: json['item_name'],
      sku: json['sku'],
      quantity: (json['quantity'] as num?)?.toDouble(),
      price: (json['price'] as num?)?.toDouble(),
    );
  }
}