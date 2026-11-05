import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _isManager = false;
  bool _isRep = false;
  String? _companyId;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadContext();
  }

  Future<void> _loadContext() async {
    try {
      final client = Supabase.instance.client;
      final user = client.auth.currentUser;
      if (user == null) return;

      // جلب أول شركة نشطة للمستخدم
      final members = await client
          .from('company_members')
          .select('company_id, role, is_active')
          .eq('user_id', user.id)
          .eq('is_active', true)
          .limit(1);

      if (members.isEmpty) {
        if (mounted) setState(() => _loading = false);
        return;
      }

      final member = members.first;
      final companyId = member['company_id'] as String;
      final role = member['role'] as String;

      // هل المستخدم مندوب نشط؟
      final reps = await client
          .from('sales_reps')
          .select('id')
          .eq('company_id', companyId)
          .eq('user_id', user.id)
          .eq('is_active', true)
          .limit(1);

      if (!mounted) return;
      setState(() {
        _companyId = companyId;
        _isManager = ['owner', 'manager', 'admin'].contains(role);
        _isRep = reps.isNotEmpty;
        _loading = false;
      });
    } catch (e) {
      if (mounted) setState(() => _loading = false);
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
          if (_companyId == null)
            const Card(
              color: Colors.orangeAccent,
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Text('لا توجد شركة نشطة لهذا الحساب'),
              ),
            )
          else ...[
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
                onTap: () => context.push('/admin/reps'),
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
