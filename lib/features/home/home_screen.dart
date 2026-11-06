import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// ============================================================
// ألوان Hesabi
// ============================================================
class _C {
  static const primary       = Color(0xFF00897B);
  static const primaryDark   = Color(0xFF00695C);
  static const primaryLight  = Color(0xFFE0F2F1);
  static const success       = Color(0xFF2E7D32);
  static const successLight  = Color(0xFFE8F5E9);
  static const warning       = Color(0xFFE65100);
  static const warningLight  = Color(0xFFFFF3E0);
  static const danger        = Color(0xFFC62828);
  static const dangerLight   = Color(0xFFFFEBEE);
  static const purple        = Color(0xFF6A1B9A);
  static const purpleLight   = Color(0xFFF3E5F5);
  static const blue          = Color(0xFF1565C0);
  static const blueLight     = Color(0xFFE3F2FD);
  static const surface       = Colors.white;
  static const surfaceGray   = Color(0xFFF5F5F5);
  static const border        = Color(0xFFE0E0E0);
  static const text          = Color(0xFF1A1A1A);
  static const textSecondary = Color(0xFF757575);
  static const bg            = Color(0xFFFAFAFA);
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // ─── الهوية ───
  String? _userName;
  List<Map<String, dynamic>> _memberships = [];
  String? _selectedCompanyId;
  String? _selectedCompanyName;
  String? _selectedRole;
  String? _repId;
  String? _repBranchId;
  String? _repType;
  bool _isManager = false;
  bool _isRep = false;

  // ─── KPIs ───
  double _todaySales = 0;
  double _todayCollections = 0;
  int _todayInvoices = 0;
  int _customersCount = 0;
  double _monthlyTarget = 0;
  double _monthlySales = 0;
  List<Map<String, dynamic>> _recentActivity = [];

