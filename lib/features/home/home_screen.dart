import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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

      // 1) اسم المستخدم (full_name من profiles، وإلا نستخدم الإيميل من auth)
      final profile = await client
          .from('profiles')
          .select('full_name')
          .eq('id', user.id)
          .maybeSingle();
      _userName = (profile?['full_name'] ?? user.email ?? '') as String;

      // 2) العضويات
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
      _selectedCompanyName = (first['companies'] as Map?)?['name'] as String?;

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
        await _loadKpis(user.id);
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
      }

      if (mounted) setState(() => _loading = false);
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    }
  }

  Future<void> _loadKpis(String userId) async {
    final client = Supabase.instance.client;
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day).toUtc();
    final monthStart = DateTime(now.year, now.month, 1).toUtc();

    try {
      final todaySalesRes = await client
          .from('sales')
          .select('id, total')
          .eq('company_id', _selectedCompanyId!)
          .eq('sales_rep_id', _repId!)
          .neq('status', 'cancelled')
          .gte('sale_date', todayStart.toIso8601String());

      final todaySalesList = (todaySalesRes as List).cast<Map<String, dynamic>>();
      _todayInvoices = todaySalesList.length;
      _todaySales = todaySalesList.fold<double>(
          0, (sum, s) => sum + ((s['total'] as num?)?.toDouble() ?? 0));
    } catch (_) {
      _todaySales = 0;
      _todayInvoices = 0;
    }

    try {
      final monthSalesRes = await client
          .from('sales')
          .select('total')
          .eq('company_id', _selectedCompanyId!)
          .eq('sales_rep_id', _repId!)
          .neq('status', 'cancelled')
          .gte('sale_date', monthStart.toIso8601String());
      _monthlySales = (monthSalesRes as List).fold<double>(
          0, (sum, s) => sum + ((s['total'] as num?)?.toDouble() ?? 0));
    } catch (_) {
      _monthlySales = 0;
    }

    try {
      final paymentsRes = await client
          .from('customer_payments')
          .select('amount')
          .eq('company_id', _selectedCompanyId!)
          .gte('created_at', todayStart.toIso8601String());
      _todayCollections = (paymentsRes as List).fold<double>(
          0, (sum, p) => sum + ((p['amount'] as num?)?.toDouble() ?? 0));
    } catch (_) {
      _todayCollections = 0;
    }

    try {
      final customersRes = await client
          .from('customers')
          .select('id')
          .eq('company_id', _selectedCompanyId!)
          .eq('is_active', true);
      _customersCount = (customersRes as List).length;
    } catch (_) {
      _customersCount = 0;
    }

    try {
      final repLink = await client
          .from('sales_reps')
          .select('rep_id')
          .eq('id', _repId!)
          .maybeSingle();
      final legacyRepId = repLink?['rep_id'];
      if (legacyRepId != null) {
        final targetRes = await client
            .from('reps')
            .select('target')
            .eq('id', legacyRepId)
            .maybeSingle();
        _monthlyTarget = (targetRes?['target'] as num?)?.toDouble() ?? 0;
      }
    } catch (_) {
      _monthlyTarget = 0;
    }
  }

  Future<void> _onCompanyChanged(String? companyId) async {
    if (companyId == null || companyId == _selectedCompanyId) return;
    final m = _memberships.firstWhere(
      (e) => e['company_id'] == companyId,
      orElse: () => {},
    );
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

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_error != null) {
      return Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error, color: Colors.red, size: 48),
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
      backgroundColor: const Color(0xFFF5F7FA),
      body: RefreshIndicator(
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
                  const SizedBox(height: 24),
                  _buildSectionTitle('الإجراءات السريعة'),
                  const SizedBox(height: 12),
                  _buildActionsGrid(),
                  const SizedBox(height: 24),
                  _buildSectionTitle('حالة النظام'),
                  const SizedBox(height: 12),
                  _buildSyncStatus(),
                  const SizedBox(height: 32),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAppBar() {
    return SliverAppBar(
      expandedHeight: 160,
      pinned: true,
      elevation: 0,
      backgroundColor: const Color(0xFF1E88E5),
      foregroundColor: Colors.white,
      actions: [
        IconButton(
          icon: const Icon(Icons.notifications_outlined),
          onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('الإشعارات - قيد التطوير')),
          ),
        ),
        IconButton(icon: const Icon(Icons.logout), onPressed: _logout),
      ],
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF1E88E5), Color(0xFF1565C0)],
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

  Widget _buildCompanySwitcher() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _selectedCompanyId,
          isExpanded: true,
          icon: const Icon(Icons.business, color: Color(0xFF1E88E5)),
          items: _memberships.map((m) {
            final company = m['companies'] as Map?;
            final name = (company?['name'] ?? 'شركة').toString();
            return DropdownMenuItem<String>(
              value: m['company_id'] as String,
              child: Text(name, style: const TextStyle(fontWeight: FontWeight.w600)),
            );
          }).toList(),
          onChanged: _onCompanyChanged,
        ),
      ),
    );
  }

  Widget _buildStatusRow() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        if (_isManager) _buildChip('مدير', Icons.admin_panel_settings, Colors.purple),
        if (_isRep)
          _buildChip(
            _repType == 'custody' ? 'مندوب بعهدة' : 'مندوب بدون عهدة',
            Icons.badge,
            Colors.green,
          ),
        _buildChip('متصل', Icons.wifi, Colors.blue),
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
          Text(
            label,
            style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 12),
          ),
        ],
      ),
    );
  }

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
          color: const Color(0xFF2E7D32),
        ),
        _buildKpiCard(
          title: 'تحصيلات اليوم',
          value: _todayCollections.toStringAsFixed(0),
          suffix: 'ج.م',
          icon: Icons.payments,
          color: const Color(0xFFEF6C00),
        ),
        _buildKpiCard(
          title: 'فواتير اليوم',
          value: _todayInvoices.toString(),
          suffix: 'فاتورة',
          icon: Icons.receipt_long,
          color: const Color(0xFF1E88E5),
        ),
        _buildKpiCard(
          title: 'عدد العملاء',
          value: _customersCount.toString(),
          suffix: 'عميل',
          icon: Icons.people,
          color: const Color(0xFF6A1B9A),
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
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
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
            ],
          ),
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
              Text(
                suffix,
                style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTargetCard() {
    final percent = (_monthlySales / _monthlyTarget * 100).clamp(0, 100);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF1E88E5).withOpacity(0.08),
            const Color(0xFF1565C0).withOpacity(0.15),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF1E88E5).withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.flag, color: Color(0xFF1E88E5), size: 20),
              const SizedBox(width: 8),
              const Text('هدف الشهر', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              const Spacer(),
              Text(
                '${percent.toStringAsFixed(0)}%',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1E88E5),
                  fontSize: 16,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: percent / 100,
              minHeight: 10,
              backgroundColor: Colors.white.withOpacity(0.6),
              valueColor: const AlwaysStoppedAnimation(Color(0xFF1E88E5)),
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
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
          color: Color(0xFF333333),
        ),
      ),
    );
  }

  Widget _buildActionsGrid() {
    final actions = <_ActionItem>[];

    if (_isRep) {
      actions.add(_ActionItem(
        title: 'نقطة البيع',
        icon: Icons.point_of_sale,
        color: const Color(0xFF2E7D32),
        onTap: () {
          if (_repBranchId == null) {
            _showMessage('لم يتم ربط حسابك بفرع. تواصل مع المدير.');
            return;
          }
          context.push('/pos', extra: {
            'companyId': _selectedCompanyId,
            'branchId': _repBranchId,
          });
        },
      ));
      actions.add(_ActionItem(
        title: 'العملاء',
        icon: Icons.people_alt,
        color: const Color(0xFF6A1B9A),
        onTap: () => _showMessage('شاشة العملاء - قريبًا'),
      ));
      actions.add(_ActionItem(
        title: 'التحصيل',
        icon: Icons.payments,
        color: const Color(0xFFEF6C00),
        onTap: () => _showMessage('شاشة التحصيل - قريبًا'),
      ));
      actions.add(_ActionItem(
        title: 'المرتجعات',
        icon: Icons.assignment_return,
        color: const Color(0xFFC62828),
        onTap: () => _showMessage('شاشة المرتجعات - قريبًا'),
      ));
      if (_repType == 'custody') {
        actions.add(_ActionItem(
          title: 'العهدة',
          icon: Icons.inventory_2,
          color: const Color(0xFF00838F),
          onTap: () => _showMessage('شاشة العهدة - قريبًا'),
        ));
      }
      actions.add(_ActionItem(
        title: 'الزيارات',
        icon: Icons.location_on,
        color: const Color(0xFF5E35B1),
        onTap: () => _showMessage('شاشة الزيارات - قريبًا'),
      ));
      actions.add(_ActionItem(
        title: 'التقارير',
        icon: Icons.bar_chart,
        color: const Color(0xFF1E88E5),
        onTap: () => _showMessage('شاشة التقارير - قريبًا'),
      ));
    }

    if (_isManager) {
      actions.add(_ActionItem(
        title: 'إدارة المندوبين',
        icon: Icons.manage_accounts,
        color: const Color(0xFF1565C0),
        onTap: () => context.push('/admin/reps', extra: _selectedCompanyId),
      ));
    }

    if (actions.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Center(
          child: Text('لا توجد إجراءات متاحة لحسابك حالياً',
              style: TextStyle(color: Colors.grey)),
        ),
      );
    }

    return GridView.count(
      crossAxisCount: 3,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 1.0,
      children: actions.map((a) => _buildActionCard(a)).toList(),
    );
  }

  Widget _buildActionCard(_ActionItem action) {
    return InkWell(
      onTap: action.onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: action.color.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(action.icon, color: action.color, size: 26),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text(
                action.title,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF333333),
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSyncStatus() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.green.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Container(
            width: 12,
            height: 12,
            decoration: const BoxDecoration(
              color: Colors.green,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('متصل بالإنترنت',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                Text('جميع البيانات محدثة',
                    style: TextStyle(fontSize: 12, color: Colors.grey)),
              ],
            ),
          ),
          Icon(Icons.cloud_done, color: Colors.green.shade600),
        ],
      ),
    );
  }

  void _showMessage(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }
}

class _ActionItem {
  final String title;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  _ActionItem({
    required this.title,
    required this.icon,
    required this.color,
    required this.onTap,
  });
}
