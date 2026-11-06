import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../data/reports_repository.dart';
import '../../domain/report_models.dart';

class ReportsPage extends StatefulWidget {
  final String companyId;
  final String salesRepId;
  const ReportsPage({
    super.key,
    required this.companyId,
    required this.salesRepId,
  });

  @override
  State<ReportsPage> createState() => _ReportsPageState();
}

enum _Period { today, week, month, year }

class _ReportsPageState extends State<ReportsPage>
    with SingleTickerProviderStateMixin {
  late final ReportsRepository _repo;
  late final TabController _tab;
  _Period _period = _Period.month;
  bool _loading = true;
  String? _error;
  RepReport? _report;

  @override
  void initState() {
    super.initState();
    _repo = ReportsRepository(Supabase.instance.client);
    _tab = TabController(length: 4, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  (DateTime, DateTime) _range() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    switch (_period) {
      case _Period.today:
        return (today, today);
      case _Period.week:
        return (today.subtract(const Duration(days: 6)), today);
      case _Period.month:
        return (DateTime(now.year, now.month, 1), today);
      case _Period.year:
        return (DateTime(now.year, 1, 1), today);
    }
  }

  String _periodLabel(_Period p) => switch (p) {
        _Period.today => 'اليوم',
        _Period.week => 'آخر 7 أيام',
        _Period.month => 'هذا الشهر',
        _Period.year => 'هذا العام',
      };

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final (from, to) = _range();
      final rep = await _repo.loadReport(
        companyId: widget.companyId,
        salesRepId: widget.salesRepId,
        from: from,
        to: to,
      );
      if (!mounted) return;
      setState(() {
        _report = rep;
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

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: ui.TextDirection.rtl,
      child: Scaffold(
        backgroundColor: _C.bg,
        body: Column(
          children: [
            _buildHeader(),
            _buildPeriodChips(),
            _buildTabBar(),
            Expanded(child: _buildBody()),
          ],
        ),
      ),
    );
  }

  // ── Header ─────────────────────────────────────────────────────────────

  Widget _buildHeader() {
    final top = MediaQuery.of(context).padding.top;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(20, top + 16, 20, 16),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [_C.primary, _C.primaryDark],
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
        ),
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.of(context).maybePop(),
            icon: const Icon(Icons.arrow_back, color: Colors.white),
          ),
          const Expanded(
            child: Text('التقارير',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w700)),
          ),
          if (!_loading && _report != null)
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(_periodLabel(_period),
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w700)),
            ),
        ],
      ),
    );
  }

  // ── Period chips ───────────────────────────────────────────────────────

  Widget _buildPeriodChips() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: _Period.values.map((p) {
            final selected = p == _period;
            return Padding(
              padding: const EdgeInsets.only(left: 6),
              child: ChoiceChip(
                label: Text(_periodLabel(p)),
                selected: selected,
                onSelected: (_) {
                  setState(() => _period = p);
                  _load();
                },
                selectedColor: _C.primaryLight,
                labelStyle: TextStyle(
                  color: selected ? _C.primaryDark : _C.text,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  fontSize: 12,
                ),
                side: BorderSide(
                    color: selected ? _C.primary : _C.border),
                backgroundColor: Colors.white,
                visualDensity: VisualDensity.compact,
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  // ── Tab bar ────────────────────────────────────────────────────────────

  Widget _buildTabBar() {
    return Container(
      color: Colors.white,
      child: TabBar(
        controller: _tab,
        labelColor: _C.primary,
        unselectedLabelColor: _C.textSecondary,
        indicatorColor: _C.primary,
        indicatorWeight: 3,
        labelStyle: const TextStyle(
            fontWeight: FontWeight.w800, fontSize: 13),
        unselectedLabelStyle: const TextStyle(
            fontWeight: FontWeight.w500, fontSize: 13),
        tabs: const [
          Tab(text: 'عام'),
          Tab(text: 'المبيعات'),
          Tab(text: 'التحصيلات'),
          Tab(text: 'المديونيات'),
        ],
      ),
    );
  }

  // ── Body ───────────────────────────────────────────────────────────────

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: _C.primary));
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
    final r = _report!;
    return TabBarView(
      controller: _tab,
      children: [
        _OverviewTab(report: r),
        _SalesTab(report: r),
        _CollectionsTab(report: r),
        _DebtsTab(report: r),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Tab 1: Overview
// ═══════════════════════════════════════════════════════════════════════════

class _OverviewTab extends StatelessWidget {
  final RepReport report;
  const _OverviewTab({required this.report});

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      color: _C.primary,
      onRefresh: () async {},
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _SummaryCard(
            icon: Icons.trending_up,
            label: 'إجمالي المبيعات',
            value: _fmt(report.salesTotal),
            sub: '${report.salesCount} فاتورة',
            color: _C.success,
          ),
          const SizedBox(height: 10),
          _SummaryCard(
            icon: Icons.payments,
            label: 'إجمالي التحصيلات',
            value: _fmt(report.collectionsTotal),
            sub: '${report.collectionsCount} دفعة',
            color: _C.warning,
          ),
          const SizedBox(height: 10),
          _SummaryCard(
            icon: Icons.assignment_return,
            label: 'إجمالي المرتجعات',
            value: _fmt(report.returnsTotal),
            sub: '${report.returnsCount} مرتجع',
            color: _C.danger,
          ),
          const SizedBox(height: 10),
          _SummaryCard(
            icon: Icons.trending_flat,
            label: 'صافي الأداء',
            value: _fmt(report.netTotal),
            sub: 'المبيعات − المرتجعات',
            color: _C.primary,
            highlighted: true,
          ),
          if (report.isEmpty) ...[
            const SizedBox(height: 24),
            _emptyNote('لا توجد بيانات لهذه الفترة'),
          ],
        ],
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final String sub;
  final Color color;
  final bool highlighted;
  const _SummaryCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.sub,
    required this.color,
    this.highlighted = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: highlighted ? color.withOpacity(0.06) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: highlighted ? color.withOpacity(0.35) : _C.border),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: const TextStyle(
                        fontSize: 12, color: _C.textSecondary)),
                const SizedBox(height: 2),
                Text(value,
                    style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: color)),
                const SizedBox(height: 2),
                Text(sub,
                    style: const TextStyle(
                        fontSize: 11, color: _C.textSecondary)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Tab 2: Sales
// ═══════════════════════════════════════════════════════════════════════════

class _SalesTab extends StatelessWidget {
  final RepReport report;
  const _SalesTab({required this.report});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const _SectionTitle('المبيعات اليومية'),
        const SizedBox(height: 8),
        if (report.dailySales.isEmpty)
          _emptyNote('لا توجد مبيعات')
        else
          _DailySalesChart(data: report.dailySales),
        const SizedBox(height: 20),
        const _SectionTitle('أفضل المنتجات'),
        const SizedBox(height: 8),
        if (report.topProducts.isEmpty)
          _emptyNote('لا توجد بيانات')
        else
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: _C.border),
            ),
            child: Column(
              children: [
                for (int i = 0; i < report.topProducts.length; i++) ...[
                  _TopProductRow(
                    index: i + 1,
                    product: report.topProducts[i],
                  ),
                  if (i < report.topProducts.length - 1)
                    const Divider(height: 1, color: _C.border),
                ],
              ],
            ),
          ),
        const SizedBox(height: 20),
        const _SectionTitle('أفضل العملاء'),
        const SizedBox(height: 8),
        if (report.topCustomers.isEmpty)
          _emptyNote('لا توجد بيانات')
        else
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: _C.border),
            ),
            child: Column(
              children: [
                for (int i = 0; i < report.topCustomers.length; i++) ...[
                  _TopCustomerRow(
                    index: i + 1,
                    customer: report.topCustomers[i],
                  ),
                  if (i < report.topCustomers.length - 1)
                    const Divider(height: 1, color: _C.border),
                ],
              ],
            ),
          ),
      ],
    );
  }
}

