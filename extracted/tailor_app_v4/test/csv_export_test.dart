import 'package:flutter_test/flutter_test.dart';
import 'package:tailor_shop_manager/data/csv_export.dart';
import 'package:tailor_shop_manager/data/models.dart';

void main() {
  OrderRecord order({
    String details = 'Suit',
    String date = '2999-01-01',
    double total = 5000,
    double paid = 2000.5,
    String status = 'pending',
  }) =>
      OrderRecord(
        id: 1,
        customerId: 1,
        details: details,
        deliveryDate: date,
        total: total,
        paid: paid,
        status: status,
      );

  test('header, BOM and numbers', () {
    final csv = buildOrdersCsv([DeliveryRow(order(), 'Ali')]);
    expect(csv.startsWith('\uFEFF'), isTrue);
    expect(csv, contains('Customer,Details,Delivery date,Status,Total,Paid,Remaining'));
    expect(csv, contains('Ali,Suit,2999-01-01,pending,5000,2000.50,2999.50'));
  });

  test('commas and quotes are escaped', () {
    final csv = buildOrdersCsv([
      DeliveryRow(order(details: 'Suit, 2 pcs'), 'Ali "Bhai"'),
    ]);
    expect(csv, contains('"Suit, 2 pcs"'));
    expect(csv, contains('"Ali ""Bhai"""'));
  });

  test('formula-looking text is neutralised', () {
    expect(csvText('=SUM(A1)'), "'=SUM(A1)");
    expect(csvText('+92300'), "'+92300");
    expect(csvText('Normal'), 'Normal');
  });

  test('delivered and Sindhi text', () {
    final csv = buildOrdersCsv([
      DeliveryRow(order(status: 'delivered', date: '2020-01-01'), 'جهانزيب'),
    ]);
    expect(csv, contains('جهانزيب,Suit,2020-01-01,delivered'));
  });
}
