class Item {
  final int id;
  final int containerId;
  final String name;
  final String? sku;
  final String? imageUrl;
  final double? thresholdPercent;
  final double? thresholdKg;
  final bool autoReplenish;
  final String? preferredMarketplace;
  final int? cartSizeTrigger;
  final List<SkuMapping>? skuMappings;

  Item({
    required this.id,
    required this.containerId,
    required this.name,
    this.sku,
    this.imageUrl,
    this.thresholdPercent,
    this.thresholdKg,
    this.autoReplenish = false,
    this.preferredMarketplace,
    this.cartSizeTrigger,
    this.skuMappings,
  });

  factory Item.fromJson(Map<String, dynamic> json) {
    return Item(
      id: json['id'] ?? 0,
      containerId: json['container_id'] ?? 0,
      name: json['name'] ?? '',
      sku: json['sku'],
      imageUrl: json['image_url'],
      thresholdPercent: (json['threshold_percent'] as num?)?.toDouble(),
      thresholdKg: (json['threshold_kg'] as num?)?.toDouble(),
      autoReplenish: json['auto_replenish'] ?? false,
      preferredMarketplace: json['preferred_marketplace'],
      cartSizeTrigger: json['cart_size_trigger'],
      skuMappings: json['sku_mappings'] != null
          ? (json['sku_mappings'] as List)
              .map((s) => SkuMapping.fromJson(s))
              .toList()
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
    'name': name,
    'sku': sku,
    'image_url': imageUrl,
    'threshold_percent': thresholdPercent,
    'threshold_kg': thresholdKg,
    'auto_replenish': autoReplenish,
    'preferred_marketplace': preferredMarketplace,
    'cart_size_trigger': cartSizeTrigger,
  };
}

class SkuMapping {
  final int id;
  final int? itemId;
  final String marketplaceName;
  final String marketplaceSku;
  final double? price;
  final String? unit;
  final String? url;

  SkuMapping({
    required this.id,
    this.itemId,
    required this.marketplaceName,
    required this.marketplaceSku,
    this.price,
    this.unit,
    this.url,
  });

  factory SkuMapping.fromJson(Map<String, dynamic> json) {
    return SkuMapping(
      id: json['id'] ?? 0,
      itemId: json['item_id'],
      marketplaceName: json['marketplace_name'] ?? '',
      marketplaceSku: json['marketplace_sku'] ?? '',
      price: (json['price'] as num?)?.toDouble(),
      unit: json['unit'],
      url: json['url'],
    );
  }
}