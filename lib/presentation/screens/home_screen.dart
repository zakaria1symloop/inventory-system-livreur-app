import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart';
import '../../providers/auth_provider.dart';
import '../../providers/delivery_provider.dart';
import '../../providers/location_provider.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/delivery_model.dart';
import '../../data/services/location_service.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeApp();
    });
  }

  Future<void> _initializeApp() async {
    // Initialize location service
    await ref.read(locationProvider.notifier).initialize();

    // Check location permission and show dialog if needed
    await _checkLocationPermission();

    // Fetch delivery data
    ref.read(deliveryProvider.notifier).fetchActiveDelivery();
    ref.read(deliveryProvider.notifier).fetchMyDeliveries();
  }

  Future<void> _checkLocationPermission() async {
    final locationNotifier = ref.read(locationProvider.notifier);
    await locationNotifier.checkStatus();

    final locationState = ref.read(locationProvider);

    if (!locationState.isEnabled) {
      if (mounted) {
        _showLocationDisabledDialog();
      }
    } else if (!locationState.hasPermission) {
      if (mounted) {
        _showPermissionDialog();
      }
    } else {
      // Start tracking if we have permission
      await locationNotifier.startTracking();
    }
  }

  void _showLocationDisabledDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.location_off, color: AppTheme.dangerColor),
            SizedBox(width: 8),
            Text('الموقع مطفأ'),
          ],
        ),
        content: const Text(
          'يرجى تفعيل خدمة الموقع لتتمكن من استخدام التطبيق وتتبع عمليات التوصيل.',
        ),
        actions: [
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await ref.read(locationProvider.notifier).openLocationSettings();
              // Recheck after returning from settings
              Future.delayed(const Duration(seconds: 1), () {
                if (mounted) _checkLocationPermission();
              });
            },
            child: const Text('فتح الإعدادات'),
          ),
        ],
      ),
    );
  }

  void _showPermissionDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.location_on, color: AppTheme.primaryColor),
            SizedBox(width: 8),
            Text('صلاحية الموقع'),
          ],
        ),
        content: const Text(
          'يحتاج التطبيق إلى صلاحية الوصول للموقع لتتبع عمليات التوصيل وتنبيهك عند الاقتراب من العملاء.',
        ),
        actions: [
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final granted = await ref
                  .read(locationProvider.notifier)
                  .requestPermission();
              if (granted) {
                await ref.read(locationProvider.notifier).startTracking();
              } else {
                if (mounted) {
                  _showPermissionDeniedDialog();
                }
              }
            },
            child: const Text('السماح'),
          ),
        ],
      ),
    );
  }

  void _showPermissionDeniedDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning, color: AppTheme.warningColor),
            SizedBox(width: 8),
            Text('الصلاحية مرفوضة'),
          ],
        ),
        content: const Text(
          'لم يتم منح صلاحية الموقع. يمكنك تفعيلها من إعدادات التطبيق.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('لاحقاً'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await ref.read(locationProvider.notifier).openAppSettings();
            },
            child: const Text('فتح الإعدادات'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final deliveryState = ref.watch(deliveryProvider);
    final locationState = ref.watch(locationProvider);

    // Update pending orders for proximity tracking when delivery changes
    if (deliveryState.activeDelivery != null) {
      final pendingOrders = deliveryState.activeDelivery!.orders
          .where((o) => o.isPending)
          .toList();
      ref.read(locationProvider.notifier).updatePendingOrders(pendingOrders);
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('تطبيق السائق'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              ref.read(deliveryProvider.notifier).fetchActiveDelivery();
              ref.read(deliveryProvider.notifier).fetchMyDeliveries();
            },
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (value) async {
              if (value == 'logout') {
                await ref.read(authProvider.notifier).logout();
                if (context.mounted) {
                  Navigator.pushReplacementNamed(context, '/login');
                }
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'profile',
                child: Row(
                  children: [
                    const Icon(Icons.person_outline, size: 20),
                    const SizedBox(width: 8),
                    Text(authState.user?.name ?? 'المستخدم'),
                  ],
                ),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem(
                value: 'logout',
                child: Row(
                  children: [
                    Icon(Icons.logout, size: 20, color: AppTheme.dangerColor),
                    SizedBox(width: 8),
                    Text(
                      'تسجيل الخروج',
                      style: TextStyle(color: AppTheme.dangerColor),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: deliveryState.isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: () async {
                await ref.read(deliveryProvider.notifier).fetchActiveDelivery();
                await ref.read(deliveryProvider.notifier).fetchMyDeliveries();
              },
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Gradient Welcome Card
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF1565C0), Color(0xFF42A5F5)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF1565C0).withValues(alpha: 0.3),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 60,
                            height: 60,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(15),
                            ),
                            child: Center(
                              child: Text(
                                authState.user?.name.substring(0, 1).toUpperCase() ?? 'S',
                                style: const TextStyle(
                                  fontSize: 28,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'مرحبا، ${authState.user?.name ?? 'السائق'}',
                                  style: const TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  DateFormat('EEEE, d MMMM yyyy', 'ar').format(DateTime.now()),
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Colors.white.withValues(alpha: 0.9),
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.2),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Text(
                                    'سائق توصيل',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Today's Stats Section
                    _TodayStatsSection(deliveryState: deliveryState),
                    const SizedBox(height: 16),

                    // Location & Speed Card
                    _LocationInfoCard(
                      locationState: locationState,
                      onEnableLocation: _checkLocationPermission,
                    ),
                    const SizedBox(height: 24),

                    // Active delivery section
                    if (deliveryState.activeDelivery != null) ...[
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'التوصيل الحالي',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          TextButton.icon(
                            onPressed: () {
                              Navigator.pushNamed(
                                context,
                                '/delivery-detail',
                                arguments: {
                                  'deliveryId':
                                      deliveryState.activeDelivery!.id,
                                },
                              );
                            },
                            icon: const Icon(Icons.open_in_new, size: 16),
                            label: const Text('التفاصيل'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      _ActiveDeliveryCard(
                        delivery: deliveryState.activeDelivery!,
                      ),
                    ] else ...[
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(32),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.grey.shade50,
                              Colors.grey.shade100,
                            ],
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                          ),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: Colors.grey.shade200,
                            width: 1,
                          ),
                        ),
                        child: Column(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.grey.withValues(alpha: 0.2),
                                    blurRadius: 10,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Icon(
                                Icons.local_shipping_outlined,
                                size: 48,
                                color: Colors.grey[400],
                              ),
                            ),
                            const SizedBox(height: 20),
                            const Text(
                              'لا يوجد توصيل نشط حاليا',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'ستظهر هنا عمليات التوصيل المسندة إليك',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[600],
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 16),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              decoration: BoxDecoration(
                                color: AppTheme.primaryColor.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.refresh, size: 16, color: AppTheme.primaryColor),
                                  const SizedBox(width: 6),
                                  Text(
                                    'اسحب للتحديث',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: AppTheme.primaryColor,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    const SizedBox(height: 24),

                    // Recent deliveries
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: AppTheme.primaryColor.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(
                                Icons.history,
                                size: 20,
                                color: AppTheme.primaryColor,
                              ),
                            ),
                            const SizedBox(width: 10),
                            const Text(
                              'آخر التوصيلات',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        TextButton.icon(
                          onPressed: () {
                            Navigator.pushNamed(context, '/history');
                          },
                          icon: const Icon(Icons.arrow_forward, size: 16),
                          label: const Text('عرض الكل'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (deliveryState.deliveries.isEmpty)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey.shade200),
                        ),
                        child: Column(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade100,
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.inbox_outlined,
                                size: 32,
                                color: Colors.grey[400],
                              ),
                            ),
                            const SizedBox(height: 12),
                            const Text(
                              'لا توجد توصيلات سابقة',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w500,
                                color: Colors.black54,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'ستظهر هنا سجل توصيلاتك المكتملة',
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.grey[500],
                              ),
                            ),
                          ],
                        ),
                      )
                    else
                      ...deliveryState.deliveries
                          .take(5)
                          .map(
                            (delivery) => _DeliveryHistoryCard(
                              delivery: delivery,
                              onTap: () {
                                Navigator.pushNamed(context, '/history');
                              },
                            ),
                          ),
                  ],
                ),
              ),
            ),
    );
  }
}

