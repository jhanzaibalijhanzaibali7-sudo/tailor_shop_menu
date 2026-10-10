import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'models.dart';
import 'photo_store.dart';

/// Local SQLite database.
///
/// Each Firebase account has its own database.
/// The original account keeps the existing tailor_shop.db file.
///
/// Schema history:
///  * v1 – customers, measurements, orders
///  * v2 – created_at, order status, indexes and foreign keys.
class DB {
  DB._();

  static final DB instance = DB._();

  static const int schemaVersion = 2;

  static const String _legacyOwnerKey = 'tailor_shop_legacy_owner_uid';

  Database? _db;
  String? _activeUid;

  Database get db {
    final d = _db;
    if (d == null) {
      throw StateError('Database is not initialised');
    }
    return d;
  }

  /// Opens the database belonging to the signed-in Firebase user.
  ///
  /// The original account keeps tailor_shop.db.
  /// Other accounts use separate database files.
  Future<void> init({required String userId}) async {
    final uid = userId.trim();

    if (uid.isEmpty) {
      throw ArgumentError('Firebase user ID cannot be empty');
    }

    // Avoid opening the same database again for the same user.
    if (_activeUid == uid && _db != null && _db!.isOpen) {
      return;
    }

    final databaseDir = await getDatabasesPath();
    final legacyPath = p.join(databaseDir, 'tailor_shop.db');
    final legacyFile = File(legacyPath);

    final prefs = await SharedPreferences.getInstance();

    // Claim the existing database for the first account that initializes
    // this updated app. Make sure the original Gmail is signed in first.
    String? legacyOwnerUid = prefs.getString(_legacyOwnerKey);

    if (legacyOwnerUid == null || legacyOwnerUid.trim().isEmpty) {
      // Save the owner before opening/migrating the database so future
      // account switches do not accidentally claim the legacy database.
      legacyOwnerUid = uid;

      final saved = await prefs.setString(_legacyOwnerKey, uid);
      if (!saved) {
        throw StateError('Could not save the original account setting.');
      }
    }

    final isLegacyOwner = uid == legacyOwnerUid;

    final safeUid = _safeFilePart(uid);

    final databasePath = isLegacyOwner
        ? legacyPath
        : p.join(databaseDir, 'tailor_shop_$safeUid.db');

    // Close the previous account's database before switching accounts.
    final previousDb = _db;
    _db = null;
    _activeUid = null;

    if (previousDb != null && previousDb.isOpen) {
      await previousDb.close();
    }

    // Configure photos before running photo migration.
    await PhotoStore.configureAccount(
      userId: safeUid,
      isLegacyOwner: isLegacyOwner,
    );

    final openedDb = await openDatabase(
      databasePath,
      version: schemaVersion,
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
      },
      onCreate: (db, version) async {
        await db.execute(
          'CREATE TABLE customers('
          'id INTEGER PRIMARY KEY AUTOINCREMENT, '
          'name TEXT NOT NULL, '
          'phone TEXT, '
          'address TEXT, '
          'created_at TEXT)',
        );

        await db.execute(
          'CREATE TABLE measurements('
          'id INTEGER PRIMARY KEY AUTOINCREMENT, '
          'customer_id INTEGER NOT NULL '
          'REFERENCES customers(id) ON DELETE CASCADE, '
          'chest TEXT, '
          'waist TEXT, '
          'shalwar TEXT, '
          'bazu TEXT, '
          'kameez TEXT, '
          'shoulder TEXT, '
          'neck TEXT, '
          'notes TEXT, '
          'photo TEXT, '
          'created_at TEXT)',
        );

        await db.execute(
          'CREATE TABLE orders('
          'id INTEGER PRIMARY KEY AUTOINCREMENT, '
          'customer_id INTEGER NOT NULL '
          'REFERENCES customers(id) ON DELETE CASCADE, '
          'details TEXT, '
          'delivery_date TEXT, '
          'total REAL NOT NULL DEFAULT 0, '
          'paid REAL NOT NULL DEFAULT 0, '
          'created_at TEXT, '
          "status TEXT NOT NULL DEFAULT 'pending')",
        );

        await _createIndexes(db);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.execute(
            'ALTER TABLE customers ADD COLUMN created_at TEXT',
          );

          await db.execute(
            'ALTER TABLE measurements ADD COLUMN created_at TEXT',
          );

          await db.execute(
            "ALTER TABLE orders ADD COLUMN status TEXT NOT NULL DEFAULT 'pending'",
          );

          await _createIndexes(db);
        }
      },
    );

    _db = openedDb;
    _activeUid = uid;

    // Keep the existing legacy-photo migration behavior.
    await _migrateLegacyPhotos();
  }

  /// Makes a Firebase UID safe for use in a filename.
  String _safeFilePart(String value) {
    return value.replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '_');
  }

  static Future<void> _createIndexes(Database db) async {
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_orders_customer '
      'ON orders(customer_id)',
    );

    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_meas_customer '
      'ON measurements(customer_id)',
    );
  }

  /// Copies old absolute photo paths into the active account's photo folder.
  Future<void> _migrateLegacyPhotos() async {
    final rows = await db.query(
      'measurements',
      columns: ['id', 'photo'],
      where: "photo IS NOT NULL AND photo != ''",
    );

    for (final r in rows) {
      final photo = r['photo'] as String;

      if (!p.isAbsolute(photo)) continue;

      if (!await File(photo).exists()) {
        await db.update(
          'measurements',
          {'photo': null},
          where: 'id = ?',
          whereArgs: [r['id']],
        );
        continue;
      }

      try {
        final name = await PhotoStore.importFile(photo);

        await db.update(
          'measurements',
          {'photo': name},
          where: 'id = ?',
          whereArgs: [r['id']],
        );
      } catch (_) {
        // Keep the old value so migration can be attempted again later.
      }
    }
  }

  // ---------------------------------------------------------------- customers

  Future<List<CustomerSummary>> customerSummaries([String q = '']) async {
    final query = q.trim();
    final where = query.isEmpty ? '' : 'WHERE c.name LIKE ? OR c.phone LIKE ?';
    final args =
        query.isEmpty ? <Object?>[] : <Object?>['%$query%', '%$query%'];

    final rows = await db.rawQuery(
      'SELECT c.id, c.name, c.phone, c.address, '
      'COALESCE(SUM(o.total - o.paid), 0) AS remaining, '
      'COUNT(o.id) AS order_count '
      'FROM customers c LEFT JOIN orders o ON o.customer_id = c.id '
      '$where GROUP BY c.id ORDER BY c.name COLLATE NOCASE',
      args,
    );

    return rows.map(CustomerSummary.fromMap).toList();
  }

  /// Plain list of (id, name) used by the voice command parser.
  Future<List<({int id, String name})>> customerNames() async {
    final rows = await db.query('customers', columns: ['id', 'name']);

    return rows
        .map(
          (r) => (
            id: (r['id'] as num).toInt(),
            name: (r['name'] as String?) ?? '',
          ),
        )
        .toList();
  }

  Future<Customer?> customerById(int id) async {
    final rows = await db.query(
      'customers',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );

    if (rows.isEmpty) return null;

    return Customer.fromMap(rows.first);
  }

  Future<int> addCustomer(String name, String phone, String address) =>
      db.insert('customers', {
        'name': name,
        'phone': phone,
        'address': address,
        'created_at': DateTime.now().toIso8601String(),
      });

  Future<void> updateCustomer(
    int id,
    String name,
    String phone,
    String address,
  ) async {
    await db.update(
      'customers',
      {'name': name, 'phone': phone, 'address': address},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Deletes a customer together with all orders, measurements and photos.
  Future<void> deleteCustomer(int id) async {
    final photoRows = await db.query(
      'measurements',
      columns: ['photo'],
      where: 'customer_id = ?',
      whereArgs: [id],
    );

    final photos = photoRows
        .map((r) => r['photo'] as String?)
        .whereType<String>()
        .toList();

    await db.transaction((txn) async {
      await txn.delete(
        'orders',
        where: 'customer_id = ?',
        whereArgs: [id],
      );

      await txn.delete(
        'measurements',
        where: 'customer_id = ?',
        whereArgs: [id],
      );

      await txn.delete(
        'customers',
        where: 'id = ?',
        whereArgs: [id],
      );
    });

    for (final ph in photos) {
      await PhotoStore.delete(ph);
    }
  }

  // ------------------------------------------------------------- measurements

  Future<List<MeasurementRecord>> measurementsFor(int customerId) async {
    final rows = await db.query(
      'measurements',
      where: 'customer_id = ?',
      whereArgs: [customerId],
      orderBy: 'id DESC',
    );

    return rows.map(MeasurementRecord.fromMap).toList();
  }

  Future<int> addMeasurement(
    int customerId,
    Map<String, String> values,
    String? photo,
  ) {
    final row = <String, Object?>{
      ...values,
      'customer_id': customerId,
      'photo': photo,
      'created_at': DateTime.now().toIso8601String(),
    };

    return db.insert('measurements', row);
  }

  Future<void> updateMeasurement(
    int id,
    Map<String, String> values,
    String? photo,
  ) async {
    final row = <String, Object?>{
      ...values,
      'photo': photo,
    };

    await db.update(
      'measurements',
      row,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> deleteMeasurement(MeasurementRecord m) async {
    await db.delete(
      'measurements',
      where: 'id = ?',
      whereArgs: [m.id],
    );

    await releasePhoto(m.photo);
  }

  /// Deletes the photo file when no measurement references it any more.
  Future<void> releasePhoto(String? stored) async {
    if (stored == null || stored.isEmpty) return;

    final rows = await db.query(
      'measurements',
      columns: ['id'],
      where: 'photo = ?',
      whereArgs: [stored],
      limit: 1,
    );

    if (rows.isEmpty) {
      await PhotoStore.delete(stored);
    }
  }

  // ------------------------------------------------------------------- orders

  Future<List<OrderRecord>> orders(int customerId) async {
    final rows = await db.query(
      'orders',
      where: 'customer_id = ?',
      whereArgs: [customerId],
      orderBy: 'id DESC',
    );

    return rows.map(OrderRecord.fromMap).toList();
  }

  Future<int> addOrder(
    int customerId,
    String details,
    String deliveryDate,
    double total,
    double paid,
  ) =>
      db.insert('orders', {
        'customer_id': customerId,
        'details': details,
        'delivery_date': deliveryDate,
        'total': total,
        'paid': paid,
        'status': 'pending',
        'created_at': DateTime.now().toIso8601String(),
      });

  Future<void> updateOrder(
    int id,
    String details,
    String deliveryDate,
    double total,
    double paid,
  ) async {
    await db.update(
      'orders',
      {
        'details': details,
        'delivery_date': deliveryDate,
        'total': total,
        'paid': paid,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> addPayment(int orderId, double amount) async {
    await db.rawUpdate(
      'UPDATE orders SET paid = paid + ? WHERE id = ?',
      [amount, orderId],
    );
  }

  Future<void> setOrderStatus(int orderId, String status) async {
    await db.update(
      'orders',
      {'status': status},
      where: 'id = ?',
      whereArgs: [orderId],
    );
  }

  Future<void> deleteOrder(int orderId) async {
    await db.delete(
      'orders',
      where: 'id = ?',
      whereArgs: [orderId],
    );
  }

  // ------------------------------------------------------------------ reports

  /// Every order with its customer name (newest first), used by CSV export.
  Future<List<DeliveryRow>> allOrderRows() async {
    final rows = await db.rawQuery(
      'SELECT o.*, c.name AS customer_name FROM orders o '
      'JOIN customers c ON c.id = o.customer_id ORDER BY o.id DESC',
    );

    return rows
        .map(
          (r) => DeliveryRow(
            OrderRecord.fromMap(r),
            (r['customer_name'] as String?) ?? '',
          ),
        )
        .toList();
  }

  Future<Totals> totals() async {
    final c = Sqflite.firstIntValue(
          await db.rawQuery('SELECT COUNT(*) FROM customers'),
        ) ??
        0;

    final o = Sqflite.firstIntValue(
          await db.rawQuery('SELECT COUNT(*) FROM orders'),
        ) ??
        0;

    final r = await db.rawQuery(
      'SELECT COALESCE(SUM(total),0) AS t, '
      'COALESCE(SUM(paid),0) AS p FROM orders',
    );

    return Totals(
      customers: c,
      orders: o,
      total: (r.first['t'] as num).toDouble(),
      paid: (r.first['p'] as num).toDouble(),
    );
  }

  Future<ReportData> reportData() async {
    final totals = await this.totals();

    final pendingRows = await db.rawQuery(
      'SELECT o.*, c.name AS customer_name FROM orders o '
      'JOIN customers c ON c.id = o.customer_id '
      "WHERE o.status != 'delivered' ORDER BY o.delivery_date ASC",
    );

    final pending = pendingRows
        .map(
          (r) => DeliveryRow(
            OrderRecord.fromMap(r),
            (r['customer_name'] as String?) ?? '',
          ),
        )
        .toList();

    final dueRows = await db.rawQuery(
      'SELECT c.id AS id, c.name AS name, '
      'SUM(o.total - o.paid) AS remaining '
      'FROM customers c JOIN orders o ON o.customer_id = c.id '
      'GROUP BY c.id HAVING remaining > 0.005 '
      'ORDER BY remaining DESC LIMIT 10',
    );

    final dues = dueRows
        .map(
          (r) => DueRow(
            (r['id'] as num).toInt(),
            (r['name'] as String?) ?? '',
            (r['remaining'] as num).toDouble(),
          ),
        )
        .toList();

    final monthRows = await db.rawQuery(
      'SELECT substr(created_at, 1, 7) AS m, COUNT(*) AS n, '
      'COALESCE(SUM(total),0) AS t, COALESCE(SUM(paid),0) AS p '
      'FROM orders WHERE created_at IS NOT NULL '
      'GROUP BY m ORDER BY m DESC LIMIT 6',
    );

    final months = monthRows
        .map(
          (r) => MonthRow(
            (r['m'] as String?) ?? '',
            (r['n'] as num).toInt(),
            (r['t'] as num).toDouble(),
            (r['p'] as num).toDouble(),
          ),
        )
        .toList();

    return ReportData(
      totals: totals,
      pending: pending,
      topDues: dues,
      months: months,
    );
  }
}
