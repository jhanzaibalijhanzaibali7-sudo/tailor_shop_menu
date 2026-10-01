import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../data/db.dart';
import '../data/models.dart';
import '../data/photo_store.dart';
import '../settings.dart';
import 'common.dart';

/// Saved measurements of one customer (newest first) + add / edit.
/// Opened from the customer menu and by the voice command "Ahmed ji maap".
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
        builder: (_) =>
            MeasurementFormPage(customer: widget.customer, existing: existing),
      ),
    );
    if (saved == true && mounted) _load();
  }

  Future<void> _delete(MeasurementRecord m) async {
    final s = AppScope.of(context);
    final ok = await confirmDialog(
      context,
      title: s.t('Delete measurement', 'ماپ ڊيليٽ ڪريو'),
      message: s.t('Delete this measurement and its photo?',
          'هي ماپ ۽ ان جي تصوير ڊيليٽ ڪجي؟'),
      confirmLabel: s.t('Delete', 'ڊيليٽ'),
      destructive: true,
    );
    if (!ok) return;
    await DB.instance.deleteMeasurement(m);
    if (mounted) _load();
  }

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.customer.name} - ${s.t('Measurements', 'ماپ')}'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _items.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Text(
                      s.t('No measurements yet. Tap "Add" to save one.',
                          'اڃا ڪا ماپ ناهي. محفوظ ڪرڻ لاءِ "شامل ڪريو" دٻايو.'),
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(10, 10, 10, 90),
                  itemCount: _items.length,
                  itemBuilder: (_, i) => _card(s, _items[i]),
                ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _edit(),
        icon: const Icon(Icons.add),
        label: Text(s.t('Add', 'شامل ڪريو')),
      ),
    );
  }

  Widget _card(AppSettings s, MeasurementRecord m) {
    final filled = kMeasurementFields
        .where((f) => (m.values[f] ?? '').trim().isNotEmpty)
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
                    fmtDate(m.createdAt),
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                ),
                IconButton(
                  tooltip: s.t('Edit', 'تبديل ڪريو'),
                  icon: const Icon(Icons.edit),
                  onPressed: () => _edit(m),
                ),
                IconButton(
                  tooltip: s.t('Delete', 'ڊيليٽ'),
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () => _delete(m),
                ),
              ],
            ),
            if (filled.isEmpty && m.photo == null)
              Text(s.t('Empty measurement', 'خالي ماپ')),
            for (final f in filled)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 100,
                      child: Text(
                        measurementLabel(f, s.sindhi),
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                    Expanded(child: Text(m.values[f]!)),
                  ],
                ),
              ),
            if (m.photo != null) ...[
              const SizedBox(height: 8),
              StoredPhoto(stored: m.photo!),
            ],
          ],
        ),
      ),
    );
  }
}

/// Add or edit one measurement, with camera / gallery photo of the book page.
class MeasurementFormPage extends StatefulWidget {
  final Customer customer;
  final MeasurementRecord? existing;
  const MeasurementFormPage({super.key, required this.customer, this.existing});

  @override
  State<MeasurementFormPage> createState() => _MeasurementFormPageState();
}

class _MeasurementFormPageState extends State<MeasurementFormPage> {
  final Map<String, TextEditingController> _ctrls = {};
  final ImagePicker _picker = ImagePicker();

  /// Stored photo name (already in the app folder) or null.
  String? _photo;

  /// Photo name stored when the form opened, to clean up if it is replaced.
  String? _originalPhoto;

  /// Photos copied in this session that are not saved yet.
  final List<String> _newPhotos = [];

  bool _saving = false;
  bool _saved = false;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    for (final f in kMeasurementFields) {
      _ctrls[f] = TextEditingController(text: e?.values[f] ?? '');
    }
    _photo = e?.photo;
    _originalPhoto = e?.photo;
  }

  @override
  void dispose() {
    for (final c in _ctrls.values) {
      c.dispose();
    }
    // Leaving without saving: delete photos copied during this session.
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
      final x = await _picker.pickImage(
        source: source,
        imageQuality: 80,
        maxWidth: 2000,
        maxHeight: 2000,
      );
      if (x == null) return;
      final name = await PhotoStore.importFile(x.path);
      _newPhotos.add(name);
      if (!mounted) return;
      setState(() => _photo = name);
    } catch (e) {
      if (!mounted) return;
      showSnack(
        context,
        source == ImageSource.camera
            ? s.t('Could not open the camera. Check the camera permission.',
                'ڪئميرا کلي نه سگهيو. ڪئميرا جي اجازت چيڪ ڪريو.')
            : s.t('Could not open the gallery. Check the photo permission.',
                'گيلري کلي نه سگهي. فوٽو جي اجازت چيڪ ڪريو.'),
      );
    }
  }

  void _removePhoto() => setState(() => _photo = null);

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);
    final values = <String, String>{
      for (final f in kMeasurementFields) f: _ctrls[f]!.text.trim(),
    };
    final e = widget.existing;
    if (e == null) {
      await DB.instance.addMeasurement(widget.customer.id, values, _photo);
    } else {
      await DB.instance.updateMeasurement(e.id, values, _photo);
    }
    _saved = true;

    // Remove photo files that are no longer used.
    if (_originalPhoto != null && _originalPhoto != _photo) {
      await DB.instance.releasePhoto(_originalPhoto);
    }
    for (final name in _newPhotos) {
      if (name != _photo) await PhotoStore.delete(name);
    }
    if (mounted) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.existing == null
            ? s.t('New Measurement', 'نئين ماپ')
            : s.t('Edit Measurement', 'ماپ تبديل ڪريو')),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(widget.customer.name,
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
          for (final f in kMeasurementFields)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: TextField(
                controller: _ctrls[f],
                // Measurements are free text (e.g. 15.5, 15½), notes can be long.
                keyboardType:
                    f == 'notes' ? TextInputType.multiline : TextInputType.text,
                maxLines: f == 'notes' ? 3 : 1,
                decoration: InputDecoration(
                  labelText: measurementLabel(f, s.sindhi),
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
                  label: Text(s.t('Camera', 'ڪئميرا')),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _pick(ImageSource.gallery),
                  icon: const Icon(Icons.photo_library),
                  label: Text(s.t('Gallery', 'گيلري')),
                ),
              ),
            ],
          ),
          if (_photo != null) ...[
            const SizedBox(height: 12),
            StoredPhoto(stored: _photo!, height: 220),
            Align(
              alignment: AlignmentDirectional.centerEnd,
              child: TextButton.icon(
                onPressed: _removePhoto,
                icon: const Icon(Icons.delete_outline),
                label: Text(s.t('Remove photo', 'تصوير هٽايو')),
              ),
            ),
          ],
          const SizedBox(height: 14),
          FilledButton.icon(
            onPressed: _saving ? null : _save,
            icon: const Icon(Icons.save),
            label: Text(s.t('Save Measurement', 'محفوظ ڪريو')),
          ),
        ],
      ),
    );
  }
}
