
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'app.dart';

class SignupPage extends StatefulWidget {
  const SignupPage({
    super.key,
    this.showLogin = false,
  });

  final bool showLogin;

  @override
  State<SignupPage> createState() => _SignupPageState();
}

class _SignupPageState extends State<SignupPage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _isLogin = false;
  bool _loading = false;
  bool _showPassword = false;
  bool _showConfirmPassword = false;

  String _t(String en, String sd, [String? ur]) {
    return AppScope.of(context).t(en, sd, ur);
  }

  @override
  void initState() {
    super.initState();
    _isLogin = widget.showLogin;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final name = _nameController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();
    final confirmPassword = _confirmPasswordController.text.trim();

    if (!_isLogin && name.isEmpty) {
      _showMessage(_t(
        'Please enter your name.',
        'مهرباني ڪري پنهنجو نالو لکو.',
        'براہ کرم اپنا نام درج کریں۔',
      ));
      return;
    }

    if (email.isEmpty) {
      _showMessage(_t(
        'Please enter your email.',
        'مهرباني ڪري پنهنجو اي ميل لکو.',
        'براہ کرم اپنا ای میل درج کریں۔',
      ));
      return;
    }

    if (password.isEmpty) {
      _showMessage(_t(
        'Please enter your password.',
        'مهرباني ڪري پنهنجو پاسورڊ لکو.',
        'براہ کرم اپنا پاس ورڈ درج کریں۔',
      ));
      return;
    }

    if (!_isLogin && password != confirmPassword) {
      _showMessage(_t(
        'Passwords do not match.',
        'پاسورڊ هڪجهڙا ناهن.',
        'دونوں پاس ورڈ ایک جیسے نہیں ہیں۔',
      ));
      return;
    }

    if (password.length < 6) {
      _showMessage(_t(
        'Password must be at least 6 characters.',
        'پاسورڊ گهٽ ۾ گهٽ 6 اکرن جو هجڻ گهرجي.',
        'پاس ورڈ کم از کم 6 حروف کا ہونا چاہیے۔',
      ));
      return;
    }

    setState(() => _loading = true);

    try {
      if (_isLogin) {
        await _auth.signInWithEmailAndPassword(
          email: email,
          password: password,
        );
      } else {
        final credential = await _auth.createUserWithEmailAndPassword(
          email: email,
          password: password,
        );

        await credential.user?.updateDisplayName(name);
        await credential.user?.reload();
      }

      // AuthGate in app.dart detects the Firebase login state
      // and automatically opens WelcomePage after database setup.
      // Do not push WelcomePage manually here.
    } on FirebaseAuthException catch (e) {
      String message;

      switch (e.code) {
        case 'email-already-in-use':
          message = _t(
            'This email is already registered. Please Login.',
            'هي اي ميل اڳ ۾ رجسٽر ٿيل آهي. لاگ ان ڪريو.',
            'یہ ای میل پہلے سے رجسٹر ہے۔ براہ کرم لاگ اِن کریں۔',
          );
          break;
        case 'invalid-email':
          message = _t(
            'Please enter a valid email address.',
            'صحيح اي ميل پتو لکو.',
            'براہ کرم درست ای میل ایڈریس درج کریں۔',
          );
          break;
        case 'weak-password':
          message = _t(
            'Password is too weak. Use at least 6 characters.',
            'پاسورڊ ڪمزور آهي. گهٽ ۾ گهٽ 6 اکر استعمال ڪريو.',
            'پاس ورڈ کمزور ہے۔ کم از کم 6 حروف استعمال کریں۔',
          );
          break;
        case 'user-not-found':
          message = _t(
            'No account found with this email.',
            'هن اي ميل سان ڪو اڪائونٽ نه مليو.',
            'اس ای میل سے کوئی اکاؤنٹ نہیں ملا۔',
          );
          break;
        case 'wrong-password':
        case 'invalid-credential':
          message = _t(
            'Email or password is incorrect.',
            'اي ميل يا پاسورڊ غلط آهي.',
            'ای میل یا پاس ورڈ غلط ہے۔',
          );
          break;
        case 'operation-not-allowed':
          message = _t(
            'Email/Password sign-in is not enabled in Firebase.',
            'Firebase ۾ اي ميل لاگ ان فعال ناهي.',
            'Firebase میں ای میل لاگ اِن فعال نہیں ہے۔',
          );
          break;
        case 'network-request-failed':
          message = _t(
            'Internet connection problem. Please try again.',
            'انٽرنيٽ جو مسئلو آهي. ٻيهر ڪوشش ڪريو.',
            'انٹرنیٹ کا مسئلہ ہے۔ دوبارہ کوشش کریں۔',
          );
          break;
        default:
          message = _t(
            'Something went wrong. Please try again.',
            'ڪجهه مسئلو ٿيو. ٻيهر ڪوشش ڪريو.',
            'کچھ مسئلہ پیش آیا۔ دوبارہ کوشش کریں۔',
          );
      }

      _showMessage(message);
    } catch (_) {
      _showMessage(_t(
        'Something went wrong. Please try again.',
        'ڪجهه مسئلو ٿيو. ٻيهر ڪوشش ڪريو.',
        'کچھ مسئلہ پیش آیا۔ دوبارہ کوشش کریں۔',
      ));
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _resetPassword() async {
    final email = _emailController.text.trim();

    if (email.isEmpty) {
      _showMessage(_t(
        'Enter your registered email first.',
        'پهريان پنهنجو رجسٽر ٿيل اي ميل لکو.',
        'پہلے اپنا رجسٹرڈ ای میل درج کریں۔',
      ));
      return;
    }

    setState(() => _loading = true);

    try {
      await _auth.sendPasswordResetEmail(email: email);

      _showMessage(_t(
        'If an account exists for this email, a reset link will be sent. Check your inbox and spam folder.',
        'جيڪڏهن هن اي ميل سان اڪائونٽ موجود آهي ته پاسورڊ ري سيٽ لنڪ موڪليو ويندو. انباڪس ۽ اسپام فولڊر ڏسو.',
        'اگر اس ای میل سے اکاؤنٹ موجود ہے تو پاس ورڈ ری سیٹ لنک بھیجا جائے گا۔ اپنا اِن باکس اور اسپیم فولڈر دیکھیں۔',
      ));
    } on FirebaseAuthException catch (e) {
      String message;

      switch (e.code) {
        case 'invalid-email':
          message = _t(
            'Please enter a valid email address.',
            'صحيح اي ميل پتو لکو.',
            'براہ کرم درست ای میل ایڈریس درج کریں۔',
          );
          break;
        case 'too-many-requests':
          message = _t(
            'Too many attempts. Please try again later.',
            'گهڻيون ڪوششون ٿي چڪيون آهن. پوءِ ڪوشش ڪريو.',
            'بہت زیادہ کوششیں ہو چکی ہیں۔ کچھ دیر بعد دوبارہ کوشش کریں۔',
          );
          break;
        case 'network-request-failed':
          message = _t(
            'Internet connection problem. Please try again.',
            'انٽرنيٽ جو مسئلو آهي. ٻيهر ڪوشش ڪريو.',
            'انٹرنیٹ کا مسئلہ ہے۔ دوبارہ کوشش کریں۔',
          );
          break;
        default:
          message = _t(
            'Could not send reset email. Please try again later.',
            'ري سيٽ اي ميل نه موڪلي سگهيس. پوءِ ڪوشش ڪريو.',
            'ری سیٹ ای میل نہیں بھیجی جا سکی۔ کچھ دیر بعد دوبارہ کوشش کریں۔',
          );
      }

      _showMessage(message);
    } catch (_) {
      _showMessage(_t(
        'Something went wrong. Please try again.',
        'ڪجهه مسئلو ٿيو. ٻيهر ڪوشش ڪريو.',
        'کچھ مسئلہ پیش آیا۔ دوبارہ کوشش کریں۔',
      ));
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
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

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    TextInputType? textInputType,
    bool obscureText = false,
    Widget? suffixIcon,
  }) {
    return TextField(
      controller: controller,
      keyboardType: textInputType,
      obscureText: obscureText,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(
          icon,
          color: const Color(0xFF7A4A2A),
        ),
        suffixIcon: suffixIcon,
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(
            color: Color(0xFF7A4A2A),
            width: 1.5,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final title = _isLogin
        ? _t('Welcome Back', 'واپس ڀليڪار', 'خوش آمدید')
        : _t('Create Your Account', 'پنهنجو اڪائونٽ ٺاهيو', 'اپنا اکاؤنٹ بنائیں');

    final subtitle = _isLogin
        ? _t(
            'Login to continue to Tailor Shop',
            'Tailor Shop جاري رکڻ لاءِ لاگ ان ڪريو',
            'Tailor Shop جاری رکھنے کے لیے لاگ اِن کریں',
          )
        : _t(
            'Create your account to get started',
            'شروع ڪرڻ لاءِ پنهنجو اڪائونٽ ٺاهيو',
            'شروع کرنے کے لیے اپنا اکاؤنٹ بنائیں',
          );

    return Scaffold(
      backgroundColor: const Color(0xFFF8F1E7),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(
              horizontal: 24,
              vertical: 30,
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 430),
              child: Column(
                children: [
                  Container(
                    width: 100,
                    height: 100,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.brown.withOpacity(0.15),
                          blurRadius: 18,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Image.asset(
                      'logo.png',
                      fit: BoxFit.contain,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    title,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 29,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF6D4228),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    subtitle,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 15,
                      color: Colors.brown.shade400,
                    ),
                  ),
                  const SizedBox(height: 30),
                  if (!_isLogin) ...[
                    _buildTextField(
                      controller: _nameController,
                      label: _t('Full Name', 'پورو نالو', 'پورا نام'),
                      hint: _t(
                        'Enter your name',
                        'پنهنجو نالو لکو',
                        'اپنا نام درج کریں',
                      ),
                      icon: Icons.person_outline,
                      textInputType: TextInputType.name,
                    ),
                    const SizedBox(height: 16),
                  ],
                  _buildTextField(
                    controller: _emailController,
                    label: _t('Email', 'اي ميل', 'ای میل'),
                    hint: _t(
                      'Enter your email',
                      'پنهنجو اي ميل لکو',
                      'اپنا ای میل درج کریں',
                    ),
                    icon: Icons.email_outlined,
                    textInputType: TextInputType.emailAddress,
                  ),
                  const SizedBox(height: 16),
                  _buildTextField(
                    controller: _passwordController,
                    label: _t('Password', 'پاسورڊ', 'پاس ورڈ'),
                    hint: _t(
                      'Enter your password',
                      'پنهنجو پاسورڊ لکو',
                      'اپنا پاس ورڈ درج کریں',
                    ),
                    icon: Icons.lock_outline,
                    obscureText: !_showPassword,
                    suffixIcon: IconButton(
                      onPressed: () {
                        setState(() {
                          _showPassword = !_showPassword;
                        });
                      },
                      icon: Icon(
                        _showPassword
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                      ),
                    ),
                  ),
                  if (_isLogin)
                    Align(
                      alignment: AlignmentDirectional.centerEnd,
                      child: TextButton(
                        onPressed: _loading ? null : _resetPassword,
                        style: TextButton.styleFrom(
                          foregroundColor: const Color(0xFF7A4A2A),
                        ),
                        child: Text(
                          _t(
                            'Forgot Password?',
                            'پاسورڊ وساري ويٺا؟',
                            'پاس ورڈ بھول گئے؟',
                          ),
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  if (!_isLogin) ...[
                    const SizedBox(height: 16),
                    _buildTextField(
                      controller: _confirmPasswordController,
                      label: _t(
                        'Confirm Password',
                        'پاسورڊ ٻيهر لکو',
                        'پاس ورڈ کی تصدیق کریں',
                      ),
                      hint: _t(
                        'Enter password again',
                        'پاسورڊ ٻيهر لکو',
                        'پاس ورڈ دوبارہ درج کریں',
                      ),
                      icon: Icons.lock_reset_outlined,
                      obscureText: !_showConfirmPassword,
                      suffixIcon: IconButton(
                        onPressed: () {
                          setState(() {
                            _showConfirmPassword = !_showConfirmPassword;
                          });
                        },
                        icon: Icon(
                          _showConfirmPassword
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined,
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 28),
                  SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: ElevatedButton(
                      onPressed: _loading ? null : _submit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF7A4A2A),
                        foregroundColor: Colors.white,
                        elevation: 3,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: _loading
                          ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                color: Colors.white,
                              ),
                            )
                          : Text(
                              _isLogin
                                  ? _t('Login', 'لاگ ان', 'لاگ اِن')
                                  : _t(
                                      'Create Account',
                                      'اڪائونٽ ٺاهيو',
                                      'اکاؤنٹ بنائیں',
                                    ),
                              style: const TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(height: 22),
                  Wrap(
                    alignment: WrapAlignment.center,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        _isLogin
                            ? _t(
                                "Don't have an account? ",
                                'اڪائونٽ ناهي؟ ',
                                'اکاؤنٹ نہیں ہے؟ ',
                              )
                            : _t(
                                'Already have an account? ',
                                'اڳ ۾ اڪائونٽ آهي؟ ',
                                'پہلے سے اکاؤنٹ ہے؟ ',
                              ),
                        style: TextStyle(
                          color: Colors.brown.shade600,
                          fontSize: 14,
                        ),
                      ),
                      GestureDetector(
                        onTap: _loading
                            ? null
                            : () {
                                setState(() {
                                  _isLogin = !_isLogin;
                                  _passwordController.clear();
                                  _confirmPasswordController.clear();
                                });
                              },
                        child: Text(
                          _isLogin
                              ? _t(
                                  'Create Account',
                                  'اڪائونٽ ٺاهيو',
                                  'اکاؤنٹ بنائیں',
                                )
                              : _t('Login', 'لاگ ان', 'لاگ اِن'),
                          style: const TextStyle(
                            color: Color(0xFF7A4A2A),
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