class _DailySalesChart extends StatelessWidget {
  final List<DailySale> data;
  const _DailySalesChart({required this.data});

  @override
  Widget build(BuildContext context) {
    final maxTotal =
        data.fold<double>(0, (s, d) => d.total > s ? d.total : s);
    final safeMax = maxTotal == 0 ? 1.0 : maxTotal;

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 16, 12, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _C.border),
      ),
      child: SizedBox(
        height: 160,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: data.map((d) {
            final heightFactor = d.total / safeMax;
            return Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text(
                      _fmtShort(d.total),
                      style: const TextStyle(
                          fontSize: 9, color: _C.textSecondary),
                    ),
                    const SizedBox(height: 2),
                    Flexible(
                      child: FractionallySizedBox(
                        heightFactor: heightFactor.clamp(0.02, 1.0),
                        child: Container(
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: _C.primary,
                            borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(4)),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      DateFormat('d/M', 'en').format(d.day),
                      style: const TextStyle(
                          fontSize: 9, color: _C.textSecondary),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}

class _TopProductRow extends StatelessWidget {
  final int index;
  final TopProduct product;
  const _TopProductRow({required this.index, required this.product});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: index <= 3
                  ? _C.primary.withOpacity(0.15)
                  : _C.surfaceGray,
              borderRadius: BorderRadius.circular(6),
            ),
            alignment: Alignment.center,
            child: Text('$index',
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: index <= 3 ? _C.primary : _C.textSecondary)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(product.productName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w600)),
                Text('${_fmtNum(product.qty)} وحدة',
                    style: const TextStyle(
                        fontSize: 11, color: _C.textSecondary)),
              ],
            ),
          ),
          Text(_fmt(product.total),
              style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: _C.success)),
        ],
      ),
    );
  }
}

