import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../data/targets_repository.dart';
import '../../domain/targets_models.dart';

class TargetsPage extends StatefulWidget {
  final String companyId;
  final String salesRepId;
  const TargetsPage({
    super.key,
    required this.companyId,
    required this.salesRepId,
  });

  @override
  State<TargetsPage> createState() => _TargetsPageState();
}

class _TargetsPageState extends State<TargetsPage>
    with SingleTickerProviderStateMixin {
  late final TargetsRepository _repo;
  late final TabController _tab;
  bool _loading = true;
  String? _error;
  RepTargetInfo? _data;

  @override
  void initState() {
    super.initState();
    _repo = TargetsRepository(Supabase.instance.client);
    _tab = TabController(length: 3, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final info = await _repo.load(
        companyId: widget.companyId,
        salesRepId: widget.salesRepId,
      );
      if (!mounted) return;
      setState(() {
        _data = info;
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
            if (!_loading && _error == null && _data != null)
              _buildTabBar(),
            Expanded(child: _buildBody()),
          ],
        ),
      ),
    );
  }

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
            child: Text('الأهداف والعمولات',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      color: Colors.white,
      child: TabBar(
        controller: _tab,
        labelColor: _C.primary,
        unselectedLabelColor: _C.textSecondary,
        indicatorColor: _C.primary,
        indicatorWeight: 3,
        labelStyle:
            const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
        unselectedLabelStyle:
            const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
        tabs: const [
          Tab(text: 'الهدف'),
          Tab(text: 'العمولة'),
          Tab(text: 'الأداء'),
        ],
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
    final d = _data!;
    return TabBarView(
      controller: _tab,
      children: [
        _TargetTab(data: d),
        _CommissionTab(data: d),
        _PerformanceTab(data: d),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Tab 1: Target
// ═══════════════════════════════════════════════════════════════════════════

class _TargetTab extends StatelessWidget {
  final RepTargetInfo data;
  const _TargetTab({required this.data});

  @override
  Widget build(BuildContext context) {
    if (!data.hasTarget) {
      return _emptyState(
        icon: Icons.flag_outlined,
        title: 'لا يوجد هدف محدد',
        subtitle: 'تواصل مع المدير لتعيين هدف شهري',
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _circularProgress(),
        const SizedBox(height: 20),
        _targetSummary(),
        const SizedBox(height: 16),
        _dailyPace(),
      ],
    );
  }

  Widget _circularProgress() {
    final pct = data.progressPercent;
    final color = data.achieved
        ? _C.success
        : pct >= 75
            ? _C.primary
            : pct >= 50
                ? _C.warning
                : _C.danger;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _C.border),
      ),
      child: Center(
        child: SizedBox(
          width: 200,
          height: 200,
          child: Stack(
            alignment: Alignment.center,
            children: [
              CustomPaint(
                size: const Size(200, 200),
                painter: _CircleProgressPainter(
                  progress: data.progress,
                  color: color,
                  bgColor: _C.surfaceGray,
                  strokeWidth: 14,
                ),
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('${pct.toStringAsFixed(0)}%',
                      style: TextStyle(
                          fontSize: 40,
                          fontWeight: FontWeight.w800,
                          color: color)),
                  const SizedBox(height: 4),
                  Text(
                    data.achieved ? 'تم تحقيق الهدف 🎉' : 'من الهدف',
                    style: const TextStyle(
                        fontSize: 12, color: _C.textSecondary),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _targetSummary() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _C.border),
      ),
      child: Column(
        children: [
          _row(
            icon: Icons.flag,
            label: 'الهدف الشهري',
            value: _fmt(data.target),
            color: _C.primary,
          ),
          const Divider(height: 20, color: _C.border),
          _row(
            icon: Icons.trending_up,
            label: 'المحقق',
            value: _fmt(data.currentNetSales),
            color: _C.success,
          ),
          const Divider(height: 20, color: _C.border),
          _row(
            icon: Icons.hourglass_bottom,
            label: 'المتبقي',
            value: _fmt(data.remaining),
            color: data.remaining > 0 ? _C.warning : _C.success,
          ),
        ],
      ),
    );
  }

  Widget _dailyPace() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _C.primary.withOpacity(0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _C.primary.withOpacity(0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.speed, color: _C.primary, size: 20),
              const SizedBox(width: 8),
              const Text('الوتيرة المطلوبة',
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: _C.primaryDark)),
            ],
          ),
          const SizedBox(height: 10),
          _row(
            icon: Icons.calendar_today,
            label: 'أيام متبقية',
            value: '${data.daysRemaining} يوم',
            color: _C.text,
          ),
          const SizedBox(height: 8),
          _row(
            icon: Icons.trending_flat,
            label: 'معدل يومي مطلوب',
            value: _fmt(data.dailyTarget),
            color: _C.warning,
          ),
        ],
      ),
    );
  }

  Widget _row({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Row(
      children: [
        Icon(icon, size: 16, color: _C.textSecondary),
        const SizedBox(width: 8),
        Expanded(
          child: Text(label,
              style: const TextStyle(
                  fontSize: 12, color: _C.textSecondary)),
        ),
        Text(value,
            style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: color)),
      ],
    );
  }
}

class _CircleProgressPainter extends CustomPainter {
  final double progress;
  final Color color;
  final Color bgColor;
  final double strokeWidth;

  _CircleProgressPainter({
    required this.progress,
    required this.color,
    required this.bgColor,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - strokeWidth) / 2;

    final bgPaint = Paint()
      ..color = bgColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    final fgPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius, bgPaint);

