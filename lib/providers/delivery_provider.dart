import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/models/delivery_model.dart';
import '../data/services/api_service.dart';

class DeliveryState {
  final DeliveryModel? activeDelivery;
  final List<DeliveryModel> deliveries;
  final bool isLoading;
  final String? error;

  DeliveryState({
    this.activeDelivery,
    this.deliveries = const [],
    this.isLoading = false,
    this.error,
  });

  DeliveryState copyWith({
    DeliveryModel? activeDelivery,
    List<DeliveryModel>? deliveries,
    bool? isLoading,
    String? error,
    bool clearActiveDelivery = false,
  }) {
    return DeliveryState(
      activeDelivery: clearActiveDelivery ? null : (activeDelivery ?? this.activeDelivery),
      deliveries: deliveries ?? this.deliveries,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

class DeliveryNotifier extends StateNotifier<DeliveryState> {
  DeliveryNotifier() : super(DeliveryState());

  Future<void> fetchActiveDelivery() async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final response = await ApiService.instance.getMyActiveDelivery();

      debugPrint('[DELIVERY] ====== RAW API RESPONSE ======');
      debugPrint('[DELIVERY] Response type: ${response.data.runtimeType}');
      debugPrint('[DELIVERY] Response: ${response.data}');
      debugPrint('[DELIVERY] ==============================');

      if (response.data != null && response.data is Map) {
        final data = response.data as Map<String, dynamic>;

        debugPrint('[DELIVERY] Data keys: ${data.keys.toList()}');

        // Check if we have a valid delivery (must have 'id' field)
        if (data.isEmpty || data['id'] == null) {
          debugPrint('[DELIVERY] No active delivery - response is empty or missing id');
          state = state.copyWith(activeDelivery: null, isLoading: false);
          return;
        }

        final deliveryOrders = data['delivery_orders'] as List?;
        debugPrint('[DELIVERY] delivery_orders count: ${deliveryOrders?.length ?? 0}');

        if (deliveryOrders != null && deliveryOrders.isNotEmpty) {
          for (int i = 0; i < deliveryOrders.length; i++) {
            final doJson = deliveryOrders[i] as Map<String, dynamic>;
            debugPrint('[DELIVERY] --- delivery_order[$i] ---');
            debugPrint('[DELIVERY] DO keys: ${doJson.keys.toList()}');
            debugPrint('[DELIVERY] DO id: ${doJson['id']}');
            debugPrint('[DELIVERY] DO client_id: ${doJson['client_id']}');
            debugPrint('[DELIVERY] DO order_id: ${doJson['order_id']}');

            final order = doJson['order'];
            debugPrint('[DELIVERY] order type: ${order?.runtimeType}');
            debugPrint('[DELIVERY] order: $order');

            if (order != null && order is Map) {
              final orderMap = order as Map<String, dynamic>;
              debugPrint('[DELIVERY] Order keys: ${orderMap.keys.toList()}');
              final items = orderMap['items'];
              debugPrint('[DELIVERY] items type: ${items?.runtimeType}');
              debugPrint('[DELIVERY] items: $items');
            }

            final client = doJson['client'];
            debugPrint('[DELIVERY] client: $client');
          }
        }

        final delivery = DeliveryModel.fromJson(data);
        debugPrint('[DELIVERY] ====== PARSED MODEL ======');
        debugPrint('[DELIVERY] orders count: ${delivery.orders.length}');

        for (int i = 0; i < delivery.orders.length; i++) {
          final o = delivery.orders[i];
          debugPrint('[DELIVERY] Order[$i]: ${o.clientName}, items: ${o.items.length}, total: ${o.grandTotal}');
          for (int j = 0; j < o.items.length; j++) {
            final item = o.items[j];
            debugPrint('[DELIVERY]   Item[$j]: ${item.productName}, qty: ${item.quantityConfirmed}, price: ${item.unitPrice}');
          }
        }
        debugPrint('[DELIVERY] ===========================');

        state = state.copyWith(activeDelivery: delivery, isLoading: false);
      } else {
        debugPrint('[DELIVERY] No active delivery found (response.data is null or not Map)');
        state = state.copyWith(isLoading: false, clearActiveDelivery: true);
      }
    } catch (e, stack) {
      debugPrint('[DELIVERY] ERROR: $e');
      debugPrint('[DELIVERY] Stack: $stack');
      state = state.copyWith(isLoading: false, clearActiveDelivery: true);
    }
  }

  Future<void> fetchMyDeliveries() async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final response = await ApiService.instance.getMyDeliveries();
      final List deliveriesList = response.data is List ? response.data : response.data['data'] ?? [];

      final deliveries = deliveriesList
          .map((d) => DeliveryModel.fromJson(d))
          .toList();

      state = state.copyWith(deliveries: deliveries, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: 'خطأ في تحميل البيانات');
    }
  }

  Future<bool> startDelivery(int deliveryId) async {
    try {
      await ApiService.instance.startDelivery(deliveryId);
      await fetchActiveDelivery();
      return true;
    } catch (e) {
      state = state.copyWith(error: 'خطأ في بدء التوصيل');
      return false;
    }
  }

  Future<bool> deliverOrder(int deliveryId, int orderId, {double? amountCollected}) async {
    try {
      debugPrint('[DELIVERY] Delivering order $orderId with amount: $amountCollected');
      await ApiService.instance.deliverOrder(
        deliveryId,
        orderId,
        amountCollected: amountCollected,
      );
      await fetchActiveDelivery();
      return true;
    } catch (e) {
      debugPrint('[DELIVERY] Error delivering order: $e');
      state = state.copyWith(error: 'خطأ في تسجيل التسليم');
      return false;
    }
  }

  Future<bool> failOrder(int deliveryId, int orderId, String reason) async {
    try {
      await ApiService.instance.failOrder(deliveryId, orderId, reason);
      await fetchActiveDelivery();
      return true;
    } catch (e) {
      state = state.copyWith(error: 'خطأ في تسجيل الفشل');
      return false;
    }
  }

  Future<bool> postponeOrder(int deliveryId, int orderId, {String? notes}) async {
    try {
      await ApiService.instance.postponeOrder(deliveryId, orderId, notes: notes);
      await fetchActiveDelivery();
      return true;
    } catch (e) {
      state = state.copyWith(error: 'خطأ في تأجيل الطلب');
      return false;
    }
  }

  Future<bool> completeDelivery(int deliveryId) async {
    try {
      await ApiService.instance.completeDelivery(deliveryId);
      state = state.copyWith(clearActiveDelivery: true);
      await fetchMyDeliveries();
      return true;
    } catch (e) {
      state = state.copyWith(error: 'خطأ في إنهاء التوصيل');
      return false;
    }
  }

  Future<bool> partialDelivery(
    int deliveryId,
    int orderId,
    List<Map<String, dynamic>> items, {
    double? amountCollected,
  }) async {
    try {
      debugPrint('[DELIVERY] Partial delivery for order $orderId with amount: $amountCollected');
      debugPrint('[DELIVERY] Items: $items');
      await ApiService.instance.partialDelivery(deliveryId, orderId, {
        'items': items,
        'amount_collected': amountCollected,
      });
      await fetchActiveDelivery();
      return true;
    } catch (e) {
      debugPrint('[DELIVERY] Error partial delivery: $e');
      state = state.copyWith(error: 'خطأ في تسجيل التسليم الجزئي');
      return false;
    }
  }

  Future<DeliveryModel?> fetchDeliveryDetails(int deliveryId) async {
    try {
      final response = await ApiService.instance.getDeliveryDetails(deliveryId);
      if (response.data != null && response.data is Map) {
        final data = response.data as Map<String, dynamic>;
        debugPrint('[DELIVERY] Got delivery details: ${data['id']}');
        final delivery = DeliveryModel.fromJson(data);
        debugPrint('[DELIVERY] Delivery has ${delivery.orders.length} orders');
        return delivery;
      }
      return null;
    } catch (e) {
      debugPrint('[DELIVERY] Error fetching delivery details: $e');
      return null;
    }
  }
}

final deliveryProvider = StateNotifierProvider<DeliveryNotifier, DeliveryState>((ref) {
  return DeliveryNotifier();
});
