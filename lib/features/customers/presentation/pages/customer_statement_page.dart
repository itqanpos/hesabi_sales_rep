import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../data/customers_repository.dart';
import '../../domain/customer_models.dart';

class CustomerStatementPage extends StatefulWidget {
  final String companyId;
  final String customerId;
  final String customerName;
  final String? customerPhone;
  final double customerBalance;

  const CustomerStatementPage({
    super.key,
    required this.companyId,
    required this.customerId,
    required this.customerName,
    this.customerPhone,
    required this.customerBalance,
  });

  @override
  State<CustomerStatementPage> createState() => _CustomerStatementPageState();
}

enum _Filter { today, week, month, all }

class _CustomerStatementPageState extends State<CustomerStatementPage> {
  late final CustomersRepository _repo;
  _Filter _filter = _Filter.month;
  bool _loading = true;
  String? _error;
  List<StatementEntry> _entries = const [];

  @override
  void initState() {
    super.initState();
    _repo = CustomersRepository(Supabase.instance.client);
    _load();
  }

  (DateTime?, DateTime?) _range() {
    final now = DateTime.now();
    switch (_filter) {
      case _Filter.today:
        return (DateTime(now.year, now.month, now.day), null);
      case _Filter.week:
        return (now.subtract(const Duration(days: 6)), null);
      case _Filter.month:
        return (DateTime(now.year, now.month, 1), null);
      case _Filter.all:
        return (null, null);
    }
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final (from, to) = _range();
      final entries = await _repo.getStatement(
        companyId: widget.companyId,
        customerId: widget.customerId,
        from: from,
        to: to,
      );
      if (!mounted) return;
      setState(() {
        _entries = entries.reversed.toList();
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

  double get _debitTotal => _entries
      .where((e) => e.isSale)
      .fold(0.0, (s, e) => s + (e.remaining ?? e.amount));

  double get _creditTotal => _entries
      .where((e) => e.isPayment)
      .fold(0.0, (s, e) => s + e.amount);

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: ui.TextDirection.rtl,
      child: Scaffold(
        backgroundColor: _C.bg,
        body: Column(
          children: [
            _Header(
              name: widget.customerName,
              phone: widget.customerPhone,
              balance: widget.customerBalance,
            ),
            _FilterStrip(
              current: _filter,
              onChanged: (f) {
                setState(() => _filter = f);
                _load();
              },
            ),
            _SummaryStrip(
              debit: _debitTotal,
              credit: _creditTotal,
              count: _entries.length,
            ),
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
                  style: const TextStyle(
                      color: _C.textSecondary, fontSize: 13)),
              const SizedBox(height: 12),
              ElevatedButton(
                  onPressed: _load, child: const Text('إعادة المحاولة')),
            ],
          ),
        ),
      );
    }
    if (_entries.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.receipt_long_outlined,
                  size: 56, color: _C.textSecondary),
              SizedBox(height: 12),
              Text('لا توجد حركات في هذه الفترة',
                  style: TextStyle(
                      color: _C.textSecondary, fontSize: 15)),
            ],
          ),
        ),
      );
    }
    return RefreshIndicator(
      color: _C.primary,
      onRefresh: _load,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        itemCount: _entries.length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (_, i) => _EntryTile(entry: _entries[i]),
      ),
    );
  }
}

// ─── Header ─────────────────────────────────────────────────────────────────

class _Header extends StatelessWidget {
  final String name;
  final String? phone;
  final double balance;
  const _Header({required this.name, this.phone, required this.balance});

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.of(context).padding.top;
    final hasDebt = balance > 0.001;
    final hasCredit = balance < -0.001;
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
              Expanded(
                child: Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          if (phone != null && phone!.isNotEmpty) ...[
            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Text(phone!,
                  style: const TextStyle(
                      color: Colors.white70, fontSize: 13)),
            ),
          ],
          const SizedBox(height: 14),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.18),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  hasDebt
                      ? 'الرصيد المدين'
                      : hasCredit
                          ? 'رصيد دائن'
                          : 'مسدَّد',
                  style: const TextStyle(
                      color: Colors.white70, fontSize: 12),
                ),
                const SizedBox(width: 10),
                Text(
                  fmtMoney(balance.abs()),
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w800),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Filter ─────────────────────────────────────────────────────────────────

class _FilterStrip extends StatelessWidget {
  final _Filter current;
  final ValueChanged<_Filter> onChanged;
  const _FilterStrip({required this.current, required this.onChanged});

