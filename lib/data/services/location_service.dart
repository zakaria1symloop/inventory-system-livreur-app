import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:url_launcher/url_launcher.dart';
import 'api_service.dart';

class LocationData {
  final double latitude;
  final double longitude;
  final double speed; // in m/s (raw from GPS)
  final double speedKmh; // in km/h (filtered)
  final double accuracy;
  final DateTime timestamp;

  // Speed threshold to filter GPS drift when stationary
  // GPS can report 1-2 m/s (~4-7 km/h) even when stopped
  static const double speedThresholdMs = 1.5; // Below 1.5 m/s (~5 km/h) = stopped

  LocationData({
    required this.latitude,
    required this.longitude,
    required this.speed,
    required this.accuracy,
    required this.timestamp,
  }) : speedKmh = _calculateFilteredSpeed(speed, accuracy);

  // Filter out GPS drift - show 0 when likely stationary
  static double _calculateFilteredSpeed(double speedMs, double accuracy) {
    // If GPS accuracy is poor (>20m) or speed is below threshold, assume stopped
    if (speedMs < 0 || speedMs < speedThresholdMs || accuracy > 20) {
      return 0.0;
    }
    return speedMs * 3.6; // Convert m/s to km/h
  }
}

class StoreProximity {
  final int orderId;
  final String clientName;
  final String? clientPhone;
  final String? clientAddress;
  final double distance; // in meters
  final bool isNearby; // within threshold (600m)
  final bool isSkipped; // user has skipped this order

  StoreProximity({
    required this.orderId,
    required this.clientName,
    this.clientPhone,
    this.clientAddress,
    required this.distance,
    required this.isNearby,
    this.isSkipped = false,
  });

  String get distanceText {
    if (distance < 1000) {
      return '${distance.toStringAsFixed(0)}م';
    } else {
      return '${(distance / 1000).toStringAsFixed(1)}كم';
    }
  }
}

class LocationService {
  static final LocationService _instance = LocationService._internal();
  factory LocationService() => _instance;
  LocationService._internal();

  static LocationService get instance => _instance;

  final FlutterLocalNotificationsPlugin _notifications = FlutterLocalNotificationsPlugin();
  StreamSubscription<Position>? _positionSubscription;
  Timer? _locationUpdateTimer;

  final _locationController = StreamController<LocationData>.broadcast();
  final _proximityController = StreamController<List<StoreProximity>>.broadcast();

  // Location update interval for backend (10 seconds)
  static const Duration locationUpdateInterval = Duration(seconds: 10);

  Stream<LocationData> get locationStream => _locationController.stream;
  Stream<List<StoreProximity>> get proximityStream => _proximityController.stream;

  LocationData? _lastLocation;
  LocationData? get lastLocation => _lastLocation;

  List<Map<String, dynamic>> _pendingStores = [];
  final Set<int> _notifiedOrders = {}; // Track which orders we've notified about
  final Set<int> _skippedOrders = {}; // Track orders user has skipped/ignored

  static const double proximityThreshold = 600.0; // 600 meters - alert to call client

  Future<void> initialize() async {
    await _initNotifications();
  }

  Future<void> _initNotifications() async {
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _notifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (response) {
        // Handle notification tap - could open phone dialer
        if (response.payload != null) {
          final phone = response.payload!;
          if (phone.isNotEmpty) {
            launchUrl(Uri.parse('tel:$phone'));
          }
        }
      },
    );