void _showCancelDialog(
  BuildContext context,
  WidgetRef ref,
  int deliveryId,
  DeliveryOrderModel order,
) {
  final reasons = [
    'المحل مغلق',
    'العميل غير موجود',
    'العميل رفض الطلب',
    'العنوان خاطئ',
    'لا يستطيع الدفع',
    'طلب التأجيل لوقت لاحق',
    'سبب آخر',
  ];

  showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Row(
        children: [
          const Icon(Icons.cancel, color: AppTheme.dangerColor),
          const SizedBox(width: 8),
          const Text('إلغاء الطلب'),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'العميل: ${order.clientName ?? "غير معروف"}',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          const Text('اختر سبب الإلغاء:'),
          const SizedBox(height: 8),
          ...reasons.map(
            (reason) => ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: const Icon(
                Icons.arrow_left,
                color: AppTheme.dangerColor,
              ),
              title: Text(reason),
              onTap: () async {
                Navigator.pop(ctx);
                final notifier = ref.read(deliveryProvider.notifier);
                final success = await notifier.failOrder(
                  deliveryId,
                  order.id,
                  reason,
                );
                if (success && context.mounted) {
                  // Remove from skipped list if it was skipped
                  ref.read(locationProvider.notifier).unskipOrder(order.id);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('تم إلغاء الطلب'),
                      backgroundColor: AppTheme.dangerColor,
                    ),
                  );
                }
              },
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('رجوع'),
        ),
      ],
    ),
  );
}

