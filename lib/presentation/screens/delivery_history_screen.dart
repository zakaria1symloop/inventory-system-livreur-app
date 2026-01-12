import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../providers/delivery_provider.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/delivery_model.dart';

String formatDate(String? date) {
  if (date == null || date.isEmpty) return '-';
  try {
    final parsed = DateTime.parse(date);
    return DateFormat('dd/MM/yyyy').format(parsed);
  } catch (_) {
    return date;
  }
}

String formatTime(String? time) {
  if (time == null || time.isEmpty) return '-';
  try {
    // Handle both full datetime and time-only formats
    if (time.contains('T') || time.contains(' ')) {
      final parsed = DateTime.parse(time);
      return DateFormat('HH:mm').format(parsed);
    }
    return time.substring(0, 5); // Just take HH:mm
  } catch (_) {
    return time;
  }
}

String formatCurrency(double amount) {
  return '${amount.toStringAsFixed(0)} د.ج';
}

class DeliveryHistoryScreen extends ConsumerStatefulWidget {
  const DeliveryHistoryScreen({super.key});

  @override
  ConsumerState<DeliveryHistoryScreen> createState() => _DeliveryHistoryScreenState();
}

class _DeliveryHistoryScreenState extends ConsumerState<DeliveryHistoryScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(deliveryProvider.notifier).fetchMyDeliveries();
    });
  }

  @override
  Widget build(BuildContext context) {
    final deliveryState = ref.watch(deliveryProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('سجل التوصيلات'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              ref.read(deliveryProvider.notifier).fetchMyDeliveries();
            },
          ),
        ],
      ),
      body: deliveryState.isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: () async {
                await ref.read(deliveryProvider.notifier).fetchMyDeliveries();
              },
              child: deliveryState.deliveries.isEmpty
                  ? ListView(
                      children: [
                        SizedBox(
                          height: MediaQuery.of(context).size.height * 0.7,
                          child: Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.history,
                                  size: 80,
                                  color: Colors.grey[300],
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'لا توجد توصيلات سابقة',
                                  style: TextStyle(
                                    fontSize: 18,
                                    color: Colors.grey[500],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: deliveryState.deliveries.length,
                      itemBuilder: (context, index) {
                        final delivery = deliveryState.deliveries[index];
                        return _DeliveryCard(
                          delivery: delivery,
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => DeliveryOrdersScreen(
                                  delivery: delivery,
                                ),
                              ),
                            );
                          },
                        );
                      },
                    ),
            ),
    );
  }
}

class _DeliveryCard extends StatelessWidget {
  final DeliveryModel delivery;
  final VoidCallback onTap;