    // Request notification permission for Android 13+
    await _requestNotificationPermission();
  }

  Future<void> _requestNotificationPermission() async {
    final androidImplementation = _notifications.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (androidImplementation != null) {
      final granted = await androidImplementation.requestNotificationsPermission();
      debugPrint('[NOTIFICATION] Permission granted: $granted');
    }
  }

  Future<bool> checkAndRequestPermission() async {
    // Check if location services are enabled
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      debugPrint('[LOCATION] Location services are disabled');
      return false;
    }

    // Check current permission status
    LocationPermission permission = await Geolocator.checkPermission();
    debugPrint('[LOCATION] Current permission: $permission');

    // Request permission if denied
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      debugPrint('[LOCATION] After request: $permission');
      if (permission == LocationPermission.denied) {
        return false;
      }
    }

    // Handle permanently denied case
    if (permission == LocationPermission.deniedForever) {
      debugPrint('[LOCATION] Permission denied forever');
      return false;
    }

    // For Android 11+, request background location if only foreground is granted
    if (permission == LocationPermission.whileInUse) {
      // Background location is needed for continuous tracking
      // User must manually enable "Allow all the time" in settings
      debugPrint('[LOCATION] Only foreground permission granted, background tracking may be limited');
    }

    return true;
  }

  /// Request background location permission (Android 11+)
  /// Returns true if background location is available
  Future<bool> requestBackgroundPermission() async {
    final permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.always) {
      return true;
    }

    // On Android 11+, we can only guide user to settings
    // The app must already have "while in use" permission
    if (permission == LocationPermission.whileInUse) {
      // Guide user to enable "Allow all the time" in app settings
      debugPrint('[LOCATION] Requesting background permission...');
      await Geolocator.openAppSettings();
      return false;
    }

    return false;
  }

  Future<bool> isLocationEnabled() async {
    return await Geolocator.isLocationServiceEnabled();
  }

  Future<void> openLocationSettings() async {
    await Geolocator.openLocationSettings();
  }

  Future<void> openAppSettings() async {
    await Geolocator.openAppSettings();
  }

  void updatePendingStores(List<Map<String, dynamic>> stores) {
    _pendingStores = stores;
    // Clear skipped orders that are no longer in the list
    _skippedOrders.removeWhere((id) => !stores.any((s) => s['orderId'] == id));
    debugPrint('[LOCATION] Updated pending stores: ${stores.length}');
  }

  void skipOrder(int orderId) {
    _skippedOrders.add(orderId);
    _notifiedOrders.add(orderId); // Also mark as notified so we don't notify again
    debugPrint('[LOCATION] Skipped order: $orderId');
  }

  void unskipOrder(int orderId) {
    _skippedOrders.remove(orderId);
    debugPrint('[LOCATION] Unskipped order: $orderId');
  }

  bool isOrderSkipped(int orderId) => _skippedOrders.contains(orderId);

  Future<void> startTracking() async {
    final hasPermission = await checkAndRequestPermission();
    if (!hasPermission) {
      debugPrint('[LOCATION] No permission to track');
      return;
    }

    // Cancel existing subscription
    await stopTracking();

    const locationSettings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 10, // Update every 10 meters
    );

    _positionSubscription = Geolocator.getPositionStream(
      locationSettings: locationSettings,
    ).listen(
      (position) {
        final locationData = LocationData(
          latitude: position.latitude,
          longitude: position.longitude,
          speed: position.speed,
          accuracy: position.accuracy,
          timestamp: position.timestamp,
        );

        _lastLocation = locationData;
        _locationController.add(locationData);

        // Check proximity to stores
        _checkProximity(locationData);
      },
      onError: (error) {
        debugPrint('[LOCATION] Stream error: $error');
      },
    );

    // Start timer to send location updates to backend every 10 seconds
    _startLocationUpdateTimer();

    debugPrint('[LOCATION] Started tracking');
  }

  void _startLocationUpdateTimer() {
    _locationUpdateTimer?.cancel();
    _locationUpdateTimer = Timer.periodic(locationUpdateInterval, (_) {
      _sendLocationToBackend();
    });
    // Also send immediately
    _sendLocationToBackend();
  }

  Future<void> _sendLocationToBackend() async {
    if (_lastLocation == null) return;

    try {
      await ApiService.instance.updateLocation(
        _lastLocation!.latitude,
        _lastLocation!.longitude,
      );
      debugPrint('[LOCATION] Sent location to backend: ${_lastLocation!.latitude}, ${_lastLocation!.longitude}');
    } catch (e) {
      debugPrint('[LOCATION] Failed to send location to backend: $e');
    }
  }

  Future<void> stopTracking() async {
    await _positionSubscription?.cancel();
    _positionSubscription = null;
    _locationUpdateTimer?.cancel();
    _locationUpdateTimer = null;
    _notifiedOrders.clear();
    debugPrint('[LOCATION] Stopped tracking');
  }

  void _checkProximity(LocationData currentLocation) {
    if (_pendingStores.isEmpty) return;

    List<StoreProximity> proximities = [];

    for (var store in _pendingStores) {
      final storeLat = store['lat'] as double?;
      final storeLng = store['lng'] as double?;

      if (storeLat == null || storeLng == null) continue;

      final distance = Geolocator.distanceBetween(
        currentLocation.latitude,
        currentLocation.longitude,
        storeLat,
        storeLng,
      );

      final isNearby = distance <= proximityThreshold;
      final orderId = store['orderId'] as int;
      final clientName = store['clientName'] as String? ?? 'عميل';
      final clientPhone = store['clientPhone'] as String?;
      final clientAddress = store['clientAddress'] as String?;
      final isSkipped = _skippedOrders.contains(orderId);

      proximities.add(StoreProximity(
        orderId: orderId,
        clientName: clientName,
        clientPhone: clientPhone,
        clientAddress: clientAddress,
        distance: distance,
        isNearby: isNearby,
        isSkipped: isSkipped,
      ));

      // Send notification if nearby, not skipped, and not already notified
      if (isNearby && !isSkipped && !_notifiedOrders.contains(orderId)) {
        _notifiedOrders.add(orderId);
        _showProximityNotification(clientName, clientPhone, distance);
      }

      // Reset notification if user moves away (> 1000m from threshold)
      if (distance > proximityThreshold + 400 && _notifiedOrders.contains(orderId)) {
        _notifiedOrders.remove(orderId);
      }
    }

    // Sort by distance (closest first), but put skipped orders at the end
    proximities.sort((a, b) {
      if (a.isSkipped && !b.isSkipped) return 1;
      if (!a.isSkipped && b.isSkipped) return -1;
      return a.distance.compareTo(b.distance);
    });
    _proximityController.add(proximities);
  }

  Future<void> _showProximityNotification(String clientName, String? phone, double distance) async {
    const androidDetails = AndroidNotificationDetails(
      'proximity_channel',
      'تنبيهات القرب',
      channelDescription: 'تنبيهات عند الاقتراب من العملاء',
      importance: Importance.high,
      priority: Priority.high,
      playSound: true,
      enableVibration: true,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    final distanceText = distance < 100
        ? '${distance.toStringAsFixed(0)}م'
        : '${(distance / 1000).toStringAsFixed(1)}كم';

    await _notifications.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      'اقتربت من $clientName',
      'المسافة: $distanceText - اضغط للاتصال',
      details,
      payload: phone ?? '',
    );

    debugPrint('[LOCATION] Sent proximity notification for $clientName');
  }

  Future<Position?> getCurrentPosition() async {
    final hasPermission = await checkAndRequestPermission();
    if (!hasPermission) return null;

    try {
      return await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
    } catch (e) {
      debugPrint('[LOCATION] Error getting position: $e');
      return null;
    }
  }

  double calculateDistance(double lat1, double lng1, double lat2, double lng2) {
    return Geolocator.distanceBetween(lat1, lng1, lat2, lng2);
  }

  void dispose() {
    stopTracking();
    _locationUpdateTimer?.cancel();
    _locationController.close();
    _proximityController.close();
  }
}
