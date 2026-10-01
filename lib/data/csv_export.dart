import 'models.dart';

/// Escapes one CSV text cell.
///
/// Cells that start with = + - @ would be run as formulas by Excel / Sheets,
/// so they get a leading apostrophe (customer names and order details are
/// typed by users, and backups can come from anywhere).
String csvText(String value) {
  var v = value;
  if (v.isNotEmpty && '=+-@\t\r'.contains(v[0])) v = "'$v";
  if (v.contains(',') ||
      v.contains('"') ||
      v.contains('\n') ||
      v.contains('\r')) {
    v = '"${v.replaceAll('"', '""')}"';
  }
  return v;
}

String _num(double v) =>
    v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(2);

/// All orders as CSV text. Starts with a UTF-8 BOM so Excel shows Sindhi
/// names correctly. Column titles are English on purpose (spreadsheet use).
String buildOrdersCsv(List<DeliveryRow> rows) {
  final out = StringBuffer('\uFEFF');
  out.write('Customer,Details,Delivery date,Status,Total,Paid,Remaining\r\n');
  for (final r in rows) {
    final o = r.order;
    final status = o.delivered ? 'delivered' : (o.overdue ? 'overdue' : 'pending');
    out.write([
      csvText(r.customerName),
      csvText(o.details),
      csvText(o.deliveryDate),
      status,
      _num(o.total),
      _num(o.paid),
      _num(o.remaining),
    ].join(','));
    out.write('\r\n');
  }
  return out.toString();
}
