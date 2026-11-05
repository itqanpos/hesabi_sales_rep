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

  bool _loading = true;
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

      _userName = user.userMetadata?['full_name'] as String? ?? user.email ?? '';

      final memberships = await client
          .from('company_members')
          .select('company_id, role, companies(name)')
          .eq('user_id', user.id)
          .eq('is_active', true);

      if ((memberships as List).isEmpty) {
        setState(() { _error = 'لا توجد شركة نشطة لهذا الحساب'; _loading = false; });
        return;
      }

      _memberships = memberships.cast<Map<String, dynamic>>();
      final first = _memberships.first;
      _selectedCompanyId = first['company_id'] as String;
      _selectedRole = first['role'] as String?;
      _selectedCompanyName = (first['companies'] as Map?)?['name'] as String?;

      await _loadCompanyContext();
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _loading = false; });
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
        await _loadKpis(user.id);
      } else {
        _isRep = false;
        _repId = null; _repBranchId = null; _repType = null;
        _todaySales = 0; _todayCollections = 0;
        _todayInvoices = 0; _customersCount = 0;
        _monthlyTarget = 0; _monthlySales = 0;
      }

      if (mounted) setState(() => _loading = false);
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _loading = false; });
    }
  }

  Future<void> _loadKpis(String userId) async {
    final client = Supabase.instance.client;
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day).toUtc();
    final monthStart = DateTime(now.year, now.month, 1).toUtc();

    try {
      final todaySalesRes = await client
          .from('sales').select('id, total')
          .eq('company_id', _selectedCompanyId!)
          .eq('sales_rep_id', _repId!)
          .neq('status', 'cancelled')
          .gte('sale_date', todayStart.toIso8601String());
      final list = (todaySalesRes as List).cast<Map<String, dynamic>>();
      _todayInvoices = list.length;
      _todaySales = list.fold<double>(0, (s, e) => s + ((e['total'] as num?)?.toDouble() ?? 0));
    } catch (_) { _todaySales = 0; _todayInvoices = 0; }

    try {
      final monthSalesRes = await client
          .from('sales').select('total')
          .eq('company_id', _selectedCompanyId!)
          .eq('sales_rep_id', _repId!)
          .neq('status', 'cancelled')
          .gte('sale_date', monthStart.toIso8601String());
      _monthlySales = (monthSalesRes as List).fold<double>(0,
          (s, e) => s + ((e['total'] as num?)?.toDouble() ?? 0));
    } catch (_) { _monthlySales = 0; }

    try {
      final paymentsRes = await client
          .from('customer_payments').select('amount')
          .eq('company_id', _selectedCompanyId!)
          .gte('created_at', todayStart.toIso8601String());
      _todayCollections = (paymentsRes as List).fold<double>(0,
          (s, e) => s + ((e['amount'] as num?)?.toDouble() ?? 0));
    } catch (_) { _todayCollections = 0; }

    try {
      final customersRes = await client
          .from('customers').select('id')
          .eq('company_id', _selectedCompanyId!)
          .eq('is_active', true);
      _customersCount = (customersRes as List).length;
    } catch (_) { _customersCount = 0; }

    try {
      final repLink = await client
          .from('sales_reps').select('rep_id')
          .eq('id', _repId!).maybeSingle();
      final legacyRepId = repLink?['rep_id'];
      if (legacyRepId != null) {
        final targetRes = await client
            .from('reps').select('target').eq('id', legacyRepId).maybeSingle();
        _monthlyTarget = (targetRes?['target'] as num?)?.toDouble() ?? 0;
      }
    } catch (_) { _monthlyTarget = 0; }
  }

  Future<void> _onCompanyChanged(String? companyId) async {
    if (companyId == null || companyId == _selectedCompanyId) return;
    final m = _memberships.firstWhere((e) => e['company_id'] == companyId, orElse: () => {});
    setState(() {
      _selectedCompanyId = companyId;
      _selectedRole = m['role'] as String?;
      _selectedCompanyName = (m['companies'] as Map?)?['name'] as String?;
    });
    await _loadCompanyContext();
  }

  Future<void> _refresh() async => await _loadCompanyContext();

  Future<void> _logout() async {
    await Supabase.instance.client.auth.signOut();
    if (mounted) context.go('/login');
  }

  void _showMessage(String msg) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

  // ═════════════════════════════════════════════════════════════
  //    Actions handlers
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
    if (_repId == null) { _showMessage('حسابك غير مربوط كمندوب.'); return; }
    context.push('/sales', extra: {
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
            case 'customers': _showMessage('شاشة العملاء - قريباً');
            case 'collections': _showMessage('شاشة التحصيل - قريباً');
            case 'returns': _showMessage('شاشة المرتجعات - قريباً');
            case 'custody': _showMessage('شاشة العهدة - قريباً');
            case 'visits': _showMessage('شاشة الزيارات - قريباً');
            case 'reports': _showMessage('شاشة التقارير - قريباً');
            case 'admin_reps':
              context.push('/admin/reps', extra: _selectedCompanyId);
            case 'logout': _logout();
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
        body: Center(child: CircularProgressIndicator(color: _C.primary)),
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
                ElevatedButton(onPressed: _bootstrap, child: const Text('إعادة المحاولة')),
                TextButton(onPressed: _logout, child: const Text('تسجيل الخروج')),
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
              padding: const EdgeInsets.all(16),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  if (_memberships.length > 1) ...[
                    _buildCompanySwitcher(),
                    const SizedBox(height: 16),
                  ],
                  _buildStatusRow(),
                  const SizedBox(height: 16),
                  _buildKpiGrid(),
                  if (_isRep && _monthlyTarget > 0) ...[
                    const SizedBox(height: 16),
                    _buildTargetCard(),
                  ],
                  const SizedBox(height: 20),
                  _buildSectionTitle('حالة النظام'),
                  const SizedBox(height: 10),
                  _buildSyncStatus(),
                  const SizedBox(height: 80), // مساحة للشريط السفلي
                ]),
              ),
            ),
          ],
        ),
      ),
      // ═════════════════════════════════════════════════════════
      //   الشريط السفلي (Bottom Navigation Bar) — كامل العرض
      // ═════════════════════════════════════════════════════════
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  // ═════════════════════════════════════════════════════════════
  //   Bottom Navigation Bar
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
                  label: 'البيع',
                  active: false,
                  onTap: _openPos,
                ),
                _NavItem(
                  icon: Icons.receipt_long,
                  label: 'الفواتير',
                  active: false,
                  onTap: _openSalesHistory,
                ),
              ],
              _NavItem(
                icon: Icons.people_alt,
                label: 'العملاء',
                active: false,
                onTap: () => _showMessage('شاشة العملاء - قريباً'),
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
      expandedHeight: 160,
      pinned: true,
      elevation: 0,
      backgroundColor: _C.primary,
      foregroundColor: Colors.white,
      actions: [
        IconButton(
          icon: const Icon(Icons.notifications_outlined),
          onPressed: () => _showMessage('الإشعارات - قريباً'),
        ),
        IconButton(icon: const Icon(Icons.logout), onPressed: _logout),
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
              padding: const EdgeInsets.fromLTRB(20, 60, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    'أهلاً، ${_userName ?? ""}',
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _selectedCompanyName ?? '',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.white.withOpacity(0.9),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ─── مُبدّل الشركات ───
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
                  style: const TextStyle(fontWeight: FontWeight.w600)),
            );
          }).toList(),
          onChanged: _onCompanyChanged,
        ),
      ),
    );
  }

  // ─── شارات الحالة ───
  Widget _buildStatusRow() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        if (_isManager) _buildChip('مدير', Icons.admin_panel_settings, _C.purple),
        if (_isRep)
          _buildChip(
            _repType == 'custody' ? 'مندوب بعهدة' : 'مندوب بدون عهدة',
            Icons.badge,
            _C.success,
          ),
        _buildChip('متصل', Icons.wifi, _C.blue),
      ],
    );
  }

  Widget _buildChip(String label, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(width: 6),
          Text(label,
              style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.bold,
                  fontSize: 12)),
        ],
      ),
    );
  }

  // ─── KPIs ───
  Widget _buildKpiGrid() {
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

  // ─── بطاقة الهدف ───
  Widget _buildTargetCard() {
    final percent = (_monthlySales / _monthlyTarget * 100).clamp(0, 100);
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
                style:
                    TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
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
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
              Text('الهدف: ${_monthlyTarget.toStringAsFixed(0)} ج.م',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
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

  // ─── حالة المزامنة ───
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
          width: 12, height: 12,
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
                  style:
                      TextStyle(fontSize: 12, color: _C.textSecondary)),
            ],
          ),
        ),
        Icon(Icons.cloud_done, color: _C.success.withOpacity(0.8)),
      ]),
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
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: active ? _C.primaryLight : Colors.transparent,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: active ? FontWeight.bold : FontWeight.w600,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// More Sheet (نافذة "المزيد")
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
        _MoreItem('customers', 'العملاء', Icons.people_alt, _C.purple),
        _MoreItem('collections', 'التحصيلات', Icons.payments, _C.warning),
        _MoreItem('returns', 'المرتجعات', Icons.assignment_return, _C.danger),
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

    items.add(_MoreItem('logout', 'تسجيل الخروج', Icons.logout, _C.danger));

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
              width: 44, height: 4,
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
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(children: [
            Container(
              width: 44, height: 44,
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
