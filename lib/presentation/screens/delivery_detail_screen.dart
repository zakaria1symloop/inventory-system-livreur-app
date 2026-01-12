import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/delivery_provider.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/delivery_model.dart';

class DeliveryDetailScreen extends ConsumerStatefulWidget {
  final int deliveryId;

  const DeliveryDetailScreen({super.key, required this.deliveryId});

  @override
  ConsumerState<DeliveryDetailScreen> createState() => _DeliveryDetailScreenState();
}

class _DeliveryDetailScreenState extends ConsumerState<DeliveryDetailScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final deliveryState = ref.watch(deliveryProvider);
    final delivery = deliveryState.activeDelivery;

    if (delivery == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('تفاصيل التوصيل')),
        body: const Center(child: Text('لا يوجد توصيل نشط')),
      );
    }

    // Orders that need action (pending or postponed)
    final pendingOrders = delivery.orders.where((o) => o.needsAction).toList();
    // Orders that are handled (delivered, partial, failed)
    final completedOrders = delivery.orders.where((o) => o.isHandled).toList();
    final totalExpected = delivery.orders.fold<double>(
      0,
      (sum, o) => sum + (o.grandTotal ?? 0),
    );
    final totalCollected = completedOrders
        .where((o) => o.isDelivered)
        .fold<double>(0, (sum, o) => sum + (o.grandTotal ?? 0));

    return Scaffold(
      appBar: AppBar(
        title: Text(delivery.reference),
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(text: 'الطلبات (${delivery.orders.length})'),
            const Tab(text: 'المخزون'),
            const Tab(text: 'الملخص'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // Orders Tab
          _OrdersTab(
            delivery: delivery,
            pendingOrders: pendingOrders,
            completedOrders: completedOrders,
          ),
          // Stock Tab
          _StockTab(delivery: delivery),
          // Summary Tab
          _SummaryTab(
            delivery: delivery,
            totalExpected: totalExpected,
            totalCollected: totalCollected,
          ),
        ],
      ),
      bottomNavigationBar: delivery.isInProgress && pendingOrders.isEmpty
          ? Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 10,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: ElevatedButton.icon(
                onPressed: () => _showEndDeliveryDialog(context, delivery, totalCollected),
                icon: const Icon(Icons.check_circle),
                label: const Text('إنهاء التوصيل'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.successColor,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            )
          : null,
    );
  }

  void _showEndDeliveryDialog(
    BuildContext context,
    DeliveryModel delivery,
    double totalCollected,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('إنهاء التوصيل'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('ملخص التوصيل:'),
            const SizedBox(height: 16),
            _SummaryRow(
              label: 'إجمالي الطلبات',
              value: '${delivery.totalOrders}',
            ),
            _SummaryRow(
              label: 'تم التسليم',
              value: '${delivery.deliveredCount}',
              color: AppTheme.successColor,
            ),
            _SummaryRow(
              label: 'فشل/مؤجل',
              value: '${delivery.failedCount}',
              color: AppTheme.dangerColor,
            ),
            const Divider(),
            _SummaryRow(
              label: 'المبلغ المحصل',
              value: '${totalCollected.toStringAsFixed(0)} د.ج',
              isBold: true,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await ref.read(deliveryProvider.notifier).completeDelivery(delivery.id);
              if (mounted) {
                Navigator.pop(context);
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.successColor),
            child: const Text('تأكيد الإنهاء'),
          ),
        ],
      ),
    );
  }
}

class _OrdersTab extends ConsumerWidget {
  final DeliveryModel delivery;
  final List<DeliveryOrderModel> pendingOrders;
  final List<DeliveryOrderModel> completedOrders;

  const _OrdersTab({
    required this.delivery,
    required this.pendingOrders,
    required this.completedOrders,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDeliveryStarted = delivery.isInProgress;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Show warning if delivery not started
        if (!isDeliveryStarted && pendingOrders.isNotEmpty) ...[
          Container(
            padding: const EdgeInsets.all(12),
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: AppTheme.warningColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppTheme.warningColor.withValues(alpha: 0.3)),
            ),
            child: const Row(
              children: [
                Icon(Icons.info_outline, color: AppTheme.warningColor),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'يجب بدء التوصيل أولاً للوصول إلى الطلبات',
                    style: TextStyle(color: AppTheme.warningColor),
                  ),
                ),
              ],
            ),
          ),
        ],
        if (pendingOrders.isNotEmpty) ...[
          Text(
            'الطلبات المتبقية (${pendingOrders.length})',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 8),
          ...pendingOrders.map((order) => _OrderCard(
                order: order,
                deliveryId: delivery.id,
                isPending: true,
                isEnabled: isDeliveryStarted,
              )),
          const SizedBox(height: 24),
        ],
        if (completedOrders.isNotEmpty) ...[
          Text(
            'الطلبات المكتملة (${completedOrders.length})',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 8),
          ...completedOrders.map((order) => _OrderCard(
                order: order,
                deliveryId: delivery.id,
                isPending: false,
              )),
        ],
        if (pendingOrders.isEmpty && completedOrders.isEmpty)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(32),
              child: Text('لا توجد طلبات', style: TextStyle(color: Colors.grey)),
            ),
          ),
      ],
    );
  }
}

