import 'dart:io';
import '../app.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../data/photo_store.dart';
import '../settings.dart';

final NumberFormat _moneyFormat = NumberFormat('#,##0.##', 'en');
final DateFormat _shownDate = DateFormat('dd-MM-yyyy', 'en');
final DateFormat _isoDate = DateFormat('yyyy-MM-dd', 'en');

/// 1500 -> "1,500", 1500.5 -> "1,500.5"
String fmtMoney(num v) => _moneyFormat.format(v);

/// Date shown to the user; digits stay Latin in every language.
String fmtDate(DateTime? d) => d == null ? '' : _shownDate.format(d);

/// Date as stored in the database.
String isoDate(DateTime d) => _isoDate.format(d);

void showSnack(BuildContext context, String message) {
  final messenger = ScaffoldMessenger.maybeOf(context);
  if (messenger == null) return;

  messenger.hideCurrentSnackBar();
  messenger.showSnackBar(
    SnackBar(content: Text(message)),
  );
}

Future<bool> confirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  String? confirmLabel,
  bool destructive = false,
}) async {
  final s = AppScope.of(context);

  final result = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: Text(
            s.t('Cancel', 'منسوخ', 'منسوخ کریں'),
          ),
        ),
        FilledButton(
          style: destructive
              ? FilledButton.styleFrom(
                  backgroundColor: Theme.of(ctx).colorScheme.error,
                  foregroundColor: Theme.of(ctx).colorScheme.onError,
                )
              : null,
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(
            confirmLabel ?? s.t('Yes', 'ها', 'ہاں'),
          ),
        ),
      ],
    ),
  );

  return result ?? false;
}

/// Shows a saved measurement-book photo (name or legacy path in the database).
class StoredPhoto extends StatefulWidget {
  final String stored;
  final double height;

  const StoredPhoto({
    super.key,
    required this.stored,
    this.height = 160,
  });

  @override
  State<StoredPhoto> createState() => _StoredPhotoState();
}

class _StoredPhotoState extends State<StoredPhoto> {
  late Future<File?> _file;

  @override
  void initState() {
    super.initState();
    _file = PhotoStore.resolve(widget.stored);
  }

  @override
  void didUpdateWidget(covariant StoredPhoto oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.stored != widget.stored) {
      _file = PhotoStore.resolve(widget.stored);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);

    return FutureBuilder<File?>(
      future: _file,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return SizedBox(
            height: widget.height,
            child: const Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

        final file = snap.data;

        if (file == null) {
          return SizedBox(
            height: widget.height,
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.broken_image_outlined),
                  Text(
                    s.t(
                      'Photo not found',
                      'تصوير نه ملي',
                      'تصویر نہیں ملی',
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        return GestureDetector(
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute<void>(
              builder: (_) => PhotoViewerPage(file: file),
            ),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.file(
              file,
              height: widget.height,
              width: double.infinity,
              fit: BoxFit.cover,
              cacheWidth: 900,
              errorBuilder: (_, __, ___) => SizedBox(
                height: widget.height,
                child: const Center(
                  child: Icon(Icons.broken_image_outlined),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class PhotoViewerPage extends StatelessWidget {
  final File file;

  const PhotoViewerPage({
    super.key,
    required this.file,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
      ),
      body: Center(
        child: InteractiveViewer(
          maxScale: 6,
          child: Image.file(
            file,
            fit: BoxFit.contain,
          ),
        ),
      ),
    );
  }
}
