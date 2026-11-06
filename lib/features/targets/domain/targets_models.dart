class RepTargetInfo {
  final double target;
  final double commissionRate;  // نسبة مئوية (مثال: 2.5 يعني 2.5%)
  final String currentMonth;
  final double currentGrossSales;
  final double currentReturns;
  final double currentNetSales;
  final int currentInvoices;
  final int daysInMonth;
  final int daysElapsed;
  final List<MonthlyPerformance> monthlyHistory;

  const RepTargetInfo({
    required this.target,
    required this.commissionRate,
    required this.currentMonth,
    required this.currentGrossSales,
    required this.currentReturns,
    required this.currentNetSales,
    required this.currentInvoices,
    required this.daysInMonth,
    required this.daysElapsed,
    required this.monthlyHistory,
  });

  factory RepTargetInfo.fromJson(Map<String, dynamic> j) {
    double n(dynamic v) => (v as num?)?.toDouble() ?? 0;
    int i(dynamic v) => (v as num?)?.toInt() ?? 0;
    return RepTargetInfo(
      target: n(j['target']),
      commissionRate: n(j['commission_rate']),
      currentMonth: (j['current_month'] as String?) ?? '',
      currentGrossSales: n(j['current_gross_sales']),
      currentReturns: n(j['current_returns']),
      currentNetSales: n(j['current_net_sales']),
      currentInvoices: i(j['current_invoices']),
      daysInMonth: i(j['days_in_month']),
      daysElapsed: i(j['days_elapsed']),
      monthlyHistory: (j['monthly_history'] as List? ?? [])
          .map((e) =>
              MonthlyPerformance.fromJson((e as Map).cast<String, dynamic>()))
          .toList(),
    );
  }

  bool get hasTarget => target > 0;
  double get progress =>
      hasTarget ? (currentNetSales / target).clamp(0.0, 1.0) : 0.0;
  double get progressPercent => progress * 100;
  double get remaining =>
      hasTarget ? (target - currentNetSales).clamp(0.0, double.infinity) : 0;
  bool get achieved => hasTarget && currentNetSales >= target;

  int get daysRemaining => (daysInMonth - daysElapsed).clamp(0, daysInMonth);
  double get dailyTarget =>
      daysRemaining > 0 ? remaining / daysRemaining : 0;

  double get commissionAmount =>
      currentNetSales * (commissionRate / 100);
}

class MonthlyPerformance {
  final String month; // YYYY-MM
  final double grossSales;
  final double returns;
  final double netSales;
  final int invoices;

  const MonthlyPerformance({
    required this.month,
    required this.grossSales,
    required this.returns,
    required this.netSales,
    required this.invoices,
  });

  factory MonthlyPerformance.fromJson(Map<String, dynamic> j) =>
      MonthlyPerformance(
        month: (j['month'] as String?) ?? '',
        grossSales: (j['gross_sales'] as num?)?.toDouble() ?? 0,
        returns: (j['returns'] as num?)?.toDouble() ?? 0,
        netSales: (j['net_sales'] as num?)?.toDouble() ?? 0,
        invoices: (j['invoices'] as num?)?.toInt() ?? 0,
      );

  String get monthLabel {
    if (month.isEmpty || month.length < 7) return month;
    try {
      final parts = month.split('-');
      final y = parts[0];
      final m = int.parse(parts[1]);
      const names = [
        'يناير', 'فبراير', 'مارس', 'أبريل', 'مايو', 'يونيو',
        'يوليو', 'أغسطس', 'سبتمبر', 'أكتوبر', 'نوفمبر', 'ديسمبر'
      ];
      return '${names[m - 1]} $y';
    } catch (_) {
      return month;
    }
  }
}
