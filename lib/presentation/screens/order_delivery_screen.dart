import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../providers/delivery_provider.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/delivery_model.dart';
import '../../data/services/api_service.dart';

class OrderDeliveryScreen extends ConsumerStatefulWidget {
  final DeliveryOrderModel order;
  final int deliveryId;

  const OrderDeliveryScreen({
    super.key,
    required this.order,
    required this.deliveryId,
  });

  @override
  ConsumerState<OrderDeliveryScreen> createState() => _OrderDeliveryScreenState();
}

class _OrderDeliveryScreenState extends ConsumerState<OrderDeliveryScreen> {
  Map<int, int> deliveredQuantities = {};
  Map<int, String> returnReasons = {};
  bool _isProcessing = false;
  bool _isLoading = true;
  List<_ProductItem> _products = [];
  String? _errorMessage;

  final TextEditingController _amountController = TextEditingController();
  bool _manualAmountEdit = false;

  @override
  void initState() {
    super.initState();
    _loadItems();
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  double get actualCollectedAmount {
    if (_amountController.text.isEmpty) return totalDeliveredAmount;
    return double.tryParse(_amountController.text) ?? totalDeliveredAmount;
  }

  double get debtAmount => totalDeliveredAmount - actualCollectedAmount;

  // Old debt before this delivery (excluding current delivery)
  double get oldDebt {
    final clientBalance = widget.order.clientBalance ?? 0;
    // Client balance includes all debt, we need to exclude this delivery's amount
    // Since this delivery hasn't been added to balance yet, clientBalance is the old debt
    return clientBalance;
  }

  double get totalDebtWithOld => oldDebt + totalDeliveredAmount;

  double get remainingDebtAfterPayment => totalDebtWithOld - actualCollectedAmount;

  void _updateAmountFromQuantity() {
    if (!_manualAmountEdit) {
      _amountController.text = totalDeliveredAmount.toStringAsFixed(0);
    }
  }

  Future<void> _loadItems() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final response = await ApiService.instance.getDeliveryOrderItems(
        widget.deliveryId,
        widget.order.id,
      );

      if (response.data != null) {
        final itemsList = response.data['items'] as List?;
        if (itemsList != null && itemsList.isNotEmpty) {
          _products = [];
          for (var itemJson in itemsList) {
            final item = _ProductItem(
              id: itemJson['id'],
              productId: itemJson['product_id'],
              productName: itemJson['product_name'] ?? 'منتج',
              unitShortName: itemJson['unit_short_name'] ?? 'وحدة',
              piecesPerPackage: _parseNum(itemJson['pieces_per_package'] ?? 1),
              quantityOrdered: _parseNum(itemJson['quantity_ordered']),
              quantityConfirmed: _parseNum(itemJson['quantity_confirmed']),
              unitPrice: _parseDouble(itemJson['unit_price']),
              discount: _parseDouble(itemJson['discount']),
              subtotal: _parseDouble(itemJson['subtotal']),
            );
            _products.add(item);
            deliveredQuantities[item.productId] = item.quantityConfirmed;
          }
        }
      }
    } catch (e, stack) {
      debugPrint('[ORDER_SCREEN] Error: $e\n$stack');
      _errorMessage = 'خطأ في تحميل المنتجات';
    }

