import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../app.dart';
import '../data/db.dart';
import '../data/models.dart';
import '../data/photo_store.dart';
import '../settings.dart';
import 'common.dart';

const Color _measurementBrown = Color(0xFF6B4F3A);
const Color _measurementDarkBrown = Color(0xFF4E342E);
const Color _measurementCream = Color(0xFFF5EDE3);
const Color _measurementSoftBrown = Color(0xFFE8D8C8);

IconData _measurementIcon(String field) {
  switch (field) {
    case 'chest':
      return Icons.accessibility_new_rounded;
    case 'waist':
      return Icons.straighten_rounded;
    case 'shalwar':
      return Icons.checkroom_rounded;
    case 'bazu':
      return Icons.fitness_center_rounded;
    case 'kameez':
      return Icons.checkroom_outlined;
    case 'shoulder':
      return Icons.accessibility_rounded;
    case 'neck':
      return Icons.person_outline_rounded;
    case 'notes':
      return Icons.notes_rounded;
    default:
      return Icons.straighten_rounded;
  }
}

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
          (field) => (measurement.values[field] ?? '').trim().isNotEmpty,
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
                            child: pw.Text(measurementLabel(field, 'en')),
                          ),
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(7),
                            child: pw.Text(measurement.values[field] ?? ''),
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
      backgroundColor: _measurementCream,
      appBar: AppBar(
        backgroundColor: _measurementCream,
        foregroundColor: _measurementDarkBrown,
        elevation: 0,
        title: Text(
          '${widget.customer.name} - '
          '${s.t('Measurements', 'ماپ', 'پیمائش')}',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: _measurementBrown),
            )
          : _items.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 88,
                          height: 88,
                          decoration: const BoxDecoration(
                            color: _measurementSoftBrown,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.straighten_rounded,
                            size: 44,
                            color: _measurementBrown,
                          ),
                        ),
                        const SizedBox(height: 18),
                        Text(
                          s.t(
                            'No measurements yet. Tap "Add" to save one.',
                            'اڃا ڪا ماپ ناهي. محفوظ ڪرڻ لاءِ "شامل ڪريو" دٻايو.',
                            'ابھی کوئی پیمائش نہیں۔ محفوظ کرنے کے لیے "شامل کریں" دبائیں۔',
                          ),
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: _measurementDarkBrown,
                            fontSize: 15,
                            height: 1.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 100),
                  itemCount: _items.length,
                  itemBuilder: (_, index) => _card(s, _items[index]),
                ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: _measurementBrown,
        foregroundColor: Colors.white,
        onPressed: () => _edit(),
        icon: const Icon(Icons.add_rounded),
        label: Text(s.t('Add', 'شامل ڪريو', 'شامل کریں')),
      ),
    );
  }

  Widget _card(AppSettings s, MeasurementRecord measurement) {
    final filled = kMeasurementFields
        .where(
          (field) => (measurement.values[field] ?? '').trim().isNotEmpty,
        )
        .toList();

    return Card(
      color: Colors.white,
      elevation: 2,
      shadowColor: _measurementBrown.withValues(alpha: 0.10),
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(22),
        side: const BorderSide(color: _measurementSoftBrown),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          Container(
            color: _measurementSoftBrown.withValues(alpha: 0.55),
            padding: const EdgeInsets.fromLTRB(14, 8, 6, 8),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: const Icon(
                    Icons.straighten_rounded,
                    color: _measurementBrown,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        s.t('Measurement Record', 'ماپ جو رڪارڊ', 'پیمائش کا ریکارڈ'),
                        style: const TextStyle(
                          color: _measurementDarkBrown,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        fmtDate(measurement.createdAt),
                        style: TextStyle(
                          color: _measurementDarkBrown.withValues(alpha: 0.75),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: s.t('Edit', 'تبديل ڪريو', 'ترمیم کریں'),
                  onPressed: () => _edit(measurement),
                  icon: const Icon(Icons.edit_outlined),
                  color: _measurementBrown,
                ),
                IconButton(
                  tooltip: s.t('Print', 'پرنٽ', 'پرنٹ'),
                  onPressed: () => _printMeasurement(measurement),
                  icon: const Icon(Icons.print_outlined),
                  color: _measurementBrown,
                ),
                IconButton(
                  tooltip: s.t('Delete', 'ڊيليٽ', 'حذف کریں'),
                  onPressed: () => _delete(measurement),
                  icon: const Icon(Icons.delete_outline_rounded),
                  color: Colors.red.shade700,
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              children: [
                if (filled.isEmpty && measurement.photo == null)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    child: Text(
                      s.t(
                        'Empty measurement',
                        'خالي ماپ',
                        'خالی پیمائش',
                      ),
                      style: const TextStyle(color: Colors.black54),
                    ),
                  ),
                for (var i = 0; i < filled.length; i++)
                  _measurementValueRow(
                    field: filled[i],
                    value: measurement.values[filled[i]]!,
                    language: s.language,
                    isLast: i == filled.length - 1,
                  ),
                if (measurement.photo != null) ...[
                  const SizedBox(height: 12),
                  Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: Text(
                      s.t(
                        'Measurement Photo',
                        'ماپ جي تصوير',
                        'پیمائش کی تصویر',
                      ),
                      style: const TextStyle(
                        color: _measurementDarkBrown,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: StoredPhoto(stored: measurement.photo!),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _measurementValueRow({
    required String field,
    required String value,
    required String language,
    required bool isLast,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: BoxDecoration(
          color: _measurementCream.withValues(alpha: 0.75),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: _measurementSoftBrown.withValues(alpha: 0.75),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: _measurementSoftBrown.withValues(alpha: 0.8),
                borderRadius: BorderRadius.circular(11),
              ),
              child: Icon(
                _measurementIcon(field),
                color: _measurementBrown,
                size: 21,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                measurementLabel(field, language),
                style: const TextStyle(
                  color: _measurementDarkBrown,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  value,
                  textAlign: TextAlign.end,
                  style: const TextStyle(
                    color: _measurementBrown,
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
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
  State<MeasurementFormPage> createState() => _MeasurementFormPageState();
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

  Widget _buildField(String field, AppSettings s) {
    final isNotes = field == 'notes';

    return Container(
      margin: const EdgeInsets.only(bottom: 13),
      padding: const EdgeInsets.fromLTRB(13, 5, 13, 7),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(17),
        border: Border.all(color: _measurementSoftBrown),
      ),
      child: Row(
        crossAxisAlignment: isNotes
            ? CrossAxisAlignment.start
            : CrossAxisAlignment.center,
        children: [
          Container(
            width: 43,
            height: 43,
            margin: EdgeInsets.only(top: isNotes ? 10 : 0),
            decoration: BoxDecoration(
              color: _measurementCream,
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(
              _measurementIcon(field),
              color: _measurementBrown,
              size: 23,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: TextField(
              controller: _ctrls[field],
              keyboardType: isNotes
                  ? TextInputType.multiline
                  : TextInputType.text,
              maxLines: isNotes ? 3 : 1,
              textInputAction:
                  isNotes ? TextInputAction.newline : TextInputAction.next,
              decoration: InputDecoration(
                labelText: measurementLabel(field, s.language),
                hintText: isNotes
                    ? s.t(
                        'Add any extra details',
                        'وڌيڪ تفصيل لکو',
                        'مزید تفصیل لکھیں',
                      )
                    : s.t(
                        'Enter measurement',
                        'ماپ لکو',
                        'پیمائش درج کریں',
                      ),
                border: InputBorder.none,
                labelStyle: const TextStyle(
                  color: _measurementBrown,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final isEditing = widget.existing != null;

    return Scaffold(
      backgroundColor: _measurementCream,
      appBar: AppBar(
        backgroundColor: _measurementCream,
        foregroundColor: _measurementDarkBrown,
        elevation: 0,
        title: Text(
          isEditing
              ? s.t(
                  'Edit Measurement',
                  'ماپ تبديل ڪريو',
                  'پیمائش میں ترمیم',
                )
              : s.t('New Measurement', 'نئين ماپ', 'نئی پیمائش'),
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _measurementBrown,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(
                    Icons.person_outline_rounded,
                    color: Colors.white,
                    size: 29,
                  ),
                ),
                const SizedBox(width: 13),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        s.t('Customer', 'گراهڪ', 'گاہک'),
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.8),
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        widget.customer.name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),
          Text(
            s.t('Body Measurements', 'جسم جون ماپون', 'جسم کی پیمائش'),
            style: const TextStyle(
              fontSize: 17,
              color: _measurementDarkBrown,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 5),
          Padding(
            padding: const EdgeInsets.only(bottom: 15),
            child: Text(
              s.t(
                'Enter the values for this customer.',
                'هن گراهڪ جون ماپون لکو.',
                'اس گاہک کی پیمائش درج کریں۔',
              ),
              style: TextStyle(
                color: _measurementDarkBrown.withValues(alpha: 0.7),
                fontSize: 13,
              ),
            ),
          ),
          for (final field in kMeasurementFields) _buildField(field, s),
          const SizedBox(height: 5),
          Text(
            s.t('Measurement Photo', 'ماپ جي تصوير', 'پیمائش کی تصویر'),
            style: const TextStyle(
              fontSize: 17,
              color: _measurementDarkBrown,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            s.t(
              'Optional: attach a photo of the measurement book.',
              'اختياري: ماپ واري ڪتاب جي تصوير شامل ڪريو.',
              'اختیاری: پیمائش والی کتاب کی تصویر شامل کریں۔',
            ),
            style: TextStyle(
              color: _measurementDarkBrown.withValues(alpha: 0.7),
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _saving ? null : () => _pick(ImageSource.camera),
                  icon: const Icon(Icons.camera_alt_outlined),
                  label: Text(s.t('Camera', 'ڪئميرا', 'کیمرہ')),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _measurementBrown,
                    side: const BorderSide(color: _measurementBrown),
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _saving ? null : () => _pick(ImageSource.gallery),
                  icon: const Icon(Icons.photo_library_outlined),
                  label: Text(s.t('Gallery', 'گيلري', 'گیلری')),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _measurementBrown,
                    side: const BorderSide(color: _measurementBrown),
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),
            ],
          ),
          if (_photo != null) ...[
            const SizedBox(height: 14),
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: StoredPhoto(
                stored: _photo!,
                height: 220,
              ),
            ),
            Align(
              alignment: AlignmentDirectional.centerEnd,
              child: TextButton.icon(
                onPressed: _saving ? null : _removePhoto,
                icon: const Icon(Icons.delete_outline),
                label: Text(
                  s.t(
                    'Remove photo',
                    'تصوير هٽايو',
                    'تصویر ہٹائیں',
                  ),
                ),
                style: TextButton.styleFrom(
                  foregroundColor: Colors.red.shade700,
                ),
              ),
            ),
          ],
          const SizedBox(height: 18),
          SizedBox(
            height: 54,
            child: FilledButton.icon(
              onPressed: _saving ? null : _save,
              style: FilledButton.styleFrom(
                backgroundColor: _measurementBrown,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              icon: _saving
                  ? const SizedBox(
                      width: 21,
                      height: 21,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.save_outlined),
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
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