  const _DeliveryCard({
    required this.delivery,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    // Calculate totals
    double totalToCollect = 0;
    double totalCollected = 0;
    for (var order in delivery.orders) {
      totalToCollect += order.amountDue ?? order.grandTotal ?? 0;
      if (order.isDelivered || order.isPartial) {
        totalCollected += order.amountCollected ?? 0;
      }
    }
    final successRate = delivery.totalOrders > 0
        ? ((delivery.deliveredCount / delivery.totalOrders) * 100).toInt()
        : 0;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Column(
          children: [
            // Header with reference and status
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withValues(alpha: 0.05),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
              ),
              child: Row(
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
                        child: const Icon(Icons.delivery_dining, color: AppTheme.primaryColor, size: 20),
                      ),
                      const SizedBox(width: 10),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            delivery.reference,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                          ),
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              Icon(Icons.calendar_today, size: 12, color: Colors.grey[600]),
                              const SizedBox(width: 4),
                              Text(
                                formatDate(delivery.date),
                                style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                              ),
                              if (delivery.startTime != null) ...[
                                const SizedBox(width: 8),
                                Icon(Icons.access_time, size: 12, color: Colors.grey[600]),
                                const SizedBox(width: 4),
                                Text(
                                  formatTime(delivery.startTime),
                                  style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                  _StatusBadge(status: delivery.status),
                ],
              ),
            ),

            // Stats row
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                children: [
                  Expanded(
                    child: _MiniStat(
                      icon: Icons.shopping_bag_outlined,
                      label: 'الطلبات',
                      value: '${delivery.deliveredCount}/${delivery.totalOrders}',
                      color: AppTheme.primaryColor,
                    ),
                  ),
                  Container(width: 1, height: 30, color: Colors.grey[300]),
                  Expanded(
                    child: _MiniStat(
                      icon: Icons.trending_up,
                      label: 'نسبة النجاح',
                      value: '$successRate%',
                      color: successRate >= 80 ? AppTheme.successColor :
                             successRate >= 50 ? Colors.orange : AppTheme.dangerColor,
                    ),
                  ),
                  Container(width: 1, height: 30, color: Colors.grey[300]),
                  Expanded(
                    child: _MiniStat(
                      icon: Icons.payments_outlined,
                      label: 'المحصّل',
                      value: formatCurrency(totalCollected),
                      color: AppTheme.successColor,
                    ),
                  ),
                ],
              ),
            ),

            // Vehicle info if available
            if (delivery.vehicleName != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Row(
                  children: [
                    Icon(Icons.local_shipping, size: 14, color: Colors.grey[500]),
                    const SizedBox(width: 6),
                    Text(
                      delivery.vehicleName!,
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                  ],
                ),
              ),

            // Client names preview
            if (delivery.orders.isNotEmpty) ...[
              const SizedBox(height: 8),
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 12),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey[200]!),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.store, size: 14, color: Colors.grey[600]),
                        const SizedBox(width: 6),
                        Text(
                          'العملاء',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.grey[700]),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    ...delivery.orders.take(4).map((order) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 3),
                      child: Row(
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: order.isDelivered ? AppTheme.successColor :
                                     order.isFailed ? AppTheme.dangerColor :
                                     order.isPartial ? Colors.orange : Colors.grey[400],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              order.clientName ?? 'عميل',
                              style: const TextStyle(fontSize: 12),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (order.clientPhone != null)
                            Padding(
                              padding: const EdgeInsets.only(left: 8),
                              child: Text(
                                order.clientPhone!,
                                style: TextStyle(fontSize: 10, color: Colors.grey[500]),
                              ),
                            ),
                          const SizedBox(width: 8),
                          Text(
                            formatCurrency(order.grandTotal ?? 0),
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: order.isDelivered ? AppTheme.successColor : Colors.grey[700],
                            ),
                          ),
                        ],
                      ),
                    )),
                    if (delivery.orders.length > 4)
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(
                          '+${delivery.orders.length - 4} طلبات أخرى',
                          style: TextStyle(fontSize: 11, color: AppTheme.primaryColor, fontWeight: FontWeight.w500),
                        ),
                      ),
                  ],
                ),
              ),
            ],

            // Money summary
            Container(
              margin: const EdgeInsets.all(12),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [AppTheme.successColor.withValues(alpha: 0.1), AppTheme.successColor.withValues(alpha: 0.05)],
                ),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.account_balance_wallet, size: 18, color: AppTheme.successColor),
                      const SizedBox(width: 8),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'إجمالي للتحصيل',
                            style: TextStyle(fontSize: 10, color: Colors.grey[600]),
                          ),
                          Text(
                            formatCurrency(totalToCollect),
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppTheme.successColor,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.check, size: 14, color: Colors.white),
                        const SizedBox(width: 4),
                        Text(
                          formatCurrency(totalCollected),
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _MiniStat({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: color),
        ),
        Text(
          label,
          style: TextStyle(fontSize: 9, color: Colors.grey[600]),
        ),
      ],
    );
  }
}