  bool _loading = true;
  bool _kpisLoading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    try {
      final client = Supabase.instance.client;
      final user = client.auth.currentUser;
      if (user == null) return;

      _userName =
          user.userMetadata?['full_name'] as String? ?? user.email ?? '';

      final memberships = await client
          .from('company_members')
          .select('company_id, role, companies(name)')
          .eq('user_id', user.id)
          .eq('is_active', true);

      if ((memberships as List).isEmpty) {
        setState(() {
          _error = 'لا توجد شركة نشطة لهذا الحساب';
          _loading = false;
        });
        return;
      }

      _memberships = memberships.cast<Map<String, dynamic>>();
      final first = _memberships.first;
      _selectedCompanyId = first['company_id'] as String;
      _selectedRole = first['role'] as String?;
      _selectedCompanyName =
          (first['companies'] as Map?)?['name'] as String?;

      await _loadCompanyContext();
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    }
  }

  Future<void> _loadCompanyContext() async {
    if (_selectedCompanyId == null) return;
    setState(() => _loading = true);

    final client = Supabase.instance.client;
    final user = client.auth.currentUser;
    if (user == null) return;

    try {
      _isManager = ['owner', 'manager', 'admin'].contains(_selectedRole);

      final reps = await client
          .from('sales_reps')
          .select('id, branch_id, rep_type')
          .eq('company_id', _selectedCompanyId!)
          .eq('user_id', user.id)
          .eq('is_active', true)
          .limit(1);

      if ((reps as List).isNotEmpty) {
        _isRep = true;
        _repId = reps.first['id'] as String;
        _repBranchId = reps.first['branch_id'] as String?;
        _repType = reps.first['rep_type'] as String?;

        // نعرض الصفحة فوراً (KPIs لسه 0) ثم نحمّلها في الخلفية
        if (mounted) setState(() => _loading = false);
        _loadKpis();
      } else {
        _isRep = false;
        _repId = null;
        _repBranchId = null;
        _repType = null;
        _todaySales = 0;
        _todayCollections = 0;
        _todayInvoices = 0;
        _customersCount = 0;
        _monthlyTarget = 0;
        _monthlySales = 0;
        _recentActivity = [];
        if (mounted) setState(() => _loading = false);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    }
  }

  /// ⚡ استدعاء واحد فقط بدل 7 استعلامات
  Future<void> _loadKpis() async {
    if (_repId == null || _selectedCompanyId == null) return;

    setState(() => _kpisLoading = true);
    try {
      final res = await Supabase.instance.client.rpc(
        'get_rep_dashboard',
        params: {
          'p_company_id': _selectedCompanyId,
          'p_sales_rep_id': _repId,
        },
      );

      final data = (res is Map) ? res as Map<String, dynamic> : {};

      double _n(dynamic v) => (v as num?)?.toDouble() ?? 0;
      int _i(dynamic v) => ((v as num?)?.toInt()) ?? 0;

      _todaySales       = _n(data['today_sales']);
      _todayInvoices    = _i(data['today_invoices']);
      _todayCollections = _n(data['today_collections']);
      _monthlySales     = _n(data['month_sales']);
      _customersCount   = _i(data['customers_count']);
      _monthlyTarget    = _n(data['monthly_target']);

      // دمج البيع والتحصيل في قائمة نشاطات مرتبة
      final sales = (data['recent_sales'] as List?) ?? const [];
      final payments = (data['recent_payments'] as List?) ?? const [];
      final merged = <Map<String, dynamic>>[];
      for (final s in sales) {
        final m = (s as Map).cast<String, dynamic>();
        merged.add({
          'type': 'sale',
          'title': 'فاتورة #${m['title'] ?? ''}',
          'amount': _n(m['amount']),
          'date': m['date'],
        });
      }
      for (final p in payments) {
        final m = (p as Map).cast<String, dynamic>();
        merged.add({
          'type': 'payment',
          'title': 'تحصيل من عميل',
          'amount': _n(m['amount']),
          'date': m['date'],
        });
      }
      merged.sort((a, b) {
        final da = DateTime.tryParse(a['date']?.toString() ?? '');
        final db = DateTime.tryParse(b['date']?.toString() ?? '');
        if (da == null && db == null) return 0;
        if (da == null) return 1;
        if (db == null) return -1;
        return db.compareTo(da);
      });
      _recentActivity = merged.take(4).toList();

      if (mounted) {
        setState(() => _kpisLoading = false);
      }
    } catch (_) {
      if (mounted) setState(() => _kpisLoading = false);
    }
  }

  Future<void> _onCompanyChanged(String? companyId) async {
    if (companyId == null || companyId == _selectedCompanyId) return;
    final m = _memberships.firstWhere(
        (e) => e['company_id'] == companyId,
        orElse: () => {});
    setState(() {
      _selectedCompanyId = companyId;
      _selectedRole = m['role'] as String?;
      _selectedCompanyName =
          (m['companies'] as Map?)?['name'] as String?;
    });
    await _loadCompanyContext();
  }

  Future<void> _refresh() async {
    await _loadKpis();
  }

  Future<void> _logout() async {
    await Supabase.instance.client.auth.signOut();
    if (mounted) context.go('/login');
  }

  void _showMessage(String msg) => ScaffoldMessenger.of(context)
      .showSnackBar(SnackBar(content: Text(msg)));

  // ═════════════════════════════════════════════════════════════
  //    Greeting + helpers
  // ═════════════════════════════════════════════════════════════
  String _greeting() {
    final h = DateTime.now().hour;
    if (h >= 4 && h < 12) return 'صباح الخير';
    if (h >= 12 && h < 17) return 'طاب يومك';
    return 'مساء الخير';
  }

  String get _shortName {
    final n = _userName?.trim() ?? '';
    if (n.isEmpty) return '';
    return n.split(RegExp(r'\s+')).first;
  }

  // ═════════════════════════════════════════════════════════════
  //    Actions
  // ═════════════════════════════════════════════════════════════
  void _openPos() {
    if (_repBranchId == null) {
      _showMessage('لم يتم ربط حسابك بفرع. تواصل مع المدير.');
      return;
    }
    context.push('/pos', extra: {
      'companyId': _selectedCompanyId,
      'branchId': _repBranchId,
    });
  }

  void _openSalesHistory() {
    if (_repId == null) {
      _showMessage('حسابك غير مربوط كمندوب.');
      return;
    }
    context.push('/sales', extra: {
      'companyId': _selectedCompanyId,
      'salesRepId': _repId,
    });
  }

  void _openCollections() {
    if (_repId == null) {
      _showMessage('حسابك غير مربوط كمندوب.');
      return;
    }
    context.push('/collections', extra: {
      'companyId': _selectedCompanyId,
      'salesRepId': _repId,
    });
  }

  void _openCustomers() {
    if (_selectedCompanyId == null) return;
    context.push('/customers', extra: {
      'companyId': _selectedCompanyId,
    });
  }

  // ⬇️⬇️ جديد: دالة فتح المرتجعات
  void _openReturns() {
    if (_repId == null) {
      _showMessage('حسابك غير مربوط كمندوب.');
      return;
    }
    context.push('/returns', extra: {
      'companyId': _selectedCompanyId,
      'salesRepId': _repId,
    });
  }

  void _openMoreSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _MoreSheet(
        isManager: _isManager,
        isRep: _isRep,
        repType: _repType,
        onAction: (key) {
          Navigator.pop(context);
          switch (key) {
            case 'invoices':
              _openSalesHistory();
            case 'returns':
              _openReturns(); // ⬅️ تعديل هنا
            case 'custody':
              _showMessage('شاشة العهدة - قريباً');
            case 'visits':
              _showMessage('شاشة الزيارات - قريباً');
            case 'reports':
              _showMessage('شاشة التقارير - قريباً');
            case 'admin_reps':
              context.push('/admin/reps', extra: _selectedCompanyId);
            case 'logout':
              _logout();
          }
        },
      ),
    );
  }

  // ═════════════════════════════════════════════════════════════
  //    BUILD
  // ═════════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(
            child: CircularProgressIndicator(color: _C.primary)),
      );
    }

    if (_error != null) {
      return Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error, color: _C.danger, size: 48),
                const SizedBox(height: 16),
                Text(_error!, textAlign: TextAlign.center),
                const SizedBox(height: 16),
                ElevatedButton(
                    onPressed: _bootstrap,
                    child: const Text('إعادة المحاولة')),
                TextButton(
                    onPressed: _logout,
                    child: const Text('تسجيل الخروج')),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: _C.bg,
      body: RefreshIndicator(
        color: _C.primary,
        onRefresh: _refresh,
        child: CustomScrollView(
          slivers: [
            _buildAppBar(),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  if (_memberships.length > 1) ...[
                    _buildCompanySwitcher(),
                    const SizedBox(height: 16),
                  ],
                  _buildQuickActions(),
                  const SizedBox(height: 20),
                  _buildSectionTitle('نظرة سريعة'),
                  const SizedBox(height: 10),
                  _buildKpiGrid(),
                  if (_isRep && _monthlyTarget > 0) ...[
                    const SizedBox(height: 16),
                    _buildTargetCard(),
                  ],
                  if (_isRep) ...[
                    const SizedBox(height: 20),
                    _buildSectionTitle('آخر النشاطات'),
                    const SizedBox(height: 10),
                    _buildRecentActivity(),
                  ],
                  const SizedBox(height: 20),
                  _buildSectionTitle('حالة النظام'),
                  const SizedBox(height: 10),
                  _buildSyncStatus(),
                ]),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  // ═════════════════════════════════════════════════════════════
  //    Quick Actions
  // ═════════════════════════════════════════════════════════════
  Widget _buildQuickActions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('إجراءات سريعة'),
        const SizedBox(height: 10),
        Row(
          children: [
            if (_isRep) ...[
              Expanded(
                child: _QuickAction(
                  icon: Icons.point_of_sale,
                  label: 'بيع جديد',
                  color: _C.success,
                  onTap: _openPos,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _QuickAction(
                  icon: Icons.payments,
                  label: 'تحصيل',
                  color: _C.warning,
                  onTap: _openCollections,
                ),
              ),
              const SizedBox(width: 10),
            ],
            Expanded(
              child: _QuickAction(
                icon: Icons.people_alt,
                label: 'عملاء',
                color: _C.purple,
                onTap: _openCustomers,
              ),
            ),
            if (_isRep) ...[
              const SizedBox(width: 10),
              Expanded(
                child: _QuickAction(
                  icon: Icons.receipt_long,
                  label: 'فواتير',
                  color: _C.blue,
                  onTap: _openSalesHistory,
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }

  // ═════════════════════════════════════════════════════════════
  //    Recent Activity
  // ═════════════════════════════════════════════════════════════
  Widget _buildRecentActivity() {
    if (_kpisLoading && _recentActivity.isEmpty) {
      return _buildSkeletonBox(height: 180);
    }
    if (_recentActivity.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: _C.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _C.border),
        ),
        child: Column(
          children: [
            Icon(Icons.inbox_outlined,
                size: 40, color: _C.textSecondary.withOpacity(0.5)),
            const SizedBox(height: 10),
            const Text('لا توجد نشاطات بعد',
                style: TextStyle(
                    color: _C.textSecondary,
                    fontSize: 13,
                    fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            const Text('ابدأ بيعاً أو تحصيلاً جديداً',
                style: TextStyle(
                    color: _C.textSecondary, fontSize: 11)),
          ],
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: _C.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _C.border),
      ),
      child: Column(
        children: [
          for (int i = 0; i < _recentActivity.length; i++) ...[
            _buildActivityItem(_recentActivity[i]),
            if (i < _recentActivity.length - 1)
              const Divider(height: 1, color: _C.border, indent: 60),
          ],
        ],
      ),
    );
  }

  Widget _buildActivityItem(Map<String, dynamic> a) {
    final isSale = a['type'] == 'sale';
    final color = isSale ? _C.success : _C.warning;
    final icon = isSale ? Icons.receipt_long : Icons.payments;
    final date = DateTime.tryParse(a['date']?.toString() ?? '');
    final timeStr =
        date != null ? DateFormat('HH:mm', 'en').format(date) : '';
    final amount = (a['amount'] as num?)?.toDouble() ?? 0;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  a['title']?.toString() ?? '',
                  style: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w600),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(timeStr,
                    style: const TextStyle(
                        fontSize: 11, color: _C.textSecondary)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '${isSale ? '' : '- '}${amount.toStringAsFixed(0)} ج.م',
            style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: color),
          ),
        ],
      ),
    );
  }

  // ═════════════════════════════════════════════════════════════
  //    Bottom Navigation Bar
  // ═════════════════════════════════════════════════════════════
  Widget _buildBottomNav() {
    return Container(
      decoration: BoxDecoration(
        color: _C.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 12,
            offset: const Offset(0, -3),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 68,
          child: Row(
            children: [
              _NavItem(
                icon: Icons.home,
                label: 'الرئيسية',
                active: true,
                onTap: () {},
              ),
              if (_isRep) ...[
                _NavItem(
                  icon: Icons.point_of_sale,
                  label: 'بيع',
                  active: false,
                  onTap: _openPos,
                ),
                _NavItem(
                  icon: Icons.payments,
                  label: 'تحصيل',
                  active: false,
                  onTap: _openCollections,
                ),
              ],
              _NavItem(
                icon: Icons.people_alt,
                label: 'العملاء',
                active: false,
                onTap: _openCustomers,
              ),
              _NavItem(
                icon: Icons.more_horiz,
                label: 'المزيد',
                active: false,
                onTap: _openMoreSheet,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── رأس الصفحة ───
  Widget _buildAppBar() {
    return SliverAppBar(
      expandedHeight: 150,
      pinned: true,
      elevation: 0,
      backgroundColor: _C.primary,
      foregroundColor: Colors.white,
      actions: [
        IconButton(
          icon: const Icon(Icons.notifications_outlined),
          onPressed: () => _showMessage('الإشعارات - قريباً'),
        ),
        IconButton(
            icon: const Icon(Icons.logout), onPressed: _logout),
      ],
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [_C.primary, _C.primaryDark],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 60, 20, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    _shortName.isEmpty
                        ? _greeting()
                        : '${_greeting()}، $_shortName',
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Icon(Icons.business,
                          color: Colors.white.withOpacity(0.85),
                          size: 14),
                      const SizedBox(width: 5),
                      Expanded(
                        child: Text(
                          _selectedCompanyName ?? '',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.white.withOpacity(0.9),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
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

  Widget _buildCompanySwitcher() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: _C.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _C.border),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _selectedCompanyId,
          isExpanded: true,
          icon: const Icon(Icons.business, color: _C.primary),
          items: _memberships.map((m) {
            final company = m['companies'] as Map?;
            final name = (company?['name'] ?? 'شركة').toString();
            return DropdownMenuItem<String>(
              value: m['company_id'] as String,
              child: Text(name,
                  style:
                      const TextStyle(fontWeight: FontWeight.w600)),
            );
          }).toList(),
          onChanged: _onCompanyChanged,
        ),
      ),
    );
  }

  // ─── KPIs ───
  Widget _buildKpiGrid() {
    if (_kpisLoading) return _buildSkeletonGrid();

    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 1.35,
      children: [
        _buildKpiCard(
          title: 'مبيعات اليوم',
          value: _todaySales.toStringAsFixed(0),
          suffix: 'ج.م',
          icon: Icons.trending_up,
          color: _C.success,
          onTap: _openSalesHistory,
        ),
        _buildKpiCard(
          title: 'تحصيلات اليوم',
          value: _todayCollections.toStringAsFixed(0),
          suffix: 'ج.م',
          icon: Icons.payments,
          color: _C.warning,
          onTap: _openCollections,
        ),
        _buildKpiCard(
          title: 'فواتير اليوم',
          value: _todayInvoices.toString(),
          suffix: 'فاتورة',
          icon: Icons.receipt_long,
          color: _C.primary,
          onTap: _openSalesHistory,
        ),
        _buildKpiCard(
          title: 'عدد العملاء',
          value: _customersCount.toString(),
          suffix: 'عميل',
          icon: Icons.people,
          color: _C.purple,
          onTap: _openCustomers,
        ),
      ],
    );
  }

  Widget _buildKpiCard({
    required String title,
    required String value,
    required String suffix,
    required IconData icon,
    required Color color,
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: _C.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _C.border),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade700,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ]),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(suffix,
                    style: TextStyle(
                        fontSize: 11, color: Colors.grey.shade500)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ─── Skeleton loaders ───
  Widget _buildSkeletonBox({required double height}) {
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: _C.surfaceGray,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _C.border),
      ),
      child: Center(
        child: SizedBox(
          width: 22,
          height: 22,
          child: CircularProgressIndicator(
              strokeWidth: 2, color: _C.primary.withOpacity(0.5)),
        ),
      ),
    );
  }

  Widget _buildSkeletonGrid() {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 1.35,
      children: List.generate(4, (_) => _buildSkeletonBox(height: 100)),
    );
  }

  // ─── بطاقة الهدف ───
  Widget _buildTargetCard() {
    final percent =
        (_monthlySales / _monthlyTarget * 100).clamp(0, 100);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            _C.primary.withOpacity(0.08),
            _C.primaryDark.withOpacity(0.15),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _C.primary.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Icon(Icons.flag, color: _C.primary, size: 20),
            const SizedBox(width: 8),
            const Text('هدف الشهر',
                style: TextStyle(
                    fontWeight: FontWeight.bold, fontSize: 14)),
            const Spacer(),
            Text('${percent.toStringAsFixed(0)}%',
                style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: _C.primary,
                    fontSize: 16)),
          ]),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: percent / 100,
              minHeight: 10,
              backgroundColor: Colors.white.withOpacity(0.6),
              valueColor: const AlwaysStoppedAnimation(_C.primary),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('مبيعات: ${_monthlySales.toStringAsFixed(0)} ج.م',
                  style: TextStyle(
                      fontSize: 12, color: Colors.grey.shade700)),
              Text('الهدف: ${_monthlyTarget.toStringAsFixed(0)} ج.م',
                  style: TextStyle(
                      fontSize: 12, color: Colors.grey.shade700)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Text(title,
          style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: _C.text)),
    );
  }

  Widget _buildSyncStatus() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _C.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _C.success.withOpacity(0.3)),
      ),
      child: Row(children: [
        Container(
          width: 12,
          height: 12,
          decoration: const BoxDecoration(
              color: _C.success, shape: BoxShape.circle),
        ),
        const SizedBox(width: 12),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('متصل بالإنترنت',
                  style: TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 14)),
              Text('جميع البيانات محدثة',
                  style: TextStyle(
                      fontSize: 12, color: _C.textSecondary)),
            ],
          ),
        ),
        Icon(Icons.cloud_done, color: _C.success.withOpacity(0.8)),
      ]),
    );
  }
}

