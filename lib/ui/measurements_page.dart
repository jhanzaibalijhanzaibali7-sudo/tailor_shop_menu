import 'dart:typed_data';
import '../app.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../data/db.dart';
import '../data/models.dart';
import '../data/photo_store.dart';
import '../settings.dart';
import 'common.dart';

/// Saved measurements of one customer (newest first) + add / edit.
class MeasurementsPage extends StatefulWidget {
  final Customer customer;

  const MeasurementsPage({super.key, required this.customer});

  @override
  State<MeasurementsPage> createState() => _MeasurementsPageState();
}

class _MeasurementsPageState extends State<MeasurementsPage> {
  List<MeasurementRecord> _items = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final rows = await DB.instance.measurementsFor(widget.customer.id);

    if (!mounted) return;

    setState(() {
      _items = rows;
      _loading = false;
    });
  }

  Future<void> _edit([MeasurementRecord? existing]) async {
    final saved = await Navigator.push<bool>(
      context,
      MaterialPageRoute<bool>(
        builder: (_) => MeasurementFormPage(
          customer: widget.customer,
          existing: existing,
        ),
      ),
    );

    if (saved == true && mounted) {
      await _load();
    }
  }

  Future<void> _delete(MeasurementRecord measurement) async {
    final s = AppScope.of(context);

    final ok = await confirmDialog(
      context,
      title: s.t(
        'Delete measurement',
        'ماپ ڊيليٽ ڪريو',
        'پیمائش حذف کریں',
      ),
      message: s.t(
        'Delete this measurement and its photo?',
        'هي ماپ ۽ ان جي تصوير ڊيليٽ ڪجي؟',
        'کیا یہ پیمائش اور اس کی تصویر حذف کر دیں؟',
      ),
      confirmLabel: s.t('Delete', 'ڊيليٽ', 'حذف کریں'),
      destructive: true,
    );

    if (!ok) return;

    await DB.instance.deleteMeasurement(measurement);

    if (mounted) {
      await _load();
    }
  }

  /// Opens a PDF preview for one measurement.
  Future<void> _printMeasurement(MeasurementRecord measurement) async {
    Uint8List? photoBytes;

    if (measurement.photo != null) {
      final file = await PhotoStore.resolve(measurement.photo);

      if (file != null && await file.exists()) {
        photoBytes = await file.readAsBytes();
      }
    }

    if (!mounted) return;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return Dialog(
          insetPadding: const EdgeInsets.all(8),
          child: SizedBox(
            width: MediaQuery.of(dialogContext).size.width * 0.95,
            height: MediaQuery.of(dialogContext).size.height * 0.92,
            child: PdfPreview(
              build: (format) => _buildMeasurementPdf(
                format,
                measurement,
                photoBytes,
              ),
              allowPrinting: true,
              allowSharing: true,
              canChangePageFormat: false,
              canChangeOrientation: false,
              pdfFileName:
                  '${widget.customer.name.replaceAll(' ', '_')}_measurement.pdf',
            ),
          ),
        );
      },
    );
  }

  Future<Uint8List> _buildMeasurementPdf(
    PdfPageFormat format,
    MeasurementRecord measurement,
    Uint8List? photoBytes,
  ) async {
    final pdf = pw.Document();

    final filled = kMeasurementFields
        .where(
          (field) =>
              (measurement.values[field] ?? '').trim().isNotEmpty,
        )
        .toList();

    pw.MemoryImage? photoImage;

    if (photoBytes != null && photoBytes.isNotEmpty) {
      photoImage = pw.MemoryImage(photoBytes);
    }

    pdf.addPage(
      pw.Page(
        pageFormat: format,
        margin: const pw.EdgeInsets.all(28),
        build: (context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                'TAILOR SHOP - MEASUREMENT',
                style: pw.TextStyle(
                  fontSize: 20,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 12),
              pw.Divider(),
              pw.SizedBox(height: 10),
              pw.Text(
                'Customer: ${widget.customer.name}',
                style: pw.TextStyle(
                  fontSize: 15,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 5),
              pw.Text(
                'Date: ${fmtDate(measurement.createdAt)}',
                style: const pw.TextStyle(fontSize: 12),
              ),
              pw.SizedBox(height: 18),
              if (filled.isEmpty)
                pw.Text(
                  'No measurements entered.',
                  style: const pw.TextStyle(fontSize: 12),
                )
              else
                pw.Table(
                  border: pw.TableBorder.all(
                    color: PdfColors.grey500,
                    width: 0.7,
                  ),
                  columnWidths: const {
                    0: pw.FlexColumnWidth(1.5),
                    1: pw.FlexColumnWidth(2.5),
                  },
                  children: [
                    pw.TableRow(
                      decoration: const pw.BoxDecoration(
                        color: PdfColors.grey200,
                      ),
                      children: [
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(7),
                          child: pw.Text(
                            'Measurement',
                            style: pw.TextStyle(
                              fontWeight: pw.FontWeight.bold,
                            ),
                          ),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(7),
                          child: pw.Text(
                            'Value',
                            style: pw.TextStyle(
                              fontWeight: pw.FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    for (final field in filled)
                      pw.TableRow(
                        children: [
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(7),
                            child: pw.Text(
                              measurementLabel(field, 'en'),
                            ),
                          ),
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(7),
                            child: pw.Text(
                              measurement.values[field] ?? '',
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              if ((measurement.values['notes'] ?? '').trim().isNotEmpty) ...[
                pw.SizedBox(height: 18),
                pw.Text(
                  'Notes',
                  style: pw.TextStyle(
                    fontSize: 14,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 5),
                pw.Container(
                  width: double.infinity,
                  padding: const pw.EdgeInsets.all(8),
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(color: PdfColors.grey500),
                  ),
                  child: pw.Text(measurement.values['notes']!.trim()),
                ),
              ],
              if (photoImage != null) ...[
                pw.SizedBox(height: 20),
                pw.Text(
                  'Measurement Book Photo',
                  style: pw.TextStyle(
                    fontSize: 14,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 8),
                pw.Container(
                  constraints: const pw.BoxConstraints(
                    maxHeight: 330,
                    maxWidth: 500,
                  ),
                  child: pw.Image(
                    photoImage,
                    fit: pw.BoxFit.contain,
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );

    return pdf.save();
  }

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          '${widget.customer.name} - '
          '${s.t('Measurements', 'ماپ', 'پیمائش')}',
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _items.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Text(
                      s.t(
                        'No measurements yet. Tap "Add" to save one.',
                        'اڃا ڪا ماپ ناهي. محفوظ ڪرڻ لاءِ "شامل ڪريو" دٻايو.',
                        'ابھی کوئی پیمائش نہیں۔ محفوظ کرنے کے لیے "شامل کریں" دبائیں۔',
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(10, 10, 10, 90),
                  itemCount: _items.length,
                  itemBuilder: (_, index) => _card(s, _items[index]),
                ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _edit(),
        icon: const Icon(Icons.add),
        label: Text(s.t('Add', 'شامل ڪريو', 'شامل کریں')),
      ),
    );
  }

  Widget _card(AppSettings s, MeasurementRecord measurement) {
    final filled = kMeasurementFields
        .where(
          (field) =>
              (measurement.values[field] ?? '').trim().isNotEmpty,
        )
        .toList();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    fmtDate(measurement.createdAt),
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                ),
                IconButton(
                  tooltip: s.t('Edit', 'تبديل ڪريو', 'ترمیم کریں'),
                  icon: const Icon(Icons.edit),
                  onPressed: () => _edit(measurement),
                ),
                IconButton(
                  tooltip: s.t('Print', 'پرنٽ', 'پرنٹ'),
                  icon: const Icon(Icons.print),
                  onPressed: () => _printMeasurement(measurement),
                ),
                IconButton(
                  tooltip: s.t('Delete', 'ڊيليٽ', 'حذف کریں'),
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () => _delete(measurement),
                ),
              ],
            ),
            if (filled.isEmpty && measurement.photo == null)
              Text(
                s.t(
                  'Empty measurement',
                  'خالي ماپ',
                  'خالی پیمائش',
                ),
              ),
            for (final field in filled)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 100,
                      child: Text(
                        measurementLabel(field, s.language),
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Text(measurement.values[field]!),
                    ),
                  ],
                ),
              ),
            if (measurement.photo != null) ...[
              const SizedBox(height: 8),
              StoredPhoto(stored: measurement.photo!),
            ],
          ],
        ),
      ),
    );
  }
}

/// Add or edit a measurement, with camera / gallery photo support.
class MeasurementFormPage extends StatefulWidget {
  final Customer customer;
  final MeasurementRecord? existing;

  const MeasurementFormPage({
    super.key,
    required this.customer,
    this.existing,
  });

  @override
  State<MeasurementFormPage> createState() =>
      _MeasurementFormPageState();
}

class _MeasurementFormPageState extends State<MeasurementFormPage> {
  final Map<String, TextEditingController> _ctrls = {};
  final ImagePicker _picker = ImagePicker();

  String? _photo;
  String? _originalPhoto;
  final List<String> _newPhotos = [];

  bool _saving = false;
  bool _saved = false;

  @override
  void initState() {
    super.initState();

    final existing = widget.existing;

    for (final field in kMeasurementFields) {
      _ctrls[field] = TextEditingController(
        text: existing?.values[field] ?? '',
      );
    }

    _photo = existing?.photo;
    _originalPhoto = existing?.photo;
  }

  @override
  void dispose() {
    for (final controller in _ctrls.values) {
      controller.dispose();
    }

    if (!_saved) {
      for (final name in _newPhotos) {
        PhotoStore.delete(name);
      }
    }

    super.dispose();
  }

  Future<void> _pick(ImageSource source) async {
    final s = AppScope.of(context);

    try {
      final picked = await _picker.pickImage(
        source: source,
        imageQuality: 80,
        maxWidth: 2000,
        maxHeight: 2000,
      );

      if (picked == null) return;

      final name = await PhotoStore.importFile(picked.path);
      _newPhotos.add(name);

      if (!mounted) return;

      setState(() => _photo = name);
    } catch (_) {
      if (!mounted) return;

      showSnack(
        context,
        source == ImageSource.camera
            ? s.t(
                'Could not open the camera. Check the camera permission.',
                'ڪئميرا کلي نه سگهيو. ڪئميرا جي اجازت چيڪ ڪريو.',
                'کیمرہ نہیں کھل سکا۔ کیمرے کی اجازت چیک کریں۔',
              )
            : s.t(
                'Could not open the gallery. Check the photo permission.',
                'گيلري کلي نه سگهي. فوٽو جي اجازت چيڪ ڪريو.',
                'گیلری نہیں کھل سکی۔ تصاویر کی اجازت چیک کریں۔',
              ),
      );
    }
  }

  void _removePhoto() {
    setState(() => _photo = null);
  }

  Future<void> _save() async {
    if (_saving) return;

    setState(() => _saving = true);

    try {
      final values = <String, String>{
        for (final field in kMeasurementFields)
          field: _ctrls[field]!.text.trim(),
      };

      final existing = widget.existing;

      if (existing == null) {
        await DB.instance.addMeasurement(
          widget.customer.id,
          values,
          _photo,
        );
      } else {
        await DB.instance.updateMeasurement(
          existing.id,
          values,
          _photo,
        );
      }

      _saved = true;

      if (_originalPhoto != null && _originalPhoto != _photo) {
        await DB.instance.releasePhoto(_originalPhoto);
      }

      for (final name in _newPhotos) {
        if (name != _photo) {
          await PhotoStore.delete(name);
        }
      }

      if (mounted) {
        Navigator.pop(context, true);
      }
    } catch (_) {
      if (!mounted) return;

      final s = AppScope.of(context);

      showSnack(
        context,
        s.t(
          'Could not save the measurement. Please try again.',
          'ماپ محفوظ نه ٿي سگهي. ٻيهر ڪوشش ڪريو.',
          'پیمائش محفوظ نہیں ہو سکی۔ دوبارہ کوشش کریں۔',
        ),
      );

      setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.existing == null
              ? s.t('New Measurement', 'نئين ماپ', 'نئی پیمائش')
              : s.t(
                  'Edit Measurement',
                  'ماپ تبديل ڪريو',
                  'پیمائش میں ترمیم',
                ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            widget.customer.name,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 12),
          for (final field in kMeasurementFields)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: TextField(
                controller: _ctrls[field],
                keyboardType: field == 'notes'
                    ? TextInputType.multiline
                    : TextInputType.text,
                maxLines: field == 'notes' ? 3 : 1,
                decoration: InputDecoration(
                  labelText: measurementLabel(field, s.language),
                  border: const OutlineInputBorder(),
                ),
              ),
            ),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _pick(ImageSource.camera),
                  icon: const Icon(Icons.camera_alt),
                  label: Text(
                    s.t('Camera', 'ڪئميرا', 'کیمرہ'),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _pick(ImageSource.gallery),
                  icon: const Icon(Icons.photo_library),
                  label: Text(
                    s.t('Gallery', 'گيلري', 'گیلری'),
                  ),
                ),
              ),
            ],
          ),
          if (_photo != null) ...[
            const SizedBox(height: 12),
            StoredPhoto(
              stored: _photo!,
              height: 220,
            ),
            Align(
              alignment: AlignmentDirectional.centerEnd,
              child: TextButton.icon(
                onPressed: _removePhoto,
                icon: const Icon(Icons.delete_outline),
                label: Text(
                  s.t(
                    'Remove photo',
                    'تصوير هٽايو',
                    'تصویر ہٹائیں',
                  ),
                ),
              ),
            ),
          ],
          const SizedBox(height: 14),
          FilledButton.icon(
            onPressed: _saving ? null : _save,
            icon: const Icon(Icons.save),
            label: Text(
              _saving
                  ? s.t(
                      'Saving...',
                      'محفوظ ٿي رهيو آهي...',
                      'محفوظ ہو رہا ہے...',
                    )
                  : s.t(
                      'Save Measurement',
                      'محفوظ ڪريو',
                      'پیمائش محفوظ کریں',
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
