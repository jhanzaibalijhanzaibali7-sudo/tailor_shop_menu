import 'package:flutter/material.dart';

import '../data/db.dart';
import '../data/models.dart';
import '../settings.dart';
import 'common.dart';

/// Orders of one customer: delivery date, total / paid / remaining.
class OrdersPage extends StatefulWidget {
  final Customer customer;

  const OrdersPage({super.key, required this.customer});

  @override
  State<OrdersPage> createState() => _OrdersPageState();
}

class _OrdersPageState extends State<OrdersPage> {
  List<OrderRecord> _orders = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final rows = await DB.instance.orders(widget.customer.id);
    if (!mounted) return;

    setState(() {
      _orders = rows;
      _loading = false;
    });
  }

  Future<void> _edit([OrderRecord? existing]) async {
    final input = await showDialog<_OrderInput>(
      context: context,
      builder: (_) => _OrderDialog(existing: existing),
    );

    if (input == null) return;

    if (existing == null) {
      await DB.instance.addOrder(
        widget.customer.id,
        input.details,
        input.deliveryDate,
        input.total,
        input.paid,
      );
    } else {
      await DB.instance.updateOrder(
        existing.id,
        input.details,
        input.deliveryDate,
        input.total,
        input.paid,
      );
    }

    if (mounted) await _load();
  }

  Future<void> _addPayment(OrderRecord order) async {
    final amount = await showDialog<double>(
      context: context,
      builder: (_) => _PaymentDialog(order: order),
    );

    if (amount == null) return;

    await DB.instance.addPayment(order.id, amount);

    if (mounted) await _load();
  }

  Future<void> _toggleDelivered(OrderRecord order) async {
    await DB.instance.setOrderStatus(
      order.id,
      order.delivered ? 'pending' : 'delivered',
    );

    if (mounted) await _load();
  }

  Future<void> _delete(OrderRecord order) async {
    final s = AppScope.of(context);

    final ok = await confirmDialog(
      context,
      title: s.t(
        'Delete order',
        'آرڊر ڊيليٽ ڪريو',
        'آرڈر حذف کریں',
      ),
      message: s.t(
        'Delete this order?',
        'هي آرڊر ڊيليٽ ڪجي؟',
        'کیا یہ آرڈر حذف کر دیں؟',
      ),
      confirmLabel: s.t('Delete', 'ڊيليٽ', 'حذف کریں'),
      destructive: true,
    );

    if (!ok) return;

    await DB.instance.deleteOrder(order.id);

    if (mounted) await _load();
  }

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final balance = Balance.fromOrders(_orders);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          '${widget.customer.name} - '
          '${s.t('Orders', 'آرڊر', 'آرڈرز')}',
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(10, 10, 10, 90),
              children: [
                _BalanceCard(balance: balance),
                if (_orders.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(32),
                    child: Text(
                      s.t(
                        'No orders yet. Tap "Order" to add one.',
                        'اڃا ڪو آرڊر ناهي. شامل ڪرڻ لاءِ "آرڊر" دٻايو.',
                        'ابھی کوئی آرڈر نہیں۔ نیا آرڈر شامل کرنے کے لیے "آرڈر" دبائیں۔',
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                for (final order in _orders) _orderCard(s, order),
              ],
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _edit(),
        icon: const Icon(Icons.add),
        label: Text(s.t('Order', 'آرڊر', 'آرڈر')),
      ),
    );
  }

  Widget _orderCard(AppSettings s, OrderRecord order) {
    final scheme = Theme.of(context).colorScheme;
    final date = order.delivery;
    final dateText = date == null ? order.deliveryDate : fmtDate(date);

    final statusText = order.delivered
        ? s.t('Delivered', 'پهچايل', 'ڈیلیور ہو گیا')
        : order.overdue
            ? s.t('Overdue', 'دير ٿيل', 'تاخیر ہو گئی')
            : s.t('Pending', 'انتظار ۾', 'زیرِ التوا');

    final statusColor = order.delivered
        ? Colors.green.shade700
        : order.overdue
            ? scheme.error
            : scheme.primary;

    return Card(
      child: ListTile(
        isThreeLine: true,
        title: Text(
          order.details.isEmpty
              ? s.t('Order', 'آرڊر', 'آرڈر')
              : order.details,
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${s.t('Delivery', 'پهچائڻ', 'ڈیلیوری')}: $dateText',
            ),
            Text(
              statusText,
              style: TextStyle(
                color: statusColor,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              '${s.t('Total', 'ڪل', 'کل رقم')}: ${fmtMoney(order.total)}   '
              '${s.t('Paid', 'وصول', 'وصول شدہ')}: ${fmtMoney(order.paid)}   '
              '${s.t('Remaining', 'باقي', 'باقی')}: ${fmtMoney(order.remaining)}',
              style: order.hasBalance
                  ? TextStyle(
                      color: scheme.error,
                      fontWeight: FontWeight.w600,
                    )
                  : null,
            ),
          ],
        ),
        trailing: PopupMenuButton<String>(
          onSelected: (value) {
            switch (value) {
              case 'pay':
                _addPayment(order);
                break;
              case 'delivered':
                _toggleDelivered(order);
                break;
              case 'edit':
                _edit(order);
                break;
              case 'delete':
                _delete(order);
                break;
            }
          },
          itemBuilder: (_) => [
            if (order.hasBalance)
              PopupMenuItem(
                value: 'pay',
                child: Text(
                  s.t('Add payment', 'رقم وصول ڪريو', 'ادائیگی وصول کریں'),
                ),
              ),
            PopupMenuItem(
              value: 'delivered',
              child: Text(
                order.delivered
                    ? s.t(
                        'Mark as pending',
                        'انتظار ۾ ڪريو',
                        'زیرِ التوا کریں',
                      )
                    : s.t(
                        'Mark as delivered',
                        'پهچايل ڪريو',
                        'ڈیلیور شدہ نشان لگائیں',
                      ),
              ),
            ),
            PopupMenuItem(
              value: 'edit',
              child: Text(s.t('Edit', 'تبديل ڪريو', 'ترمیم کریں')),
            ),
            PopupMenuItem(
              value: 'delete',
              child: Text(s.t('Delete', 'ڊيليٽ', 'حذف کریں')),
            ),
          ],
        ),
      ),
    );
  }
}

