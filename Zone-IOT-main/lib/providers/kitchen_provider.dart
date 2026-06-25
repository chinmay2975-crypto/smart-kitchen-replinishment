import 'package:flutter/foundation.dart';
import '../models/kitchen.dart';
import '../config/api_config.dart';
import '../services/api_service.dart';
import 'auth_provider.dart';

class KitchenProvider with ChangeNotifier {
  final ApiService _api = ApiService();
  AuthProvider? _auth;

  List<Kitchen> _kitchens = [];
  Kitchen? _selectedKitchen;
  bool _isLoading = false;
  String? _error;

  List<Kitchen> get kitchens => _kitchens;
  Kitchen? get selectedKitchen => _selectedKitchen;
  bool get isLoading => _isLoading;
  String? get error => _error;

  void updateAuth(AuthProvider auth) {
    _auth = auth;
    _api.setAccessToken(auth.accessToken);
  }

  Future<void> loadKitchens() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await _api.get(ApiConfig.kitchens);
      if (response['status'] == 'Success') {
        _kitchens = (response['kitchens'] as List)
            .map((k) => Kitchen.fromJson(k))
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

  Future<bool> createKitchen(String name, {String? address}) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await _api.post(ApiConfig.kitchens, body: {
        'name': name,
        'address': address,
      });
      if (response['status'] == 'Success') {
        await loadKitchens();
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

  Future<bool> updateKitchen(int id, {String? name, String? address}) async {
    try {
      final response = await _api.put('${ApiConfig.kitchens}/$id', body: {
        'name': name,
        'address': address,
      });
      if (response['status'] == 'Success') {
        await loadKitchens();
        return true;
      }
      return false;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> deleteKitchen(int id) async {
    try {
      final response = await _api.delete('${ApiConfig.kitchens}/$id');
      if (response['status'] == 'Success') {
        await loadKitchens();
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