// ============================================================
// Quick Action Card
// ============================================================
class _QuickAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _QuickAction({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 14),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withOpacity(0.25)),
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(height: 8),
            Text(label,
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: color),
                maxLines: 1,
                overflow: TextOverflow.ellipsis),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// Bottom Navigation Item
// ============================================================
class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;
  const _NavItem({
    required this.icon,
    required this.label,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = active ? _C.primary : _C.textSecondary;
    return Expanded(
      child: InkWell(
        onTap: onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: active ? _C.primaryLight : Colors.transparent,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(height: 2),
            Text(label,
                style: TextStyle(
                    fontSize: 10.5,
                    fontWeight:
                        active ? FontWeight.bold : FontWeight.w600,
                    color: color)),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// More Sheet
// ============================================================
class _MoreSheet extends StatelessWidget {
  final bool isManager;
  final bool isRep;
  final String? repType;
  final ValueChanged<String> onAction;

  const _MoreSheet({
    required this.isManager,
    required this.isRep,
    required this.repType,
    required this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    final items = <_MoreItem>[];

    if (isRep) {
      items.addAll([
        _MoreItem(
            'invoices', 'الفواتير', Icons.receipt_long, _C.blue),
        _MoreItem('returns', 'المرتجعات', Icons.assignment_return,
            _C.danger),
        if (repType == 'custody')
          _MoreItem('custody', 'العهدة', Icons.inventory_2, _C.primary),
        _MoreItem('visits', 'الزيارات', Icons.location_on, _C.purple),
        _MoreItem('reports', 'التقارير', Icons.bar_chart, _C.blue),
      ]);
    }

    if (isManager) {
      items.add(_MoreItem('admin_reps', 'إدارة المندوبين',
          Icons.manage_accounts, _C.blue));
    }

    items.add(
        _MoreItem('logout', 'تسجيل الخروج', Icons.logout, _C.danger));

    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.4,
      maxChildSize: 0.85,
      expand: false,
      builder: (context, scroll) => Container(
        decoration: const BoxDecoration(
          color: _C.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(children: [
          const SizedBox(height: 10),
          Center(
            child: Container(
              width: 44,
              height: 4,
              decoration: BoxDecoration(
                  color: Colors.grey.shade400,
                  borderRadius: BorderRadius.circular(2)),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
            child: Row(children: [
              const Text('المزيد',
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: _C.text)),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context),
              ),
            ]),
          ),
          const Divider(height: 1, color: _C.border),
          Expanded(
            child: ListView(
              controller: scroll,
              padding: const EdgeInsets.all(16),
              children: [
                for (final item in items) ...[
                  _buildTile(context, item),
                  const SizedBox(height: 8),
                ],
              ],
            ),
          ),
        ]),
      ),
    );
  }

  Widget _buildTile(BuildContext context, _MoreItem item) {
    return Material(
      color: _C.surfaceGray,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => onAction(item.key),
        child: Padding(
          padding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: item.color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(item.icon, color: item.color, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(item.label,
                  style: const TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w600,
                      color: _C.text)),
            ),
            const Icon(Icons.chevron_left,
                color: _C.textSecondary, size: 20),
          ]),
        ),
      ),
    );
  }
}

class _MoreItem {
  final String key;
  final String label;
  final IconData icon;
  final Color color;
  const _MoreItem(this.key, this.label, this.icon, this.color);
}
