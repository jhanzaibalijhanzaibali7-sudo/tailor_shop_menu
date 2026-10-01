import 'dart:convert';
import 'dart:io';

import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'db.dart';
import 'photo_store.dart';

class RestoreSummary {
  final int customers;
  final int measurements;
  final int orders;
  final int photos;
  final int skipped;

  const RestoreSummary({
    required this.customers,
    required this.measurements,
    required this.orders,
    required this.photos,
    required this.skipped,
  });
}

/// JSON backup / restore.
///
/// Format v2 also embeds the measurement-book photos (base64) so a restore on
/// a new phone brings the photos back. Format v1 (from the old app) can still
/// be restored.
class BackupService {
  BackupService._();

  static const String formatV1 = 'tailor_shop_backup_v1';
  static const String formatV2 = 'tailor_shop_backup_v2';

  static const _customerCols = ['id', 'name', 'phone', 'address', 'created_at'];
  static const _measurementCols = [
    'id', 'customer_id', 'chest', 'waist', 'shalwar', 'bazu', 'kameez',
    'shoulder', 'neck', 'notes', 'photo', 'created_at',
  ];
  static const _orderCols = [
    'id', 'customer_id', 'details', 'delivery_date', 'total', 'paid',
    'created_at', 'status',
  ];

  /// Folder for automatic safety backups (made before every restore).
  static Future<Directory> autoBackupDir() async {
    final base = await getApplicationDocumentsDirectory();
    final d = Directory(p.join(base.path, 'auto_backups'));
    if (!await d.exists()) await d.create(recursive: true);
    return d;
  }

  /// Keeps only the newest [keep] files in [dir].
  static Future<void> pruneAutoBackups(Directory dir, {int keep = 5}) async {
    try {
      final files = await dir
          .list()
          .where((e) => e is File && e.path.endsWith('.json'))
          .cast<File>()
          .toList();
      files.sort((a, b) => b.path.compareTo(a.path));
      for (final f in files.skip(keep)) {
        await f.delete();
      }
    } catch (_) {}
  }

  /// Writes a backup file into [dir] and returns it. Photos are streamed one by
  /// one so memory use stays low even with many photos.
  static Future<File> createBackup({
    required Directory dir,
    String prefix = 'tailor_backup',
  }) async {
    final db = DB.instance.db;
    final customers = await db.query('customers');
    final orders = await db.query('orders');
    final measurementRows = await db.query('measurements');

    final stamp = DateFormat('yyyyMMdd_HHmmss', 'en').format(DateTime.now());
    final file = File(p.join(dir.path, '${prefix}_$stamp.json'));
    final sink = file.openWrite(encoding: utf8);
    try {
      final measurements = <Map<String, Object?>>[];
      final photoFiles = <String, File>{};
      for (final m in measurementRows) {
        final row = Map<String, Object?>.from(m);
        final stored = row['photo'] as String?;
        final f = await PhotoStore.resolve(stored);
        if (f != null) {
          final name = p.basename(f.path);
          row['photo'] = name;
          photoFiles[name] = f;
        } else {
          row['photo'] = null;
        }
        measurements.add(row);
      }

      sink.write('{"format":${jsonEncode(formatV2)},');
      sink.write('"created_at":${jsonEncode(DateTime.now().toIso8601String())},');
      sink.write('"customers":${jsonEncode(customers)},');
      sink.write('"measurements":${jsonEncode(measurements)},');
      sink.write('"orders":${jsonEncode(orders)},');
      sink.write('"photos":{');
      var first = true;
      for (final entry in photoFiles.entries) {
        final bytes = await entry.value.readAsBytes();
        if (!first) sink.write(',');
        first = false;
        sink.write('${jsonEncode(entry.key)}:${jsonEncode(base64Encode(bytes))}');
      }
      sink.write('}}');
      await sink.flush();
    } finally {
      await sink.close();
    }
    return file;
  }

  static List<Map<String, Object?>> _rows(Object? v) {
    if (v is! List) return <Map<String, Object?>>[];
    return v
        .whereType<Map>()
        .map((e) => Map<String, Object?>.from(e))
        .toList();
  }