class _StatChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _StatChip({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
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

// Screen to show orders within a delivery
class DeliveryOrdersScreen extends StatelessWidget {
  final DeliveryModel delivery;

  const DeliveryOrdersScreen({super.key, required this.delivery});

  @override
  Widget build(BuildContext context) {
    // Calculate totals
    double totalCollected = 0;
    for (var order in delivery.orders) {
      if (order.isDelivered || order.isPartial) {
        totalCollected += order.amountCollected ?? 0;
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(delivery.reference),
      ),
      body: Column(
        children: [
          // Summary card
          Container(
            width: double.infinity,
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.calendar_today, size: 16),
                        const SizedBox(width: 6),
                        Text(
                          formatDate(delivery.date),
                          style: const TextStyle(fontWeight: FontWeight.w500),
                        ),
                        if (delivery.startTime != null) ...[
                          const SizedBox(width: 12),
                          const Icon(Icons.access_time, size: 16),
                          const SizedBox(width: 4),
                          Text(
                            '${formatTime(delivery.startTime)}${delivery.endTime != null ? ' - ${formatTime(delivery.endTime)}' : ''}',
                            style: const TextStyle(fontWeight: FontWeight.w500),
                          ),
                        ],
                      ],
                    ),
                    _StatusBadge(status: delivery.status),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _SummaryItem(
                      label: 'إجمالي الطلبات',
                      value: '${delivery.totalOrders}',
                      icon: Icons.shopping_bag,
                    ),
                    _SummaryItem(
                      label: 'تم التسليم',
                      value: '${delivery.deliveredCount}',
                      icon: Icons.check_circle,
                      color: AppTheme.successColor,
                    ),
                    _SummaryItem(
                      label: 'فشل',
                      value: '${delivery.failedCount}',
                      icon: Icons.cancel,
                      color: AppTheme.dangerColor,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.payments, color: AppTheme.successColor),
                      const SizedBox(width: 8),
                      Text(
                        'المبلغ المحصّل: ${totalCollected.toStringAsFixed(0)} د.ج',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: AppTheme.successColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Orders list
          Expanded(
            child: delivery.orders.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.inbox, size: 60, color: Colors.grey[300]),
                        const SizedBox(height: 16),
                        Text(
                          'لا توجد طلبات',
                          style: TextStyle(color: Colors.grey[500]),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: delivery.orders.length,
                    itemBuilder: (context, index) {
                      final order = delivery.orders[index];
                      return _OrderCard(
                        order: order,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => OrderDetailsScreen(
                                order: order,
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _SummaryItem extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color? color;

  const _SummaryItem({
    required this.label,
    required this.value,
    required this.icon,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: color ?? Colors.grey),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 20,
            color: color,
          ),
        ),
        Text(
          label,
          style: const TextStyle(fontSize: 11, color: Colors.grey),
        ),
      ],
    );
  }
}

class _OrderCard extends StatelessWidget {
  final DeliveryOrderModel order;
  final VoidCallback onTap;

  const _OrderCard({
    required this.order,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              // Order number
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: _getStatusColor(order.status).withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Center(
                  child: Text(
                    '${order.deliveryOrder}',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: _getStatusColor(order.status),
                    ),
                  ),
                ),
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
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        _OrderStatusBadge(status: order.status),
                      ],
                    ),
                    const SizedBox(height: 4),
                    if (order.clientAddress != null)
                      Row(
                        children: [
                          Icon(Icons.location_on, size: 14, color: Colors.grey[500]),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              order.clientAddress!,
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    if (order.clientPhone != null) ...[
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Icon(Icons.phone, size: 14, color: Colors.grey[500]),
                          const SizedBox(width: 4),
                          Text(
                            order.clientPhone!,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.blue[50],
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            '${order.items.length} منتج',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.blue[700],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        if (order.amountCollected != null && order.amountCollected! > 0)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppTheme.successColor.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              'محصّل: ${order.amountCollected!.toStringAsFixed(0)} د.ج',
                              style: const TextStyle(
                                fontSize: 11,
                                color: AppTheme.successColor,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                      ],
                    ),
                    if (order.failureReason != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          'السبب: ${order.failureReason}',
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppTheme.dangerColor,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (order.grandTotal != null)
                    Text(
                      '${order.grandTotal!.toStringAsFixed(0)} د.ج',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  const SizedBox(height: 4),
                  const Icon(
                    Icons.arrow_forward_ios,
                    size: 16,
                    color: Colors.grey,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'delivered':
        return AppTheme.successColor;
      case 'partial':
        return Colors.orange;
      case 'failed':
        return AppTheme.dangerColor;
      case 'postponed':
        return Colors.purple;
      default:
        return AppTheme.primaryColor;
    }
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
        bgColor = Colors.orange.withValues(alpha: 0.1);
        textColor = Colors.orange;
        label = 'جزئي';
        break;
      case 'failed':
        bgColor = AppTheme.dangerColor.withValues(alpha: 0.1);
        textColor = AppTheme.dangerColor;
        label = 'فشل';
        break;
      case 'postponed':
        bgColor = Colors.purple.withValues(alpha: 0.1);
        textColor = Colors.purple;
        label = 'مؤجل';
        break;
      default:
        bgColor = Colors.grey.withValues(alpha: 0.1);
        textColor = Colors.grey;
        label = status;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: textColor,
        ),
      ),
    );
  }
}

// Screen to show order item details
class OrderDetailsScreen extends StatelessWidget {
  final DeliveryOrderModel order;

  const OrderDetailsScreen({super.key, required this.order});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('طلب ${order.clientName ?? ""}'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Client info card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          backgroundColor: AppTheme.primaryColor.withValues(alpha: 0.1),
                          child: Text(
                            order.clientName?.substring(0, 1) ?? 'ع',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: AppTheme.primaryColor,
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
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              if (order.clientPhone != null)
                                Text(
                                  order.clientPhone!,
                                  style: TextStyle(
                                    color: Colors.grey[600],
                                  ),
                                ),
                            ],
                          ),
                        ),
                        _OrderStatusBadge(status: order.status),
                      ],
                    ),
                    if (order.clientAddress != null) ...[
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Icon(Icons.location_on, size: 16, color: Colors.grey[600]),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              order.clientAddress!,
                              style: TextStyle(color: Colors.grey[600]),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Order summary
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('المبلغ الإجمالي'),
                        Text(
                          '${order.grandTotal?.toStringAsFixed(0) ?? 0} د.ج',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    if (order.amountDue != null) ...[
                      const Divider(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('المبلغ المستحق'),
                          Text(
                            '${order.amountDue!.toStringAsFixed(0)} د.ج',
                            style: const TextStyle(fontWeight: FontWeight.w500),
                          ),
                        ],
                      ),
                    ],
                    if (order.amountCollected != null && order.amountCollected! > 0) ...[
                      const Divider(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('المبلغ المحصّل'),
                          Text(
                            '${order.amountCollected!.toStringAsFixed(0)} د.ج',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: AppTheme.successColor,
                            ),
                          ),
                        ],
                      ),
                    ],
                    if (order.failureReason != null) ...[
                      const Divider(height: 16),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('سبب الفشل'),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              order.failureReason!,
                              style: const TextStyle(
                                color: AppTheme.dangerColor,
                                fontWeight: FontWeight.w500,
                              ),
                              textAlign: TextAlign.end,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Items header
            const Text(
              'المنتجات',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),

            // Items list
            if (order.items.isEmpty)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Center(
                    child: Text(
                      'لا توجد منتجات',
                      style: TextStyle(color: Colors.grey[500]),
                    ),
                  ),
                ),
              )
            else
              ...order.items.map((item) => _ItemCard(item: item)),
          ],
        ),
      ),
    );
  }
}

