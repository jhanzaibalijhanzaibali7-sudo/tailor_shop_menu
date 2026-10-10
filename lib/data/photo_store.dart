
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Stores measurement photos separately for each account.
class PhotoStore {
  PhotoStore._();

  static int _counter = 0;
  static String? _accountId;

  // Keep the existing folder for the original account.
  static bool _useLegacyFolder = true;

  /// Called when the authenticated account's database is selected.
  static Future<void> configureAccount({
    required String userId,
    required bool isLegacyOwner,
  }) async {
    _accountId = userId.replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '_');
    _useLegacyFolder = isLegacyOwner;
  }

  static Future<Directory> dir() async {
    final base = await getApplicationDocumentsDirectory();

    final folder = _useLegacyFolder
        ? 'measurement_photos'
        : 'measurement_photos_${_accountId ?? 'unassigned'}';

    final d = Directory(p.join(base.path, folder));

    if (!await d.exists()) {
      await d.create(recursive: true);
    }

    return d;
  }

  /// Copies a picked photo into the active account's folder.
  static Future<String> importFile(String sourcePath) async {
    final d = await dir();

    var ext = p.extension(sourcePath).toLowerCase();
    if (ext.isEmpty || ext.length > 6) ext = '.jpg';

    _counter++;

    final name =
        'm_${DateTime.now().microsecondsSinceEpoch}_$_counter$ext';

    await File(sourcePath).copy(p.join(d.path, name));

    return name;
  }

  /// Writes a restored photo under a sanitised filename.
  static Future<String> writeBytes(
    String name,
    List<int> bytes,
  ) async {
    final d = await dir();
    final safe = p.basename(name);

    if (safe.isEmpty || safe == '.' || safe == '..') {
      throw const FormatException('Invalid photo name');
    }

    await File(p.join(d.path, safe)).writeAsBytes(
      bytes,
      flush: true,
    );

    return safe;
  }

  /// Resolves both stored filenames and legacy absolute paths.
  static Future<File?> resolve(String? stored) async {
    if (stored == null || stored.isEmpty) return null;

    if (p.isAbsolute(stored)) {
      final legacy = File(stored);
      if (await legacy.exists()) return legacy;
    }

    final d = await dir();
    final f = File(p.join(d.path, p.basename(stored)));

    if (await f.exists()) return f;

    return null;
  }

  static Future<void> delete(String? stored) async {
    if (stored == null || stored.isEmpty) return;

    try {
      final d = await dir();
      final f = File(p.join(d.path, p.basename(stored)));

      if (await f.exists()) {
        await f.delete();
      }
    } catch (_) {
      // Do not fail a customer or measurement deletion because of a photo.
    }
  }

  /// Deletes photos not referenced by the active account's database.
  static Future<void> removeUnreferenced(Set<String> keep) async {
    try {
      final d = await dir();

      await for (final entity in d.list()) {
        if (entity is File &&
            !keep.contains(p.basename(entity.path))) {
          await entity.delete();
        }
      }
    } catch (_) {}
  }
}