  static Map<String, Object?> _pick(Map<String, Object?> row, List<String> cols) {
    final out = <String, Object?>{};
    for (final c in cols) {
      if (row.containsKey(c)) out[c] = row[c];
    }
    return out;
  }

  static int? _int(Object? v) {
    if (v is num) return v.toInt();
    if (v is String) return int.tryParse(v);
    return null;
  }

  /// Replaces ALL current data with the content of [file].
  ///
  /// Everything is validated first; the database part runs in one transaction,
  /// so a bad file never leaves the app half-restored. Throws
  /// [FormatException] for files that are not valid backups.
  static Future<RestoreSummary> restore(File file) async {
    final Object? decoded;
    try {
      decoded = jsonDecode(await file.readAsString());
    } catch (_) {
      throw const FormatException('Not a valid backup file');
    }
    if (decoded is! Map) {
      throw const FormatException('Not a valid backup file');
    }
    final fmt = decoded['format'];
    if (fmt != formatV1 && fmt != formatV2) {
      throw const FormatException('Unsupported backup format');
    }

    final customers = _rows(decoded['customers']);
    final measurements = _rows(decoded['measurements']);
    final orders = _rows(decoded['orders']);

    final customerIds = <int>{};
    for (final c in customers) {
      final id = _int(c['id']);
      if (id == null) throw const FormatException('Customer without id');
      if (((c['name'] as String?) ?? '').trim().isEmpty) {
        throw const FormatException('Customer without name');
      }
      customerIds.add(id);
    }

    // 1. Photos -> app folder (before touching the database).
    var photoCount = 0;
    final restoredNames = <String>{};
    final photos = decoded['photos'];
    if (photos is Map) {
      for (final entry in photos.entries) {
        final value = entry.value;
        if (entry.key is! String || value is! String) continue;
        try {
          final name =
              await PhotoStore.writeBytes(entry.key as String, base64Decode(value));
          restoredNames.add(name);
          photoCount++;
        } catch (_) {
          // Skip a damaged photo, keep restoring the rest.
        }
      }
    }

    // 2. Normalise photo references.
    for (final m in measurements) {
      final stored = m['photo'];
      if (stored is! String || stored.isEmpty) {
        m['photo'] = null;
        continue;
      }
      final name = p.basename(stored);
      if (restoredNames.contains(name)) {
        m['photo'] = name;
      } else if (p.isAbsolute(stored) && await File(stored).exists()) {
        // v1 backup restored on the same phone: the old file is still there.
        m['photo'] = await PhotoStore.importFile(stored);
      } else {
        final existing = await PhotoStore.resolve(name);
        m['photo'] = existing == null ? null : name;
      }
    }

    // 3. Database, all-or-nothing.
    var skipped = 0;
    final db = DB.instance.db;
    final keptMeasurements = <Map<String, Object?>>[];
    final keptOrders = <Map<String, Object?>>[];
    for (final m in measurements) {
      final cid = _int(m['customer_id']);
      if (cid != null && customerIds.contains(cid)) {
        keptMeasurements.add(m);
      } else {
        skipped++;
      }
    }
    for (final o in orders) {
      final cid = _int(o['customer_id']);
      if (cid != null && customerIds.contains(cid)) {
        keptOrders.add(o);
      } else {
        skipped++;
      }
    }

    await db.transaction((txn) async {
      await txn.delete('orders');
      await txn.delete('measurements');
      await txn.delete('customers');
      final batch = txn.batch();
      for (final c in customers) {
        batch.insert('customers', _pick(c, _customerCols));
      }
      for (final m in keptMeasurements) {
        batch.insert('measurements', _pick(m, _measurementCols));
      }
      for (final o in keptOrders) {
        final row = _pick(o, _orderCols);
        row['status'] ??= 'pending';
        batch.insert('orders', row);
      }
      await batch.commit(noResult: true);
    });

    // 4. Remove photo files that no restored measurement points to.
    final keep = <String>{
      for (final m in keptMeasurements)
        if (m['photo'] is String) m['photo'] as String,
    };
    await PhotoStore.removeUnreferenced(keep);

    return RestoreSummary(
      customers: customers.length,
      measurements: keptMeasurements.length,
      orders: keptOrders.length,
      photos: photoCount,
      skipped: skipped,
    );
  }
}
