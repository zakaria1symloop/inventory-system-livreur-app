class DeliveryModel {
  final int id;
  final String reference;
  final int livreurId;
  final int? vehicleId;
  final String date;
  final String? startTime;
  final String? endTime;
  final String status;
  final int totalOrders;
  final int deliveredCount;
  final int failedCount;
  final String? notes;
  final String? livreurName;
  final String? vehicleName;
  final List<DeliveryOrderModel> orders;

  DeliveryModel({
    required this.id,
    required this.reference,
    required this.livreurId,
    this.vehicleId,
    required this.date,
    this.startTime,
    this.endTime,
    required this.status,
    required this.totalOrders,
    required this.deliveredCount,
    required this.failedCount,
    this.notes,
    this.livreurName,
    this.vehicleName,
    this.orders = const [],
  });

  factory DeliveryModel.fromJson(Map<String, dynamic> json) {
    // API returns 'delivery_orders' from Laravel
    final ordersList = json['delivery_orders'] ?? json['orders'];

    List<DeliveryOrderModel> parsedOrders = [];
    if (ordersList != null) {
      for (var orderJson in (ordersList as List)) {
        try {
          parsedOrders.add(DeliveryOrderModel.fromJson(orderJson));
        } catch (e) {
          print('[DELIVERY] Error parsing order: $e');
          print('[DELIVERY] Order JSON: $orderJson');
        }
      }
    }

    return DeliveryModel(
      id: json['id'],
      reference: json['reference'],
      livreurId: json['livreur_id'],
      vehicleId: json['vehicle_id'],
      date: json['date'],
      startTime: json['start_time'],
      endTime: json['end_time'],
      status: json['status'],
      totalOrders: json['total_orders'] ?? 0,
      deliveredCount: json['delivered_count'] ?? 0,
      failedCount: json['failed_count'] ?? 0,
      notes: json['notes'],
      livreurName: json['livreur']?['name'],
      vehicleName: json['vehicle']?['name'],
      orders: parsedOrders,
    );
  }

  Map<String, dynamic> toDbMap() {
    return {
      'id': id,
      'reference': reference,
      'livreur_id': livreurId,
      'vehicle_id': vehicleId,
      'date': date,
      'start_time': startTime,
      'end_time': endTime,
      'status': status,
      'total_orders': totalOrders,
      'delivered_count': deliveredCount,
      'failed_count': failedCount,
      'notes': notes,
      'livreur_name': livreurName,
      'vehicle_name': vehicleName,
    };
  }

  factory DeliveryModel.fromDbMap(Map<String, dynamic> map) {
    return DeliveryModel(
      id: map['id'],
      reference: map['reference'],
      livreurId: map['livreur_id'],
      vehicleId: map['vehicle_id'],
      date: map['date'],
      startTime: map['start_time'],
      endTime: map['end_time'],
      status: map['status'],
      totalOrders: map['total_orders'],
      deliveredCount: map['delivered_count'],
      failedCount: map['failed_count'],
      notes: map['notes'],
      livreurName: map['livreur_name'],
      vehicleName: map['vehicle_name'],
    );
  }

  bool get isPreparing => status == 'preparing';
  bool get isInProgress => status == 'in_progress';
  bool get isCompleted => status == 'completed';
  bool get isCancelled => status == 'cancelled';
}

class DeliveryOrderModel {
  final int id;
  final int deliveryId;
  final int orderId;
  final int clientId;
  final int deliveryOrder;
  final String status;
  final String? deliveredAt;
  final String? attemptedAt;
  final String? failureReason;
  final String? notes;
  final String? clientName;
  final String? clientPhone;
  final String? clientAddress;
  final double? clientLat;
  final double? clientLng;
  final double? grandTotal;
  final double? amountDue;
  final double? amountCollected;
  final List<OrderItemModel> items;