class _TopCustomerRow extends StatelessWidget {
  final int index;
  final TopCustomer customer;
  const _TopCustomerRow({required this.index, required this.customer});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: index <= 3
                  ? _C.primary.withOpacity(0.15)
                  : _C.surfaceGray,
              borderRadius: BorderRadius.circular(6),
            ),
            alignment: Alignment.center,
            child: Text('$index',
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: index <= 3 ? _C.primary : _C.textSecondary)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(customer.customerName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w600)),
                Text('${customer.invoices} فاتورة',
                    style: const TextStyle(
                        fontSize: 11, color: _C.textSecondary)),
              ],
            ),
          ),
          Text(_fmt(customer.total),
              style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: _C.primary)),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Tab 3: Collections
// ═══════════════════════════════════════════════════════════════════════════

class _CollectionsTab extends StatelessWidget {
  final RepReport report;
  const _CollectionsTab({required this.report});

  @override
  Widget build(BuildContext context) {
    final total = report.collectionsTotal;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: _C.success.withOpacity(0.08),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _C.success.withOpacity(0.3)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('إجمالي التحصيلات',
                  style: TextStyle(
                      fontSize: 12, color: _C.textSecondary)),
              const SizedBox(height: 4),
              Text(_fmt(total),
                  style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      color: _C.success)),
              Text('${report.collectionsCount} دفعة',
                  style: const TextStyle(
                      fontSize: 11, color: _C.textSecondary)),
            ],
          ),
        ),
        const SizedBox(height: 20),
        const _SectionTitle('التوزيع حسب طريقة الدفع'),
        const SizedBox(height: 8),
        if (report.byMethod.isEmpty)
          _emptyNote('لا توجد دفعات')
        else
          ...report.byMethod.map((m) {
            final pct = total > 0 ? m.total / total : 0.0;
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: _C.border),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(m.label,
                            style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700)),
                      ),
                      Text('${(pct * 100).toStringAsFixed(0)}%',
                          style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: _C.textSecondary)),
                      const SizedBox(width: 8),
                      Text(_fmt(m.total),
                          style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              color: _C.warning)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: pct,
                      minHeight: 6,
                      backgroundColor: _C.surfaceGray,
                      valueColor:
                          const AlwaysStoppedAnimation(_C.warning),
                    ),
                  ),
                ],
              ),
            );
          }),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Tab 4: Debts
