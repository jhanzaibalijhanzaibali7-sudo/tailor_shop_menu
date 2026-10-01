import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../data/csv_export.dart';
import '../data/db.dart';
import '../data/models.dart';
import '../settings.dart';
import 'common.dart';
import 'orders_page.dart';

/// Reports: totals, pending deliveries, biggest dues, last months.
class ReportsPage extends StatefulWidget {
  const ReportsPage({super.key});

  @override
  State<ReportsPage> createState() => _ReportsPageState();
}

class _ReportsPageState extends State<ReportsPage> {
  late Future<ReportData> _future;

  @override
  void initState() {
    super.initState();
    _future = DB.instance.reportData();
  }

  Future<void> _refresh() async {
    final f = DB.instance.reportData();
    setState(() => _future = f);
    await f;
  }

  /// Shares every order as a CSV file (opens in Excel / Google Sheets).
  Future<void> _exportCsv() async {
    final s = AppScope.of(context);
    try {
      final rows = await DB.instance.allOrderRows();
      if (rows.isEmpty) {
        if (mounted) {
          showSnack(context,
              s.t('No orders to export', 'ايڪسپورٽ لاءِ ڪو آرڊر ناهي'));
        }
        return;
      }
      final dir = await getTemporaryDirectory();
      final stamp = DateFormat('yyyyMMdd_HHmmss', 'en').format(DateTime.now());
      final file = File(p.join(dir.path, 'orders_$stamp.csv'));
      await file.writeAsString(buildOrdersCsv(rows), encoding: utf8);
      await Share.shareXFiles([XFile(file.path)],
          text: s.t('Tailor shop orders', 'درزي دڪان جا آرڊر'));
    } catch (e) {
      if (mounted) {
        showSnack(context, '${s.t('Export failed', 'ايڪسپورٽ ناڪام')}: $e');
      }
    }
  }

  Future<void> _openCustomer(int id) async {
    final c = await DB.instance.customerById(id);
    if (c == null || !mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute<void>(builder: (_) => OrdersPage(customer: c)),
    );
    if (mounted) _refresh();
  }

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(s.t('Reports', 'رپورٽون')),
        actions: [
          IconButton(
            tooltip: s.t('Export orders (CSV)', 'آرڊر ايڪسپورٽ (CSV)'),
            icon: const Icon(Icons.ios_share),
            onPressed: _exportCsv,
          ),
        ],
      ),
      body: FutureBuilder<ReportData>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError || snap.data == null) {
            return Center(child: Text('${snap.error}'));
          }
          final r = snap.data!;
          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(12),
              children: [
                _totalsCard(s, r.totals),
                _section(s.t('Pending deliveries', 'انتظار ۾ آرڊر'),
                    r.overdueCount > 0
                        ? '${r.overdueCount} ${s.t('overdue', 'دير ٿيل')}'
                        : null),
                if (r.pending.isEmpty)
                  _empty(s.t('No pending orders', 'ڪو انتظار ۾ آرڊر ناهي')),
                for (final row in r.pending.take(15)) _pendingTile(s, row),
                _section(s.t('Highest dues', 'سڀ کان وڌيڪ باقي'), null),
                if (r.topDues.isEmpty)
                  _empty(s.t('Nobody owes money', 'ڪنهن جو به باقي ناهي')),
                for (final d in r.topDues)
                  Card(
                    child: ListTile(
                      title: Text(d.customerName),
                      trailing: Text(
                        fmtMoney(d.remaining),
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      onTap: () => _openCustomer(d.customerId),
                    ),
                  ),
                _section(s.t('Last months', 'پوئين مهينا'), null),
                if (r.months.isEmpty)
                  _empty(s.t('No orders yet', 'اڃا ڪو آرڊر ناهي')),
                for (final m in r.months)
                  Card(
                    child: ListTile(
                      title: Text(m.month),
                      subtitle: Text(
                        '${s.t('Orders', 'آرڊر')}: ${m.orders}   '
                        '${s.t('Total', 'ڪل')}: ${fmtMoney(m.total)}   '
                        '${s.t('Paid', 'وصول')}: ${fmtMoney(m.paid)}',
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _totalsCard(AppSettings s, Totals t) {
    Widget row(String label, String value, {Color? color}) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            children: [
              Expanded(child: Text(label)),
              Text(value,
                  style: TextStyle(fontWeight: FontWeight.bold, color: color)),
            ],
          ),
        );
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          children: [
            row(s.t('Customers', 'گراهڪ'), '${t.customers}'),
            row(s.t('Orders', 'آرڊر'), '${t.orders}'),
            const Divider(),
            row(s.t('Total sales', 'ڪل وڪرو'), fmtMoney(t.total)),
            row(s.t('Received', 'وصول ٿيل'), fmtMoney(t.paid),
                color: Colors.green.shade700),
            row(s.t('Remaining', 'باقي'), fmtMoney(t.remaining),
                color: t.remaining > 0.005
                    ? Theme.of(context).colorScheme.error
                    : null),
          ],
        ),
      ),
    );
  }

  Widget _section(String title, String? badge) => Padding(
        padding: const EdgeInsets.fromLTRB(4, 16, 4, 6),
        child: Row(
          children: [
            Expanded(
              child: Text(title, style: Theme.of(context).textTheme.titleMedium),
            ),
            if (badge != null)
              Text(badge,
                  style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                      fontWeight: FontWeight.bold)),
          ],
        ),
      );

  Widget _empty(String text) => Padding(
        padding: const EdgeInsets.all(12),
        child: Text(text),
      );

  Widget _pendingTile(AppSettings s, DeliveryRow row) {
    final o = row.order;
    final date = o.delivery;
    return Card(
      child: ListTile(
        title: Text(row.customerName),
        subtitle: Text(
          '${o.details.isEmpty ? s.t('Order', 'آرڊر') : o.details}\n'
          '${s.t('Delivery', 'پهچائڻ')}: ${date == null ? o.deliveryDate : fmtDate(date)}'
          '${o.overdue ? '  •  ${s.t('Overdue', 'دير ٿيل')}' : ''}',
        ),
        isThreeLine: true,
        trailing: o.hasBalance
            ? Text(fmtMoney(o.remaining),
                style: TextStyle(
                    color: Theme.of(context).colorScheme.error,
                    fontWeight: FontWeight.bold))
            : null,
        onTap: () => _openCustomer(o.customerId),
      ),
    );
  }
}