class _BalanceCard extends StatelessWidget {
  final Balance balance;

  const _BalanceCard({required this.balance});

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final scheme = Theme.of(context).colorScheme;

    Widget cell(String label, double value, {Color? color}) {
      return Expanded(
        child: Column(
          children: [
            Text(
              label,
              style: Theme.of(context).textTheme.labelMedium,
            ),
            const SizedBox(height: 4),
            Text(
              fmtMoney(value),
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(
                    color: color,
                    fontWeight: FontWeight.bold,
                  ),
            ),
          ],
        ),
      );
    }

    return Card(
      color: scheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            cell(s.t('Total', 'ڪل', 'کل رقم'), balance.total),
            cell(
              s.t('Paid', 'وصول', 'وصول شدہ'),
              balance.paid,
              color: Colors.green.shade700,
            ),
            cell(
              s.t('Remaining', 'باقي', 'باقی'),
              balance.remaining,
              color: balance.remaining > 0.005 ? scheme.error : null,
            ),
          ],
        ),
      ),
    );
  }
}

/// Voice command: "How much is still due?"
Future<void> showBalanceSheet(
  BuildContext context,
  Customer customer,
) async {
  final orders = await DB.instance.orders(customer.id);

  if (!context.mounted) return;

  final s = AppScope.of(context);
  final balance = Balance.fromOrders(orders);
  final unpaid = orders.where((order) => order.hasBalance).toList();

  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (ctx) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              customer.name,
              style: Theme.of(ctx).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            _BalanceCard(balance: balance),
            if (unpaid.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text(
                  s.t(
                    'Nothing is due. All paid.',
                    'ڪجهه باقي ناهي. سڀ ادا ٿيل آهي.',
                    'کوئی رقم باقی نہیں۔ تمام ادائیگی ہو چکی ہے۔',
                  ),
                ),
              )
            else
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    for (final order in unpaid)
                      ListTile(
                        dense: true,
                        title: Text(
                          order.details.isEmpty
                              ? s.t('Order', 'آرڊر', 'آرڈر')
                              : order.details,
                        ),
                        subtitle: Text(
                          '${s.t('Delivery', 'پهچائڻ', 'ڈیلیوری')}: '
                          '${order.delivery == null ? order.deliveryDate : fmtDate(order.delivery)}',
                        ),
                        trailing: Text(
                          fmtMoney(order.remaining),
                          style: TextStyle(
                            color: Theme.of(ctx).colorScheme.error,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            Align(
              alignment: AlignmentDirectional.centerEnd,
              child: TextButton.icon(
                onPressed: () {
                  Navigator.pop(ctx);
                  Navigator.push(
                    context,
                    MaterialPageRoute<void>(
                      builder: (_) => OrdersPage(customer: customer),
                    ),
                  );
                },
                icon: const Icon(Icons.receipt_long),
                label: Text(
                  s.t('Open orders', 'آرڊر کوليو', 'آرڈرز کھولیں'),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _OrderInput {
  final String details;
  final String deliveryDate;
  final double total;
  final double paid;

  const _OrderInput(
    this.details,
    this.deliveryDate,
    this.total,
    this.paid,
  );
}

class _OrderDialog extends StatefulWidget {
  final OrderRecord? existing;

  const _OrderDialog({this.existing});

  @override
  State<_OrderDialog> createState() => _OrderDialogState();
}

class _OrderDialogState extends State<_OrderDialog> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _details;
  late final TextEditingController _total;
  late final TextEditingController _paid;
  late DateTime _date;

  @override
  void initState() {
    super.initState();

    final order = widget.existing;

    _details = TextEditingController(text: order?.details ?? '');
    _total = TextEditingController(
      text: order == null ? '' : _plain(order.total),
    );
    _paid = TextEditingController(
      text: order == null ? '' : _plain(order.paid),
    );
    _date = order?.delivery ?? DateTime.now().add(const Duration(days: 7));
  }

  static String _plain(double value) {
    return value == value.roundToDouble()
        ? value.toStringAsFixed(0)
        : value.toString();
  }

  @override
  void dispose() {
    _details.dispose();
    _total.dispose();
    _paid.dispose();
    super.dispose();
  }

  double _parse(String text) => double.tryParse(text.trim()) ?? 0;

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );

    if (picked != null) {
      setState(() => _date = picked);
    }
  }

  String? _amountError(AppSettings s, String? value) {
    final text = (value ?? '').trim();

    if (text.isEmpty) return null;

    final number = double.tryParse(text);

    if (number == null || number < 0) {
      return s.t(
        'Enter a valid amount',
        'صحيح رقم لکو',
        'درست رقم درج کریں',
      );
    }

    return null;
  }

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);

    return AlertDialog(
      title: Text(
        widget.existing == null
            ? s.t('New Order', 'نئون آرڊر', 'نیا آرڈر')
            : s.t('Edit Order', 'آرڊر تبديل ڪريو', 'آرڈر میں ترمیم'),
      ),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _details,
                decoration: InputDecoration(
                  labelText: s.t('Details', 'تفصيل', 'تفصیلات'),
                ),
              ),
              const SizedBox(height: 8),
              InkWell(
                onTap: _pickDate,
                child: InputDecorator(
                  decoration: InputDecoration(
                    labelText: s.t(
                      'Delivery date',
                      'پهچائڻ جي تاريخ',
                      'ڈیلیوری کی تاریخ',
                    ),
                    suffixIcon: const Icon(Icons.calendar_today),
                  ),
                  child: Text(fmtDate(_date)),
                ),
              ),
              TextFormField(
                controller: _total,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: InputDecoration(
                  labelText: s.t('Total', 'ڪل', 'کل رقم'),
                ),
                validator: (value) => _amountError(s, value),
              ),
              TextFormField(
                controller: _paid,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: InputDecoration(
                  labelText: s.t('Paid', 'وصول ٿيل', 'وصول شدہ'),
                ),
                validator: (value) {
                  final base = _amountError(s, value);

                  if (base != null) return base;

                  if (_parse(value ?? '') > _parse(_total.text) + 0.005) {
                    return s.t(
                      'Paid cannot be more than total',
                      'وصول ٿيل رقم ڪل کان وڌيڪ نه ٿي سگهي',
                      'وصول شدہ رقم کل رقم سے زیادہ نہیں ہو سکتی',
                    );
                  }

                  return null;
                },
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(s.t('Cancel', 'منسوخ', 'منسوخ کریں')),
        ),
        FilledButton(
          onPressed: () {
            if (_formKey.currentState!.validate()) {
              Navigator.pop(
                context,
                _OrderInput(
                  _details.text.trim(),
                  isoDate(_date),
                  _parse(_total.text),
                  _parse(_paid.text),
                ),
              );
            }
          },
          child: Text(s.t('Save', 'محفوظ ڪريو', 'محفوظ کریں')),
        ),
      ],
    );
  }
}