  DeliveryOrderModel({
    required this.id,
    required this.deliveryId,
    required this.orderId,
    required this.clientId,
    required this.deliveryOrder,
    required this.status,
    this.deliveredAt,
    this.attemptedAt,
    this.failureReason,
    this.notes,
    this.clientName,
    this.clientPhone,
    this.clientAddress,
    this.clientLat,
    this.clientLng,
    this.grandTotal,
    this.amountDue,
    this.amountCollected,
    this.items = const [],
  });

  factory DeliveryOrderModel.fromJson(Map<String, dynamic> json) {
    List<OrderItemModel> parsedItems = [];
    final orderData = json['order'] as Map<String, dynamic>?;

    print('[DELIVERY_ORDER] Parsing delivery_order id: ${json['id']}');
    print('[DELIVERY_ORDER] Has order data: ${orderData != null}');

    if (orderData != null) {
      print('[DELIVERY_ORDER] Order keys: ${orderData.keys.toList()}');
      print('[DELIVERY_ORDER] Order id: ${orderData['id']}');
    }

    final itemsList = orderData?['items'] as List?;
    print('[DELIVERY_ORDER] Items list length: ${itemsList?.length ?? 0}');

    if (itemsList != null) {
      for (var i = 0; i < itemsList.length; i++) {
        try {
          final itemJson = itemsList[i];
          print('[DELIVERY_ORDER] Parsing item $i: ${itemJson['product']?['name'] ?? 'no product name'}');
          parsedItems.add(OrderItemModel.fromJson(itemJson));
          print('[DELIVERY_ORDER] Item $i parsed successfully');
        } catch (e, stack) {
          print('[DELIVERY_ORDER] Error parsing item $i: $e');
          print('[DELIVERY_ORDER] Stack: $stack');
        }
      }
    }

    // Helper to parse number from string or num
    double? parseDouble(dynamic value) {
      if (value == null) return null;
      if (value is num) return value.toDouble();
      if (value is String) return double.tryParse(value);
      return null;
    }

    // Get grandTotal from order or from amount_due
    double? grandTotal = parseDouble(orderData?['grand_total']);
    grandTotal ??= parseDouble(json['amount_due']);

    // Parse amount_due and amount_collected from delivery_order
    final amountDue = parseDouble(json['amount_due']);
    final amountCollected = parseDouble(json['amount_collected']);

    print('[DELIVERY_ORDER] Final parsed items count: ${parsedItems.length}');
    print('[DELIVERY_ORDER] Client name: ${json['client']?['name']}');
    print('[DELIVERY_ORDER] Grand total: $grandTotal');
    print('[DELIVERY_ORDER] Amount due: $amountDue, Amount collected: $amountCollected');

    return DeliveryOrderModel(
      id: json['id'],
      deliveryId: json['delivery_id'],
      orderId: json['order_id'],
      clientId: json['client_id'],
      deliveryOrder: json['delivery_order'] ?? 1,
      status: json['status'] ?? 'pending',
      deliveredAt: json['delivered_at'],
      attemptedAt: json['attempted_at'],
      failureReason: json['failure_reason'],
      notes: json['notes'],
      clientName: json['client']?['name'],
      clientPhone: json['client']?['phone'],
      clientAddress: json['client']?['address'],
      clientLat: parseDouble(json['client']?['gps_lat']),
      clientLng: parseDouble(json['client']?['gps_lng']),
      grandTotal: grandTotal,
      amountDue: amountDue,
      amountCollected: amountCollected,
      items: parsedItems,
    );
  }

  Map<String, dynamic> toDbMap() {
    return {
      'id': id,
      'delivery_id': deliveryId,
      'order_id': orderId,
      'client_id': clientId,
      'delivery_order': deliveryOrder,
      'status': status,
      'delivered_at': deliveredAt,
      'attempted_at': attemptedAt,
      'failure_reason': failureReason,
      'notes': notes,
      'client_name': clientName,
      'client_phone': clientPhone,
      'client_address': clientAddress,
      'client_lat': clientLat,
      'client_lng': clientLng,
      'grand_total': grandTotal,
      'amount_due': amountDue,
      'amount_collected': amountCollected,
    };
  }

