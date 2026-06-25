import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';

class ApiService {
  String? _accessToken;

  void setAccessToken(String? token) {
    _accessToken = token;
  }

  Map<String, String> get _headers => {
    'Content-Type': 'application/json',
    if (_accessToken != null) 'Authorization': 'Bearer $_accessToken',
  };

  Future<Map<String, dynamic>> get(String endpoint, {Map<String, String>? queryParams}) async {
    try {
      var uri = Uri.parse(endpoint);
      if (queryParams != null) {
        uri = uri.replace(queryParameters: queryParams);
      }
      final response = await http.get(uri, headers: _headers)
          .timeout(ApiConfig.requestTimeout);
      return _handleResponse(response);
    } on SocketException {
      return {'status': 'Failed', 'message': 'No internet connection'};
    } catch (e) {
      return {'status': 'Failed', 'message': e.toString()};
    }
  }

  Future<Map<String, dynamic>> post(String endpoint, {Map<String, dynamic>? body}) async {
    try {
      final response = await http.post(
        Uri.parse(endpoint),
        headers: _headers,
        body: body != null ? jsonEncode(body) : null,
      ).timeout(ApiConfig.requestTimeout);
      return _handleResponse(response);
    } on SocketException {
      return {'status': 'Failed', 'message': 'No internet connection'};
    } catch (e) {
      return {'status': 'Failed', 'message': e.toString()};
    }
  }

  Future<Map<String, dynamic>> put(String endpoint, {Map<String, dynamic>? body}) async {
    try {
      final response = await http.put(
        Uri.parse(endpoint),
        headers: _headers,
        body: body != null ? jsonEncode(body) : null,
      ).timeout(ApiConfig.requestTimeout);
      return _handleResponse(response);
    } on SocketException {
      return {'status': 'Failed', 'message': 'No internet connection'};
    } catch (e) {
      return {'status': 'Failed', 'message': e.toString()};
    }
  }

  Future<Map<String, dynamic>> delete(String endpoint) async {
    try {
      final response = await http.delete(
        Uri.parse(endpoint),
        headers: _headers,
      ).timeout(ApiConfig.requestTimeout);
      return _handleResponse(response);
    } on SocketException {
      return {'status': 'Failed', 'message': 'No internet connection'};
    } catch (e) {
      return {'status': 'Failed', 'message': e.toString()};
    }
  }

  Map<String, dynamic> _handleResponse(http.Response response) {
    try {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return data;
    } catch (e) {
      return {
        'status': 'Failed',
        'message': 'Invalid response from server',
        'status_code': response.statusCode,
      };
    }
  }
}