class _PaymentDialog extends StatefulWidget {
  final OrderRecord order;

  const _PaymentDialog({required this.order});

  @override
  State<_PaymentDialog> createState() => _PaymentDialogState();
}

class _PaymentDialogState extends State<_PaymentDialog> {
  final _formKey = GlobalKey<FormState>();
  final _amount = TextEditingController();

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final remaining = widget.order.remaining;

    return AlertDialog(
      title: Text(
        s.t('Add payment', 'رقم وصول ڪريو', 'ادائیگی وصول کریں'),
      ),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '${s.t('Remaining', 'باقي', 'باقی')}: ${fmtMoney(remaining)}',
            ),
            TextFormField(
              controller: _amount,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: InputDecoration(
                labelText: s.t('Amount', 'رقم', 'رقم'),
              ),
              validator: (value) {
                final number = double.tryParse((value ?? '').trim());

                if (number == null || number <= 0) {
                  return s.t(
                    'Enter a valid amount',
                    'صحيح رقم لکو',
                    'درست رقم درج کریں',
                  );
                }

                if (number > remaining + 0.005) {
                  return s.t(
                    'More than the remaining amount',
                    'باقي رقم کان وڌيڪ آهي',
                    'باقی رقم سے زیادہ ہے',
                  );
                }

                return null;
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(s.t('Cancel', 'منسوخ', 'منسوخ کریں')),
        ),
        FilledButton(
          onPressed: () {
            if (_formKey.currentState!.validate()) {
              Navigator.pop(
                context,
                double.parse(_amount.text.trim()),
              );
            }
          },
          child: Text(s.t('Save', 'محفوظ ڪريو', 'محفوظ کریں')),
        ),
      ],
    );
  }
}
