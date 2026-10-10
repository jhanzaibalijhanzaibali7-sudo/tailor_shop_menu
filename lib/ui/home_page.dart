
import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import 'profile_page.dart';
import '../app.dart';
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
  static const Color mainBrown = Color(0xFF6B4F3A);
  static const Color darkBrown = Color(0xFF4E342E);
  static const Color lightBrown = Color(0xFFF5EDE3);
  static const Color softBrown = Color(0xFFE8D8C8);

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

  // Navigation

  Future<void> _openOrders(Customer c) async {
    await Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) => OrdersPage(customer: c),
      ),
    );

    if (mounted) _load();
  }

  Future<void> _openMeasurements(Customer c) async {
    await Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) => MeasurementsPage(customer: c),
      ),
    );

    if (mounted) _load();
  }

  // Language selector

  Future<void> _pickAppLanguage() async {
    final s = AppScope.of(context);

    final picked = await showDialog<String>(
      context: context,
      builder: (ctx) => SimpleDialog(
        backgroundColor: lightBrown,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
        ),
        title: Text(
          s.t(
            'Choose app language',
            'ايپ جي ٻولي چونڊيو',
            'ایپ کی زبان منتخب کریں',
          ),
          style: const TextStyle(
            color: darkBrown,
            fontWeight: FontWeight.bold,
          ),
        ),
        children: [
          _languageOption(ctx, 'en', 'English', '🇬🇧', s.language),
          _languageOption(ctx, 'sd', 'سنڌي', '🇵🇰', s.language),
          _languageOption(ctx, 'ur', 'اردو', '🇵🇰', s.language),
        ],
      ),
    );

    if (picked != null) {
      await s.setLanguage(picked);
    }
  }

  Widget _languageOption(
    BuildContext ctx,
    String code,
    String label,
    String flag,
    String selectedLanguage,
  ) {
    return SimpleDialogOption(
      onPressed: () => Navigator.pop(ctx, code),
      child: Row(
        children: [
          Text(flag, style: const TextStyle(fontSize: 20)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                color: darkBrown,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          if (selectedLanguage == code)
            const Icon(Icons.check_circle, color: mainBrown),
        ],
      ),
    );
  }

  // Customers

  Future<void> _editCustomer([Customer? existing]) async {
    final input = await showDialog<_CustomerInput>(
      context: context,
      builder: (_) => _CustomerDialog(existing: existing),
    );

    if (input == null) return;

    if (existing == null) {
      await DB.instance.addCustomer(
        input.name,
        input.phone,
        input.address,
      );
    } else {
      await DB.instance.updateCustomer(
        existing.id,
        input.name,
        input.phone,
        input.address,
      );
    }

    if (mounted) _load();
  }

  Future<void> _deleteCustomer(Customer c) async {
    final s = AppScope.of(context);

    final ok = await confirmDialog(
      context,
      title: s.t(
        'Delete customer',
        'گراهڪ ڊيليٽ ڪريو',
        'گاہک حذف کریں',
      ),
      message: s.t(
        'Delete ${c.name} with all measurements, photos and orders? This cannot be undone.',
        '${c.name} کي سڀني ماپن، تصويرن ۽ آرڊرن سميت ڊيليٽ ڪجي؟ هي واپس نه ٿيندو.',
        'کیا ${c.name} کو تمام پیمائشوں، تصاویر اور آرڈرز سمیت حذف کرنا ہے؟ یہ عمل واپس نہیں ہو سکتا۔',
      ),
      confirmLabel: s.t('Delete', 'ڊيليٽ', 'حذف کریں'),
      destructive: true,
    );

    if (!ok || !mounted) return;

    await DB.instance.deleteCustomer(c.id);

    if (mounted) _load();
  }

  // Sign out

  Future<void> _signOut() async {
    final s = AppScope.of(context);

    final ok = await confirmDialog(
      context,
      title: s.t(
        'Sign Out',
        'سائن آئوٽ',
        'سائن آؤٹ',
      ),
      message: s.t(
        'Are you sure you want to sign out?',
        'ڇا توهان واقعي سائن آئوٽ ڪرڻ چاهيو ٿا؟',
        'کیا آپ واقعی سائن آؤٹ کرنا چاہتے ہیں؟',
      ),
      confirmLabel: s.t(
        'Sign Out',
        'سائن آئوٽ',
        'سائن آؤٹ',
      ),
      destructive: true,
    );

    if (!ok || !mounted) return;

    try {
      // Firebase authStateChanges will notify AuthGate.
      await FirebaseAuth.instance.signOut();

      if (!mounted) return;

      // Remove HomePage and WelcomePage from the navigation stack.
      // AuthGate is the root and will show SignupPage after sign-out.
      Navigator.of(context).popUntil((route) => route.isFirst);
    } catch (e) {
      if (!mounted) return;

      showSnack(
        context,
        '${s.t(
          'Sign out failed',
          'سائن آئوٽ ناڪام',
          'سائن آؤٹ ناکام',
        )}: $e',
      );
    }
  }

  // Voice search and commands

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
        if (mounted) {
          setState(() => _heard = w);
        }
      },
    );

    if (!mounted) return;

    setState(() => _listening = false);

    if (!result.ok) {
      showSnack(
        context,
        result.permissionDenied
            ? s.t(
                'Microphone permission is needed for voice.',
                'آواز لاءِ مائيڪروفون جي اجازت گهرجي.',
                'آواز کے لیے مائیکروفون کی اجازت درکار ہے۔',
              )
            : s.t(
                "Couldn't hear anything. Please try again.",
                'ڪجهه ٻڌي نه سگهيس. ٻيهر ڪوشش ڪريو.',
                'کچھ سنائی نہیں دیا۔ دوبارہ کوشش کریں۔',
              ),
      );
      return;
    }

    if (result.transcripts.isEmpty) {
      showSnack(
        context,
        s.t(
          "Couldn't hear anything. Please try again.",
          'ڪجهه ٻڌي نه سگهيس. ٻيهر ڪوشش ڪريو.',
          'کچھ سنائی نہیں دیا۔ دوبارہ کوشش کریں۔',
        ),
      );
      return;
    }

    final names = await DB.instance.customerNames();

    final refs = [
      for (final n in names) VoiceCustomerRef(n.id, n.name),
    ];

    final cmd = VoiceCommandParser.parseBest(
      result.transcripts,
      refs,
    );

    if (!mounted) return;

    if (!cmd.hasCustomer) {
      final words = cmd.leftover.isNotEmpty
          ? cmd.leftover.join(' ')
          : result.transcripts.first;

      _search.text = words;
      await _load();

      if (!mounted) return;

      showSnack(
        context,
        '${s.t(
          'Customer not found',
          'گراهڪ نه مليو',
          'گاہک نہیں ملا',
        )}: ${result.transcripts.first}',
      );
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
        break;

      case VoiceIntent.showBalance:
        await showBalanceSheet(context, customer);
        break;

      case VoiceIntent.openOrders:
      case VoiceIntent.none:
        await _openOrders(customer);
        break;
    }
  }

  Future<VoiceCustomerRef?> _chooseCustomer(
    List<VoiceMatch> matches,
  ) {
    final s = AppScope.of(context);

    return showDialog<VoiceCustomerRef>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: Text(
          s.t(
            'Which customer?',
            'ڪهڙو گراهڪ؟',
            'کون سا گاہک؟',
          ),
        ),
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

  // Voice language selector

  Future<void> _pickVoiceLanguage() async {
    final s = AppScope.of(context);

    final options = <String, String>{
      'auto': s.t(
        'Automatic (recommended)',
        'خودڪار (بهتر)',
        'خودکار (تجویز کردہ)',
      ),
      'sd': 'سنڌي (Sindhi)',
      'ur': 'اردو (Urdu)',
      'hi': 'हिन्दी (Hindi)',
      'en': 'English',
    };

    final picked = await showDialog<String>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: Text(
          s.t(
            'Voice recognition language',
            'آواز سڃاڻڻ جي ٻولي',
            'آواز پہچاننے کی زبان',
          ),
        ),
        children: [
          for (final e in options.entries)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(ctx, e.key),
              child: Row(
                children: [
                  Expanded(child: Text(e.value)),
                  if (s.voiceLang == e.key)
                    const Icon(Icons.check, color: mainBrown),
                ],
              ),
            ),
        ],
      ),
    );

    if (picked != null) {
      await s.setVoiceLang(picked);
    }
  }

  void _showVoiceHelp() {
    final s = AppScope.of(context);

    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          s.t(
            'Voice commands',
            'آواز جا حڪم',
            'آواز کے احکامات',
          ),
        ),
        content: const SingleChildScrollView(
          child: Directionality(
            textDirection: TextDirection.ltr,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Measurement / ماپ',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                Text(
                  '"Jahanzeb ji maap"\n'
                  '"Jahanzeb ji maap dikha"\n'
                  '"Ahmed ji measurement"\n'
                  '"Ahmed ka measurement dikhao"\n'
                  '"جهانزيب جي ماپ"',
                ),
                SizedBox(height: 12),
                Text(
                  'Order / آرڊر',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                Text(
                  '"Jahanzeb jo order kholo"\n'
                  '"Salman jo order kholo"\n'
                  '"Jahanzeb ka order kholo"\n'
                  '"سلمان جو آرڊر ڪولو"',
                ),
                SizedBox(height: 12),
                Text(
                  'Balance / باقي',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                Text(
                  '"Jahanzeb te ketro paiso baqi aa"\n'
                  '"Salman ka kitna paisa baqi hai"\n'
                  '"جهانزيب تي ڪيترو پيسو باقي آهي"',
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(s.t('Close', 'بند', 'بند کریں')),
          ),
        ],
      ),
    );
  }

  // Backup / restore

  Future<void> _backup() async {
    final s = AppScope.of(context);

    try {
      final dir = await getTemporaryDirectory();
      final file = await BackupService.createBackup(dir: dir);

      final result = await Share.shareXFiles(
        [XFile(file.path)],
        text: s.t(
          'Tailor shop backup',
          'درزي دڪان جو بيڪ اپ',
          'ٹیلر شاپ بیک اپ',
        ),
      );

      if (result.status != ShareResultStatus.dismissed) {
        await s.markBackup();
      }
    } catch (e) {
      if (mounted) {
        showSnack(
          context,
          '${s.t(
            'Backup failed',
            'بيڪ اپ ناڪام',
            'بیک اپ ناکام',
          )}: $e',
        );
      }
    }
  }

  Future<void> _restore() async {
    final s = AppScope.of(context);

    final picked = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json'],
    );

    if (picked == null || picked.files.isEmpty) return;

    final path = picked.files.first.path;

    if (path == null || !mounted) return;

    final ok = await confirmDialog(
      context,
      title: s.t(
        'Restore backup',
        'بيڪ اپ بحال ڪريو',
        'بیک اپ بحال کریں',
      ),
      message: s.t(
        'All current customers, measurements, photos and orders will be replaced by the backup. A safety copy of the current data is saved first. Continue?',
        'موجوده سڀ گراهڪ، ماپون، تصويرون ۽ آرڊر بيڪ اپ سان مٽجي ويندا. پهرين موجوده ڊيٽا جي حفاظتي ڪاپي محفوظ ٿيندي. اڳتي هلون؟',
        'تمام موجودہ گاہک، پیمائشیں، تصاویر اور آرڈرز بیک اپ سے بدل جائیں گے۔ پہلے موجودہ ڈیٹا کی حفاظتی کاپی بنائی جائے گی۔ کیا جاری رکھیں؟',
      ),
      confirmLabel: s.t(
        'Restore',
        'بحال ڪريو',
        'بحال کریں',
      ),
      destructive: true,
    );

    if (!ok || !mounted) return;

    try {
      final autoDir = await BackupService.autoBackupDir();

      await BackupService.createBackup(
        dir: autoDir,
        prefix: 'pre_restore',
      );

      await BackupService.pruneAutoBackups(autoDir);

      final r = await BackupService.restore(File(path));

      await _load();

      if (!mounted) return;

      showSnack(
        context,
        '${s.t(
          'Restore complete',
          'بحالي مڪمل ٿي وئي',
          'بحالی مکمل ہوگئی',
        )}: '
        '${r.customers} ${s.t('customers', 'گراهڪ', 'گاہک')}, '
        '${r.orders} ${s.t('orders', 'آرڊر', 'آرڈرز')}, '
        '${r.photos} ${s.t('photos', 'تصويرون', 'تصاویر')}',
      );
    } on FormatException catch (e) {
      if (mounted) {
        showSnack(
          context,
          '${s.t(
            'Restore failed',
            'بحالي ناڪام',
            'بحالی ناکام',
          )}: '
          '${s.t(
            'this is not a valid backup file',
            'هيءَ صحيح بيڪ اپ فائل ناهي',
            'یہ درست بیک اپ فائل نہیں ہے',
          )} (${e.message})',
        );
      }
    } catch (e) {
      if (mounted) {
        showSnack(
          context,
          '${s.t(
            'Restore failed',
            'بحالي ناڪام',
            'بحالی ناکام',
          )}: $e',
        );
      }
    }
  }

  // Menu item design

  Widget _modernMenuItem({
    required IconData icon,
    required String title,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: softBrown,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: mainBrown, size: 21),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              color: darkBrown,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  // Build

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final isLoggedIn = FirebaseAuth.instance.currentUser != null;

    return Scaffold(
      backgroundColor: lightBrown,
      appBar: AppBar(
        backgroundColor: darkBrown,
        foregroundColor: Colors.white,
        elevation: 2,
        centerTitle: true,
        title: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.content_cut_rounded, size: 25),
            SizedBox(width: 9),
            Text(
              'Tailor Shop',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 22,
                letterSpacing: 0.3,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: s.t(
              'App language',
              'ايپ جي ٻولي',
              'ایپ کی زبان',
            ),
            onPressed: _pickAppLanguage,
            icon: const Icon(Icons.translate_rounded),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 10),
            child: PopupMenuButton<String>(
              tooltip: s.t('Menu', 'مينيو', 'مینو'),
              offset: const Offset(0, 8),
              elevation: 8,
              color: lightBrown,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
              icon: const Icon(
                Icons.menu_rounded,
                color: Colors.white,
                size: 28,
              ),
              style: IconButton.styleFrom(
                backgroundColor: mainBrown,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.all(9),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onSelected: (v) {
                switch (v) {
                  case 'profile':
                    Navigator.push(
                      context,
                      MaterialPageRoute<void>(
                        builder: (_) => const ProfilePage(),
                      ),
                    );
                    break;

                  case 'backup':
                    _backup();
                    break;

                  case 'restore':
                    _restore();
                    break;

                  case 'reports':
                    Navigator.push(
                      context,
                      MaterialPageRoute<void>(
                        builder: (_) => const ReportsPage(),
                      ),
                    );
                    break;

                  case 'voice_lang':
                    _pickVoiceLanguage();
                    break;

                  case 'voice_help':
                    _showVoiceHelp();
                    break;

                  case 'sign_out':
                    _signOut();
                    break;

                  case 'sign_in':
                    // Return to AuthGate. It displays SignupPage
                    // when Firebase has no signed-in user.
                    Navigator.of(context).popUntil(
                      (route) => route.isFirst,
                    );
                    break;

                  case 'app_language':
                    _pickAppLanguage();
                    break;
                }
              },
              itemBuilder: (_) => [
                PopupMenuItem<String>(
                  enabled: false,
                  height: 65,
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: mainBrown,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.content_cut_rounded,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          s.t(
                            'Tailor Shop',
                            'درزي جو دڪان',
                            'ٹیلر شاپ',
                          ),
                          style: const TextStyle(
                            color: darkBrown,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const PopupMenuDivider(),
                PopupMenuItem<String>(
                  value: 'app_language',
                  child: _modernMenuItem(
                    icon: Icons.translate_rounded,
                    title: s.t(
                      'App language',
                      'ايپ جي ٻولي',
                      'ایپ کی زبان',
                    ),
                  ),
                ),
                PopupMenuItem<String>(
                  value: 'profile',
                  child: _modernMenuItem(
                    icon: Icons.person_rounded,
                    title: s.t(
                      'Profile',
                      'پروفائل',
                      'پروفائل',
                    ),
                  ),
                ),
                PopupMenuItem<String>(
                  value: 'reports',
                  child: _modernMenuItem(
                    icon: Icons.bar_chart_rounded,
                    title: s.t(
                      'Reports',
                      'رپورٽون',
                      'رپورٹس',
                    ),
                  ),
                ),
                PopupMenuItem<String>(
                  value: 'backup',
                  child: _modernMenuItem(
                    icon: Icons.cloud_upload_rounded,
                    title: s.t(
                      'Backup',
                      'بيڪ اپ',
                      'بیک اپ',
                    ),
                  ),
                ),
                PopupMenuItem<String>(
                  value: 'restore',
                  child: _modernMenuItem(
                    icon: Icons.cloud_download_rounded,
                    title: s.t(
                      'Restore',
                      'بحال ڪريو',
                      'بحال کریں',
                    ),
                  ),
                ),
                PopupMenuItem<String>(
                  enabled: false,
                  height: 52,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: softBrown,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.history_rounded,
                          size: 20,
                          color: darkBrown,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '${s.t(
                              'Last backup',
                              'آخري بيڪ اپ',
                              'آخری بیک اپ',
                            )}: '
                            '${s.lastBackup == null ? s.t('never', 'ڪڏهن به نه', 'ابھی تک نہیں') : fmtDate(s.lastBackup)}',
                            style: const TextStyle(
                              color: darkBrown,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const PopupMenuDivider(),
                PopupMenuItem<String>(
                  value: 'voice_help',
                  child: _modernMenuItem(
                    icon: Icons.record_voice_over_rounded,
                    title: s.t(
                      'Voice commands',
                      'آواز جا حڪم',
                      'آواز کے احکامات',
                    ),
                  ),
                ),
                PopupMenuItem<String>(
                  value: 'voice_lang',
                  child: _modernMenuItem(
                    icon: Icons.language_rounded,
                    title: s.t(
                      'Voice language',
                      'آواز جي ٻولي',
                      'آواز کی زبان',
                    ),
                  ),
                ),
                const PopupMenuDivider(),
                PopupMenuItem<String>(
                  value: isLoggedIn ? 'sign_out' : 'sign_in',
                  child: _modernMenuItem(
                    icon: isLoggedIn
                        ? Icons.logout_rounded
                        : Icons.login_rounded,
                    title: isLoggedIn
                        ? s.t(
                            'Sign Out',
                            'سائن آئوٽ',
                            'سائن آؤٹ',
                          )
                        : s.t(
                            'Sign In',
                            'سائن اِن',
                            'سائن اِن',
                          ),
                  ),
                ),
              ],
            ),
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
                    cursorColor: mainBrown,
                    decoration: InputDecoration(
                      labelText: s.t(
                        'Search customer',
                        'گراهڪ ڳوليو',
                        'گاہک تلاش کریں',
                      ),
                      labelStyle: const TextStyle(color: darkBrown),
                      prefixIcon: const Icon(
                        Icons.search,
                        color: mainBrown,
                      ),
                      suffixIcon: IconButton(
                        tooltip: s.t(
                          'Voice search',
                          'آواز سان ڳولا',
                          'آواز سے تلاش',
                        ),
                        onPressed: () => _listen(commandMode: false),
                        icon: Icon(
                          _listening ? Icons.mic : Icons.mic_none,
                          color: mainBrown,
                        ),
                      ),
                      filled: true,
                      fillColor: Colors.white,
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(
                          color: mainBrown,
                          width: 2,
                        ),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(
                          color: mainBrown.withValues(alpha: 0.35),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                IconButton(
                  tooltip: s.t(
                    'Voice command',
                    'آواز جو حڪم',
                    'آواز کا حکم',
                  ),
                  onPressed: () => _listen(commandMode: true),
                  style: IconButton.styleFrom(
                    backgroundColor: mainBrown,
                    foregroundColor: Colors.white,
                  ),
                  icon: const Icon(Icons.record_voice_over),
                ),
              ],
            ),
            if (_listening)
              Card(
                color: softBrown,
                elevation: 1,
                child: ListTile(
                  leading: const Icon(Icons.mic, color: darkBrown),
                  title: Text(
                    _heard.isEmpty
                        ? s.t(
                            'Listening… speak now',
                            'ٻڌي رهيو آهيان… ڳالهايو',
                            'سن رہا ہوں… بولیں',
                          )
                        : _heard,
                    style: const TextStyle(color: darkBrown),
                  ),
                  trailing: TextButton(
                    style: TextButton.styleFrom(
                      foregroundColor: mainBrown,
                    ),
                    onPressed: _voice.stop,
                    child: Text(
                      s.t('Done', 'ٿي ويو', 'ہو گیا'),
                    ),
                  ),
                ),
              ),
            if (_list.isNotEmpty &&
                _search.text.isEmpty &&
                s.backupOverdue)
              Card(
                color: softBrown,
                elevation: 1,
                child: ListTile(
                  leading: const Icon(
                    Icons.backup,
                    color: darkBrown,
                  ),
                  title: Text(
                    s.lastBackup == null
                        ? s.t(
                            'No backup yet',
                            'اڃا بيڪ اپ ناهي',
                            'ابھی بیک اپ نہیں ہے',
                          )
                        : s.t(
                            'Last backup is over a week old',
                            'آخري بيڪ اپ هڪ هفتي کان پراڻو آهي',
                            'آخری بیک اپ کو ایک ہفتے سے زیادہ ہو گیا ہے',
                          ),
                    style: const TextStyle(
                      color: darkBrown,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  trailing: TextButton(
                    style: TextButton.styleFrom(
                      foregroundColor: mainBrown,
                    ),
                    onPressed: _backup,
                    child: Text(
                      s.t(
                        'Backup now',
                        'هاڻي بيڪ اپ ڪريو',
                        'ابھی بیک اپ کریں',
                      ),
                    ),
                  ),
                ),
              ),
            const SizedBox(height: 10),
            Expanded(child: _buildList(s)),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: mainBrown,
        foregroundColor: Colors.white,
        elevation: 4,
        onPressed: () => _editCustomer(),
        icon: const Icon(Icons.person_add),
        label: Text(
          s.t('Customer', 'گراهڪ', 'گاہک'),
        ),
      ),
    );
  }

  // Customer list

  Widget _buildList(AppSettings s) {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(color: mainBrown),
      );
    }

    if (_list.isEmpty) {
      return Center(
        child: Text(
          _search.text.trim().isEmpty
              ? s.t(
                  'No customers yet. Tap "Customer" to add one.',
                  'اڃا ڪو گراهڪ ناهي. گراهڪ شامل ڪرڻ لاءِ "گراهڪ" دٻايو.',
                  'ابھی کوئی گاہک نہیں۔ شامل کرنے کے لیے "گاہک" دبائیں۔',
                )
              : s.t(
                  'No customer found',
                  'گراهڪ نه مليو',
                  'کوئی گاہک نہیں ملا',
                ),
          textAlign: TextAlign.center,
          style: const TextStyle(color: darkBrown),
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

        if (c.phone.isNotEmpty) {
          parts.add(c.phone);
        }

        if (item.remaining > 0.005) {
          parts.add(
            '${s.t(
              'Remaining',
              'باقي',
              'باقی',
            )}: ${fmtMoney(item.remaining)}',
          );
        }

        return Card(
          color: Colors.white,
          elevation: 2,
          margin: const EdgeInsets.symmetric(vertical: 5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(
              color: mainBrown.withValues(alpha: 0.15),
            ),
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 4,
            ),
            leading: CircleAvatar(
              backgroundColor: mainBrown,
              foregroundColor: Colors.white,
              child: Text(
                c.name.isEmpty ? '?' : c.name.characters.first,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            title: Text(
              c.name,
              style: const TextStyle(
                color: darkBrown,
                fontWeight: FontWeight.w600,
              ),
            ),
            subtitle: parts.isEmpty
                ? null
                : Text(
                    parts.join('  •  '),
                    style: const TextStyle(
                      color: Color(0xFF795548),
                    ),
                  ),
            onTap: () => _openOrders(c),
            trailing: PopupMenuButton<String>(
              tooltip: s.t(
                'Customer options',
                'گراهڪ جا آپشن',
                'گاہک کے اختیارات',
              ),
              offset: const Offset(-8, 8),
              elevation: 8,
              color: lightBrown,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
              icon: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: softBrown,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.more_vert_rounded,
                  color: mainBrown,
                  size: 24,
                ),
              ),
              onSelected: (v) {
                switch (v) {
                  case 'measure':
                    _openMeasurements(c);
                    break;

                  case 'orders':
                    _openOrders(c);
                    break;

                  case 'edit':
                    _editCustomer(c);
                    break;

                  case 'delete':
                    _deleteCustomer(c);
                    break;
                }
              },
              itemBuilder: (_) => [
                PopupMenuItem<String>(
                  enabled: false,
                  height: 62,
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(9),
                        decoration: BoxDecoration(
                          color: mainBrown,
                          borderRadius: BorderRadius.circular(11),
                        ),
                        child: const Icon(
                          Icons.person_rounded,
                          color: Colors.white,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          c.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: darkBrown,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const PopupMenuDivider(),
                PopupMenuItem<String>(
                  value: 'measure',
                  child: _customerMenuItem(
                    icon: Icons.straighten_rounded,
                    title: s.t(
                      'Measurements',
                      'ماپ',
                      'پیمائشیں',
                    ),
                  ),
                ),
                PopupMenuItem<String>(
                  value: 'orders',
                  child: _customerMenuItem(
                    icon: Icons.receipt_long_rounded,
                    title: s.t(
                      'Orders',
                      'آرڊر',
                      'آرڈرز',
                    ),
                  ),
                ),
                PopupMenuItem<String>(
                  value: 'edit',
                  child: _customerMenuItem(
                    icon: Icons.edit_rounded,
                    title: s.t(
                      'Edit',
                      'تبديل ڪريو',
                      'ترمیم کریں',
                    ),
                  ),
                ),
                PopupMenuItem<String>(
                  value: 'delete',
                  child: _customerMenuItem(
                    icon: Icons.delete_outline_rounded,
                    title: s.t(
                      'Delete',
                      'ڊيليٽ',
                      'حذف کریں',
                    ),
                    delete: true,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _customerMenuItem({
    required IconData icon,
    required String title,
    bool delete = false,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: delete
                ? const Color(0xFFF2D6D2)
                : softBrown,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            icon,
            color: delete
                ? const Color(0xFFB3261E)
                : mainBrown,
            size: 21,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            title,
            style: TextStyle(
              color: delete
                  ? const Color(0xFFB3261E)
                  : darkBrown,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

// Customer input

class _CustomerInput {
  final String name;
  final String phone;
  final String address;

  const _CustomerInput(
    this.name,
    this.phone,
    this.address,
  );
}

// Customer dialog

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

  static const Color mainBrown = Color(0xFF6B4F3A);
  static const Color darkBrown = Color(0xFF4E342E);

  @override
  void initState() {
    super.initState();

    _name = TextEditingController(
      text: widget.existing?.name ?? '',
    );
    _phone = TextEditingController(
      text: widget.existing?.phone ?? '',
    );
    _address = TextEditingController(
      text: widget.existing?.address ?? '',
    );
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
      title: Text(
        widget.existing == null
            ? s.t(
                'New Customer',
                'نئون گراهڪ',
                'نیا گاہک',
              )
            : s.t(
                'Edit Customer',
                'گراهڪ تبديل ڪريو',
                'گاہک میں ترمیم کریں',
              ),
        style: const TextStyle(
          color: darkBrown,
          fontWeight: FontWeight.bold,
        ),
      ),
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
                cursorColor: mainBrown,
                decoration: InputDecoration(
                  labelText: s.t(
                    'Name',
                    'نالو',
                    'نام',
                  ),
                  labelStyle: const TextStyle(
                    color: darkBrown,
                  ),
                  focusedBorder: const UnderlineInputBorder(
                    borderSide: BorderSide(
                      color: mainBrown,
                      width: 2,
                    ),
                  ),
                ),
                validator: (v) =>
                    (v == null || v.trim().isEmpty)
                        ? s.t(
                            'Name is required',
                            'نالو ضروري آهي',
                            'نام ضروری ہے',
                          )
                        : null,
              ),
              TextFormField(
                controller: _phone,
                keyboardType: TextInputType.phone,
                cursorColor: mainBrown,
                decoration: InputDecoration(
                  labelText: s.t(
                    'Phone',
                    'فون',
                    'فون',
                  ),
                  labelStyle: const TextStyle(
                    color: darkBrown,
                  ),
                  focusedBorder: const UnderlineInputBorder(
                    borderSide: BorderSide(
                      color: mainBrown,
                      width: 2,
                    ),
                  ),
                ),
              ),
              TextFormField(
                controller: _address,
                cursorColor: mainBrown,
                decoration: InputDecoration(
                  labelText: s.t(
                    'Address',
                    'پتو',
                    'پتہ',
                  ),
                  labelStyle: const TextStyle(
                    color: darkBrown,
                  ),
                  focusedBorder: const UnderlineInputBorder(
                    borderSide: BorderSide(
                      color: mainBrown,
                      width: 2,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          style: TextButton.styleFrom(
            foregroundColor: mainBrown,
          ),
          onPressed: () => Navigator.pop(context),
          child: Text(
            s.t('Cancel', 'منسوخ', 'منسوخ کریں'),
          ),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: mainBrown,
            foregroundColor: Colors.white,
          ),
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
          child: Text(
            s.t('Save', 'محفوظ ڪريو', 'محفوظ کریں'),
          ),
        ),
      ],
    );
  }
}
