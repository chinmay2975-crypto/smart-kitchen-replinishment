import 'package:dio/dio.dart';

import '../models/cart_item.dart';

class CartService {
  final Dio dio;

  CartService(this.dio);

  Future<List<CartItem>> list() async {
    final response = await dio.get('/api/v1/cart');
    return (response.data as List<dynamic>)
        .map((e) => CartItem.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<CheckoutResult> checkout() async {
    final response = await dio.post('/api/v1/cart/checkout');
    return CheckoutResult.fromJson(response.data as Map<String, dynamic>);
  }

  Future<DeliverResult> deliver(String cartItemId) async {
    final response = await dio.post('/api/v1/cart/$cartItemId/deliver');
    return DeliverResult.fromJson(response.data as Map<String, dynamic>);
  }
}