    if (mounted) {
      setState(() {
        _isLoading = false;
        _amountController.text = totalDeliveredAmount.toStringAsFixed(0);
      });
    }
  }

  int _parseNum(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is String) return int.tryParse(value.split('.')[0]) ?? 0;
    return 0;
  }

  double _parseDouble(dynamic value) {
    if (value == null) return 0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0;
    return 0;
  }

  double get totalDeliveredAmount {
    double total = 0;
    for (var item in _products) {
      final qty = deliveredQuantities[item.productId] ?? 0;
      // unitPrice is already the price per package, don't multiply by piecesPerPackage
      total += qty * item.unitPrice;
    }
    return total;
  }

  double get totalReturnedAmount {
    double total = 0;
    for (var item in _products) {
      final delivered = deliveredQuantities[item.productId] ?? 0;
      final returned = item.quantityConfirmed - delivered;
      // unitPrice is already the price per package, don't multiply by piecesPerPackage
      total += returned * item.unitPrice;
    }
    return total;
  }

  int get totalDeliveredQty {
    int total = 0;
    for (var item in _products) {
      total += deliveredQuantities[item.productId] ?? 0;
    }
    return total;
  }

  int get totalReturnedQty {
    int total = 0;
    for (var item in _products) {
      final delivered = deliveredQuantities[item.productId] ?? 0;
      total += item.quantityConfirmed - delivered;
    }
    return total;
  }

  bool get hasReturns => totalReturnedQty > 0;

  bool get canSubmit {
    if (hasReturns) {
      for (var item in _products) {
        final delivered = deliveredQuantities[item.productId] ?? 0;
        if (item.quantityConfirmed - delivered > 0 && returnReasons[item.productId] == null) {
          return false;
        }
      }
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: Text(widget.order.clientName ?? 'تسليم الطلب', style: const TextStyle(fontSize: 16)),
        titleSpacing: 0,
        actions: [
          if (widget.order.clientPhone != null)
            IconButton(
              icon: const Icon(Icons.phone, color: AppTheme.successColor, size: 22),
              onPressed: () => _callClient(widget.order.clientPhone!),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 40),
            ),
          if (widget.order.clientLat != null && widget.order.clientLng != null)
            IconButton(
              icon: const Icon(Icons.navigation, color: AppTheme.primaryColor, size: 22),
              onPressed: () => _openMap(widget.order.clientLat!, widget.order.clientLng!),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 40),
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? _buildError()
              : Column(
                  children: [
                    _buildClientHeader(),
                    Expanded(
                      child: _products.isEmpty
                          ? _buildNoItems()
                          : ListView.builder(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                              itemCount: _products.length,
                              itemBuilder: (context, index) => _buildProductItem(_products[index]),
                            ),
                    ),
                    _buildBottomSection(),
                  ],
                ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 48, color: AppTheme.dangerColor),
          const SizedBox(height: 12),
          Text(_errorMessage!, style: const TextStyle(color: Colors.grey, fontSize: 14)),
          const SizedBox(height: 12),
          TextButton.icon(
            onPressed: _loadItems,
            icon: const Icon(Icons.refresh, size: 18),
            label: const Text('إعادة المحاولة', style: TextStyle(fontSize: 13)),
          ),
        ],
      ),
    );
  }

  Widget _buildClientHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      color: Colors.white,
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppTheme.primaryColor,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(
              child: Text(
                '${widget.order.deliveryOrder}',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.order.clientName ?? 'عميل',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
                if (widget.order.clientAddress != null)
                  Text(widget.order.clientAddress!,
                    style: TextStyle(color: Colors.grey[600], fontSize: 11),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${widget.order.grandTotal?.toStringAsFixed(0) ?? 0} د.ج',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.primaryColor),
              ),
              Text('${_products.length} منتج', style: TextStyle(color: Colors.grey[600], fontSize: 10)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildNoItems() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.inventory_2_outlined, size: 48, color: Colors.grey),
          const SizedBox(height: 12),
          const Text('لا توجد منتجات', style: TextStyle(color: Colors.grey, fontSize: 14)),
          TextButton.icon(
            onPressed: _loadItems,
            icon: const Icon(Icons.refresh, size: 18),
            label: const Text('إعادة التحميل', style: TextStyle(fontSize: 13)),
          ),
        ],
      ),
    );
  }

  Widget _buildProductItem(_ProductItem item) {
    final deliveredQty = deliveredQuantities[item.productId] ?? 0;
    final returnedQty = item.quantityConfirmed - deliveredQty;

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: returnedQty > 0 ? Border.all(color: Colors.red[300]!, width: 1) : null,
      ),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          children: [
            // Product info row
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(item.productName, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Text(
                            '${item.unitPrice.toStringAsFixed(0)} د.ج × ${item.quantityConfirmed}',
                            style: TextStyle(color: Colors.grey[600], fontSize: 11),
                          ),
                          if (item.piecesPerPackage > 1) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                              decoration: BoxDecoration(
                                color: Colors.blue[50],
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                '${item.piecesPerPackage} قطعة',
                                style: TextStyle(fontSize: 9, color: Colors.blue[700], fontWeight: FontWeight.bold),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '${item.subtotal.toStringAsFixed(0)} د.ج',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                    Text(
                      '${item.unitPrice.toStringAsFixed(0)}×${item.quantityConfirmed}',
                      style: TextStyle(fontSize: 8, color: Colors.grey[500]),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 8),
            // Quantity control row
            Row(
              children: [
                // Quick buttons
                _quickChip('الكل', AppTheme.successColor, deliveredQty == item.quantityConfirmed, () {
                  setState(() {
                    deliveredQuantities[item.productId] = item.quantityConfirmed;
                    returnReasons.remove(item.productId);
                    _updateAmountFromQuantity();
                  });
                }),
                const SizedBox(width: 4),
                _quickChip('صفر', AppTheme.dangerColor, deliveredQty == 0, () {
                  setState(() {
                    deliveredQuantities[item.productId] = 0;
                    _updateAmountFromQuantity();
                  });
                }),
                const Spacer(),
                // Quantity controls
                _qtyButton(Icons.remove, deliveredQty > 0, () {
                  setState(() {
                    deliveredQuantities[item.productId] = deliveredQty - 1;
                    _updateAmountFromQuantity();
                  });
                }),
                Container(
                  width: 44,
                  height: 32,
                  margin: const EdgeInsets.symmetric(horizontal: 6),
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Center(
                    child: Text('$deliveredQty', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                ),
                _qtyButton(Icons.add, deliveredQty < item.quantityConfirmed, () {
                  setState(() {
                    deliveredQuantities[item.productId] = deliveredQty + 1;
                    _updateAmountFromQuantity();
                  });
                }),
              ],
            ),
            // Return reason dropdown if there are returns
            if (returnedQty > 0) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.red[50],
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  children: [
                    Text('مرتجع: $returnedQty', style: const TextStyle(color: AppTheme.dangerColor, fontSize: 11, fontWeight: FontWeight.w600)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Container(
                        height: 32,
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: Colors.red[200]!),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: returnReasons[item.productId],
                            hint: const Text('سبب الإرجاع', style: TextStyle(fontSize: 11)),
                            isExpanded: true,
                            isDense: true,
                            style: const TextStyle(fontSize: 11, color: Colors.black87),
                            items: const [
                              DropdownMenuItem(value: 'refused', child: Text('رفض العميل')),
                              DropdownMenuItem(value: 'damaged', child: Text('تالف')),
                              DropdownMenuItem(value: 'excess', child: Text('زيادة')),
                              DropdownMenuItem(value: 'other', child: Text('أخرى')),
                            ],
                            onChanged: (value) {
                              if (value != null) setState(() => returnReasons[item.productId] = value);
                            },
                          ),
                        ),
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

  Widget _quickChip(String label, Color color, bool selected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? color : color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : color,
            fontWeight: FontWeight.w600,
            fontSize: 11,
          ),
        ),
      ),
    );
  }

  Widget _qtyButton(IconData icon, bool enabled, VoidCallback onTap) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: enabled ? (icon == Icons.add ? AppTheme.successColor : AppTheme.dangerColor) : Colors.grey[300],
          borderRadius: BorderRadius.circular(6),
        ),
        child: Icon(icon, color: Colors.white, size: 20),
      ),
    );
  }

  Widget _buildBottomSection() {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 8, offset: const Offset(0, -2))],
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Old debt info card
            if (oldDebt > 0) ...[
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.orange[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange[200]!),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('دين سابق:', style: TextStyle(fontSize: 11, color: Colors.orange[800])),
                        Text('${oldDebt.toStringAsFixed(0)} د.ج',
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.orange[800])),
                      ],
                    ),
                    const Divider(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('هذا التوصيل:', style: TextStyle(fontSize: 11, color: Colors.grey[700])),
                        Text('${totalDeliveredAmount.toStringAsFixed(0)} د.ج',
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey[700])),
                      ],
                    ),
                    const Divider(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('المجموع الكلي:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.red[800])),
                        Text('${totalDebtWithOld.toStringAsFixed(0)} د.ج',
                            style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.red[800])),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
            ],
            // Summary row
            Row(
              children: [
                _summaryBox('للتسليم', totalDeliveredAmount, totalDeliveredQty, AppTheme.successColor),
                const SizedBox(width: 8),
                _summaryBox('مرتجع', totalReturnedAmount, totalReturnedQty, AppTheme.dangerColor),
                const SizedBox(width: 8),
                // Amount input
                Expanded(
                  flex: 2,
                  child: Container(
                    height: 50,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    decoration: BoxDecoration(
                      color: Colors.blue[50],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.blue[200]!),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.payments, color: AppTheme.primaryColor, size: 18),
                        const SizedBox(width: 6),
                        Expanded(
                          child: TextField(
                            controller: _amountController,
                            keyboardType: TextInputType.number,
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                            decoration: const InputDecoration(
                              border: InputBorder.none,
                              isDense: true,
                              contentPadding: EdgeInsets.zero,
                              hintText: '0',
                            ),
                            onChanged: (_) => setState(() => _manualAmountEdit = true),
                          ),
                        ),
                        const Text('د.ج', style: TextStyle(fontSize: 11, color: Colors.grey)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            // Payment status warning/info
            if (actualCollectedAmount != totalDeliveredAmount || oldDebt > 0) ...[
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
                decoration: BoxDecoration(
                  color: remainingDebtAfterPayment > 0
                      ? Colors.orange[100]
                      : actualCollectedAmount > totalDeliveredAmount
                          ? Colors.green[100]
                          : Colors.blue[50],
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Column(
                  children: [
                    if (actualCollectedAmount > totalDeliveredAmount && oldDebt > 0) ...[
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('دفع زائد للدين القديم:', style: TextStyle(color: Colors.green[800], fontSize: 11)),
                          Text('${(actualCollectedAmount - totalDeliveredAmount).toStringAsFixed(0)} د.ج',
                              style: TextStyle(color: Colors.green[800], fontSize: 11, fontWeight: FontWeight.bold)),
                        ],
                      ),
                      const SizedBox(height: 4),
                    ],
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Icon(
                              remainingDebtAfterPayment > 0 ? Icons.warning_amber_rounded : Icons.check_circle,
                              color: remainingDebtAfterPayment > 0 ? Colors.orange : Colors.green,
                              size: 16
                            ),
                            const SizedBox(width: 6),
                            Text(
                              remainingDebtAfterPayment > 0 ? 'الدين المتبقي:' : 'تم السداد:',
                              style: TextStyle(
                                color: remainingDebtAfterPayment > 0 ? Colors.orange[800] : Colors.green[800],
                                fontSize: 12,
                                fontWeight: FontWeight.w600
                              )
                            ),
                          ],
                        ),
                        Text(
                          '${remainingDebtAfterPayment.abs().toStringAsFixed(0)} د.ج',
                          style: TextStyle(
                            color: remainingDebtAfterPayment > 0 ? Colors.orange[800] : Colors.green[800],
                            fontSize: 12,
                            fontWeight: FontWeight.bold
                          )
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 8),
            // Action buttons
            Row(
              children: [
                _actionBtn(Icons.close, 'فشل', AppTheme.dangerColor, false, _showFailDialog),
                const SizedBox(width: 6),
                _actionBtn(Icons.schedule, 'تأجيل', AppTheme.warningColor, false, _postponeOrder),
                const SizedBox(width: 6),
                Expanded(
                  flex: 2,
                  child: SizedBox(
                    height: 42,
                    child: ElevatedButton.icon(
                      onPressed: (_isProcessing || !canSubmit) ? null : _deliverOrder,
                      icon: _isProcessing
                          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.check, size: 18),
                      label: Text(hasReturns ? 'تسليم جزئي' : 'تسليم', style: const TextStyle(fontSize: 13)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: hasReturns ? AppTheme.warningColor : AppTheme.successColor,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
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

  Widget _summaryBox(String label, double amount, int qty, Color color) {
    return Expanded(
      child: Container(
        height: 50,
        padding: const EdgeInsets.symmetric(vertical: 4),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(label, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w500)),
            Text('${amount.toStringAsFixed(0)}', style: TextStyle(color: color, fontSize: 14, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  Widget _actionBtn(IconData icon, String label, Color color, bool filled, VoidCallback onTap) {
    return Expanded(
      child: SizedBox(
        height: 42,
        child: OutlinedButton(
          onPressed: _isProcessing ? null : onTap,
          style: OutlinedButton.styleFrom(
            side: BorderSide(color: color),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            padding: EdgeInsets.zero,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: color, size: 16),
              Text(label, style: TextStyle(color: color, fontSize: 10)),
            ],
          ),
        ),
      ),
    );
  }

  void _callClient(String phone) async {
    final uri = Uri.parse('tel:$phone');
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }

  void _openMap(double lat, double lng) async {
    final uri = Uri.parse('https://www.google.com/maps/dir/?api=1&destination=$lat,$lng');
    if (await canLaunchUrl(uri)) await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<void> _deliverOrder() async {
    if (!mounted) return;
    final notifier = ref.read(deliveryProvider.notifier);
    final collectedAmount = actualCollectedAmount;

    setState(() => _isProcessing = true);

    bool success;
    try {
      if (hasReturns && _products.isNotEmpty) {
        final items = _products.map((item) {
          final delivered = deliveredQuantities[item.productId] ?? 0;
          final returned = item.quantityConfirmed - delivered;
          return {
            'product_id': item.productId,
            'quantity_delivered': delivered,
            'quantity_returned': returned,
            'return_reason': returned > 0 ? (returnReasons[item.productId] ?? 'other') : null,
          };
        }).toList();

        success = await notifier.partialDelivery(widget.deliveryId, widget.order.id, items, amountCollected: collectedAmount);
      } else {
        success = await notifier.deliverOrder(widget.deliveryId, widget.order.id, amountCollected: collectedAmount);
      }
    } catch (e) {
      debugPrint('[ORDER_SCREEN] Error: $e');
      success = false;
    }

    if (!mounted) return;
    setState(() => _isProcessing = false);
    if (success) Navigator.pop(context, true);
  }

  Future<void> _postponeOrder() async {
    if (!mounted) return;
    final notifier = ref.read(deliveryProvider.notifier);
    setState(() => _isProcessing = true);

    bool success;
    try {
      success = await notifier.postponeOrder(widget.deliveryId, widget.order.id);
    } catch (e) {
      success = false;
    }

    if (!mounted) return;
    setState(() => _isProcessing = false);
    if (success) Navigator.pop(context, true);
  }

  void _showFailDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('سبب الفشل', style: TextStyle(fontSize: 16)),
        contentPadding: const EdgeInsets.symmetric(vertical: 8),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: ['المحل مغلق', 'العميل غير موجود', 'رفض الطلب', 'العنوان خاطئ', 'سبب آخر']
              .map((reason) => ListTile(
                    dense: true,
                    title: Text(reason, style: const TextStyle(fontSize: 14)),
                    onTap: () {
                      Navigator.pop(ctx);
                      _failOrder(reason);
                    },
                  ))
              .toList(),
        ),
      ),
    );
  }

  Future<void> _failOrder(String reason) async {
    if (!mounted) return;
    final notifier = ref.read(deliveryProvider.notifier);
    setState(() => _isProcessing = true);

    bool success;
    try {
      success = await notifier.failOrder(widget.deliveryId, widget.order.id, reason);
    } catch (e) {
      success = false;
    }

    if (!mounted) return;
    setState(() => _isProcessing = false);
    if (success) Navigator.pop(context, true);
  }
}

class _ProductItem {
  final int id;
  final int productId;
  final String productName;
  final String unitShortName;
  final int piecesPerPackage;
  final int quantityOrdered;
  final int quantityConfirmed;
  final double unitPrice;
  final double discount;
  final double subtotal;

  _ProductItem({
    required this.id,
    required this.productId,
    required this.productName,
    this.unitShortName = 'وحدة',
    this.piecesPerPackage = 1,
    required this.quantityOrdered,
    required this.quantityConfirmed,
    required this.unitPrice,
    required this.discount,
    required this.subtotal,
  });
}
