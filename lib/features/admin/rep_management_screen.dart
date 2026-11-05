import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class RepManagementScreen extends StatefulWidget {
  final String? companyId;
  const RepManagementScreen({super.key, required this.companyId}); // <--- هذا هو السطر الذي يحدد المتغير

  @override
  State<RepManagementScreen> createState() => _RepManagementScreenState();
}

class _RepManagementScreenState extends State<RepManagementScreen> {
  String? _companyId;
  List<Map<String, dynamic>> _candidates = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _companyId = widget.companyId;
    if (_companyId == null) {
      setState(() {
        _error = 'لم يتم تحديد الشركة، يرجى العودة للرئيسية وإعادة المحاولة.';
        _loading = false;
      });
    } else {
      _loadCandidates();
    }
  }

  Future<void> _loadCandidates() async {
    if (_companyId == null) return;
    setState(() => _loading = true);
    try {
      final res = await Supabase.instance.client.rpc(
        'admin_list_rep_candidates',
        params: {'p_company_id': _companyId},
      );
      final list = (res as List).cast<Map<String, dynamic>>();
      if (!mounted) return;
      setState(() {
        _candidates = list;
        _loading = false;
        _error = null;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    }
  }

  Future<void> _openEditSheet(Map<String, dynamic> candidate) async {
    if (_companyId == null) return;

    final branches = await Supabase.instance.client
        .from('branches')
        .select('id, name')
        .eq('company_id', _companyId!)
        .eq('is_active', true)
        .order('name');

    if (!mounted) return;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _RepFormSheet(
        companyId: _companyId!,
        userId: candidate['user_id'] as String,
        userName: (candidate['full_name'] ?? '') as String,
        branches: (branches as List).cast<Map<String, dynamic>>(),
        onSaved: _loadCandidates,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('إدارة المندوبين')),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error, color: Colors.red, size: 48),
              const SizedBox(height: 12),
              Text(_error!, textAlign: TextAlign.center),
              const SizedBox(height: 12),
              if (_companyId != null)
                ElevatedButton(
                  onPressed: _loadCandidates,
                  child: const Text('إعادة المحاولة'),
                ),
            ],
          ),
        ),
      );
    }
    if (_candidates.isEmpty) {
      return const Center(child: Text('لا يوجد أعضاء في الشركة'));
    }

    return RefreshIndicator(
      onRefresh: _loadCandidates,
      child: ListView.separated(
        padding: const EdgeInsets.all(12),
        itemCount: _candidates.length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (context, i) {
          final c = _candidates[i];
          final isRep = c['is_already_rep'] == true;
          final name = (c['full_name'] ?? 'بدون اسم') as String;
          final email = (c['email'] ?? '') as String;
          final role = (c['role'] ?? '') as String;

          return Card(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Row(
                children: [
                  CircleAvatar(
                    backgroundColor:
                        isRep ? Colors.green.shade100 : Colors.grey.shade200,
                    child: Icon(
                      isRep ? Icons.badge : Icons.person,
                      color: isRep ? Colors.green.shade800 : Colors.grey.shade700,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          name,
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 16),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '$role • ${isRep ? "مندوب" : "عضو"}',
                          style: TextStyle(
                            color: isRep
                                ? Colors.green.shade800
                                : Colors.grey.shade600,
                            fontSize: 13,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (email.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            email,
                            style: TextStyle(
                              color: Colors.grey.shade500,
                              fontSize: 12,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textDirection: TextDirection.ltr,
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton.tonal(
                    onPressed: () => _openEditSheet(c),
                    child: Text(isRep ? 'تعديل' : 'تعيين'),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _RepFormSheet extends StatefulWidget {
  final String companyId;
  final String userId;
  final String userName;
  final List<Map<String, dynamic>> branches;
  final VoidCallback onSaved;

  const _RepFormSheet({
    required this.companyId,
    required this.userId,
    required this.userName,
    required this.branches,
    required this.onSaved,
  });

  @override
  State<_RepFormSheet> createState() => _RepFormSheetState();
}

class _RepFormSheetState extends State<_RepFormSheet> {
  String _repType = 'no_custody';
  String? _branchId;
  final _phoneCtrl = TextEditingController();
  final _regionCtrl = TextEditingController();
  final _codeCtrl = TextEditingController();
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    if (widget.branches.isNotEmpty) {
      _branchId = widget.branches.first['id'] as String;
    }
  }

  @override
  void dispose() {
    _phoneCtrl.dispose();
    _regionCtrl.dispose();
    _codeCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_branchId == null) {
      setState(() => _error = 'اختر الفرع');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      await Supabase.instance.client.rpc(
        'admin_upsert_sales_rep',
        params: {
          'p_company_id': widget.companyId,
          'p_user_id': widget.userId,
          'p_rep_type': _repType,
          'p_branch_id': _branchId,
          'p_warehouse_id': null,
          'p_treasury_id': null,
          'p_employee_code':
              _codeCtrl.text.trim().isEmpty ? null : _codeCtrl.text.trim(),
          'p_phone':
              _phoneCtrl.text.trim().isEmpty ? null : _phoneCtrl.text.trim(),
          'p_region':
              _regionCtrl.text.trim().isEmpty ? null : _regionCtrl.text.trim(),
          'p_is_active': true,
        },
      );
      if (mounted) {
        Navigator.of(context).pop();
        widget.onSaved();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _saving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade400,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text('تعيين مندوب: ${widget.userName}',
                style: const TextStyle(
                    fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(
                    value: 'no_custody',
                    label: Text('بدون عهدة'),
                    icon: Icon(Icons.inventory_2_outlined)),
                ButtonSegment(
                    value: 'custody',
                    label: Text('بعهدة'),
                    icon: Icon(Icons.warehouse)),
              ],
              selected: {_repType},
              onSelectionChanged: (s) => setState(() => _repType = s.first),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: _branchId,
              decoration: const InputDecoration(
                labelText: 'الفرع',
                prefixIcon: Icon(Icons.store),
              ),
              items: widget.branches
                  .map((b) => DropdownMenuItem(
                        value: b['id'] as String,
                        child: Text((b['name'] ?? '') as String),
                      ))
                  .toList(),
              onChanged: (v) => setState(() => _branchId = v),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _phoneCtrl,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: 'الهاتف (اختياري)',
                prefixIcon: Icon(Icons.phone),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _regionCtrl,
              decoration: const InputDecoration(
                labelText: 'المنطقة (اختياري)',
                prefixIcon: Icon(Icons.map),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _codeCtrl,
              decoration: const InputDecoration(
                labelText: 'كود الموظف (اختياري)',
                prefixIcon: Icon(Icons.numbers),
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(_error!,
                    style: TextStyle(color: Colors.red.shade900)),
              ),
            ],
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: _saving ? null : _save,
              icon: _saving
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.save),
              label: Text(_saving ? 'جارٍ الحفظ...' : 'حفظ'),
            ),
          ],
        ),
      ),
    );
  }
}
