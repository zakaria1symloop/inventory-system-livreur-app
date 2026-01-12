import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/services/location_service.dart';
import '../data/models/delivery_model.dart';

class LocationState {
  final bool isEnabled;
  final bool hasPermission;
  final bool isTracking;
  final LocationData? currentLocation;
  final List<StoreProximity> proximities;
  final StoreProximity? nearestStore;
  final String? error;

  LocationState({
    this.isEnabled = false,
    this.hasPermission = false,
    this.isTracking = false,
    this.currentLocation,
    this.proximities = const [],
    this.nearestStore,
    this.error,
  });

  LocationState copyWith({
    bool? isEnabled,
    bool? hasPermission,
    bool? isTracking,
    LocationData? currentLocation,
    List<StoreProximity>? proximities,
    StoreProximity? nearestStore,
    String? error,
    bool clearError = false,
    bool clearNearestStore = false,
  }) {
    return LocationState(
      isEnabled: isEnabled ?? this.isEnabled,
      hasPermission: hasPermission ?? this.hasPermission,
      isTracking: isTracking ?? this.isTracking,
      currentLocation: currentLocation ?? this.currentLocation,
      proximities: proximities ?? this.proximities,
      nearestStore: clearNearestStore ? null : (nearestStore ?? this.nearestStore),
      error: clearError ? null : (error ?? this.error),
    );
  }

  double get speedKmh => currentLocation?.speedKmh ?? 0;
  double get speed => currentLocation?.speed ?? 0;
}

class LocationNotifier extends StateNotifier<LocationState> {
  LocationNotifier() : super(LocationState());

  final LocationService _service = LocationService.instance;
  StreamSubscription<LocationData>? _locationSub;
  StreamSubscription<List<StoreProximity>>? _proximitySub;

  Future<void> initialize() async {
    await _service.initialize();
    await checkStatus();
  }

  Future<void> checkStatus() async {
    final isEnabled = await _service.isLocationEnabled();
    final hasPermission = await _service.checkAndRequestPermission();

    state = state.copyWith(
      isEnabled: isEnabled,
      hasPermission: hasPermission,
      clearError: true,
    );
  }

  Future<bool> requestPermission() async {
    final hasPermission = await _service.checkAndRequestPermission();
    state = state.copyWith(hasPermission: hasPermission);
    return hasPermission;
  }

  Future<void> openLocationSettings() async {
    await _service.openLocationSettings();
  }

  Future<void> openAppSettings() async {
    await _service.openAppSettings();
  }

  void updatePendingOrders(List<DeliveryOrderModel> orders) {
    final stores = orders
        .where((o) => o.clientLat != null && o.clientLng != null)
        .map((o) => {
              'orderId': o.id,
              'clientName': o.clientName ?? 'عميل',
              'clientPhone': o.clientPhone,
              'clientAddress': o.clientAddress,
              'lat': o.clientLat!,
              'lng': o.clientLng!,
            })
        .toList();

    _service.updatePendingStores(stores);
  }

  void skipOrder(int orderId) {
    _service.skipOrder(orderId);
    // Trigger a state update to refresh UI
    state = state.copyWith();
  }

  void unskipOrder(int orderId) {
    _service.unskipOrder(orderId);
    state = state.copyWith();
  }

  bool isOrderSkipped(int orderId) => _service.isOrderSkipped(orderId);

  /// Get orders sorted by distance (closest first, skipped at end)
  List<DeliveryOrderModel> sortOrdersByDistance(List<DeliveryOrderModel> orders) {
    if (state.currentLocation == null) return orders;

    final ordersWithDistance = orders.map((order) {
      double? distance;
      if (order.clientLat != null && order.clientLng != null) {
        distance = _service.calculateDistance(
          state.currentLocation!.latitude,
          state.currentLocation!.longitude,
          order.clientLat!,
          order.clientLng!,
        );
      }
      return (order: order, distance: distance, isSkipped: _service.isOrderSkipped(order.id));
    }).toList();

    // Sort: non-skipped by distance first, then skipped by distance
    ordersWithDistance.sort((a, b) {
      if (a.isSkipped && !b.isSkipped) return 1;
      if (!a.isSkipped && b.isSkipped) return -1;
      if (a.distance == null && b.distance == null) return 0;
      if (a.distance == null) return 1;
      if (b.distance == null) return -1;
      return a.distance!.compareTo(b.distance!);
    });

    return ordersWithDistance.map((e) => e.order).toList();
  }

  Future<void> startTracking() async {
    if (!state.hasPermission) {
      final granted = await requestPermission();
      if (!granted) {
        state = state.copyWith(error: 'يرجى تفعيل صلاحية الموقع');
        return;
      }
    }

    if (!state.isEnabled) {
      state = state.copyWith(error: 'يرجى تفعيل خدمة الموقع');
      return;
    }

    // Subscribe to location updates
    _locationSub = _service.locationStream.listen((location) {
      state = state.copyWith(currentLocation: location);
    });

    // Subscribe to proximity updates
    _proximitySub = _service.proximityStream.listen((proximities) {
      final nearest = proximities.isNotEmpty ? proximities.first : null;
      state = state.copyWith(
        proximities: proximities,
        nearestStore: nearest,
        clearNearestStore: nearest == null,
      );
    });

    await _service.startTracking();
    state = state.copyWith(isTracking: true, clearError: true);
  }

  Future<void> stopTracking() async {
    await _locationSub?.cancel();
    await _proximitySub?.cancel();
    _locationSub = null;
    _proximitySub = null;

    await _service.stopTracking();
    state = state.copyWith(
      isTracking: false,
      clearNearestStore: true,
    );
  }

  double? getDistanceToOrder(DeliveryOrderModel order) {
    if (state.currentLocation == null) return null;
    if (order.clientLat == null || order.clientLng == null) return null;

    return _service.calculateDistance(
      state.currentLocation!.latitude,
      state.currentLocation!.longitude,
      order.clientLat!,
      order.clientLng!,
    );
  }

  @override
  void dispose() {
    stopTracking();
    super.dispose();
  }
}

final locationProvider = StateNotifierProvider<LocationNotifier, LocationState>((ref) {
  return LocationNotifier();
});
