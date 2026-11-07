import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';          // ⬅️ السطر المضاف
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../data/customers_repository.dart';
import '../../domain/customer_models.dart';
import '../widgets/add_customer_sheet.dart';

class _C {
  static const primary = Color(0xFF00897B);
  static const primaryDark = Color(0xFF00695C);
  static const primaryLight = Color(0xFFE0F2F1);
  static const success = Color(0xFF2E7D32);
  static const danger = Color(0xFFC62828);
  static const surfaceGray = Color(0xFFF5F5F5);
  static const border = Color(0xFFE0E0E0);
  static const textSecondary = Color(0xFF757575);
  static const bg = Color(0xFFFAFAFA);
}

class CustomersPage extends StatefulWidget {
  final String companyId;
  const CustomersPage({super.key, required this.companyId});

  @override
  State<CustomersPage> createState() => _CustomersPageState();
}

class _CustomersPageState extends State<CustomersPage> {
  late final CustomersRepository _repo;
  final _searchCtrl = TextEditingController();
  bool _loading = true;
  String? _error;
  List<CustomerSummary> _all = const [];
  List<CustomerSummary> _filtered = const [];

  @override
  void initState() {
    super.initState();
    _repo = CustomersRepository(Supabase.instance.client);
    _load();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final list = await _repo.listCustomers(companyId: widget.companyId);
      if (!mounted) return;
      setState(() {
        _all = list;
        _filtered = list;
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

  void _onSearch(String q) {
    final s = q.trim().toLowerCase();
    setState(() {
      _filtered = s.isEmpty
          ? _all
          : _all.where((c) {
              return c.name.toLowerCase().contains(s) ||
                  (c.phone ?? '').toLowerCase().contains(s);
            }).toList();
    });
  }

  Future<void> _openAddCustomer() async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AddCustomerSheet(
        companyId: widget.companyId,
        repo: _repo,
      ),
    );
    if (saved == true) _load();
  }

  void _openStatement(CustomerSummary c) {
    context.push('/customer-statement', extra: {
      'companyId': widget.companyId,
      'customerId': c.id,
      'customerName': c.name,
      'customerPhone': c.phone,
      'customerBalance': c.balance,
    });
  }

  double get _totalDebt =>
      _all.where((c) => c.hasDebt).fold(0.0, (s, c) => s + c.balance);

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: ui.TextDirection.rtl,
      child: Scaffold(
        backgroundColor: _C.bg,
        floatingActionButton: FloatingActionButton.extended(
          onPressed: _openAddCustomer,
          backgroundColor: _C.primary,
          icon: const Icon(Icons.person_add, color: Colors.white),
          label: const Text('عميل جديد',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
        ),
        body: Column(
          children: [
            _Header(count: _all.length, totalDebt: _totalDebt),
            _SearchBox(controller: _searchCtrl, onChanged: _onSearch),
            Expanded(child: _buildBody()),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(
          child: CircularProgressIndicator(color: _C.primary));
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline,
                  size: 48, color: _C.danger),
              const SizedBox(height: 12),
              Text(_error!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: _C.textSecondary, fontSize: 13)),
              const SizedBox(height: 12),
              ElevatedButton(
                  onPressed: _load, child: const Text('إعادة المحاولة')),
            ],
          ),
        ),
      );
    }
    if (_filtered.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.people_outline,
                  size: 56, color: _C.textSecondary),
              const SizedBox(height: 12),
              Text(
                _all.isEmpty ? 'لا يوجد عملاء' : 'لا توجد نتائج مطابقة',
                style:
                    const TextStyle(color: _C.textSecondary, fontSize: 15),
              ),
            ],
          ),
        ),
      );
    }
    return RefreshIndicator(
      color: _C.primary,
      onRefresh: _load,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 96), // Space for FAB
        itemCount: _filtered.length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (_, i) => _CustomerTile(
          customer: _filtered[i],
          onTap: () => _openStatement(_filtered[i]),
        ),
      ),
    );
  }
}

// ─── Header ─────────────────────────────────────────────────────────────────
class _Header extends StatelessWidget {
  final int count;
  final double totalDebt;
  const _Header({required this.count, required this.totalDebt});

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.of(context).padding.top;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(20, top + 16, 20, 20),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [_C.primary, _C.primaryDark],
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconButton(
                onPressed: () => Navigator.of(context).maybePop(),
                icon: const Icon(Icons.arrow_back, color: Colors.white),
              ),
              const Text('العملاء',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w700)),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _StatChip(label: 'عدد العملاء', value: '$count'),
              const SizedBox(width: 10),
              _StatChip(label: 'إجمالي المديونية', value: fmtMoney(totalDebt)),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final String label;
  final String value;
  const _StatChip({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.18),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: const TextStyle(color: Colors.white70, fontSize: 11)),
          const SizedBox(height: 2),
          Text(value,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

// ─── Search ─────────────────────────────────────────────────────────────────
class _SearchBox extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  const _SearchBox({required this.controller, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        decoration: InputDecoration(
          hintText: 'ابحث باسم العميل أو الهاتف',
          prefixIcon: const Icon(Icons.search, color: _C.textSecondary),
          filled: true,
          fillColor: _C.surfaceGray,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }
}

// ─── Tile ───────────────────────────────────────────────────────────────────
class _CustomerTile extends StatelessWidget {
  final CustomerSummary customer;
  final VoidCallback onTap;
  const _CustomerTile({required this.customer, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final color = customer.hasDebt
        ? _C.danger
        : customer.hasCredit
            ? _C.success
            : _C.textSecondary;
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _C.border),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: _C.primaryLight,
                  borderRadius: BorderRadius.circular(12),
                ),
                alignment: Alignment.center,
                child: Text(
                  customer.name.isNotEmpty ? customer.name.substring(0, 1) : '؟',
                  style: const TextStyle(
                      color: _C.primaryDark,
                      fontSize: 18,
                      fontWeight: FontWeight.w800),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      customer.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w700),
                    ),
                    if (customer.phone != null &&
                        customer.phone!.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        customer.phone!,
                        style: const TextStyle(
                            fontSize: 12, color: _C.textSecondary),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    fmtMoney(customer.balance.abs()),
                    style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: color),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    customer.hasDebt
                        ? 'مديونية'
                        : customer.hasCredit
                            ? 'رصيد دائن'
                            : 'مسدَّد',
                    style:
                        const TextStyle(fontSize: 11, color: _C.textSecondary),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String fmtMoney(double v) {
  final f = NumberFormat('#,##0.00', 'en');
  return '${f.format(v)} ج.م';
}

String fmtDate(DateTime d) => DateFormat('yyyy/MM/dd', 'en').format(d);
String fmtDateTime(DateTime d) => DateFormat('yyyy/MM/dd HH:mm', 'en').format(d);
