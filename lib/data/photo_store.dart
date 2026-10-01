import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Keeps measurement-book photos in the app's own documents folder.
///
/// v3 stored the temporary path returned by the camera/gallery picker, which
/// the OS can delete at any time. Now the picked file is copied here and only
/// the file *name* is stored in the database, so photos survive app updates and
/// can be included in backups.
class PhotoStore {
  PhotoStore._();

  static int _counter = 0;

  static Future<Directory> dir() async {
    final base = await getApplicationDocumentsDirectory();
    final d = Directory(p.join(base.path, 'measurement_photos'));
    if (!await d.exists()) {
      await d.create(recursive: true);
    }
    return d;
  }

  /// Copies [sourcePath] into the photo folder and returns the stored name.
  static Future<String> importFile(String sourcePath) async {
    final d = await dir();
    var ext = p.extension(sourcePath).toLowerCase();
    if (ext.isEmpty || ext.length > 6) ext = '.jpg';
    _counter++;
    final name = 'm_${DateTime.now().microsecondsSinceEpoch}_$_counter$ext';
    await File(sourcePath).copy(p.join(d.path, name));
    return name;
  }

  /// Writes raw bytes (used by restore) under a sanitised file name.
  static Future<String> writeBytes(String name, List<int> bytes) async {
    final d = await dir();
    final safe = p.basename(name);
    if (safe.isEmpty || safe == '.' || safe == '..') {
      throw const FormatException('Invalid photo name');
    }
    await File(p.join(d.path, safe)).writeAsBytes(bytes, flush: true);
    return safe;
  }

  /// Finds the file for a stored value (new: file name, old v3: absolute path).
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
      if (await f.exists()) await f.delete();
    } catch (_) {
      // A photo that cannot be deleted is not worth failing the user's action.
    }
  }

  /// Deletes every photo whose name is not in [keep].
  static Future<void> removeUnreferenced(Set<String> keep) async {
    try {
      final d = await dir();
      await for (final entity in d.list()) {
        if (entity is File && !keep.contains(p.basename(entity.path))) {
          await entity.delete();
        }
      }
    } catch (_) {}
  }
}