class _OrderCard extends ConsumerWidget {
  final DeliveryOrderModel order;
  final int deliveryId;
  final bool isPending;
  final bool isEnabled;

  const _OrderCard({
    required this.order,
    required this.deliveryId,
    required this.isPending,
    this.isEnabled = true,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final canTap = isPending && isEnabled;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: canTap ? null : Colors.grey[50],
      child: InkWell(
        onTap: canTap
            ? () async {
                // Store notifier reference before async operation
                final notifier = ref.read(deliveryProvider.notifier);
                final result = await Navigator.pushNamed(
                  context,
                  '/order-delivery',
                  arguments: {
                    'order': order,
                    'deliveryId': deliveryId,
                  },
                );
                if (result == true && context.mounted) {
                  notifier.fetchActiveDelivery();
                }
              }
            : null,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: canTap
                          ? AppTheme.primaryColor.withValues(alpha: 0.1)
                          : Colors.grey.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Center(
                      child: Text(
                        '${order.deliveryOrder}',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: canTap ? AppTheme.primaryColor : Colors.grey,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          order.clientName ?? 'عميل',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        if (order.clientAddress != null)
                          Text(
                            order.clientAddress!,
                            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                          ),
                      ],
                    ),
                  ),
                  _OrderStatusBadge(status: order.status),
                ],
              ),
              const SizedBox(height: 12),

