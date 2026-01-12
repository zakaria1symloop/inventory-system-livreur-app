class ApiConstants {
  // Local development
  // static const String baseUrl = 'http://192.168.100.36:8080/api';
  // Production:
  static const String baseUrl = 'https://rafik-biskra.symloop.com/api';
  static const Duration timeout = Duration(seconds: 30);

  // Auth
  static const String login = '/login';
  static const String logout = '/logout';
  static const String user = '/user';

  // Sync
  static const String masterData = '/sync/master-data';
  static const String pushChanges = '/sync/push';

  // Deliveries
  static const String deliveries = '/deliveries';
  static const String myActiveDelivery = '/my-active-delivery';
  static const String myDeliveries = '/my-deliveries';

  // Orders
  static const String orders = '/orders';
  static const String confirmedOrders = '/confirmed-orders';

  // Location
  static const String updateLocation = '/location/update';
}
