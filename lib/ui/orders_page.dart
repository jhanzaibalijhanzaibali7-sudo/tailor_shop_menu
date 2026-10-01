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
      await DB.instance.addOrder(widget.customer.id, input.details,
          input.deliveryDate, input.total, input.paid);
    } else {
      await DB.instance.updateOrder(existing.id, input.details,
          input.deliveryDate, input.total, input.paid);
    }
    if (mounted) _load();
  }

  Future<void> _addPayment(OrderRecord o) async {
    final amount = await showDialog<double>(
      context: context,
      builder: (_) => _PaymentDialog(order: o),
    );
    if (amount == null) return;
    await DB.instance.addPayment(o.id, amount);
    if (mounted) _load();
  }

  Future<void> _toggleDelivered(OrderRecord o) async {
    await DB.instance
        .setOrderStatus(o.id, o.delivered ? 'pending' : 'delivered');
    if (mounted) _load();
  }

  Future<void> _delete(OrderRecord o) async {
    final s = AppScope.of(context);
    final ok = await confirmDialog(
      context,
      title: s.t('Delete order', 'آرڊر ڊيليٽ ڪريو'),
      message: s.t('Delete this order?', 'هي آرڊر ڊيليٽ ڪجي؟'),
      confirmLabel: s.t('Delete', 'ڊيليٽ'),
      destructive: true,
    );
    if (!ok) return;
    await DB.instance.deleteOrder(o.id);
    if (mounted) _load();
  }

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final balance = Balance.fromOrders(_orders);

    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.customer.name} - ${s.t('Orders', 'آرڊر')}'),
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
                      s.t('No orders yet. Tap "Order" to add one.',
                          'اڃا ڪو آرڊر ناهي. شامل ڪرڻ لاءِ "آرڊر" دٻايو.'),
                      textAlign: TextAlign.center,
                    ),
                  ),
                for (final o in _orders) _orderCard(s, o),
              ],
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _edit(),
        icon: const Icon(Icons.add),
        label: Text(s.t('Order', 'آرڊر')),
      ),
    );
  }

  Widget _orderCard(AppSettings s, OrderRecord o) {
    final scheme = Theme.of(context).colorScheme;
    final date = o.delivery;
    final dateText = date == null ? o.deliveryDate : fmtDate(date);
    final statusText = o.delivered
        ? s.t('Delivered', 'پهچايل')
        : (o.overdue ? s.t('Overdue', 'دير ٿيل') : s.t('Pending', 'انتظار ۾'));
    final statusColor = o.delivered
        ? Colors.green.shade700
        : (o.overdue ? scheme.error : scheme.primary);

    return Card(
      child: ListTile(
        isThreeLine: true,
        title: Text(o.details.isEmpty ? s.t('Order', 'آرڊر') : o.details),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${s.t('Delivery', 'پهچائڻ')}: $dateText   '),
            Text(
              statusText,
              style: TextStyle(color: statusColor, fontWeight: FontWeight.bold),
            ),
            Text(
              '${s.t('Total', 'ڪل')}: ${fmtMoney(o.total)}   '
              '${s.t('Paid', 'وصول')}: ${fmtMoney(o.paid)}   '
              '${s.t('Remaining', 'باقي')}: ${fmtMoney(o.remaining)}',
              style: o.hasBalance
                  ? TextStyle(color: scheme.error, fontWeight: FontWeight.w600)
                  : null,
            ),
          ],
        ),
        trailing: PopupMenuButton<String>(
          onSelected: (v) {
            switch (v) {
              case 'pay':
                _addPayment(o);
              case 'delivered':
                _toggleDelivered(o);
              case 'edit':
                _edit(o);
              case 'delete':
                _delete(o);
            }
          },
          itemBuilder: (_) => [
            if (o.hasBalance)
              PopupMenuItem(
                  value: 'pay', child: Text(s.t('Add payment', 'رقم وصول ڪريو'))),
            PopupMenuItem(
              value: 'delivered',
              child: Text(o.delivered
                  ? s.t('Mark as pending', 'انتظار ۾ ڪريو')
                  : s.t('Mark as delivered', 'پهچايل ڪريو')),
            ),
            PopupMenuItem(value: 'edit', child: Text(s.t('Edit', 'تبديل ڪريو'))),
            PopupMenuItem(value: 'delete', child: Text(s.t('Delete', 'ڊيليٽ'))),
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

    Widget cell(String label, double value, {Color? color}) => Expanded(
          child: Column(
            children: [
              Text(label, style: Theme.of(context).textTheme.labelMedium),
              const SizedBox(height: 4),
              Text(
                fmtMoney(value),
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(color: color, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        );

    return Card(
      color: scheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            cell(s.t('Total', 'ڪل'), balance.total),
            cell(s.t('Paid', 'وصول'), balance.paid, color: Colors.green.shade700),
            cell(
              s.t('Remaining', 'باقي'),
              balance.remaining,
              color: balance.remaining > 0.005 ? scheme.error : null,
            ),
          ],
        ),
      ),
    );
  }
}

/// Voice command "how much is still due": totals and unpaid orders.
Future<void> showBalanceSheet(BuildContext context, Customer customer) async {
  final orders = await DB.instance.orders(customer.id);
  if (!context.mounted) return;
  final s = AppScope.of(context);
  final balance = Balance.fromOrders(orders);
  final unpaid = orders.where((o) => o.hasBalance).toList();

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
            Text(customer.name, style: Theme.of(ctx).textTheme.titleLarge),
            const SizedBox(height: 8),
            _BalanceCard(balance: balance),
            if (unpaid.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text(s.t('Nothing is due. All paid.',
                    'ڪجهه باقي ناهي. سڀ ادا ٿيل آهي.')),
              )
            else
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    for (final o in unpaid)
                      ListTile(
                        dense: true,
                        title: Text(o.details.isEmpty
                            ? s.t('Order', 'آرڊر')
                            : o.details),
                        subtitle: Text(
                            '${s.t('Delivery', 'پهچائڻ')}: ${o.delivery == null ? o.deliveryDate : fmtDate(o.delivery)}'),
                        trailing: Text(
                          fmtMoney(o.remaining),
                          style: TextStyle(
                              color: Theme.of(ctx).colorScheme.error,
                              fontWeight: FontWeight.bold),
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
                        builder: (_) => OrdersPage(customer: customer)),
                  );
                },
                icon: const Icon(Icons.receipt_long),
                label: Text(s.t('Open orders', 'آرڊر کوليو')),
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
  const _OrderInput(this.details, this.deliveryDate, this.total, this.paid);
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
    final o = widget.existing;
    _details = TextEditingController(text: o?.details ?? '');
    _total = TextEditingController(text: o == null ? '' : _plain(o.total));
    _paid = TextEditingController(text: o == null ? '' : _plain(o.paid));
    _date = o?.delivery ?? DateTime.now().add(const Duration(days: 7));
  }

  static String _plain(double v) =>
      v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toString();

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
    if (picked != null) setState(() => _date = picked);
  }

  String? _amountError(AppSettings s, String? v) {
    final text = (v ?? '').trim();
    if (text.isEmpty) return null;
    final n = double.tryParse(text);
    if (n == null || n < 0) return s.t('Enter a valid amount', 'صحيح رقم لکو');
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    return AlertDialog(
      title: Text(widget.existing == null
          ? s.t('New Order', 'نئون آرڊر')
          : s.t('Edit Order', 'آرڊر تبديل ڪريو')),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _details,
                decoration: InputDecoration(labelText: s.t('Details', 'تفصيل')),
              ),
              const SizedBox(height: 8),
              InkWell(
                onTap: _pickDate,
                child: InputDecorator(
                  decoration: InputDecoration(
                    labelText: s.t('Delivery date', 'پهچائڻ جي تاريخ'),
                    suffixIcon: const Icon(Icons.calendar_today),
                  ),
                  child: Text(fmtDate(_date)),
                ),
              ),
              TextFormField(
                controller: _total,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(labelText: s.t('Total', 'ڪل')),
                validator: (v) => _amountError(s, v),
              ),
              TextFormField(
                controller: _paid,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(labelText: s.t('Paid', 'وصول ٿيل')),
                validator: (v) {
                  final base = _amountError(s, v);
                  if (base != null) return base;
                  if (_parse(v ?? '') > _parse(_total.text) + 0.005) {
                    return s.t('Paid cannot be more than total',
                        'وصول ٿيل رقم ڪل کان وڌيڪ نه ٿي سگهي');
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
          child: Text(s.t('Cancel', 'منسوخ')),
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
          child: Text(s.t('Save', 'محفوظ ڪريو')),
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
      title: Text(s.t('Add payment', 'رقم وصول ڪريو')),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('${s.t('Remaining', 'باقي')}: ${fmtMoney(remaining)}'),
            TextFormField(
              controller: _amount,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(labelText: s.t('Amount', 'رقم')),
              validator: (v) {
                final n = double.tryParse((v ?? '').trim());
                if (n == null || n <= 0) {
                  return s.t('Enter a valid amount', 'صحيح رقم لکو');
                }
                if (n > remaining + 0.005) {
                  return s.t('More than the remaining amount',
                      'باقي رقم کان وڌيڪ آهي');
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
          child: Text(s.t('Cancel', 'منسوخ')),
        ),
        FilledButton(
          onPressed: () {
            if (_formKey.currentState!.validate()) {
              Navigator.pop(context, double.parse(_amount.text.trim()));
            }
          },
          child: Text(s.t('Save', 'محفوظ ڪريو')),
        ),
      ],
    );
  }
}
