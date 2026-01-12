import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/constants/api_constants.dart';
import '../../core/constants/app_constants.dart';

class ApiService {
  late final Dio _dio;
  static ApiService? _instance;

  ApiService._() {
    debugPrint('[API] Initializing with baseUrl: ${ApiConstants.baseUrl}');
    _dio = Dio(BaseOptions(
      baseUrl: ApiConstants.baseUrl,
      connectTimeout: ApiConstants.timeout,
      receiveTimeout: ApiConstants.timeout,
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
    ));

    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        debugPrint('[API] REQUEST: ${options.method} ${options.uri}');
        final prefs = await SharedPreferences.getInstance();
        final token = prefs.getString(AppConstants.tokenKey);
        if (token != null) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        return handler.next(options);
      },
      onResponse: (response, handler) {
        debugPrint('[API] RESPONSE: ${response.statusCode}');
        return handler.next(response);
      },
      onError: (error, handler) {
        debugPrint('[API] ERROR: ${error.type} - ${error.message}');
        debugPrint('[API] ERROR response: ${error.response?.data}');
        if (error.response?.statusCode == 401) {
          // Handle unauthorized
        }
        return handler.next(error);
      },
    ));
  }

  static ApiService get instance {
    _instance ??= ApiService._();
    return _instance!;
  }

  // Auth
  Future<Response> login(String email, String password) async {
    return _dio.post(ApiConstants.login, data: {
      'email': email,
      'password': password,
    });
  }

  Future<Response> logout() async {
    return _dio.post(ApiConstants.logout);
  }

  Future<Response> getUser() async {
    return _dio.get(ApiConstants.user);
  }

  // Deliveries
  Future<Response> getMyActiveDelivery() async {
    return _dio.get(ApiConstants.myActiveDelivery);
  }

  Future<Response> getMyDeliveries() async {
    return _dio.get(ApiConstants.myDeliveries);
  }

  Future<Response> getDeliveryDetails(int deliveryId) async {
    return _dio.get('${ApiConstants.deliveries}/$deliveryId');
  }

  Future<Response> startDelivery(int deliveryId) async {
    return _dio.post('${ApiConstants.deliveries}/$deliveryId/start');
  }

  Future<Response> completeDelivery(int deliveryId) async {
    return _dio.post('${ApiConstants.deliveries}/$deliveryId/complete');
  }

  Future<Response> deliverOrder(int deliveryId, int orderId, {double? amountCollected}) async {
    return _dio.post(
      '${ApiConstants.deliveries}/$deliveryId/orders/$orderId/deliver',
      data: amountCollected != null ? {'amount_collected': amountCollected} : null,
    );
  }

  Future<Response> partialDelivery(int deliveryId, int orderId, Map<String, dynamic> data) async {
    debugPrint('[API] Partial delivery data: $data');
    return _dio.post(
      '${ApiConstants.deliveries}/$deliveryId/orders/$orderId/partial',
      data: data,
    );
  }

  Future<Response> failOrder(int deliveryId, int orderId, String failureReason) async {
    return _dio.post(
      '${ApiConstants.deliveries}/$deliveryId/orders/$orderId/fail',
      data: {'reason': failureReason},
    );
  }

  Future<Response> postponeOrder(int deliveryId, int orderId, {String? notes}) async {
    return _dio.post(
      '${ApiConstants.deliveries}/$deliveryId/orders/$orderId/postpone',
      data: {'notes': notes},
    );
  }

  Future<Response> processReturns(int deliveryId) async {
    return _dio.post('${ApiConstants.deliveries}/$deliveryId/process-returns');
  }

  Future<Response> getDeliveryOrderItems(int deliveryId, int deliveryOrderId) async {
    debugPrint('[API] Getting items for delivery $deliveryId, order $deliveryOrderId');
    return _dio.get('${ApiConstants.deliveries}/$deliveryId/orders/$deliveryOrderId/items');
  }

  // Location
  Future<Response> updateLocation(double latitude, double longitude) async {
    return _dio.post(ApiConstants.updateLocation, data: {
      'latitude': latitude,
      'longitude': longitude,
    });
  }
}
