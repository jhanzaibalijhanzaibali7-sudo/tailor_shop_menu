import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

  @override
  void initState() {
    super.initState();

    _nameController = TextEditingController();
    _shopController = TextEditingController();
    _phoneController = TextEditingController();

    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final user = _auth.currentUser;

    if (user == null) {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
      return;
    }

    try {
      final doc = await _firestore
          .collection('users')
          .doc(user.uid)
          .get();

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

        _profileImagePath =
            prefs.getString('profile_image_path');

        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _loading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Could not load profile: $e',
          ),
        ),
      );
    }
  }

  Future<void> _pickProfileImage() async {
    final XFile? image = await _imagePicker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
    );

    if (image == null) return;

    final prefs = await SharedPreferences.getInstance();

    await prefs.setString(
      'profile_image_path',
      image.path,
    );

    if (!mounted) return;

    setState(() {
      _profileImagePath = image.path;
    });
  }

  Future<void> _saveProfile() async {
    final user = _auth.currentUser;

    if (user == null) return;

    final name = _nameController.text.trim();
    final shopName = _shopController.text.trim();
    final phone = _phoneController.text.trim();

    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Please enter your full name',
          ),
        ),
      );
      return;
    }

    setState(() {
      _saving = true;
    });

    try {
      await user.updateDisplayName(name);

      await _firestore
          .collection('users')
          .doc(user.uid)
          .set(
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

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Profile saved successfully',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _saving = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Could not save profile: $e',
          ),
        ),
      );
    }
  }

  Future<void> _showChangePasswordDialog() async {
    final currentPasswordController =
        TextEditingController();
    final newPasswordController =
        TextEditingController();
    final confirmPasswordController =
        TextEditingController();

    bool obscureCurrent = true;
    bool obscureNew = true;
    bool obscureConfirm = true;
    bool changingPassword = false;

    await showDialog(
      context: context,
      barrierDismissible: !changingPassword,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            Future<void> changePassword() async {
              final user = _auth.currentUser;

              if (user == null) return;

              final currentPassword =
                  currentPasswordController.text.trim();
              final newPassword =
                  newPasswordController.text.trim();
              final confirmPassword =
                  confirmPasswordController.text.trim();

              if (currentPassword.isEmpty ||
                  newPassword.isEmpty ||
                  confirmPassword.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'Please fill all password fields',
                    ),
                  ),
                );
                return;
              }

              if (newPassword.length < 6) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'New password must be at least 6 characters',
                    ),
                  ),
                );
                return;
              }

              if (newPassword != confirmPassword) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'New passwords do not match',
                    ),
                  ),
                );
                return;
              }

              setDialogState(() {
                changingPassword = true;
              });

              try {
                final email = user.email;

                if (email == null || email.isEmpty) {
                  throw FirebaseAuthException(
                    code: 'no-email',
                    message:
                        'No email is associated with this account.',
                  );
                }

                final credential =
                    EmailAuthProvider.credential(
                  email: email,
                  password: currentPassword,
                );

                await user.reauthenticateWithCredential(
                  credential,
                );

                await user.updatePassword(newPassword);

                if (!mounted) return;

                Navigator.of(dialogContext).pop();

                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'Password changed successfully',
                    ),
                  ),
                );
              } on FirebaseAuthException catch (e) {
                setDialogState(() {
                  changingPassword = false;
                });

                String message =
                    'Could not change password';

                if (e.code == 'wrong-password' ||
                    e.code == 'invalid-credential') {
                  message =
                      'Current password is incorrect';
                } else if (e.code == 'weak-password') {
                  message =
                      'New password is too weak';
                } else if (e.code == 'requires-recent-login') {
                  message =
                      'Please sign in again and try changing the password';
                } else if (e.message != null &&
                    e.message!.isNotEmpty) {
                  message = e.message!;
                }

                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(message),
                  ),
                );
              } catch (e) {
                setDialogState(() {
                  changingPassword = false;
                });

                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      'Could not change password: $e',
                    ),
                  ),
                );
              }
            }

            return AlertDialog(
              title: const Text(
                'Change Password',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                ),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller:
                          currentPasswordController,
                      obscureText: obscureCurrent,
                      enabled: !changingPassword,
                      decoration: InputDecoration(
                        labelText: 'Current Password',
                        prefixIcon:
                            const Icon(Icons.lock_outline),
                        suffixIcon: IconButton(
                          onPressed: changingPassword
                              ? null
                              : () {
                                  setDialogState(() {
                                    obscureCurrent =
                                        !obscureCurrent;
                                  });
                                },
                          icon: Icon(
                            obscureCurrent
                                ? Icons.visibility
                                : Icons.visibility_off,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 15),
                    TextField(
                      controller: newPasswordController,
                      obscureText: obscureNew,
                      enabled: !changingPassword,
                      decoration: InputDecoration(
                        labelText: 'New Password',
                        prefixIcon:
                            const Icon(Icons.lock_reset),
                        suffixIcon: IconButton(
                          onPressed: changingPassword
                              ? null
                              : () {
                                  setDialogState(() {
                                    obscureNew =
                                        !obscureNew;
                                  });
                                },
                          icon: Icon(
                            obscureNew
                                ? Icons.visibility
                                : Icons.visibility_off,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 15),
                    TextField(
                      controller:
                          confirmPasswordController,
                      obscureText: obscureConfirm,
                      enabled: !changingPassword,
                      decoration: InputDecoration(
                        labelText:
                            'Confirm New Password',
                        prefixIcon:
                            const Icon(Icons.lock_reset),
                        suffixIcon: IconButton(
                          onPressed: changingPassword
                              ? null
                              : () {
                                  setDialogState(() {
                                    obscureConfirm =
                                        !obscureConfirm;
                                  });
                                },
                          icon: Icon(
                            obscureConfirm
                                ? Icons.visibility
                                : Icons.visibility_off,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: changingPassword
                      ? null
                      : () {
                          Navigator.of(dialogContext).pop();
                        },
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: changingPassword
                      ? null
                      : changePassword,
                  style: ElevatedButton.styleFrom(
                    backgroundColor:
                        const Color(0xFF6D4228),
                    foregroundColor: Colors.white,
                  ),
                  child: changingPassword
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child:
                              CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text(
                          'Change Password',
                        ),
                ),
              ],
            );
          },
        );
      },
    );

    currentPasswordController.dispose();
    newPasswordController.dispose();
    confirmPasswordController.dispose();
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
        padding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 4,
        ),
        child: TextField(
          controller: controller,
          keyboardType: keyboardType,
          enabled: _editingInformation,
          decoration: InputDecoration(
            border: InputBorder.none,
            icon: Icon(
              icon,
              color: const Color(0xFF7A4A2A),
            ),
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
        leading: Icon(
          icon,
          color: const Color(0xFF7A4A2A),
        ),
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
  void dispose() {
    _nameController.dispose();
    _shopController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = _auth.currentUser;

    final String email =
        user?.email ?? 'No Gmail';

    final String userId =
        user?.uid ?? 'No User ID';

    return Scaffold(
      backgroundColor: const Color(0xFFF8F1E7),
      appBar: AppBar(
        title: const Text(
          'Profile',
          style: TextStyle(
            fontWeight: FontWeight.bold,
          ),
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

                  // Profile Photo
                  GestureDetector(
                    onTap: _pickProfileImage,
                    child: Stack(
                      alignment: Alignment.bottomRight,
                      children: [
                        CircleAvatar(
                          radius: 62,
                          backgroundColor:
                              const Color(0xFF7A4A2A),
                          backgroundImage:
                              _profileImagePath != null &&
                                      File(
                                        _profileImagePath!,
                                      ).existsSync()
                                  ? FileImage(
                                      File(
                                        _profileImagePath!,
                                      ),
                                    )
                                  : null,
                          child: _profileImagePath == null ||
                                  !File(
                                    _profileImagePath!,
                                  ).existsSync()
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
                            border: Border.all(
                              color: Colors.white,
                              width: 2,
                            ),
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

                  const Text(
                    'Tap photo to change',
                    style: TextStyle(
                      color: Colors.brown,
                      fontSize: 13,
                    ),
                  ),

                  const SizedBox(height: 25),

                  // User ID
                  _readOnlyField(
                    icon: Icons.badge_outlined,
                    label: 'User ID',
                    value: userId,
                  ),

                  // Gmail
                  _readOnlyField(
                    icon: Icons.email_outlined,
                    label: 'Gmail',
                    value: email,
                  ),

                  const SizedBox(height: 10),

                  // Edit Information
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () {
                        setState(() {
                          _editingInformation =
                              !_editingInformation;
                        });
                      },
                      icon: Icon(
                        _editingInformation
                            ? Icons.close
                            : Icons.edit_outlined,
                      ),
                      label: Text(
                        _editingInformation
                            ? 'Cancel Edit'
                            : 'Edit Information',
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor:
                            const Color(0xFF6D4228),
                        side: const BorderSide(
                          color: Color(0xFF6D4228),
                        ),
                        padding:
                            const EdgeInsets.symmetric(
                          vertical: 14,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.circular(16),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 18),

                  // Full Name
                  _editableField(
                    icon: Icons.person_outline,
                    label: 'Full Name',
                    controller: _nameController,
                  ),

                  // Shop Name
                  _editableField(
                    icon: Icons.store_outlined,
                    label: 'Shop Name',
                    controller: _shopController,
                  ),

                  // Phone Number
                  _editableField(
                    icon: Icons.phone_outlined,
                    label: 'Phone Number',
                    controller: _phoneController,
                    keyboardType:
                        TextInputType.phone,
                  ),

                  if (_editingInformation) ...[
                    const SizedBox(height: 12),

                    SizedBox(
                      width: double.infinity,
                      height: 54,
                      child: ElevatedButton.icon(
                        onPressed:
                            _saving
                                ? null
                                : _saveProfile,
                        icon: _saving
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child:
                                    CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(
                                Icons.save_outlined,
                              ),
                        label: Text(
                          _saving
                              ? 'Saving...'
                              : 'Save Profile',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        style:
                            ElevatedButton.styleFrom(
                          backgroundColor:
                              const Color(0xFF6D4228),
                          foregroundColor: Colors.white,
                          disabledBackgroundColor:
                              const Color(0xFF9E806B),
                          shape:
                              RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius.circular(16),
                          ),
                        ),
                      ),
                    ),
                  ],

                  const SizedBox(height: 18),

                  // Change Password
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed:
                          _showChangePasswordDialog,
                      icon: const Icon(
                        Icons.lock_reset,
                      ),
                      label: const Text(
                        'Change Password',
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor:
                            const Color(0xFF6D4228),
                        side: const BorderSide(
                          color: Color(0xFF6D4228),
                        ),
                        padding:
                            const EdgeInsets.symmetric(
                          vertical: 14,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.circular(16),
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