              // Products preview
              if (order.items.isNotEmpty) ...[
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    children: [
                      ...order.items.take(3).map((item) => Padding(
                            padding: const EdgeInsets.symmetric(vertical: 2),
                            child: Row(
                              children: [
                                Text(
                                  '${item.quantityConfirmed}x',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                ),
                                if (item.piecesPerPackage > 1) ...[
                                  const SizedBox(width: 4),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                    decoration: BoxDecoration(
                                      color: Colors.blue[50],
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      '${item.piecesPerPackage}ق',
                                      style: TextStyle(fontSize: 9, color: Colors.blue[700], fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                ],
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    item.productName ?? 'منتج',
                                    style: const TextStyle(fontSize: 12),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                Text(
                                  '${item.subtotal.toStringAsFixed(0)} د.ج',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey[600],
                                  ),
                                ),
                              ],
                            ),
                          )),
                      if (order.items.length > 3)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            '+${order.items.length - 3} منتجات أخرى',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey[500],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
              ],

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${order.grandTotal?.toStringAsFixed(0) ?? 0} د.ج',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: canTap ? AppTheme.primaryColor : Colors.grey,
                    ),
                  ),
                  if (isPending) ...[
                    // Show postponed badge if order was postponed
                    if (order.isPostponed)
                      Container(
                        margin: const EdgeInsets.only(bottom: 4),
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.orange.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          'مؤجل',
                          style: TextStyle(fontSize: 10, color: Colors.orange, fontWeight: FontWeight.bold),
                        ),
                      ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: canTap
                            ? (order.isPostponed ? Colors.orange : AppTheme.primaryColor)
                            : Colors.grey,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            canTap ? 'تسليم' : 'مقفل',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Icon(
                            canTap ? Icons.chevron_right : Icons.lock,
                            color: Colors.white,
                            size: 18,
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
              if (!isPending && order.failureReason != null) ...[
                const Divider(),
                Row(
                  children: [
                    const Icon(Icons.info_outline, size: 16, color: Colors.grey),
                    const SizedBox(width: 8),
                    Text(
                      order.failureReason!,
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _StockTab extends StatelessWidget {
  final DeliveryModel delivery;

  const _StockTab({required this.delivery});

  @override
  Widget build(BuildContext context) {
    // Group all products from all orders
    final Map<int, Map<String, dynamic>> products = {};

    for (var order in delivery.orders) {
      for (var item in order.items) {
        if (products.containsKey(item.productId)) {
          products[item.productId]!['loaded'] += item.quantityConfirmed;
          products[item.productId]!['delivered'] += item.quantityDelivered;
          products[item.productId]!['returned'] += item.quantityReturned;
        } else {
          products[item.productId] = {
            'name': item.productName ?? 'منتج',
            'loaded': item.quantityConfirmed,
            'delivered': item.quantityDelivered,
            'returned': item.quantityReturned,
          };
        }
      }
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text(
          'المخزون المحمّل',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        const SizedBox(height: 12),
        if (products.isEmpty)
          const Card(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Center(
                child: Text('لا توجد منتجات', style: TextStyle(color: Colors.grey)),
              ),
            ),
          )
        else
          ...products.entries.map((entry) {
            final data = entry.value;
            final remaining = data['loaded'] - data['delivered'] - data['returned'];
            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            data['name'],
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              _StockBadge(
                                label: 'محمّل',
                                value: data['loaded'],
                                color: Colors.blue,
                              ),
                              const SizedBox(width: 8),
                              _StockBadge(
                                label: 'تم',
                                value: data['delivered'],
                                color: Colors.green,
                              ),
                              const SizedBox(width: 8),
                              _StockBadge(
                                label: 'مرتجع',
                                value: data['returned'],
                                color: Colors.red,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: remaining > 0
                            ? AppTheme.warningColor.withValues(alpha: 0.1)
                            : AppTheme.successColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'متبقي: $remaining',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: remaining > 0 ? AppTheme.warningColor : AppTheme.successColor,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
      ],
    );
  }
}

class _StockBadge extends StatelessWidget {
  final String label;
  final int value;
  final Color color;

  const _StockBadge({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        '$label: $value',
        style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600),
      ),
    );
  }
}

class _SummaryTab extends StatelessWidget {
  final DeliveryModel delivery;
  final double totalExpected;
  final double totalCollected;

  const _SummaryTab({
    required this.delivery,
    required this.totalExpected,
    required this.totalCollected,
  });

  @override
  Widget build(BuildContext context) {
    final returns = delivery.orders
        .where((o) => o.status == 'partial' || o.status == 'failed' || o.status == 'postponed')
        .toList();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Financial summary
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'ملخص مالي',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(height: 16),
                _SummaryRow(
                  label: 'المبلغ المتوقع',
                  value: '${totalExpected.toStringAsFixed(0)} د.ج',
                ),
                _SummaryRow(
                  label: 'المبلغ المحصل',
                  value: '${totalCollected.toStringAsFixed(0)} د.ج',
                  color: AppTheme.successColor,
                ),
                const Divider(),
                _SummaryRow(
                  label: 'المبلغ المتبقي',
                  value: '${(totalExpected - totalCollected).toStringAsFixed(0)} د.ج',
                  color: AppTheme.dangerColor,
                  isBold: true,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Orders summary
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'ملخص الطلبات',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(height: 16),
                _SummaryRow(label: 'إجمالي الطلبات', value: '${delivery.totalOrders}'),
                _SummaryRow(
                  label: 'تم التسليم',
                  value: '${delivery.deliveredCount}',
                  color: AppTheme.successColor,
                ),
                _SummaryRow(
                  label: 'فشل/مؤجل',
                  value: '${delivery.failedCount}',
                  color: AppTheme.dangerColor,
                ),
                _SummaryRow(
                  label: 'متبقي',
                  value: '${delivery.totalOrders - delivery.deliveredCount - delivery.failedCount}',
                  color: AppTheme.warningColor,
                ),
              ],
            ),
          ),
        ),

        if (returns.isNotEmpty) ...[
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'الطلبات المرتجعة/المؤجلة',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const SizedBox(height: 12),
                  ...returns.map((order) => ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: _OrderStatusBadge(status: order.status),
                        title: Text(order.clientName ?? 'عميل'),
                        subtitle: Text(order.failureReason ?? '-'),
                        trailing: Text('${order.grandTotal?.toStringAsFixed(0) ?? 0} د.ج'),
                      )),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final String label;
  final String value;
  final Color? color;
  final bool isBold;

  const _SummaryRow({
    required this.label,
    required this.value,
    this.color,
    this.isBold = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Text(
            value,
            style: TextStyle(
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
              color: color,
              fontSize: isBold ? 16 : 14,
            ),
          ),
        ],
      ),
    );
  }
}

class _OrderStatusBadge extends StatelessWidget {
  final String status;

  const _OrderStatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    Color bgColor;
    Color textColor;
    String label;

    switch (status) {
      case 'pending':
        bgColor = AppTheme.warningColor.withValues(alpha: 0.1);
        textColor = AppTheme.warningColor;
        label = 'معلق';
        break;
      case 'delivered':
        bgColor = AppTheme.successColor.withValues(alpha: 0.1);
        textColor = AppTheme.successColor;
        label = 'تم التسليم';
        break;
      case 'partial':
        bgColor = AppTheme.primaryColor.withValues(alpha: 0.1);
        textColor = AppTheme.primaryColor;
        label = 'جزئي';
        break;
      case 'failed':
        bgColor = AppTheme.dangerColor.withValues(alpha: 0.1);
        textColor = AppTheme.dangerColor;
        label = 'فشل';
        break;
      case 'postponed':
        bgColor = Colors.grey.withValues(alpha: 0.1);
        textColor = Colors.grey;
        label = 'مؤجل';
        break;
      default:
        bgColor = Colors.grey.withValues(alpha: 0.1);
        textColor = Colors.grey;
        label = status;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: textColor),
      ),
    );
  }
}
