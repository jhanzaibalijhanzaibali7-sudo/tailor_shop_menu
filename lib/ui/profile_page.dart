
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../app.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final ImagePicker _imagePicker = ImagePicker();

  late TextEditingController _nameController;
  late TextEditingController _shopController;
  late TextEditingController _phoneController;

  String? _profileImagePath;
  bool _saving = false;
  bool _loading = true;
  bool _editingInformation = false;

  String _t(String en, String sd, [String? ur]) {
    return AppScope.of(context).t(en, sd, ur);
  }

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _shopController = TextEditingController();
    _phoneController = TextEditingController();
    _loadProfile();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _shopController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    final user = _auth.currentUser;

    if (user == null) {
      if (mounted) setState(() => _loading = false);
      return;
    }

    try {
      final doc = await _firestore.collection('users').doc(user.uid).get();
      final prefs = await SharedPreferences.getInstance();

      if (!mounted) return;

      setState(() {
        _nameController.text =
            doc.data()?['fullName']?.toString() ??
            user.displayName ??
            '';
        _shopController.text =
            doc.data()?['shopName']?.toString() ?? '';
        _phoneController.text =
            doc.data()?['phone']?.toString() ?? '';
        _profileImagePath = prefs.getString('profile_image_path');
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
      _showMessage(_t(
        'Could not load profile. Please try again.',
        'پروفائل لوڊ نه ٿي سگهيو. ٻيهر ڪوشش ڪريو.',
        'پروفائل لوڈ نہیں ہو سکی۔ دوبارہ کوشش کریں۔',
      ));
    }
  }

  Future<void> _pickProfileImage() async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 80,
      );

      if (image == null) return;

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('profile_image_path', image.path);

      if (!mounted) return;
      setState(() => _profileImagePath = image.path);
    } catch (_) {
      _showMessage(_t(
        'Could not select photo. Please try again.',
        'تصوير چونڊي نه سگهجي. ٻيهر ڪوشش ڪريو.',
        'تصویر منتخب نہیں ہو سکی۔ دوبارہ کوشش کریں۔',
      ));
    }
  }

  Future<void> _saveProfile() async {
    final user = _auth.currentUser;
    if (user == null) return;

    final name = _nameController.text.trim();
    final shopName = _shopController.text.trim();
    final phone = _phoneController.text.trim();

    if (name.isEmpty) {
      _showMessage(_t(
        'Please enter your full name.',
        'مهرباني ڪري پنهنجو پورو نالو لکو.',
        'براہ کرم اپنا پورا نام درج کریں۔',
      ));
      return;
    }

    setState(() => _saving = true);

    try {
      await user.updateDisplayName(name);

      await _firestore.collection('users').doc(user.uid).set(
        {
          'fullName': name,
          'email': user.email ?? '',
          'shopName': shopName,
          'phone': phone,
          'photoUrl': null,
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );

      await user.reload();

      if (!mounted) return;

      setState(() {
        _saving = false;
        _editingInformation = false;
      });

      _showMessage(_t(
        'Profile saved successfully.',
        'پروفائل ڪاميابي سان محفوظ ٿي وئي.',
        'پروفائل کامیابی سے محفوظ ہو گئی۔',
      ));
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      _showMessage(_t(
        'Could not save profile. Please try again.',
        'پروفائل محفوظ نه ٿي. ٻيهر ڪوشش ڪريو.',
        'پروفائل محفوظ نہیں ہو سکی۔ دوبارہ کوشش کریں۔',
      ));
    }
  }

  Future<void> _showChangePasswordDialog() async {
    final currentController = TextEditingController();
    final newController = TextEditingController();
    final confirmController = TextEditingController();

    bool obscureCurrent = true;
    bool obscureNew = true;
    bool obscureConfirm = true;
    bool changing = false;

    try {
      await showDialog(
        context: context,
        builder: (dialogContext) {
          return StatefulBuilder(
            builder: (context, setDialogState) {
              Future<void> changePassword() async {
                final user = _auth.currentUser;
                if (user == null) return;

                final current = currentController.text.trim();
                final newPassword = newController.text.trim();
                final confirm = confirmController.text.trim();

                if (current.isEmpty ||
                    newPassword.isEmpty ||
                    confirm.isEmpty) {
                  _showMessage(_t(
                    'Please fill all password fields.',
                    'پاسورڊ جا سڀ خانا ڀريو.',
                    'براہ کرم پاس ورڈ کے تمام خانے پُر کریں۔',
                  ));
                  return;
                }

                if (newPassword.length < 6) {
                  _showMessage(_t(
                    'New password must be at least 6 characters.',
                    'نئون پاسورڊ گهٽ ۾ گهٽ 6 اکرن جو هجي.',
                    'نیا پاس ورڈ کم از کم 6 حروف کا ہونا چاہیے۔',
                  ));
                  return;
                }

                if (newPassword != confirm) {
                  _showMessage(_t(
                    'New passwords do not match.',
                    'نوان پاسورڊ هڪجهڙا ناهن.',
                    'نئے پاس ورڈ ایک جیسے نہیں ہیں۔',
                  ));
                  return;
                }

                setDialogState(() => changing = true);

                try {
                  final email = user.email;
                  if (email == null || email.isEmpty) {
                    throw FirebaseAuthException(code: 'no-email');
                  }

                  final credential = EmailAuthProvider.credential(
                    email: email,
                    password: current,
                  );

                  await user.reauthenticateWithCredential(credential);
                  await user.updatePassword(newPassword);

                  if (!mounted) return;
                  Navigator.of(dialogContext).pop();

                  _showMessage(_t(
                    'Password changed successfully.',
                    'پاسورڊ ڪاميابي سان تبديل ٿيو.',
                    'پاس ورڈ کامیابی سے تبدیل ہو گیا۔',
                  ));
                } on FirebaseAuthException catch (e) {
                  setDialogState(() => changing = false);

                  String message;
                  if (e.code == 'wrong-password' ||
                      e.code == 'invalid-credential') {
                    message = _t(
                      'Current password is incorrect.',
                      'موجوده پاسورڊ غلط آهي.',
                      'موجودہ پاس ورڈ غلط ہے۔',
                    );
                  } else if (e.code == 'weak-password') {
                    message = _t(
                      'New password is too weak.',
                      'نئون پاسورڊ ڪمزور آهي.',
                      'نیا پاس ورڈ کمزور ہے۔',
                    );
                  } else if (e.code == 'requires-recent-login') {
                    message = _t(
                      'Please sign in again and try changing the password.',
                      'ٻيهر لاگ ان ڪري پاسورڊ تبديل ڪريو.',
                      'دوبارہ لاگ اِن کریں اور پاس ورڈ تبدیل کریں۔',
                    );
                  } else {
                    message = _t(
                      'Could not change password. Please try again.',
                      'پاسورڊ تبديل نه ٿي سگهيو. ٻيهر ڪوشش ڪريو.',
                      'پاس ورڈ تبدیل نہیں ہو سکا۔ دوبارہ کوشش کریں۔',
                    );
                  }

                  _showMessage(message);
                } catch (_) {
                  setDialogState(() => changing = false);
                  _showMessage(_t(
                    'Could not change password. Please try again.',
                    'پاسورڊ تبديل نه ٿي سگهيو. ٻيهر ڪوشش ڪريو.',
                    'پاس ورڈ تبدیل نہیں ہو سکا۔ دوبارہ کوشش کریں۔',
                  ));
                }
              }

              Widget passwordField({
                required TextEditingController controller,
                required String label,
                required bool obscure,
                required VoidCallback toggle,
              }) {
                return TextField(
                  controller: controller,
                  obscureText: obscure,
                  enabled: !changing,
                  decoration: InputDecoration(
                    labelText: label,
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      onPressed: changing ? null : toggle,
                      icon: Icon(
                        obscure ? Icons.visibility : Icons.visibility_off,
                      ),
                    ),
                  ),
                );
              }

              return AlertDialog(
                title: Text(
                  _t('Change Password', 'پاسورڊ تبديل ڪريو', 'پاس ورڈ تبدیل کریں'),
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                content: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      passwordField(
                        controller: currentController,
                        label: _t('Current Password', 'موجوده پاسورڊ', 'موجودہ پاس ورڈ'),
                        obscure: obscureCurrent,
                        toggle: () => setDialogState(
                          () => obscureCurrent = !obscureCurrent,
                        ),
                      ),
                      const SizedBox(height: 15),
                      passwordField(
                        controller: newController,
                        label: _t('New Password', 'نئون پاسورڊ', 'نیا پاس ورڈ'),
                        obscure: obscureNew,
                        toggle: () => setDialogState(
                          () => obscureNew = !obscureNew,
                        ),
                      ),
                      const SizedBox(height: 15),
                      passwordField(
                        controller: confirmController,
                        label: _t(
                          'Confirm New Password',
                          'نئون پاسورڊ ٻيهر لکو',
                          'نیا پاس ورڈ دوبارہ درج کریں',
                        ),
                        obscure: obscureConfirm,
                        toggle: () => setDialogState(
                          () => obscureConfirm = !obscureConfirm,
                        ),
                      ),
                    ],
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: changing
                        ? null
                        : () => Navigator.of(dialogContext).pop(),
                    child: Text(_t('Cancel', 'رد ڪريو', 'منسوخ کریں')),
                  ),
                  ElevatedButton(
                    onPressed: changing ? null : changePassword,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF6D4228),
                      foregroundColor: Colors.white,
                    ),
                    child: changing
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Text(_t(
                            'Change Password',
                            'پاسورڊ تبديل ڪريو',
                            'پاس ورڈ تبدیل کریں',
                          )),
                  ),
                ],
              );
            },
          );
        },
      );
    } finally {
      currentController.dispose();
      newController.dispose();
      confirmController.dispose();
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Widget _editableField({
    required IconData icon,
    required String label,
    required TextEditingController controller,
    TextInputType? keyboardType,
  }) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 14),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        child: TextField(
          controller: controller,
          keyboardType: keyboardType,
          enabled: _editingInformation,
          decoration: InputDecoration(
            border: InputBorder.none,
            icon: Icon(icon, color: const Color(0xFF7A4A2A)),
            labelText: label,
            labelStyle: const TextStyle(
              color: Color(0xFF7A4A2A),
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }

  Widget _readOnlyField({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 14),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 4,
        ),
        leading: Icon(icon, color: const Color(0xFF7A4A2A)),
        title: Text(
          label,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            color: Color(0xFF7A4A2A),
          ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 5),
          child: Text(
            value,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = _auth.currentUser;
    final email = user?.email ?? _t('No email', 'اي ميل ناهي', 'ای میل نہیں');
    final userId = user?.uid ?? _t('No User ID', 'يوزر آءِ ڊي ناهي', 'یوزر آئی ڈی نہیں');

    final hasProfileImage = _profileImagePath != null &&
        File(_profileImagePath!).existsSync();

    return Scaffold(
      backgroundColor: const Color(0xFFF8F1E7),
      appBar: AppBar(
        title: Text(
          _t('Profile', 'پروفائل', 'پروفائل'),
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        backgroundColor: const Color(0xFF6D4228),
        foregroundColor: Colors.white,
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(
                color: Color(0xFF6D4228),
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  const SizedBox(height: 10),
                  GestureDetector(
                    onTap: _pickProfileImage,
                    child: Stack(
                      alignment: Alignment.bottomRight,
                      children: [
                        CircleAvatar(
                          radius: 62,
                          backgroundColor: const Color(0xFF7A4A2A),
                          backgroundImage: hasProfileImage
                              ? FileImage(File(_profileImagePath!))
                              : null,
                          child: !hasProfileImage
                              ? const Icon(
                                  Icons.person,
                                  size: 68,
                                  color: Colors.white,
                                )
                              : null,
                        ),
                        Container(
                          padding: const EdgeInsets.all(9),
                          decoration: BoxDecoration(
                            color: const Color(0xFF6D4228),
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2),
                          ),
                          child: const Icon(
                            Icons.camera_alt,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    _t(
                      'Tap photo to change',
                      'تصوير تبديل ڪرڻ لاءِ دٻايو',
                      'تصویر تبدیل کرنے کے لیے ٹیپ کریں',
                    ),
                    style: const TextStyle(color: Colors.brown, fontSize: 13),
                  ),
                  const SizedBox(height: 25),

                  _readOnlyField(
                    icon: Icons.badge_outlined,
                    label: _t('User ID', 'يوزر آءِ ڊي', 'یوزر آئی ڈی'),
                    value: userId,
                  ),
                  _readOnlyField(
                    icon: Icons.email_outlined,
                    label: _t('Email', 'اي ميل', 'ای میل'),
                    value: email,
                  ),
                  const SizedBox(height: 10),

                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () {
                        setState(() {
                          _editingInformation = !_editingInformation;
                        });
                      },
                      icon: Icon(
                        _editingInformation ? Icons.close : Icons.edit_outlined,
                      ),
                      label: Text(
                        _editingInformation
                            ? _t('Cancel Edit', 'تبديلي رد ڪريو', 'ترمیم منسوخ کریں')
                            : _t('Edit Information', 'معلومات تبديل ڪريو', 'معلومات میں ترمیم کریں'),
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF6D4228),
                        side: const BorderSide(color: Color(0xFF6D4228)),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),

                  _editableField(
                    icon: Icons.person_outline,
                    label: _t('Full Name', 'پورو نالو', 'پورا نام'),
                    controller: _nameController,
                  ),
                  _editableField(
                    icon: Icons.store_outlined,
                    label: _t('Shop Name', 'دڪان جو نالو', 'دکان کا نام'),
                    controller: _shopController,
                  ),
                  _editableField(
                    icon: Icons.phone_outlined,
                    label: _t('Phone Number', 'فون نمبر', 'فون نمبر'),
                    controller: _phoneController,
                    keyboardType: TextInputType.phone,
                  ),

                  if (_editingInformation) ...[
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      height: 54,
                      child: ElevatedButton.icon(
                        onPressed: _saving ? null : _saveProfile,
                        icon: _saving
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.save_outlined),
                        label: Text(
                          _saving
                              ? _t('Saving...', 'محفوظ ٿي رهيو آهي...', 'محفوظ ہو رہا ہے...')
                              : _t('Save Profile', 'پروفائل محفوظ ڪريو', 'پروفائل محفوظ کریں'),
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF6D4228),
                          foregroundColor: Colors.white,
                          disabledBackgroundColor: const Color(0xFF9E806B),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                      ),
                    ),
                  ],

                  const SizedBox(height: 18),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _showChangePasswordDialog,
                      icon: const Icon(Icons.lock_reset),
                      label: Text(
                        _t('Change Password', 'پاسورڊ تبديل ڪريو', 'پاس ورڈ تبدیل کریں'),
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF6D4228),
                        side: const BorderSide(color: Color(0xFF6D4228)),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 25),
                ],
              ),
            ),
    );
  }
}