// ═══════════════════════════════════════════════════════════════════════════

class _DebtsTab extends StatelessWidget {
  final RepReport report;
  const _DebtsTab({required this.report});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: _C.danger.withOpacity(0.08),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _C.danger.withOpacity(0.3)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('إجمالي المديونيات',
                  style: TextStyle(
                      fontSize: 12, color: _C.textSecondary)),
              const SizedBox(height: 4),
              Text(_fmt(report.debtsTotal),
                  style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      color: _C.danger)),
              Text('${report.debts.length} عميل مدين',
                  style: const TextStyle(
                      fontSize: 11, color: _C.textSecondary)),
            ],
          ),
        ),
        const SizedBox(height: 16),
        if (report.debts.isEmpty)
          _emptyNote('لا توجد مديونيات 🎉')
        else
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: _C.border),
            ),
            child: Column(
              children: [
                for (int i = 0; i < report.debts.length; i++) ...[
                  _DebtRow(debt: report.debts[i]),
                  if (i < report.debts.length - 1)
                    const Divider(height: 1, color: _C.border),
                ],
              ],
            ),
          ),
      ],
    );
  }
}

class _DebtRow extends StatelessWidget {
  final DebtCustomer debt;
  const _DebtRow({required this.debt});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: _C.dangerLight,
              borderRadius: BorderRadius.circular(10),
            ),
            alignment: Alignment.center,
            child: Text(
              debt.customerName.isNotEmpty
                  ? debt.customerName.substring(0, 1)
                  : '؟',
              style: const TextStyle(
                  color: _C.danger,
                  fontWeight: FontWeight.w800,
                  fontSize: 15),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(debt.customerName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w700)),
                if (debt.phone != null && debt.phone!.isNotEmpty)
                  Text(debt.phone!,
                      style: const TextStyle(
                          fontSize: 11, color: _C.textSecondary)),
              ],
            ),
          ),
          Text(_fmt(debt.balance),
              style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: _C.danger)),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Shared widgets
// ═══════════════════════════════════════════════════════════════════════════

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(text,
        style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w800,
            color: _C.text));
  }
}

Widget _emptyNote(String text) {
  return Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: _C.surfaceGray,
      borderRadius: BorderRadius.circular(12),
    ),
    child: Center(
      child: Text(text,
          style: const TextStyle(
              fontSize: 13, color: _C.textSecondary)),
    ),
  );
}

String _fmt(double v) {
  final f = NumberFormat('#,##0.00', 'en');
  return '${f.format(v)} ج.م';
}

String _fmtShort(double v) {
  if (v >= 1000) return '${(v / 1000).toStringAsFixed(1)}k';
  return v.toStringAsFixed(0);
}

String _fmtNum(double v) {
  if (v == v.roundToDouble()) return v.toStringAsFixed(0);
  return v.toStringAsFixed(2);
}

class _C {
  static const primary = Color(0xFF00897B);
  static const primaryDark = Color(0xFF00695C);
  static const primaryLight = Color(0xFFE0F2F1);
  static const success = Color(0xFF2E7D32);
  static const warning = Color(0xFFE65100);
  static const danger = Color(0xFFC62828);
  static const dangerLight = Color(0xFFFFEBEE);
  static const border = Color(0xFFE0E0E0);
  static const text = Color(0xFF1A1A1A);
  static const textSecondary = Color(0xFF757575);
  static const surfaceGray = Color(0xFFF5F5F5);
  static const bg = Color(0xFFFAFAFA);
}
