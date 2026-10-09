/// Measurement fields stored in the `measurements` table (unchanged from v3).
const List<String> kMeasurementFields = [
  'chest',
  'waist',
  'shalwar',
  'bazu',
  'kameez',
  'shoulder',
  'neck',
  'notes',
];

const Map<String, String> _labelEn = {
  'chest': 'Chest',
  'waist': 'Waist',
  'shalwar': 'Shalwar',
  'bazu': 'Bazu',
  'kameez': 'Kameez',
  'shoulder': 'Shoulder',
  'neck': 'Neck',
  'notes': 'Notes',
};

const Map<String, String> _labelSd = {
  'chest': 'ڇاتي',
  'waist': 'ڪمر',
  'shalwar': 'شلوار',
  'bazu': 'ٻانهن',
  'kameez': 'قميص',
  'shoulder': 'ڪلهو',
  'neck': 'ڳچي',
  'notes': 'نوٽ',
};

const Map<String, String> _labelUr = {
  'chest': 'چھاتی',
  'waist': 'کمر',
  'shalwar': 'شلوار',
  'bazu': 'بازو',
  'kameez': 'قمیض',
  'shoulder': 'کندھا',
  'neck': 'گلا',
  'notes': 'نوٹس',
};

/// Returns a measurement label in English, Sindhi, or Urdu.
/// Pass 'en', 'sd', or 'ur' as the language code.
String measurementLabel(String field, String language) {
  switch (language) {
    case 'sd':
      return _labelSd[field] ?? field;
    case 'ur':
      return _labelUr[field] ?? field;
    default:
      return _labelEn[field] ?? field;
  }
}

double _num(Object? v) => (v is num) ? v.toDouble() : 0.0;

class Customer {
  final int id;
  final String name;
  final String phone;
  final String address;

  const Customer({
    required this.id,
    required this.name,
    this.phone = '',
    this.address = '',
  });

  factory Customer.fromMap(Map<String, Object?> m) => Customer(
        id: (m['id'] as num).toInt(),
        name: (m['name'] as String?) ?? '',
        phone: (m['phone'] as String?) ?? '',
        address: (m['address'] as String?) ?? '',
      );
}

class CustomerSummary {
  final Customer customer;
  final double remaining;
  final int orderCount;

  const CustomerSummary({
    required this.customer,
    required this.remaining,
    required this.orderCount,
  });

  factory CustomerSummary.fromMap(Map<String, Object?> m) =>
      CustomerSummary(
        customer: Customer.fromMap(m),
        remaining: _num(m['remaining']),
        orderCount: (m['order_count'] as num?)?.toInt() ?? 0,
      );
}

class MeasurementRecord {
  final int id;
  final int customerId;
  final Map<String, String> values;
  final String? photo;
  final DateTime? createdAt;

  const MeasurementRecord({
    required this.id,
    required this.customerId,
    required this.values,
    this.photo,
    this.createdAt,
  });

  factory MeasurementRecord.fromMap(Map<String, Object?> m) {
    final values = <String, String>{};

    for (final f in kMeasurementFields) {
      values[f] = (m[f] as String?) ?? '';
    }

    final photo = m['photo'] as String?;

    return MeasurementRecord(
      id: (m['id'] as num).toInt(),
      customerId: (m['customer_id'] as num).toInt(),
      values: values,
      photo: (photo == null || photo.isEmpty) ? null : photo,
      createdAt: DateTime.tryParse(
        (m['created_at'] as String?) ?? '',
      ),
    );
  }
}

class OrderRecord {
  final int id;
  final int customerId;
  final String details;
  final String deliveryDate;
  final double total;
  final double paid;
  final String status;
  final DateTime? createdAt;

  const OrderRecord({
    required this.id,
    required this.customerId,
    required this.details,
    required this.deliveryDate,
    required this.total,
    required this.paid,
    required this.status,
    this.createdAt,
  });

  factory OrderRecord.fromMap(Map<String, Object?> m) =>
      OrderRecord(
        id: (m['id'] as num).toInt(),
        customerId: (m['customer_id'] as num).toInt(),
        details: (m['details'] as String?) ?? '',
        deliveryDate: (m['delivery_date'] as String?) ?? '',
        total: _num(m['total']),
        paid: _num(m['paid']),
        status: (m['status'] as String?) ?? 'pending',
        createdAt: DateTime.tryParse(
          (m['created_at'] as String?) ?? '',
        ),
      );

  double get remaining => total - paid;

  bool get hasBalance => remaining > 0.005;

  bool get delivered => status == 'delivered';

  DateTime? get delivery => DateTime.tryParse(deliveryDate);

  bool get overdue {
    final d = delivery;

    if (d == null || delivered) return false;

    final now = DateTime.now();

    return d.isBefore(DateTime(now.year, now.month, now.day));
  }
}

class Balance {
  final double total;
  final double paid;
  final int orders;

  const Balance({
    this.total = 0,
    this.paid = 0,
    this.orders = 0,
  });

  double get remaining => total - paid;

  factory Balance.fromOrders(List<OrderRecord> orders) {
    var t = 0.0;
    var p = 0.0;

    for (final o in orders) {
      t += o.total;
      p += o.paid;
    }

    return Balance(
      total: t,
      paid: p,
      orders: orders.length,
    );
  }
}

class Totals {
  final int customers;
  final int orders;
  final double total;
  final double paid;

  const Totals({
    required this.customers,
    required this.orders,
    required this.total,
    required this.paid,
  });

  double get remaining => total - paid;
}

class DeliveryRow {
  final OrderRecord order;
  final String customerName;

  const DeliveryRow(this.order, this.customerName);
}

class DueRow {
  final int customerId;
  final String customerName;
  final double remaining;

  const DueRow(
    this.customerId,
    this.customerName,
    this.remaining,
  );
}

class MonthRow {
  final String month; // yyyy-MM
  final int orders;
  final double total;
  final double paid;

  const MonthRow(
    this.month,
    this.orders,
    this.total,
    this.paid,
  );
}

class ReportData {
  final Totals totals;
  final List<DeliveryRow> pending;
  final List<DueRow> topDues;
  final List<MonthRow> months;

  const ReportData({
    required this.totals,
    required this.pending,
    required this.topDues,
    required this.months,
  });

  int get overdueCount =>
      pending.where((r) => r.order.overdue).length;
}
