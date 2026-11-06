import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class _C {
  static const primary = Color(0xFF00897B);
  static const primaryDark = Color(0xFF00695C);
  static const primaryLight = Color(0xFFE0F2F1);
  static const danger = Color(0xFFC62828);
  static const dangerLight = Color(0xFFFFEBEE);
  static const surface = Colors.white;
  static const surfaceGray = Color(0xFFF5F5F5);
  static const border = Color(0xFFE0E0E0);
  static const text = Color(0xFF1A1A1A);
  static const textSecondary = Color(0xFF757575);
  static const bg = Color(0xFFFAFAFA);
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _identifierCtrl = TextEditingController(); // إيميل أو كود موظف
  final _passCtrl = TextEditingController();
  bool _loading = false;
  bool _obscurePassword = true;
  String? _error;

  @override
  void dispose() {
    _identifierCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  /// إذا كان المُدخل لا يحتوي على @ نعتبره كود موظف ونضيف البريد الوهمي
  String _resolveEmail(String input) {
    final value = input.trim();
    if (value.contains('@')) return value;
    return '$value@hesaby.local';
  }

  Future<void> _login() async {
    FocusScope.of(context).unfocus();
    if (_identifierCtrl.text.trim().isEmpty || _passCtrl.text.isEmpty) {
      setState(() => _error = 'يرجى إدخال بيانات الدخول كاملة');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final email = _resolveEmail(_identifierCtrl.text);
      await Supabase.instance.client.auth.signInWithPassword(
        email: email,
        password: _passCtrl.text,
      );
      if (mounted) context.go('/home');
    } on AuthException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _C.primary,
      body: Stack(
        children: [
          // ─── الخلفية العلوية (تدرج أخضر) ───
          Container(
            height: MediaQuery.of(context).size.height * 0.45,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [_C.primary, _C.primaryDark],
                begin: Alignment.topRight,
                end: Alignment.bottomLeft,
              ),
            ),
          ),

          // ─── المحتوى ───
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // ─── اللوجو واسم التطبيق ───
                      _buildLogoHeader(),
                      const SizedBox(height: 40),

                      // ─── بطاقة تسجيل الدخول ───
                      _buildLoginCard(),

                      const SizedBox(height: 24),

                      // ─── تذييل ───
                      Text(
                        'الإصدار 1.0.0',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.white.withOpacity(0.7),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════
  //   اللوجو والرأس
  // ═══════════════════════════════════════════════════════════════════════
  Widget _buildLogoHeader() {
    return Column(
      children: [
        // اللوجو (في دائرة بيضاء)
        Container(
          width: 110,
          height: 110,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.15),
                blurRadius: 16,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: ClipOval(
            child: Image.asset(
              'assets/images/logo.png',
              fit: BoxFit.contain,
              // في حال عدم وجود اللوجو، يعرض أيقونة بديلة
              errorBuilder: (_, __, ___) => const Icon(
                Icons.point_of_sale,
                size: 60,
                color: _C.primary,
              ),
            ),
          ),
        ),
        const SizedBox(height: 20),

        // اسم التطبيق
        const Text(
          'حسابي - المندوب',
          style: TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.w800,
            color: Colors.white,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'تطبيق إدارة المبيعات والتحصيلات',
          style: TextStyle(
            fontSize: 13,
            color: Colors.white.withOpacity(0.85),
          ),
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════════════
  //   بطاقة الدخول
  // ═══════════════════════════════════════════════════════════════════════
  Widget _buildLoginCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: _C.surface,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // عنوان البطاقة
          const Text(
            'تسجيل الدخول',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: _C.text,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'سجّل بالإيميل أو كود الموظف للمتابعة',
            style: TextStyle(fontSize: 13, color: _C.textSecondary),
          ),
          const SizedBox(height: 24),

          // حقل الهوية
          _buildTextField(
            controller: _identifierCtrl,
            label: 'الإيميل أو كود الموظف',
            hint: 'example@mail.com أو 12345',
            icon: Icons.person_outline,
            keyboardType: TextInputType.emailAddress,
            textDirection: TextDirection.ltr,
          ),
          const SizedBox(height: 14),

          // حقل كلمة المرور
          _buildPasswordField(),

          // رسالة الخطأ
          if (_error != null) ...[
            const SizedBox(height: 14),
            _buildErrorBanner(_error!),
          ],

          const SizedBox(height: 24),

          // زر الدخول
          SizedBox(
            height: 52,
            child: ElevatedButton(
              onPressed: _loading ? null : _login,
              style: ElevatedButton.styleFrom(
                backgroundColor: _C.primary,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(28),
                ),
              ),
              child: _loading
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.4,
                        color: Colors.white,
                      ),
                    )
                  : const Text(
                      'تسجيل الدخول',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── حقل نصي عادي ───
  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    TextInputType? keyboardType,
    TextDirection? textDirection,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      textDirection: textDirection,
      style: const TextStyle(fontSize: 14, color: _C.text),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        hintStyle: TextStyle(
          fontSize: 12,
          color: Colors.grey.shade400,
        ),
        labelStyle: const TextStyle(
          fontSize: 13,
          color: _C.textSecondary,
        ),
        prefixIcon: Icon(icon, color: _C.primary, size: 22),
        filled: true,
        fillColor: _C.surfaceGray,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: _C.border.withOpacity(0.5)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: _C.primary, width: 1.5),
        ),
      ),
    );
  }

  // ─── حقل كلمة المرور ───
  Widget _buildPasswordField() {
    return TextField(
      controller: _passCtrl,
      obscureText: _obscurePassword,
      onSubmitted: (_) => _loading ? null : _login(),
      style: const TextStyle(fontSize: 14, color: _C.text),
      decoration: InputDecoration(
        labelText: 'كلمة المرور',
        labelStyle: const TextStyle(
          fontSize: 13,
          color: _C.textSecondary,
        ),
        prefixIcon: const Icon(Icons.lock_outline, color: _C.primary, size: 22),
        suffixIcon: IconButton(
          icon: Icon(
            _obscurePassword ? Icons.visibility_off : Icons.visibility,
            color: _C.textSecondary,
            size: 20,
          ),
          onPressed: () =>
              setState(() => _obscurePassword = !_obscurePassword),
        ),
        filled: true,
        fillColor: _C.surfaceGray,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: _C.border.withOpacity(0.5)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: _C.primary, width: 1.5),
        ),
      ),
    );
  }

  // ─── بانر الخطأ ───
  Widget _buildErrorBanner(String message) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: _C.dangerLight,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _C.danger.withOpacity(0.25)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: _C.danger, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                fontSize: 12.5,
                color: _C.danger,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
