import 'package:flutter/foundation.dart';
import '../models/container.dart';
import '../models/item.dart';
import '../models/order.dart';
import '../config/api_config.dart';
import '../services/api_service.dart';
import 'auth_provider.dart';

class ContainerProvider with ChangeNotifier {
  final ApiService _api = ApiService();
  AuthProvider? _auth;

  List<Container> _containers = [];
  List<Item> _items = [];
  List<Order> _orders = [];
  Container? _selectedContainer;
  bool _isLoading = false;
  String? _error;

  List<Container> get containers => _containers;
  List<Item> get items => _items;
  List<Order> get orders => _orders;
  Container? get selectedContainer => _selectedContainer;
  bool get isLoading => _isLoading;
  String? get error => _error;

  void updateAuth(AuthProvider auth) {
    _auth = auth;
    _api.setAccessToken(auth.accessToken);
  }

  // ==================== CONTAINERS ====================

  Future<void> loadContainers(int kitchenId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await _api.get(
        '${ApiConfig.kitchens}/$kitchenId/containers',
      );
      if (response['status'] == 'Success') {
        _containers = (response['containers'] as List)
            .map((c) => Container.fromJson(c))
            .toList();
      } else {
        _error = response['message'];
      }
    } catch (e) {
      _error = e.toString();
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<bool> createContainer(int kitchenId, String label,
      {double? capacityKg, int? deviceId}) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await _api.post(
        '${ApiConfig.kitchens}/$kitchenId/containers',
        body: {
          'label': label,
          'capacity_kg': capacityKg ?? 1.0,
          'device_id': deviceId,
        },
      );
      if (response['status'] == 'Success') {
        await loadContainers(kitchenId);
        return true;
      } else {
        _error = response['message'];
        _isLoading = false;
        notifyListeners();
        return false;
      }
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // ==================== ITEMS ====================

  Future<void> loadItems(int containerId) async {
    try {
      final response = await _api.get(
        '${ApiConfig.containers}/$containerId/items',
      );
      if (response['status'] == 'Success') {
        _items = (response['items'] as List)
            .map((i) => Item.fromJson(i))
            .toList();
        notifyListeners();
      }
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  Future<Item?> createItem(int containerId, String name,
      {double? thresholdPercent,
      bool autoReplenish = false,
      String? sku}) async {
    try {
      final response = await _api.post(
        '${ApiConfig.containers}/$containerId/items',
        body: {
          'name': name,
          'threshold_percent': thresholdPercent ?? 20.0,
          'auto_replenish': autoReplenish,
          'sku': sku,
        },
      );
      if (response['status'] == 'Success') {
        await loadItems(containerId);
        return Item.fromJson(response['item']);
      }
      return null;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return null;
    }
  }

  // ==================== ORDERS ====================

  Future<void> loadOrders() async {
    try {
      final response = await _api.get(ApiConfig.orders);
      if (response['status'] == 'Success') {
        _orders = (response['orders'] as List)
            .map((o) => Order.fromJson(o))
            .toList();
        notifyListeners();
      }
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  // ==================== CART ====================

  Future<Map<String, dynamic>> getCart() async {
    try {
      final response = await _api.get(ApiConfig.cart);
      return response;
    } catch (e) {
      return {'status': 'Failed', 'message': e.toString()};
    }
  }

  Future<bool> checkout() async {
    try {
      final response = await _api.post('${ApiConfig.cart}/checkout');
      if (response['status'] == 'Success') {
        await loadOrders();
        return true;
      }
      return false;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }
}