import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<Map<String, dynamic>> _memberships = [];
  String? _selectedCompanyId;
  bool _isManager = false;
  bool _isRep = false;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadMemberships();
  }

  Future<void> _loadMemberships() async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) return;

      // جلب كل الشركات التي ينتمي إليها المستخدم
      final res = await Supabase.instance.client
          .from('company_members')
          .select('company_id, role, companies(name)')
          .eq('user_id', user.id)
          .eq('is_active', true);

      if (res.isEmpty) {
        if (mounted) {
          setState(() {
            _error = 'لا توجد شركة نشطة لهذا الحساب';
            _loading = false;
          });
        }
        return;
      }

      if (mounted) {
        setState(() {
          _memberships = (res as List).cast<Map<String, dynamic>>();
          _selectedCompanyId = _memberships.first['company_id'] as String;
        });
      }

      await _updateContext();
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    }
  }

  Future<void> _updateContext() async {
    if (_selectedCompanyId == null) return;
    setState(() => _loading = true);

    final user = Supabase.instance.client.auth.currentUser;
    final member = _memberships.firstWhere(
      (m) => m['company_id'] == _selectedCompanyId,
      orElse: () => {},
    );

    final role = member['role'] as String? ?? 'user';
    bool isRep = false;

    try {
      // التحقق هل المستخدم مندوب في هذه الشركة تحديدًا
      final reps = await Supabase.instance.client
          .from('sales_reps')
          .select('id')
          .eq('company_id', _selectedCompanyId!)
          .eq('user_id', user!.id)
          .eq('is_active', true)
          .limit(1);
      isRep = reps.isNotEmpty;
    } catch (_) {}

    if (mounted) {
      setState(() {
        _isManager = ['owner', 'manager', 'admin'].contains(role);
        _isRep = isRep;
        _loading = false;
        _error = null;
      });
    }
  }

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
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_error!, style: const TextStyle(color: Colors.red)),
              const SizedBox(height: 16),
              ElevatedButton(onPressed: _loadMemberships, child: const Text('إعادة المحاولة')),
              TextButton(onPressed: _logout, child: const Text('تسجيل الخروج')),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('حسابي - المندوب'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _logout,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // قائمة اختيار الشركة
          if (_memberships.length > 1) ...[
            DropdownButtonFormField<String>(
              value: _selectedCompanyId,
              decoration: const InputDecoration(
                labelText: 'الشركة النشطة',
                prefixIcon: Icon(Icons.business),
                border: OutlineInputBorder(),
              ),
              items: _memberships.map((m) {
                final company = m['companies'] as Map<String, dynamic>?;
                final name = company?['name'] ?? 'شركة غير معروفة';
                return DropdownMenuItem(
                  value: m['company_id'] as String,
                  child: Text(name as String),
                );
              }).toList(),
              onChanged: (val) {
                if (val != null) {
                  setState(() => _selectedCompanyId = val);
                  _updateContext();
                }
              },
            ),
            const SizedBox(height: 16),
          ] else if (_memberships.isNotEmpty) ...[
            Card(
              child: ListTile(
                leading: const Icon(Icons.business),
                title: const Text('الشركة النشطة'),
                subtitle: Text((_memberships.first['companies'] as Map<String, dynamic>?)?['name'] ?? ''),
              ),
            ),
            const SizedBox(height: 16),
          ],

          _StatusCard(
            title: 'حالة الحساب',
            isRep: _isRep,
            isManager: _isManager,
          ),
          const SizedBox(height: 16),

          if (_isManager)
            _MenuCard(
              title: 'إدارة المندوبين',
              subtitle: 'تعيين أعضاء الشركة كمندوبين',
              icon: Icons.people,
              onTap: () => context.push('/admin/reps', extra: _selectedCompanyId),
            ),
          if (_isRep)
            _MenuCard(
              title: 'نقطة البيع',
              subtitle: 'سيتم تفعيلها في المرحلة القادمة',
              icon: Icons.point_of_sale,
              onTap: () => ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('قيد التطوير')),
              ),
            ),
        ],
      ),
    );
  }
}

class _StatusCard extends StatelessWidget {
  final String title;
  final bool isRep;
  final bool isManager;

  const _StatusCard({
    required this.title,
    required this.isRep,
    required this.isManager,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style: const TextStyle(
                    fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            _chip('مندوب', isRep),
            const SizedBox(height: 8),
            _chip('مدير', isManager),
          ],
        ),
      ),
    );
  }

  Widget _chip(String label, bool active) {
    return Row(
      children: [
        Icon(
          active ? Icons.check_circle : Icons.cancel,
          color: active ? Colors.green : Colors.grey,
          size: 20,
        ),
        const SizedBox(width: 8),
        Text('$label: ${active ? "نعم" : "لا"}'),
      ],
    );
  }
}

class _MenuCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;

  const _MenuCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: Icon(icon, color: Theme.of(context).colorScheme.primary),
        title: Text(title,
            style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.arrow_back_ios),
        onTap: onTap,
      ),
    );
  }
}
