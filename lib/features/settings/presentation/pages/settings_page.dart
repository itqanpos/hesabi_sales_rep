import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../sales/data/invoice_settings_repository.dart';
import '../../../sales/presentation/widgets/bluetooth_printer_service.dart';
import '../../../sales/presentation/widgets/direct_invoice_printer.dart';
import '../../domain/settings_models.dart';

class _C {
  static const primary = Color(0xFF00897B);
  static const primaryDark = Color(0xFF00695C);
  static const primaryLight = Color(0xFFE0F2F1);
  static const success = Color(0xFF2E7D32);
  static const successLight = Color(0xFFE8F5E9);
  static const warning = Color(0xFFE65100);
  static const warningLight = Color(0xFFFFF3E0);
  static const danger = Color(0xFFC62828);
  static const dangerLight = Color(0xFFFFEBEE);
  static const surface = Colors.white;
  static const surfaceGray = Color(0xFFF5F5F5);
  static const border = Color(0xFFE0E0E0);
  static const text = Color(0xFF1A1A1A);
  static const textSecondary = Color(0xFF757575);
  static const bg = Color(0xFFFAFAFA);
}

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  late final InvoiceSettingsRepository _repo;

  // Company data (read-only)
  String? _companyId;
  CompanyInfo? _company;
  InvoiceSettings? _hesabiSettings;

  // Local overrides
  LocalPrintOverrides _original = const LocalPrintOverrides();
  LocalPrintOverrides _edited = const LocalPrintOverrides();

  // Printer (local)
  String? _printerName;
  String? _printerAddress;
  bool _loadingPrinter = false;

  // UI state
  bool _loading = true;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _repo = InvoiceSettingsRepository(Supabase.instance.client);
    _load();
  }

  bool get _hasChanges =>
      _original.paperWidth != _edited.paperWidth ||
      _original.fontScale != _edited.fontScale;

  // ─── Load ────────────────────────────────────────────────────────────
  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final client = Supabase.instance.client;
      final userId = client.auth.currentUser?.id;
      if (userId == null) throw 'غير مسجل الدخول';

      final member = await client
          .from('company_members')
          .select('company_id')
          .eq('user_id', userId)
          .eq('is_active', true)
          .limit(1)
          .maybeSingle();
      if (member == null) throw 'لا توجد شركة مرتبطة بحسابك';

      final companyId = member['company_id'] as String;
      _companyId = companyId;

      final comp = await client
          .from('companies')
          .select(
              'id, name, phone, email, address, tax_number, commercial_register')
          .eq('id', companyId)
          .maybeSingle();

      final hesabiSettings = await _repo.load(companyId);
      final localOverrides = await _repo.loadLocalOverrides();

      final printerName = await BluetoothPrinterService.getSavedPrinterName();
      final printerAddress =
          await BluetoothPrinterService.getSavedPrinterAddress();

      if (!mounted) return;
      setState(() {
        _company = CompanyInfo.fromJson(comp ?? {'id': companyId});
        _hesabiSettings = hesabiSettings;
        _original = localOverrides;
        _edited = localOverrides;
        _printerName = printerName;
        _printerAddress = printerAddress;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  // ─── Save ────────────────────────────────────────────────────────────
  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await _repo.saveLocalOverrides(_edited);
      if (!mounted) return;
      setState(() {
        _original = _edited;
        _saving = false;
      });
      _snack('✅ تم حفظ الإعدادات');
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      _snack('فشل الحفظ: $e', isError: true);
    }
  }

  // ─── Printer ─────────────────────────────────────────────────────────
  Future<void> _changePrinter() async {
    setState(() => _loadingPrinter = true);
    final printers = await BluetoothPrinterService.discoverPrinters();
    if (!mounted) return;
    setState(() => _loadingPrinter = false);

    if (printers.isEmpty) {
      _snack('لا توجد طابعات مقترنة. اذهب لإعدادات البلوتوث أولاً.',
          isError: true);
      return;
    }

    final selected = await showModalBottomSheet<dynamic>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _PrinterPickerSheet(printers: printers),
    );

    if (selected != null && mounted) {
      setState(() {
        _printerName = selected.name as String?;
        _printerAddress = selected.address as String?;
      });
    }
  }

  Future<void> _testPrint() async {
    if (_printerAddress == null) {
      _snack('اربط طابعة أولاً', isError: true);
      return;
    }
    await DirectInvoicePrinter.printTest(context);
  }

  void _snack(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: isError ? _C.danger : _C.success,
      ),
    );
  }

  // ═════════════════════════════════════════════════════════════════════
  //   BUILD
  // ═════════════════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: _C.bg,
        appBar: _buildAppBar(),
        body: _loading
            ? const Center(
                child: CircularProgressIndicator(color: _C.primary))
            : _error != null
                ? _buildError()
                : _buildBody(),
        bottomNavigationBar: _hasChanges ? _buildSaveBar() : null,
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: _C.primary,
      foregroundColor: Colors.white,
      elevation: 0,
      title: const Text('الإعدادات',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
      actions: [
        IconButton(
          onPressed: _loading ? null : _load,
          icon: const Icon(Icons.refresh),
          tooltip: 'تحديث',
        ),
      ],
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: _C.danger, size: 56),
            const SizedBox(height: 12),
            Text(_error!, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _load,
              icon: const Icon(Icons.refresh),
              label: const Text('إعادة المحاولة'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
      children: [
        _buildCompanyCard(),
        const SizedBox(height: 20),
        _buildSectionTitle('🖨️ طابعة البلوتوث'),
        const SizedBox(height: 8),
        _buildPrinterSection(),
        const SizedBox(height: 20),
        _buildSectionTitle('⚙️ تخصيص لجهازي فقط'),
        const SizedBox(height: 8),
        _buildLocalOverridesSection(),
        const SizedBox(height: 20),
        _buildSectionTitle('ℹ️ الحساب'),
        const SizedBox(height: 8),
        _buildAccountSection(),
      ],
    );
  }

  // ═════════════════════════════════════════════════════════════════════
  //   Company Card (read-only)
  // ═════════════════════════════════════════════════════════════════════
  Widget _buildCompanyCard() {
    final logoUrl = _hesabiSettings?.logoUrl;
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header with "read only" badge
          Row(
            children: [
              const Icon(Icons.business, color: _C.primary, size: 20),
              const SizedBox(width: 8),
              const Text('بيانات الشركة',
                  style: TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w800)),
              const Spacer(),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: _C.warningLight,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.lock_outline,
                        size: 12, color: _C.warning),
                    SizedBox(width: 4),
                    Text('قراءة فقط',
                        style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: _C.warning)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          // Logo + name
          Row(
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: _C.surfaceGray,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: _C.border),
                ),
                clipBehavior: Clip.antiAlias,
                child: logoUrl != null
                    ? Image.network(logoUrl, fit: BoxFit.cover)
                    : const Icon(Icons.business,
                        size: 32, color: _C.textSecondary),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _company?.name ?? '—',
                      style: const TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w800),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (_company?.phone != null &&
                        _company!.phone!.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(Icons.phone,
                              size: 12, color: _C.textSecondary),
                          const SizedBox(width: 4),
                          Text(_company!.phone!,
                              style: const TextStyle(
                                  fontSize: 11, color: _C.textSecondary)),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(height: 1, color: _C.border),
          const SizedBox(height: 12),
          // Hesabi print settings (read-only preview)
          _readOnlyRow(
            icon: Icons.description_outlined,
            label: 'حجم الورق (من Hesabi)',
            value: _hesabiSettings?.paperWidth ?? '80mm',
          ),
          const SizedBox(height: 8),
          _readOnlyRow(
            icon: Icons.text_fields,
            label: 'حجم الخط (من Hesabi)',
            value:
                '${(_hesabiSettings?.fontScale ?? 1.0).toStringAsFixed(2)}×',
          ),
          const SizedBox(height: 8),
          _readOnlyRow(
            icon: Icons.qr_code,
            label: 'QR Code',
            value: (_hesabiSettings?.showQrOnPrint ?? false) ? 'مفعّل' : 'معطّل',
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: _C.primaryLight,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Row(
              children: [
                Icon(Icons.info_outline, size: 16, color: _C.primaryDark),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'لتعديل بيانات الشركة أو إعدادات الطباعة، افتح تطبيق Hesabi الرئيسي.',
                    style: TextStyle(
                        fontSize: 11,
                        color: _C.primaryDark,
                        fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _readOnlyRow({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Row(
      children: [
        Icon(icon, size: 14, color: _C.textSecondary),
        const SizedBox(width: 8),
        Expanded(
          child: Text(label,
              style: const TextStyle(
                  fontSize: 12, color: _C.textSecondary)),
        ),
        Text(value,
            style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: _C.text)),
      ],
    );
  }

  // ═════════════════════════════════════════════════════════════════════
  //   Printer Section
  // ═════════════════════════════════════════════════════════════════════
  Widget _buildPrinterSection() {
    return _Card(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          ListTile(
            leading: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: _printerAddress != null
                    ? _C.successLight
                    : _C.surfaceGray,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                Icons.print,
                color: _printerAddress != null
                    ? _C.success
                    : _C.textSecondary,
                size: 22,
              ),
            ),
            title: Text(
              _printerName ?? 'لا توجد طابعة',
              style: const TextStyle(
                  fontSize: 14, fontWeight: FontWeight.w700),
            ),
            subtitle: _printerAddress != null
                ? Text(
                    _printerAddress!,
                    style: const TextStyle(
                        fontSize: 11, color: _C.textSecondary),
                  )
                : const Text('لم يتم ربط طابعة بعد',
                    style:
                        TextStyle(fontSize: 11, color: _C.textSecondary)),
            trailing: _loadingPrinter
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: _C.primary),
                  )
                : TextButton(
                    onPressed: _changePrinter,
                    child: Text(_printerAddress == null ? 'ربط' : 'تغيير'),
                  ),
          ),
          if (_printerAddress != null) ...[
            const Divider(height: 1, color: _C.border),
            ListTile(
              leading: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: _C.primaryLight,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.receipt_long,
                    color: _C.primary, size: 22),
              ),
              title: const Text('طباعة تجريبية',
                  style:
                      TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
              subtitle: const Text('اختبار جودة الطباعة والترميز العربي',
                  style:
                      TextStyle(fontSize: 11, color: _C.textSecondary)),
              trailing:
                  const Icon(Icons.chevron_left, color: _C.textSecondary),
              onTap: _testPrint,
            ),
          ],
        ],
      ),
    );
  }

  // ═════════════════════════════════════════════════════════════════════
  //   Local Overrides Section
  // ═════════════════════════════════════════════════════════════════════
  Widget _buildLocalOverridesSection() {
    final hesabiPaper = _hesabiSettings?.paperWidth ?? '80mm';
    final hesabiFont = _hesabiSettings?.fontScale ?? 1.0;

    return Column(
      children: [
        _Card(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              // Paper width override
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.description_outlined,
                            size: 20, color: _C.textSecondary),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Text('حجم الورق على جهازي',
                              style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700)),
                        ),
                        // Toggle to enable override
                        Switch(
                          value: _edited.paperWidth != null,
                          activeColor: _C.primary,
                          onChanged: (enabled) {
                            setState(() {
                              _edited = LocalPrintOverrides(
                                paperWidth:
                                    enabled ? hesabiPaper : null,
                                fontScale: _edited.fontScale,
                              );
                            });
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _edited.paperWidth != null
                          ? 'مخصص لجهازك'
                          : 'يستخدم إعداد Hesabi ($hesabiPaper)',
                      style: TextStyle(
                        fontSize: 11,
                        color: _edited.paperWidth != null
                            ? _C.primary
                            : _C.textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (_edited.paperWidth != null) ...[
                      const SizedBox(height: 10),
                      SegmentedButton<String>(
                        segments: const [
                          ButtonSegment(
                              value: '58mm', label: Text('58mm')),
                          ButtonSegment(
                              value: '80mm', label: Text('80mm')),
                        ],
                        selected: {_edited.paperWidth!},
                        onSelectionChanged: (v) {
                          setState(() {
                            _edited = LocalPrintOverrides(
                              paperWidth: v.first,
                              fontScale: _edited.fontScale,
                            );
                          });
                        },
                        style: SegmentedButton.styleFrom(
                          selectedBackgroundColor: _C.primaryLight,
                          selectedForegroundColor: _C.primaryDark,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const Divider(height: 1, color: _C.border),

              // Font scale override
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.text_fields,
                            size: 20, color: _C.textSecondary),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Text('حجم الخط على جهازي',
                              style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700)),
                        ),
                        Switch(
                          value: _edited.fontScale != null,
                          activeColor: _C.primary,
                          onChanged: (enabled) {
                            setState(() {
                              _edited = LocalPrintOverrides(
                                paperWidth: _edited.paperWidth,
                                fontScale:
                                    enabled ? hesabiFont : null,
                              );
                            });
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _edited.fontScale != null
                          ? 'مخصص لجهازك (${_edited.fontScale!.toStringAsFixed(2)}×)'
                          : 'يستخدم إعداد Hesabi (${hesabiFont.toStringAsFixed(2)}×)',
                      style: TextStyle(
                        fontSize: 11,
                        color: _edited.fontScale != null
                            ? _C.primary
                            : _C.textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (_edited.fontScale != null) ...[
                      const SizedBox(height: 10),
                      Slider(
                        value: _edited.fontScale!.clamp(0.8, 2.0),
                        min: 0.8,
                        max: 2.0,
                        divisions: 12,
                        activeColor: _C.primary,
                        label:
                            '${_edited.fontScale!.toStringAsFixed(1)}×',
                        onChanged: (v) {
                          setState(() {
                            _edited = LocalPrintOverrides(
                              paperWidth: _edited.paperWidth,
                              fontScale: v,
                            );
                          });
                        },
                      ),
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 4),
                        child: Row(
                          mainAxisAlignment:
                              MainAxisAlignment.spaceBetween,
                          children: [
                            Text('صغير',
                                style: TextStyle(
                                    fontSize: 11,
                                    color: _C.textSecondary)),
                            Text('كبير',
                                style: TextStyle(
                                    fontSize: 11,
                                    color: _C.textSecondary)),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Row(
            children: [
              Icon(Icons.info_outline,
                  size: 14, color: Colors.grey.shade500),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'التخصيص يُحفظ على جهازك فقط — لا يؤثر على Hesabi أو أجهزة المندوبين الآخرين.',
                  style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey.shade600,
                      height: 1.4),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ═════════════════════════════════════════════════════════════════════
  //   Account Section
  // ═════════════════════════════════════════════════════════════════════
  Widget _buildAccountSection() {
    final user = Supabase.instance.client.auth.currentUser;
    final email = user?.email ?? '—';
    final fullName =
        (user?.userMetadata?['full_name'] as String?) ?? email;

    return _Card(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          ListTile(
            leading: const Icon(Icons.person, color: _C.primary),
            title: const Text('مسجل الدخول بـ',
                style: TextStyle(fontSize: 12, color: _C.textSecondary)),
            subtitle: Text(fullName,
                style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: _C.text)),
            trailing: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 140),
              child: Text(
                email,
                textAlign: TextAlign.left,
                style: const TextStyle(
                    fontSize: 11, color: _C.textSecondary),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
          const Divider(height: 1, color: _C.border),
          ListTile(
            leading: const Icon(Icons.info_outline,
                color: _C.textSecondary),
            title: const Text('إصدار التطبيق',
                style:
                    TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
            trailing: const Text('1.0.0',
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: _C.textSecondary)),
          ),
          const Divider(height: 1, color: _C.border),
          ListTile(
            leading: const Icon(Icons.logout, color: _C.danger),
            title: const Text('تسجيل الخروج',
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: _C.danger)),
            trailing:
                const Icon(Icons.chevron_left, color: _C.danger),
            onTap: _confirmLogout,
          ),
        ],
      ),
    );
  }

  Future<void> _confirmLogout() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('تسجيل الخروج'),
        content: const Text('هل تريد تسجيل الخروج من التطبيق؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: _C.danger),
            child: const Text('تسجيل الخروج'),
          ),
        ],
      ),
    );
    if (ok == true) {
      await Supabase.instance.client.auth.signOut();
      if (mounted) {
        Navigator.of(context)
            .pushNamedAndRemoveUntil('/login', (route) => false);
      }
    }
  }

  // ═════════════════════════════════════════════════════════════════════
  //   Save Bar
  // ═════════════════════════════════════════════════════════════════════
  Widget _buildSaveBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 12,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 52,
          child: ElevatedButton.icon(
            onPressed: _saving ? null : _save,
            style: ElevatedButton.styleFrom(
              backgroundColor: _C.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(28),
              ),
            ),
            icon: _saving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.check_circle_outline),
            label: Text(
              _saving ? 'جاري الحفظ...' : 'حفظ التخصيص',
              style: const TextStyle(
                  fontSize: 15, fontWeight: FontWeight.w800),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Text(title,
          style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: _C.text)),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Shared widgets
// ═══════════════════════════════════════════════════════════════════════════

class _Card extends StatelessWidget {
  final Widget child;
  final EdgeInsets? padding;
  const _Card({required this.child, this.padding});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding ?? const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _C.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _C.border),
      ),
      child: child,
    );
  }
}

class _PrinterPickerSheet extends StatelessWidget {
  final List<dynamic> printers;
  const _PrinterPickerSheet({required this.printers});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              margin: const EdgeInsets.only(top: 10, bottom: 4),
              width: 42,
              height: 6,
              decoration: BoxDecoration(
                color: _C.border,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('اختر الطابعة',
                  style: TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w800)),
            ),
            const Divider(height: 1, color: _C.border),
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: printers.length,
                separatorBuilder: (_, __) =>
                    const Divider(height: 1, color: _C.border),
                itemBuilder: (_, i) {
                  final d = printers[i];
                  final name = d.name as String? ?? 'طابعة';
                  final address = d.address as String? ?? '';
                  return ListTile(
                    leading: const Icon(Icons.print, color: _C.primary),
                    title: Text(name,
                        style:
                            const TextStyle(fontWeight: FontWeight.w700)),
                    subtitle: Text(address,
                        style: const TextStyle(
                            fontSize: 11, color: _C.textSecondary)),
                    onTap: () async {
                      if (address.isEmpty) return;
                      await BluetoothPrinterService.savePrinter(
                          address: address, name: name);
                      if (!context.mounted) return;
                      Navigator.pop(context, d);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