class _ItemCard extends StatelessWidget {
  final OrderItemModel item;

  const _ItemCard({required this.item});

  @override
  Widget build(BuildContext context) {
    final isFullyDelivered = item.quantityDelivered == item.quantityConfirmed;
    final hasReturned = item.quantityReturned > 0;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.inventory_2,
                    color: AppTheme.primaryColor,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.productName ?? 'منتج #${item.productId}',
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        '${item.unitPrice.toStringAsFixed(0)} د.ج / وحدة',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  '${item.subtotal.toStringAsFixed(0)} د.ج',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: AppTheme.primaryColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: _QuantityInfo(
                      label: 'مطلوب',
                      value: item.quantityConfirmed,
                      color: AppTheme.primaryColor,
                    ),
                  ),
                  Container(
                    width: 1,
                    height: 30,
                    color: Colors.grey[300],
                  ),
                  Expanded(
                    child: _QuantityInfo(
                      label: 'مسلّم',
                      value: item.quantityDelivered,
                      color: isFullyDelivered ? AppTheme.successColor : Colors.orange,
                    ),
                  ),
                  if (hasReturned) ...[
                    Container(
                      width: 1,
                      height: 30,
                      color: Colors.grey[300],
                    ),
                    Expanded(
                      child: _QuantityInfo(
                        label: 'مرتجع',
                        value: item.quantityReturned,
                        color: AppTheme.dangerColor,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (item.discount > 0) ...[
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    'خصم: ${item.discount.toStringAsFixed(0)} د.ج',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.green[700],
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _QuantityInfo extends StatelessWidget {
  final String label;
  final int value;
  final Color color;

  const _QuantityInfo({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          '$value',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 18,
            color: color,
          ),
        ),
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            color: Colors.grey,
          ),
        ),
      ],
    );
  }
}