class _ActiveDeliveryCard extends ConsumerWidget {
  final DeliveryModel delivery;

  const _ActiveDeliveryCard({required this.delivery});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locationNotifier = ref.read(locationProvider.notifier);
    final locationState = ref.watch(locationProvider);

    // Get orders that need action (pending or postponed) sorted by distance
    final allPendingOrders = delivery.orders
        .where((o) => o.needsAction)
        .toList();
    final pendingOrders = locationNotifier.sortOrdersByDistance(
      allPendingOrders,
    );

    final deliveredOrders = delivery.orders
        .where((o) => o.isDelivered || o.isPartial)
        .toList();

    // Calculate money totals - use amountCollected for delivered, amountDue for pending
    final totalCollected = deliveredOrders.fold<double>(
      0,
      (sum, o) => sum + (o.amountCollected ?? 0),
    );
    final totalRemaining = pendingOrders.fold<double>(
      0,
      (sum, o) => sum + (o.amountDue ?? o.grandTotal ?? 0),
    );

    // Calculate stock totals
    int totalProductsLoaded = 0;
    int totalProductsDelivered = 0;
    int totalProductsRemaining = 0;

    for (var order in delivery.orders) {
      for (var item in order.items) {
        totalProductsLoaded += item.quantityConfirmed;
        totalProductsDelivered += item.quantityDelivered;
      }
    }
    totalProductsRemaining = totalProductsLoaded - totalProductsDelivered;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  delivery.reference,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                _StatusBadge(status: delivery.status),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                _StatItem(
                  icon: Icons.shopping_bag,
                  label: 'إجمالي',
                  value: '${delivery.totalOrders}',
                ),
                _StatItem(
                  icon: Icons.check_circle,
                  label: 'تم',
                  value: '${deliveredOrders.length}',
                  color: AppTheme.successColor,
                ),
                _StatItem(
                  icon: Icons.pending,
                  label: 'متبقي',
                  value: '${pendingOrders.length}',
                  color: AppTheme.warningColor,
                ),
              ],
            ),

            // Money summary
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.successColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.payments, color: AppTheme.successColor),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'المال المحصّل',
                          style: TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                        Text(
                          '${totalCollected.toStringAsFixed(0)} د.ج',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                            color: AppTheme.successColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      const Text(
                        'المتبقي',
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                      Text(
                        '${totalRemaining.toStringAsFixed(0)} د.ج',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: AppTheme.warningColor,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Stock summary
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.inventory_2, color: Colors.blue),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'المنتجات في السيارة: $totalProductsRemaining وحدة',
                      style: const TextStyle(
                        fontWeight: FontWeight.w500,
                        color: Colors.blue,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      Navigator.pushNamed(
                        context,
                        '/delivery-detail',
                        arguments: {'deliveryId': delivery.id},
                      );
                    },
                    child: const Text('التفاصيل'),
                  ),
                ],
              ),
            ),

            const Divider(height: 24),

            // Proximity Alert - show when close to a client (600m)
            if (delivery.isInProgress &&
                locationState.nearestStore != null &&
                locationState.nearestStore!.isNearby &&
                !locationState.nearestStore!.isSkipped)
              _ProximityAlertCard(
                proximity: locationState.nearestStore!,
                onCall: () {
                  final phone = locationState.nearestStore!.clientPhone;
                  if (phone != null && phone.isNotEmpty) {
                    launchUrl(Uri.parse('tel:$phone'));
                  }
                },
                onSkip: () {
                  ref
                      .read(locationProvider.notifier)
                      .skipOrder(locationState.nearestStore!.orderId);
                },
                onDeliver: () async {
                  final order = pendingOrders.firstWhere(
                    (o) => o.id == locationState.nearestStore!.orderId,
                    orElse: () => pendingOrders.first,
                  );
                  final notifier = ref.read(deliveryProvider.notifier);
                  final result = await Navigator.pushNamed(
                    context,
                    '/order-delivery',
                    arguments: {'order': order, 'deliveryId': delivery.id},
                  );
                  if (result == true && context.mounted) {
                    notifier.fetchActiveDelivery();
                  }
                },
              ),

            // Split orders into active and skipped
            Builder(
              builder: (context) {
                final activeOrders = pendingOrders
                    .where((o) => !locationNotifier.isOrderSkipped(o.id))
                    .toList();
                final skippedOrders = pendingOrders
                    .where((o) => locationNotifier.isOrderSkipped(o.id))
                    .toList();

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Active pending orders list
                    if (activeOrders.isNotEmpty) ...[
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'الطلبات المتبقية (${activeOrders.length})',
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          if (locationState.currentLocation != null)
                            Text(
                              'مرتبة حسب المسافة',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey[600],
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      ...activeOrders
                          .take(3)
                          .map(
                            (order) => _OrderItemWithActions(
                              order: order,
                              deliveryId: delivery.id,
                              isEnabled: delivery.isInProgress,
                              onTap: delivery.isInProgress
                                  ? () async {
                                      final notifier = ref.read(
                                        deliveryProvider.notifier,
                                      );
                                      final result = await Navigator.pushNamed(
                                        context,
                                        '/order-delivery',
                                        arguments: {
                                          'order': order,
                                          'deliveryId': delivery.id,
                                        },
                                      );
                                      if (result == true && context.mounted) {
                                        notifier.fetchActiveDelivery();
                                      }
                                    }
                                  : null,
                              onSkip: delivery.isInProgress
                                  ? () {
                                      ref
                                          .read(locationProvider.notifier)
                                          .skipOrder(order.id);
                                    }
                                  : null,
                              onCancel: delivery.isInProgress
                                  ? () => _showCancelDialog(
                                      context,
                                      ref,
                                      delivery.id,
                                      order,
                                    )
                                  : null,
                            ),
                          ),
                      if (activeOrders.length > 3)
                        TextButton(
                          onPressed: () {
                            Navigator.pushNamed(
                              context,
                              '/delivery-detail',
                              arguments: {'deliveryId': delivery.id},
                            );
                          },
                          child: Text('عرض الكل (${activeOrders.length})'),
                        ),
                    ],

                    // Skipped orders section
                    if (skippedOrders.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.orange.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Colors.orange.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(
                                  Icons.schedule,
                                  color: Colors.orange,
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'طلبات متخطاة (${skippedOrders.length})',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    color: Colors.orange,
                                  ),
                                ),
                                const Spacer(),
                                Text(
                                  'يجب إكمالها أو إلغاؤها',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.orange[700],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            ...skippedOrders.map(
                              (order) => _SkippedOrderItem(
                                order: order,
                                deliveryId: delivery.id,
                                onRestore: () {
                                  ref
                                      .read(locationProvider.notifier)
                                      .unskipOrder(order.id);
                                },
                                onDeliver: delivery.isInProgress
                                    ? () async {
                                        final notifier = ref.read(
                                          deliveryProvider.notifier,
                                        );
                                        final result =
                                            await Navigator.pushNamed(
                                              context,
                                              '/order-delivery',
                                              arguments: {
                                                'order': order,
                                                'deliveryId': delivery.id,
                                              },
                                            );
                                        if (result == true && context.mounted) {
                                          notifier.fetchActiveDelivery();
                                        }
                                      }
                                    : null,
                                onCancel: delivery.isInProgress
                                    ? () => _showCancelDialog(
                                        context,
                                        ref,
                                        delivery.id,
                                        order,
                                      )
                                    : null,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                );
              },
            ),

            const SizedBox(height: 12),

            // Action buttons
            if (delivery.isPreparing)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () async {
                    await ref
                        .read(deliveryProvider.notifier)
                        .startDelivery(delivery.id);
                  },
                  icon: const Icon(Icons.play_arrow),
                  label: const Text('بدء التوصيل'),
                ),
              )
            else if (delivery.isInProgress && pendingOrders.isEmpty)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () async {
                    await ref
                        .read(deliveryProvider.notifier)
                        .completeDelivery(delivery.id);
                  },
                  icon: const Icon(Icons.check),
                  label: const Text('إنهاء التوصيل'),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _OrderItem extends ConsumerWidget {
  final DeliveryOrderModel order;
  final int deliveryId;
  final VoidCallback? onTap;
  final bool isEnabled;

  const _OrderItem({
    required this.order,
    required this.deliveryId,
    this.onTap,
    this.isEnabled = true,
  });

  String _formatDistance(double meters) {
    if (meters < 1000) {
      return '${meters.toStringAsFixed(0)}م';
    } else {
      return '${(meters / 1000).toStringAsFixed(1)}كم';
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final itemsCount = order.items.length;
    final distance = ref
        .read(locationProvider.notifier)
        .getDistanceToOrder(order);
    final isSkipped = ref
        .watch(locationProvider.notifier)
        .isOrderSkipped(order.id);

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      color: isEnabled
          ? (isSkipped ? Colors.grey[50] : null)
          : Colors.grey[100],
      child: InkWell(
        onTap: isEnabled ? onTap : null,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              // Order number badge with distance
              Column(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: isEnabled
                          ? (isSkipped ? Colors.grey : AppTheme.primaryColor)
                          : Colors.grey,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Center(
                      child: Text(
                        '${order.deliveryOrder}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ),
                  if (distance != null) ...[
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: distance < 600
                            ? AppTheme.successColor.withValues(alpha: 0.2)
                            : Colors.blue.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        _formatDistance(distance),
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: distance < 600
                              ? AppTheme.successColor
                              : Colors.blue,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(width: 12),
              // Client info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            order.clientName ?? 'عميل',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: isEnabled
                                  ? (isSkipped ? Colors.grey : null)
                                  : Colors.grey,
                            ),
                          ),
                        ),
                        if (isSkipped)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.orange.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text(
                              'متخطى',
                              style: TextStyle(
                                fontSize: 10,
                                color: Colors.orange,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$itemsCount منتج',
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                    if (!isEnabled)
                      Text(
                        'ابدأ التوصيل أولاً',
                        style: TextStyle(
                          fontSize: 11,
                          color: AppTheme.warningColor,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                  ],
                ),
              ),
              // Amount
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (order.grandTotal != null)
                    Text(
                      '${order.grandTotal!.toStringAsFixed(0)} د.ج',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: isEnabled ? AppTheme.primaryColor : Colors.grey,
                        fontSize: 16,
                      ),
                    ),
                  Icon(
                    isEnabled ? Icons.chevron_right : Icons.lock,
                    color: Colors.grey,
                    size: isEnabled ? 24 : 20,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color? color;

  const _StatItem({
    required this.icon,
    required this.label,
    required this.value,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Icon(icon, color: color ?? Colors.grey),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
        ],
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String status;

  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    Color bgColor;
    Color textColor;
    String label;

    switch (status) {
      case 'preparing':
        bgColor = AppTheme.warningColor.withValues(alpha: 0.1);
        textColor = AppTheme.warningColor;
        label = 'جاري التحضير';
        break;
      case 'in_progress':
        bgColor = AppTheme.primaryColor.withValues(alpha: 0.1);
        textColor = AppTheme.primaryColor;
        label = 'جاري التوصيل';
        break;
      case 'completed':
        bgColor = AppTheme.successColor.withValues(alpha: 0.1);
        textColor = AppTheme.successColor;
        label = 'مكتمل';
        break;
      case 'cancelled':
        bgColor = AppTheme.dangerColor.withValues(alpha: 0.1);
        textColor = AppTheme.dangerColor;
        label = 'ملغي';
        break;
      default:
        bgColor = Colors.grey.withValues(alpha: 0.1);
        textColor = Colors.grey;
        label = status;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: textColor,
        ),
      ),
    );
  }
}

class _DeliveryHistoryCard extends StatelessWidget {
  final DeliveryModel delivery;
  final VoidCallback? onTap;

  const _DeliveryHistoryCard({required this.delivery, this.onTap});

  String _formatDate(String? date) {
    if (date == null || date.isEmpty) return '';
    try {
      final parsed = DateTime.parse(date);
      return '${parsed.day}/${parsed.month}/${parsed.year}';
    } catch (_) {
      return date;
    }
  }

  @override
  Widget build(BuildContext context) {
    final successRate = delivery.totalOrders > 0
        ? (delivery.deliveredCount / delivery.totalOrders * 100)
        : 0.0;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                // Status icon with gradient background
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: delivery.isCompleted
                          ? [AppTheme.successColor, AppTheme.successColor.withValues(alpha: 0.7)]
                          : [Colors.grey.shade400, Colors.grey.shade300],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    delivery.isCompleted ? Icons.check_circle : Icons.local_shipping,
                    color: Colors.white,
                    size: 26,
                  ),
                ),
                const SizedBox(width: 14),
                // Delivery info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              delivery.reference,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                              ),
                            ),
                          ),
                          _StatusBadge(status: delivery.status),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          // Orders count
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: AppTheme.primaryColor.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.shopping_bag, size: 12, color: AppTheme.primaryColor),
                                const SizedBox(width: 4),
                                Text(
                                  '${delivery.deliveredCount}/${delivery.totalOrders}',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: AppTheme.primaryColor,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          // Success rate
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: successRate >= 80
                                  ? AppTheme.successColor.withValues(alpha: 0.1)
                                  : successRate >= 50
                                      ? Colors.orange.withValues(alpha: 0.1)
                                      : AppTheme.dangerColor.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              '${successRate.toStringAsFixed(0)}%',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: successRate >= 80
                                    ? AppTheme.successColor
                                    : successRate >= 50
                                        ? Colors.orange
                                        : AppTheme.dangerColor,
                              ),
                            ),
                          ),
                          const Spacer(),
                          // Date
                          if (delivery.date != null)
                            Text(
                              _formatDate(delivery.date),
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey[500],
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Icon(Icons.chevron_left, color: Colors.grey[400], size: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _LocationInfoCard extends StatelessWidget {
  final LocationState locationState;
  final VoidCallback onEnableLocation;

  const _LocationInfoCard({
    required this.locationState,
    required this.onEnableLocation,
  });

  String _formatDistance(double meters) {
    if (meters < 1000) {
      return '${meters.toStringAsFixed(0)}م';
    } else {
      return '${(meters / 1000).toStringAsFixed(1)}كم';
    }
  }

  @override
  Widget build(BuildContext context) {
    // Show warning if location is not enabled or no permission
    if (!locationState.isEnabled || !locationState.hasPermission) {
      return Card(
        color: AppTheme.warningColor.withValues(alpha: 0.1),
        child: InkWell(
          onTap: onEnableLocation,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppTheme.warningColor.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.location_off,
                    color: AppTheme.warningColor,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        !locationState.isEnabled
                            ? 'الموقع مطفأ'
                            : 'صلاحية الموقع مطلوبة',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: AppTheme.warningColor,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'اضغط هنا لتفعيل الموقع',
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_left, color: AppTheme.warningColor),
              ],
            ),
          ),
        ),
      );
    }

    // Show location info when tracking
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Speed and tracking status
            Row(
              children: [
                // Speed indicator
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.speed, color: AppTheme.primaryColor),
                        const SizedBox(width: 8),
                        Text(
                          '${locationState.speedKmh.toStringAsFixed(0)} كم/س',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                            color: AppTheme.primaryColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                // Tracking status
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: locationState.isTracking
                        ? AppTheme.successColor.withValues(alpha: 0.1)
                        : Colors.grey.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        locationState.isTracking
                            ? Icons.gps_fixed
                            : Icons.gps_off,
                        color: locationState.isTracking
                            ? AppTheme.successColor
                            : Colors.grey,
                        size: 20,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        locationState.isTracking ? 'متصل' : 'غير متصل',
                        style: TextStyle(
                          fontWeight: FontWeight.w500,
                          color: locationState.isTracking
                              ? AppTheme.successColor
                              : Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            // Nearest store info
            if (locationState.nearestStore != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: locationState.nearestStore!.isNearby
                      ? AppTheme.successColor.withValues(alpha: 0.15)
                      : Colors.blue.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                  border: locationState.nearestStore!.isNearby
                      ? Border.all(color: AppTheme.successColor, width: 2)
                      : null,
                ),
                child: Row(
                  children: [
                    Icon(
                      locationState.nearestStore!.isNearby
                          ? Icons.store
                          : Icons.near_me,
                      color: locationState.nearestStore!.isNearby
                          ? AppTheme.successColor
                          : Colors.blue,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            locationState.nearestStore!.isNearby
                                ? 'وصلت إلى ${locationState.nearestStore!.clientName}'
                                : 'أقرب عميل: ${locationState.nearestStore!.clientName}',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: locationState.nearestStore!.isNearby
                                  ? AppTheme.successColor
                                  : Colors.blue,
                            ),
                          ),
                          Text(
                            'المسافة: ${_formatDistance(locationState.nearestStore!.distance)}',
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (locationState.nearestStore!.clientPhone != null)
                      IconButton(
                        onPressed: () {
                          final phone = locationState.nearestStore!.clientPhone;
                          if (phone != null && phone.isNotEmpty) {
                            launchUrl(Uri.parse('tel:$phone'));
                          }
                        },
                        icon: const Icon(
                          Icons.phone,
                          color: AppTheme.successColor,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ProximityAlertCard extends StatelessWidget {
  final StoreProximity proximity;
  final VoidCallback onCall;
  final VoidCallback onSkip;
  final VoidCallback onDeliver;

  const _ProximityAlertCard({
    required this.proximity,
    required this.onCall,
    required this.onSkip,
    required this.onDeliver,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppTheme.successColor.withValues(alpha: 0.15),
            AppTheme.primaryColor.withValues(alpha: 0.1),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.successColor, width: 2),
        boxShadow: [
          BoxShadow(
            color: AppTheme.successColor.withValues(alpha: 0.3),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppTheme.successColor.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.location_on,
                    color: AppTheme.successColor,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'اقتربت من العميل!',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.successColor,
                        ),
                      ),
                      Text(
                        'المسافة: ${proximity.distanceText}',
                        style: TextStyle(fontSize: 13, color: Colors.grey[700]),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Client info
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.person, size: 18, color: Colors.grey),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          proximity.clientName,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (proximity.clientAddress != null) ...[
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        const Icon(
                          Icons.location_city,
                          size: 18,
                          color: Colors.grey,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            proximity.clientAddress!,
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey[600],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                  if (proximity.clientPhone != null) ...[
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        const Icon(Icons.phone, size: 18, color: Colors.grey),
                        const SizedBox(width: 8),
                        Text(
                          proximity.clientPhone!,
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Action buttons
            Row(
              children: [
                // Call button
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: proximity.clientPhone != null ? onCall : null,
                    icon: const Icon(Icons.phone, size: 20),
                    label: const Text('اتصل'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.successColor,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // Deliver button
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: onDeliver,
                    icon: const Icon(Icons.local_shipping, size: 20),
                    label: const Text('تسليم'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryColor,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // Skip button
                OutlinedButton.icon(
                  onPressed: onSkip,
                  icon: const Icon(Icons.skip_next, size: 20),
                  label: const Text('تخطي'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.grey[700],
                    padding: const EdgeInsets.symmetric(
                      vertical: 12,
                      horizontal: 12,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// Order item with swipe actions for cancel
class _OrderItemWithActions extends ConsumerWidget {
  final DeliveryOrderModel order;
  final int deliveryId;
  final VoidCallback? onTap;
  final VoidCallback? onCancel;
  final VoidCallback? onSkip;
  final bool isEnabled;

  const _OrderItemWithActions({
    required this.order,
    required this.deliveryId,
    this.onTap,
    this.onCancel,
    this.onSkip,
    this.isEnabled = true,
  });

  String _formatDistance(double meters) {
    if (meters < 1000) {
      return '${meters.toStringAsFixed(0)}م';
    } else {
      return '${(meters / 1000).toStringAsFixed(1)}كم';
    }
  }

  void _openMaps() async {
    Uri uri;
    if (order.clientLat != null && order.clientLng != null) {
      uri = Uri.parse(
        'https://www.google.com/maps/dir/?api=1&destination=${order.clientLat},${order.clientLng}',
      );
    } else if (order.clientAddress != null && order.clientAddress!.isNotEmpty) {
      uri = Uri.parse(
        'https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(order.clientAddress!)}',
      );
    } else {
      return;
    }
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  bool get _canOpenMaps {
    return order.clientLat != null && order.clientLng != null ||
        (order.clientAddress != null && order.clientAddress!.isNotEmpty);
  }

  void _showActionsSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle bar
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            // Client name header
            Text(
              order.clientName ?? 'عميل',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            if (order.clientAddress != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  order.clientAddress!,
                  style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                  textAlign: TextAlign.center,
                ),
              ),
            const SizedBox(height: 20),
            // Action buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                // Navigation
                if (_canOpenMaps)
                  _ActionButton(
                    icon: Icons.navigation,
                    label: 'خرائط',
                    color: Colors.blue,
                    onTap: () {
                      Navigator.pop(context);
                      _openMaps();
                    },
                  ),
                // Call
                if (order.clientPhone != null)
                  _ActionButton(
                    icon: Icons.phone,
                    label: 'اتصال',
                    color: Colors.green,
                    onTap: () {
                      Navigator.pop(context);
                      launchUrl(Uri.parse('tel:${order.clientPhone}'));
                    },
                  ),
                // Skip
                if (onSkip != null)
                  _ActionButton(
                    icon: Icons.skip_next,
                    label: 'تخطي',
                    color: Colors.orange,
                    onTap: () {
                      Navigator.pop(context);
                      onSkip!();
                    },
                  ),
                // Cancel
                if (onCancel != null)
                  _ActionButton(
                    icon: Icons.cancel,
                    label: 'إلغاء',
                    color: AppTheme.dangerColor,
                    onTap: () {
                      Navigator.pop(context);
                      onCancel!();
                    },
                  ),
              ],
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final itemsCount = order.items.length;
    final distance = ref
        .read(locationProvider.notifier)
        .getDistanceToOrder(order);

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      color: isEnabled ? null : Colors.grey[100],
      child: InkWell(
        onTap: isEnabled ? onTap : null,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              // Order number badge with distance
              Column(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: isEnabled
                          ? (order.isPostponed
                                ? Colors.orange
                                : AppTheme.primaryColor)
                          : Colors.grey,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Center(
                      child: Text(
                        '${order.deliveryOrder}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ),
                  if (distance != null) ...[
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: distance < 600
                            ? AppTheme.successColor.withValues(alpha: 0.2)
                            : Colors.blue.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        _formatDistance(distance),
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: distance < 600
                              ? AppTheme.successColor
                              : Colors.blue,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(width: 12),
              // Client info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            order.clientName ?? 'عميل',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: isEnabled ? null : Colors.grey,
                            ),
                          ),
                        ),
                        if (order.isPostponed)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.orange.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text(
                              'مؤجل',
                              style: TextStyle(
                                fontSize: 10,
                                color: Colors.orange,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$itemsCount منتج',
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                    if (!isEnabled)
                      Text(
                        'ابدأ التوصيل أولاً',
                        style: TextStyle(
                          fontSize: 11,
                          color: AppTheme.warningColor,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                  ],
                ),
              ),
              // Amount and actions
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (order.grandTotal != null)
                    Text(
                      '${order.grandTotal!.toStringAsFixed(0)} د.ج',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: isEnabled ? AppTheme.primaryColor : Colors.grey,
                        fontSize: 14,
                      ),
                    ),
                  const SizedBox(height: 4),
                  if (isEnabled)
                    GestureDetector(
                      onTap: () => _showActionsSheet(context),
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Colors.grey.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Icon(
                          Icons.more_vert,
                          size: 20,
                          color: Colors.grey,
                        ),
                      ),
                    )
                  else
                    const Icon(Icons.lock, color: Colors.grey, size: 20),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Skipped order item with restore/deliver/cancel actions
class _SkippedOrderItem extends StatelessWidget {
  final DeliveryOrderModel order;
  final int deliveryId;
  final VoidCallback? onRestore;
  final VoidCallback? onDeliver;
  final VoidCallback? onCancel;

  const _SkippedOrderItem({
    required this.order,
    required this.deliveryId,
    this.onRestore,
    this.onDeliver,
    this.onCancel,
  });

  bool get _canOpenMaps {
    return order.clientLat != null && order.clientLng != null ||
        (order.clientAddress != null && order.clientAddress!.isNotEmpty);
  }

  void _openMaps() async {
    Uri uri;
    if (order.clientLat != null && order.clientLng != null) {
      uri = Uri.parse(
        'https://www.google.com/maps/dir/?api=1&destination=${order.clientLat},${order.clientLng}',
      );
    } else if (order.clientAddress != null && order.clientAddress!.isNotEmpty) {
      uri = Uri.parse(
        'https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(order.clientAddress!)}',
      );
    } else {
      return;
    }
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          // Order badge
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: Colors.orange.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Center(
              child: Text(
                '${order.deliveryOrder}',
                style: const TextStyle(
                  color: Colors.orange,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          // Client info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  order.clientName ?? 'عميل',
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
                Text(
                  '${order.grandTotal?.toStringAsFixed(0) ?? 0} د.ج',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
              ],
            ),
          ),
          // Actions
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Maps navigation button
              if (_canOpenMaps)
                IconButton(
                  onPressed: _openMaps,
                  icon: const Icon(Icons.navigation, size: 20),
                  color: Colors.blue,
                  tooltip: 'خرائط',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 36,
                    minHeight: 36,
                  ),
                ),
              // Restore button
              IconButton(
                onPressed: onRestore,
                icon: const Icon(Icons.undo, size: 20),
                color: Colors.grey,
                tooltip: 'إعادة للقائمة',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
              ),
              // Deliver button
              IconButton(
                onPressed: onDeliver,
                icon: const Icon(Icons.local_shipping, size: 20),
                color: AppTheme.successColor,
                tooltip: 'تسليم',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
              ),
              // Cancel button
              IconButton(
                onPressed: onCancel,
                icon: const Icon(Icons.cancel, size: 20),
                color: AppTheme.dangerColor,
                tooltip: 'إلغاء',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// Action button for bottom sheet
class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(icon, color: color, size: 28),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

// Today's Statistics Section
class _TodayStatsSection extends StatelessWidget {
  final DeliveryState deliveryState;

  const _TodayStatsSection({required this.deliveryState});

  @override
  Widget build(BuildContext context) {
    // Calculate today's stats from active delivery and history
    int totalDeliveries = 0;
    int completedDeliveries = 0;
    int pendingDeliveries = 0;
    double totalCollected = 0;
    int totalOrders = 0;
    int deliveredOrders = 0;

    // Stats from active delivery
    if (deliveryState.activeDelivery != null) {
      final active = deliveryState.activeDelivery!;
      totalOrders += active.totalOrders;
      deliveredOrders += active.orders.where((o) => o.isDelivered || o.isPartial).length;
      pendingDeliveries = 1;
      totalCollected += active.orders
          .where((o) => o.isDelivered || o.isPartial)
          .fold<double>(0, (sum, o) => sum + (o.amountCollected ?? 0));
    }

    // Stats from today's completed deliveries
    final today = DateTime.now();
    final todayDeliveries = deliveryState.deliveries.where((d) {
      if (d.date == null) return false;
      try {
        final deliveryDate = DateTime.parse(d.date!);
        return deliveryDate.year == today.year &&
            deliveryDate.month == today.month &&
            deliveryDate.day == today.day;
      } catch (_) {
        return false;
      }
    }).toList();

    totalDeliveries = todayDeliveries.length + (deliveryState.activeDelivery != null ? 1 : 0);
    completedDeliveries = todayDeliveries.where((d) => d.isCompleted).length;

    // Calculate success rate
    final successRate = totalOrders > 0 ? (deliveredOrders / totalOrders * 100) : 0.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'إحصائيات اليوم',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _StatCard(
                icon: Icons.local_shipping,
                label: 'رحلات التوصيل',
                value: '$totalDeliveries',
                color: AppTheme.primaryColor,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _StatCard(
                icon: Icons.check_circle,
                label: 'مكتملة',
                value: '$completedDeliveries',
                color: AppTheme.successColor,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _StatCard(
                icon: Icons.payments,
                label: 'المحصّل',
                value: '${totalCollected.toStringAsFixed(0)} د.ج',
                color: const Color(0xFF2E7D32),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _StatCard(
                icon: Icons.trending_up,
                label: 'نسبة النجاح',
                value: '${successRate.toStringAsFixed(0)}%',
                color: successRate >= 80
                    ? AppTheme.successColor
                    : successRate >= 50
                        ? AppTheme.warningColor
                        : AppTheme.dangerColor,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// Stat Card Widget
class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const Spacer(),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }
}