    final sweep = 2 * math.pi * progress.clamp(0.0, 1.0);
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      sweep,
      false,
      fgPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _CircleProgressPainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.color != color;
}

// ═══════════════════════════════════════════════════════════════════════════
// Tab 2: Commission
// ═══════════════════════════════════════════════════════════════════════════

class _CommissionTab extends StatelessWidget {
  final RepTargetInfo data;
  const _CommissionTab({required this.data});

  @override
  Widget build(BuildContext context) {
    final hasCommission = data.commissionRate > 0;
    final commission = data.commissionAmount;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [_C.success, Color(0xFF1B5E20)],
              begin: Alignment.topRight,
              end: Alignment.bottomLeft,
            ),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.payments, color: Colors.white, size: 22),
                  SizedBox(width: 8),
                  Text('عمولتي هذا الشهر',
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: Colors.white)),
                ],
              ),
              const SizedBox(height: 12),
              Text(_fmt(commission),
                  style: const TextStyle(
                      fontSize: 34,
                      fontWeight: FontWeight.w900,
                      color: Colors.white)),
              const SizedBox(height: 4),
              Text(
                hasCommission
                    ? 'صافي ${_fmt(data.currentNetSales)} × ${data.commissionRate.toStringAsFixed(2)}%'
                    : 'لم يتم تحديد نسبة عمولة',
                style: TextStyle(
                    fontSize: 12,
                    color: Colors.white.withOpacity(0.85)),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        const Text('تفصيل الحساب',
            style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: _C.text)),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _C.border),
          ),
          child: Column(
            children: [
              _row(Icons.receipt_long, 'إجمالي المبيعات',
                  _fmt(data.currentGrossSales), _C.success),
              const Divider(height: 1, color: _C.border),
              _row(Icons.assignment_return, 'المرتجعات',
                  '- ${_fmt(data.currentReturns)}', _C.danger),
              const Divider(height: 1, color: _C.border),
              _row(Icons.trending_flat, 'صافي المبيعات',
                  _fmt(data.currentNetSales), _C.primary,
                  highlight: true),
              const Divider(height: 1, color: _C.border),
              _row(Icons.percent, 'نسبة العمولة',
                  hasCommission
                      ? '${data.commissionRate.toStringAsFixed(2)}%'
                      : '—',
                  _C.textSecondary),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: _C.warning.withOpacity(0.06),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _C.warning.withOpacity(0.25)),
          ),
          child: Row(
            children: [
              const Icon(Icons.info_outline,
                  color: _C.warning, size: 20),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'العمولة تقديرية بناءً على صافي المبيعات. الأرقام النهائية تُعتمد من الإدارة.',
                  style: TextStyle(
                      fontSize: 11,
                      color: _C.warning,
                      fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _row(IconData icon, String label, String value, Color color,
      {bool highlight = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      child: Row(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Text(label,
                style: TextStyle(
                    fontSize: 13,
                    fontWeight:
                        highlight ? FontWeight.w800 : FontWeight.w500,
                    color: _C.text)),
          ),
          Text(value,
              style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: color)),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Tab 3: Performance
// ═══════════════════════════════════════════════════════════════════════════

class _PerformanceTab extends StatelessWidget {
  final RepTargetInfo data;
  const _PerformanceTab({required this.data});

  @override
  Widget build(BuildContext context) {
    if (data.monthlyHistory.isEmpty) {
      return _emptyState(
        icon: Icons.bar_chart_outlined,
        title: 'لا توجد بيانات',
        subtitle: 'لم تُسجَّل أي مبيعات بعد',
      );
    }
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text('آخر 6 شهور',
            style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: _C.text)),
        const SizedBox(height: 10),
        ...data.monthlyHistory.map(_monthlyCard),
      ],
    );
  }

  Widget _monthlyCard(MonthlyPerformance m) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
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
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: _C.primaryLight,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(m.monthLabel,
                    style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: _C.primaryDark)),
              ),
              const Spacer(),
              Text('${m.invoices} فاتورة',
                  style: const TextStyle(
                      fontSize: 11, color: _C.textSecondary)),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _miniStat('صافي',
                    _fmt(m.netSales), _C.primary),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _miniStat('مرتجعات',
                    _fmt(m.returns), _C.danger),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _miniStat(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: TextStyle(
                  fontSize: 10,
                  color: color.withOpacity(0.8),
                  fontWeight: FontWeight.w600)),
          Text(value,
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: color)),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Shared
// ═══════════════════════════════════════════════════════════════════════════

Widget _emptyState({
  required IconData icon,
  required String title,
  required String subtitle,
}) {
  return Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 56, color: _C.textSecondary),
          const SizedBox(height: 12),
          Text(title,
              style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: _C.text)),
          const SizedBox(height: 4),
          Text(subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontSize: 12, color: _C.textSecondary)),
        ],
      ),
    ),
  );
}

String _fmt(double v) {
  final f = NumberFormat('#,##0.00', 'en');
  return '${f.format(v)} ج.م';
}

class _C {
  static const primary = Color(0xFF00897B);
  static const primaryDark = Color(0xFF00695C);
  static const primaryLight = Color(0xFFE0F2F1);
  static const success = Color(0xFF2E7D32);
  static const warning = Color(0xFFE65100);
  static const danger = Color(0xFFC62828);
  static const surfaceGray = Color(0xFFF5F5F5);
  static const border = Color(0xFFE0E0E0);
  static const text = Color(0xFF1A1A1A);
  static const textSecondary = Color(0xFF757575);
  static const bg = Color(0xFFFAFAFA);
}