  factory DeliveryOrderModel.fromDbMap(Map<String, dynamic> map) {
    return DeliveryOrderModel(
      id: map['id'],
      deliveryId: map['delivery_id'],
      orderId: map['order_id'],
      clientId: map['client_id'],
      deliveryOrder: map['delivery_order'],
      status: map['status'],
      deliveredAt: map['delivered_at'],
      attemptedAt: map['attempted_at'],
      failureReason: map['failure_reason'],
      notes: map['notes'],
      clientName: map['client_name'],
      clientPhone: map['client_phone'],
      clientAddress: map['client_address'],
      clientLat: map['client_lat'],
      clientLng: map['client_lng'],
      grandTotal: map['grand_total'],
      amountDue: map['amount_due'],
      amountCollected: map['amount_collected'],
    );
  }

  bool get isPending => status == 'pending';
  bool get isDelivered => status == 'delivered';
  bool get isPartial => status == 'partial';
  bool get isFailed => status == 'failed';
  bool get isPostponed => status == 'postponed';

  // Order needs action (not completed - can be pending or postponed)
  bool get needsAction => status == 'pending' || status == 'postponed';

  // Order is handled (delivered, partial, failed - but NOT postponed)
  bool get isHandled => status == 'delivered' || status == 'partial' || status == 'failed';
}

class OrderItemModel {
  final int id;
  final int orderId;
  final int productId;
  final String? productName;
  final int piecesPerPackage;
  final int quantityOrdered;
  final int quantityConfirmed;
  final int quantityDelivered;
  final int quantityReturned;
  final double unitPrice;
  final double discount;
  final double subtotal;
  final String? notes;

  OrderItemModel({
    required this.id,
    required this.orderId,
    required this.productId,
    this.productName,
    this.piecesPerPackage = 1,
    required this.quantityOrdered,
    required this.quantityConfirmed,
    required this.quantityDelivered,
    required this.quantityReturned,
    required this.unitPrice,
    required this.discount,
    required this.subtotal,
    this.notes,
  });

  factory OrderItemModel.fromJson(Map<String, dynamic> json) {
    // Helper to parse number from string or num
    double parseDouble(dynamic value) {
      if (value == null) return 0;
      if (value is num) return value.toDouble();
      if (value is String) return double.tryParse(value) ?? 0;
      return 0;
    }

    int parseInt(dynamic value) {
      if (value == null) return 0;
      if (value is int) return value;
      if (value is double) return value.toInt();
      if (value is String) return int.tryParse(value) ?? 0;
      return 0;
    }

    return OrderItemModel(
      id: json['id'],
      orderId: json['order_id'],
      productId: json['product_id'],
      productName: json['product']?['name'],
      piecesPerPackage: parseInt(json['product']?['pieces_per_package'] ?? 1),
      quantityOrdered: parseInt(json['quantity_ordered']),
      quantityConfirmed: parseInt(json['quantity_confirmed'] ?? json['quantity_ordered']),
      quantityDelivered: parseInt(json['quantity_delivered']),
      quantityReturned: parseInt(json['quantity_returned']),
      unitPrice: parseDouble(json['unit_price']),
      discount: parseDouble(json['discount']),
      subtotal: parseDouble(json['subtotal']),
      notes: json['notes'],
    );
  }

  Map<String, dynamic> toDbMap() {
    return {
      'id': id,
      'order_id': orderId,
      'product_id': productId,
      'product_name': productName,
      'pieces_per_package': piecesPerPackage,
      'quantity_ordered': quantityOrdered,
      'quantity_confirmed': quantityConfirmed,
      'quantity_delivered': quantityDelivered,
      'quantity_returned': quantityReturned,
      'unit_price': unitPrice,
      'discount': discount,
      'subtotal': subtotal,
      'notes': notes,
    };
  }
}