  static const _labels = {
    _Filter.today: 'اليوم',
    _Filter.week: 'الأسبوع',
    _Filter.month: 'الشهر',
    _Filter.all: 'الكل',
  };

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: _Filter.values.map((f) {
            final selected = f == current;
            return Padding(
              padding: const EdgeInsets.only(left: 8),
              child: ChoiceChip(
                label: Text(_labels[f]!),
                selected: selected,
                onSelected: (_) => onChanged(f),
                selectedColor: _C.primaryLight,
                labelStyle: TextStyle(
                  color: selected ? _C.primaryDark : _C.text,
                  fontWeight:
                      selected ? FontWeight.w700 : FontWeight.w500,
                ),
                side: BorderSide(
                    color: selected ? _C.primary : _C.border),
                backgroundColor: Colors.white,
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}

// ─── Summary ────────────────────────────────────────────────────────────────

class _SummaryStrip extends StatelessWidget {
  final double debit;
  final double credit;
  final int count;
  const _SummaryStrip({
    required this.debit,
    required this.credit,
    required this.count,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _C.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: _SumItem(
              label: 'مدين (فواتير)',
              value: fmtMoney(debit),
              color: _C.danger,
            ),
          ),
          Container(width: 1, height: 32, color: _C.border),
          Expanded(
            child: _SumItem(
              label: 'دائن (دفعات)',
              value: fmtMoney(credit),
              color: _C.success,
            ),
          ),
          Container(width: 1, height: 32, color: _C.border),
          Expanded(
            child: _SumItem(
              label: 'حركات',
              value: '$count',
              color: _C.text,
            ),
          ),
        ],
      ),
    );
  }
}

class _SumItem extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _SumItem({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(label,
            style:
                const TextStyle(fontSize: 11, color: _C.textSecondary)),
        const SizedBox(height: 4),
        Text(value,
            style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: color)),
      ],
    );
  }
}

// ─── Entry tile ─────────────────────────────────────────────────────────────

class _EntryTile extends StatelessWidget {
  final StatementEntry entry;
  const _EntryTile({required this.entry});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _C.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: entry.isSale
                      ? _C.dangerLight
                      : _C.successLight,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  entry.isSale
                      ? Icons.receipt_long
                      : Icons.payments,
                  color: entry.isSale ? _C.danger : _C.success,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      entry.isSale
                          ? 'فاتورة #${entry.refNumber ?? '—'}'
                          : 'دفعة ${entry.methodLabel}',
                      style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      fmtDateTime(entry.date),
                      style: const TextStyle(
                          fontSize: 11, color: _C.textSecondary),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                entry.isSale
                    ? fmtMoney(entry.amount)
                    : '- ${fmtMoney(entry.amount)}',
                style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color:
                        entry.isSale ? _C.danger : _C.success),
              ),
            ],
          ),
          if (entry.isSale && entry.paidAmount != null) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _MiniStat(
                    label: 'مدفوع',
                    value: fmtMoney(entry.paidAmount!),
                    color: _C.success,
                  ),
                ),
                Expanded(
                  child: _MiniStat(
                    label: 'متبقي',
                    value: fmtMoney(entry.remaining ?? 0),
                    color: _C.warning,
                  ),
                ),
              ],
            ),
          ],
          if (entry.notes != null && entry.notes!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: _C.surfaceGray,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                entry.notes!,
                style: const TextStyle(
                    fontSize: 12, color: _C.textSecondary),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _MiniStat({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(left: 6),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: TextStyle(
                  fontSize: 11,
                  color: color,
                  fontWeight: FontWeight.w600)),
          Text(value,
              style: TextStyle(
                  fontSize: 12,
                  color: color,
                  fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }
}

// ─── Colors ─────────────────────────────────────────────────────────────────

class _C {
  static const primary = Color(0xFF00897B);
  static const primaryDark = Color(0xFF00695C);
  static const primaryLight = Color(0xFFE0F2F1);
  static const success = Color(0xFF2E7D32);
  static const successLight = Color(0xFFE8F5E9);
  static const warning = Color(0xFFE65100);
  static const danger = Color(0xFFC62828);
  static const dangerLight = Color(0xFFFFEBEE);
  static const surfaceGray = Color(0xFFF5F5F5);
  static const border = Color(0xFFE0E0E0);
  static const text = Color(0xFF1A1A1A);
  static const textSecondary = Color(0xFF757575);
  static const bg = Color(0xFFFAFAFA);
}
