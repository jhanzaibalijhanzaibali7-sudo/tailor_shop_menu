import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../data/backup_service.dart';
import '../data/db.dart';
import '../data/models.dart';
import '../settings.dart';
import '../voice/command_parser.dart';
import '../voice/voice_service.dart';
import 'common.dart';
import 'measurements_page.dart';
import 'orders_page.dart';
import 'reports_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final TextEditingController _search = TextEditingController();
  final VoiceService _voice = VoiceService();
  List<CustomerSummary> _list = [];
  bool _loading = true;
  bool _listening = false;
  String _heard = '';
  int _loadToken = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    unawaited(_voice.dispose());
    _search.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final token = ++_loadToken;
    final rows = await DB.instance.customerSummaries(_search.text);
    if (!mounted || token != _loadToken) return;
    setState(() {
      _list = rows;
      _loading = false;
    });
  }

  // ------------------------------------------------------------ navigation

  Future<void> _openOrders(Customer c) async {
    await Navigator.push(
      context,
      MaterialPageRoute<void>(builder: (_) => OrdersPage(customer: c)),
    );
    if (mounted) _load();
  }

  Future<void> _openMeasurements(Customer c) async {
    await Navigator.push(
      context,
      MaterialPageRoute<void>(builder: (_) => MeasurementsPage(customer: c)),
    );
    if (mounted) _load();
  }

  // ------------------------------------------------------------- customers

  Future<void> _editCustomer([Customer? existing]) async {
    final input = await showDialog<_CustomerInput>(
      context: context,
      builder: (_) => _CustomerDialog(existing: existing),
    );
    if (input == null) return;
    if (existing == null) {
      await DB.instance.addCustomer(input.name, input.phone, input.address);
    } else {
      await DB.instance
          .updateCustomer(existing.id, input.name, input.phone, input.address);
    }
    if (mounted) _load();
  }

  Future<void> _deleteCustomer(Customer c) async {
    final s = AppScope.of(context);
    final ok = await confirmDialog(
      context,
      title: s.t('Delete customer', 'گراهڪ ڊيليٽ ڪريو'),
      message: s.t(
        'Delete ${c.name} with all measurements, photos and orders? This cannot be undone.',
        '${c.name} کي سڀني ماپن، تصويرن ۽ آرڊرن سميت ڊيليٽ ڪجي؟ هي واپس نه ٿيندو.',
      ),
      confirmLabel: s.t('Delete', 'ڊيليٽ'),
      destructive: true,
    );
    if (!ok) return;
    await DB.instance.deleteCustomer(c.id);
    if (mounted) _load();
  }

  // ----------------------------------------------------------------- voice

  /// [commandMode] false = voice search (fills the search box),
  /// true = voice command (opens the right screen).
  Future<void> _listen({required bool commandMode}) async {
    if (_listening) {
      await _voice.stop();
      return;
    }
    final s = AppScope.of(context);
    setState(() {
      _listening = true;
      _heard = '';
    });

    final result = await _voice.listenOnce(
      localePref: s.voiceLang,
      onPartial: (w) {
        if (mounted) setState(() => _heard = w);
      },
    );
    if (!mounted) return;
    setState(() => _listening = false);

    if (!result.ok) {
      showSnack(
        context,
        result.permissionDenied
            ? s.t('Microphone permission is needed for voice.',
                'آواز لاءِ مائيڪروفون جي اجازت گهرجي.')
            : s.t("Couldn't hear anything. Please try again.",
                'ڪجهه ٻڌي نه سگهيس. ٻيهر ڪوشش ڪريو.'),
      );
      return;
    }

    final names = await DB.instance.customerNames();
    final refs = [for (final n in names) VoiceCustomerRef(n.id, n.name)];
    final cmd = VoiceCommandParser.parseBest(result.transcripts, refs);
    if (!mounted) return;

    if (!cmd.hasCustomer) {
      // No saved customer sounds like the spoken name: show what was heard
      // (without command words) in the search box.
      final words = cmd.leftover.isNotEmpty
          ? cmd.leftover.join(' ')
          : result.transcripts.first;
      _search.text = words;
      await _load();
      if (!mounted) return;
      showSnack(context,
          '${s.t('Customer not found', 'گراهڪ نه مليو')}: ${result.transcripts.first}');
      return;
    }

    if (!commandMode) {
      _search.text = cmd.best!.customer.name;
      await _load();
      return;
    }

    var chosen = cmd.best!.customer;
    if (cmd.isAmbiguous) {
      final picked = await _chooseCustomer(cmd.matches);
      if (picked == null || !mounted) return;
      chosen = picked;
    }
    final customer = await DB.instance.customerById(chosen.id);
    if (customer == null || !mounted) return;

    switch (cmd.intent) {
      case VoiceIntent.showMeasurements:
        await _openMeasurements(customer);
      case VoiceIntent.showBalance:
        await showBalanceSheet(context, customer);
      case VoiceIntent.openOrders:
      case VoiceIntent.none:
        await _openOrders(customer);
    }
  }

  Future<VoiceCustomerRef?> _chooseCustomer(List<VoiceMatch> matches) {
    final s = AppScope.of(context);
    return showDialog<VoiceCustomerRef>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: Text(s.t('Which customer?', 'ڪهڙو گراهڪ؟')),
        children: [
          for (final m in matches)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(ctx, m.customer),
              child: Text(m.customer.name),
            ),
        ],
      ),
    );
  }

  Future<void> _pickVoiceLanguage() async {
    final s = AppScope.of(context);
    final options = <String, String>{
      'auto': s.t('Automatic (recommended)', 'خودڪار (بهتر)'),
      'sd': 'سنڌي (Sindhi)',
      'ur': 'اردو (Urdu)',
      'hi': 'हिन्दी (Hindi)',
      'en': 'English',
    };
    final picked = await showDialog<String>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: Text(s.t('Voice recognition language', 'آواز سڃاڻڻ جي ٻولي')),
        children: [
          for (final e in options.entries)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(ctx, e.key),
              child: Row(
                children: [
                  Expanded(child: Text(e.value)),
                  if (s.voiceLang == e.key) const Icon(Icons.check),
                ],
              ),
            ),
        ],
      ),
    );
    if (picked != null) await s.setVoiceLang(picked);
  }

  void _showVoiceHelp() {
    final s = AppScope.of(context);
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(s.t('Voice commands', 'آواز جا حڪم')),
        content: SingleChildScrollView(
          child: Directionality(
            textDirection: TextDirection.ltr,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text('Measurement / ماپ', style: TextStyle(fontWeight: FontWeight.bold)),
                Text('"Jahanzeb ji maap"\n"Jahanzeb ji maap dikha"\n"Ahmed ji measurement"\n"Ahmed ka measurement dikhao"\n"جهانزيب جي ماپ"'),
                SizedBox(height: 12),
                Text('Order / آرڊر', style: TextStyle(fontWeight: FontWeight.bold)),
                Text('"Jahanzeb jo order kholo"\n"Salman jo order kholo"\n"Jahanzeb ka order kholo"\n"سلمان جو آرڊر ڪولو"'),
                SizedBox(height: 12),
                Text('Balance / باقي', style: TextStyle(fontWeight: FontWeight.bold)),
                Text('"Jahanzeb te ketro paiso baqi aa"\n"Salman ka kitna paisa baqi hai"\n"جهانزيب تي ڪيترو پيسو باقي آهي"'),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(s.t('Close', 'بند')),
          ),
        ],
      ),
    );
  }

  // ------------------------------------------------------- backup / restore

  Future<void> _backup() async {
    final s = AppScope.of(context);
    try {
      final dir = await getTemporaryDirectory();
      final file = await BackupService.createBackup(dir: dir);
      final result = await Share.shareXFiles(
        [XFile(file.path)],
        text: s.t('Tailor shop backup', 'درزي دڪان جو بيڪ اپ'),
      );
      if (result.status != ShareResultStatus.dismissed) {
        await s.markBackup();
      }
    } catch (e) {
      if (mounted) {
        showSnack(context, '${s.t('Backup failed', 'بيڪ اپ ناڪام')}: $e');
      }
    }
  }

  Future<void> _restore() async {
    final s = AppScope.of(context);
    final picked = await FilePicker.platform
        .pickFiles(type: FileType.custom, allowedExtensions: ['json']);
    if (picked == null || picked.files.isEmpty) return;
    final path = picked.files.first.path;
    if (path == null || !mounted) return;

    final ok = await confirmDialog(
      context,
      title: s.t('Restore backup', 'بيڪ اپ بحال ڪريو'),
      message: s.t(
        'All current customers, measurements, photos and orders will be replaced by the backup. A safety copy of the current data is saved first. Continue?',
        'موجوده سڀ گراهڪ، ماپون، تصويرون ۽ آرڊر بيڪ اپ سان مٽجي ويندا. پهرين موجوده ڊيٽا جي حفاظتي ڪاپي محفوظ ٿيندي. اڳتي هلون؟',
      ),
      confirmLabel: s.t('Restore', 'بحال ڪريو'),
      destructive: true,
    );
    if (!ok || !mounted) return;

    try {
      final autoDir = await BackupService.autoBackupDir();
      await BackupService.createBackup(dir: autoDir, prefix: 'pre_restore');
      await BackupService.pruneAutoBackups(autoDir);

      final r = await BackupService.restore(File(path));
      await _load();
      if (!mounted) return;
      showSnack(
        context,
        '${s.t('Restore complete', 'بحالي مڪمل ٿي وئي')}: '
        '${r.customers} ${s.t('customers', 'گراهڪ')}, '
        '${r.orders} ${s.t('orders', 'آرڊر')}, '
        '${r.photos} ${s.t('photos', 'تصويرون')}',
      );
    } on FormatException catch (e) {
      if (mounted) {
        showSnack(context,
            '${s.t('Restore failed', 'بحالي ناڪام')}: ${s.t('this is not a valid backup file', 'هيءَ صحيح بيڪ اپ فائل ناهي')} (${e.message})');
      }
    } catch (e) {
      if (mounted) {
        showSnack(context, '${s.t('Restore failed', 'بحالي ناڪام')}: $e');
      }
    }
  }

  // ------------------------------------------------------------------- build

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(s.t('Tailor Shop', 'درزي جو دڪان')),
        actions: [
          TextButton(
            onPressed: s.toggleLanguage,
            child: Text(s.sindhi ? 'English' : 'سنڌي'),
          ),
          PopupMenuButton<String>(
            onSelected: (v) {
              switch (v) {
                case 'backup':
                  _backup();
                case 'restore':
                  _restore();
                case 'reports':
                  Navigator.push(
                    context,
                    MaterialPageRoute<void>(builder: (_) => const ReportsPage()),
                  );
                case 'voice_lang':
                  _pickVoiceLanguage();
                case 'voice_help':
                  _showVoiceHelp();
              }
            },
            itemBuilder: (_) => [
              PopupMenuItem(value: 'reports', child: Text(s.t('Reports', 'رپورٽون'))),
              PopupMenuItem(value: 'backup', child: Text(s.t('Backup', 'بيڪ اپ'))),
              PopupMenuItem(value: 'restore', child: Text(s.t('Restore', 'بحال ڪريو'))),
              PopupMenuItem(
                enabled: false,
                child: Text(
                  '${s.t('Last backup', 'آخري بيڪ اپ')}: '
                  '${s.lastBackup == null ? s.t('never', 'ڪڏهن به نه') : fmtDate(s.lastBackup)}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
              const PopupMenuDivider(),
              PopupMenuItem(
                  value: 'voice_help',
                  child: Text(s.t('Voice commands', 'آواز جا حڪم'))),
              PopupMenuItem(
                  value: 'voice_lang',
                  child: Text(s.t('Voice language', 'آواز جي ٻولي'))),
            ],
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _search,
                    onChanged: (_) => _load(),
                    decoration: InputDecoration(
                      labelText: s.t('Search customer', 'گراهڪ ڳوليو'),
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: IconButton(
                        tooltip: s.t('Voice search', 'آواز سان ڳولا'),
                        onPressed: () => _listen(commandMode: false),
                        icon: Icon(_listening ? Icons.mic : Icons.mic_none),
                      ),
                      border: const OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                IconButton(
                  tooltip: s.t('Voice command', 'آواز جو حڪم'),
                  onPressed: () => _listen(commandMode: true),
                  icon: const Icon(Icons.record_voice_over),
                ),
              ],
            ),
            if (_listening)
              Card(
                color: scheme.primaryContainer,
                child: ListTile(
                  leading: const Icon(Icons.mic),
                  title: Text(_heard.isEmpty
                      ? s.t('Listening… speak now', 'ٻڌي رهيو آهيان… ڳالهايو')
                      : _heard),
                  trailing: TextButton(
                    onPressed: _voice.stop,
                    child: Text(s.t('Done', 'ٿي ويو')),
                  ),
                ),
              ),
            if (_list.isNotEmpty && _search.text.isEmpty && s.backupOverdue)
              Card(
                color: scheme.tertiaryContainer,
                child: ListTile(
                  leading: const Icon(Icons.backup),
                  title: Text(s.lastBackup == null
                      ? s.t('No backup yet', 'اڃا بيڪ اپ ناهي')
                      : s.t('Last backup is over a week old',
                          'آخري بيڪ اپ هڪ هفتي کان پراڻو آهي')),
                  trailing: TextButton(
                    onPressed: _backup,
                    child: Text(s.t('Backup now', 'هاڻي بيڪ اپ ڪريو')),
                  ),
                ),
              ),
            const SizedBox(height: 10),
            Expanded(child: _buildList(s)),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _editCustomer(),
        icon: const Icon(Icons.person_add),
        label: Text(s.t('Customer', 'گراهڪ')),
      ),
    );
  }

  Widget _buildList(AppSettings s) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_list.isEmpty) {
      return Center(
        child: Text(
          _search.text.trim().isEmpty
              ? s.t('No customers yet. Tap "Customer" to add one.',
                  'اڃا ڪو گراهڪ ناهي. گراهڪ شامل ڪرڻ لاءِ "گراهڪ" دٻايو.')
              : s.t('No customer found', 'گراهڪ نه مليو'),
          textAlign: TextAlign.center,
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 88),
      itemCount: _list.length,
      itemBuilder: (_, i) {
        final item = _list[i];
        final c = item.customer;
        final parts = <String>[];
        if (c.phone.isNotEmpty) parts.add(c.phone);
        if (item.remaining > 0.005) {
          parts.add('${s.t('Remaining', 'باقي')}: ${fmtMoney(item.remaining)}');
        }
        return Card(
          child: ListTile(
            leading: CircleAvatar(
              child: Text(c.name.isEmpty ? '?' : c.name.characters.first),
            ),
            title: Text(c.name),
            subtitle: parts.isEmpty ? null : Text(parts.join('  •  ')),
            onTap: () => _openOrders(c),
            trailing: PopupMenuButton<String>(
              onSelected: (v) {
                switch (v) {
                  case 'measure':
                    _openMeasurements(c);
                  case 'orders':
                    _openOrders(c);
                  case 'edit':
                    _editCustomer(c);
                  case 'delete':
                    _deleteCustomer(c);
                }
              },
              itemBuilder: (_) => [
                PopupMenuItem(value: 'measure', child: Text(s.t('Measurements', 'ماپ'))),
                PopupMenuItem(value: 'orders', child: Text(s.t('Orders', 'آرڊر'))),
                PopupMenuItem(value: 'edit', child: Text(s.t('Edit', 'تبديل ڪريو'))),
                PopupMenuItem(value: 'delete', child: Text(s.t('Delete', 'ڊيليٽ'))),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _CustomerInput {
  final String name;
  final String phone;
  final String address;
  const _CustomerInput(this.name, this.phone, this.address);
}

class _CustomerDialog extends StatefulWidget {
  final Customer? existing;
  const _CustomerDialog({this.existing});

  @override
  State<_CustomerDialog> createState() => _CustomerDialogState();
}

class _CustomerDialogState extends State<_CustomerDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _phone;
  late final TextEditingController _address;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.existing?.name ?? '');
    _phone = TextEditingController(text: widget.existing?.phone ?? '');
    _address = TextEditingController(text: widget.existing?.address ?? '');
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _address.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    return AlertDialog(
      title: Text(widget.existing == null
          ? s.t('New Customer', 'نئون گراهڪ')
          : s.t('Edit Customer', 'گراهڪ تبديل ڪريو')),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _name,
                autofocus: true,
                textCapitalization: TextCapitalization.words,
                decoration: InputDecoration(labelText: s.t('Name', 'نالو')),
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? s.t('Name is required', 'نالو ضروري آهي')
                    : null,
              ),
              TextFormField(
                controller: _phone,
                keyboardType: TextInputType.phone,
                decoration: InputDecoration(labelText: s.t('Phone', 'فون')),
              ),
              TextFormField(
                controller: _address,
                decoration: InputDecoration(labelText: s.t('Address', 'پتو')),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(s.t('Cancel', 'منسوخ')),
        ),
        FilledButton(
          onPressed: () {
            if (_formKey.currentState!.validate()) {
              Navigator.pop(
                context,
                _CustomerInput(
                  _name.text.trim(),
                  _phone.text.trim(),
                  _address.text.trim(),
                ),
              );
            }
          },
          child: Text(s.t('Save', 'محفوظ ڪريو')),
        ),
      ],
    );
  }
}
