import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

import '../../domain/sales_models.dart';
import '../../data/sales_history_repository.dart';

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
  static const surface       = Colors.white;
  static const surfaceGray   = Color(0xFFF5F5F5);
  static const border        = Color(0xFFE0E0E0);
  static const text          = Color(0xFF1A1A1A);
  static const textSecondary = Color(0xFF757575);
  static const bg            = Color(0xFFFAFAFA);
}

enum _DateFilter { today, week, month, all }

class SalesHistoryPage extends StatefulWidget {
  final String companyId;
  final String salesRepId;
  const SalesHistoryPage({
    super.key, required this.companyId, required this.salesRepId,
  });

  @override
  State<SalesHistoryPage> createState() => _SalesHistoryPageState();
}

class _SalesHistoryPageState extends State<SalesHistoryPage> {
  late final SalesHistoryRepository _repo;
  final _searchCtrl = TextEditingController();
  final _searchFocus = FocusNode();

  List<SaleSummary> _sales = [];
  bool _loading = true;
  String? _error;
  String _searchQuery = '';
  _DateFilter _filter = _DateFilter.today;

  @override
  void initState() {
    super.initState();
    _repo = SalesHistoryRepository(Supabase.instance.client);
    _load();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  (DateTime?, DateTime?) get _dateRange {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    switch (_filter) {
      case _DateFilter.today:
        return (today, today.add(const Duration(days: 1)));
      case _DateFilter.week:
        return (today.subtract(const Duration(days: 7)), now);
      case _DateFilter.month:
        return (DateTime(now.year, now.month, 1), now);
      case _DateFilter.all:
        return (null, null);
    }
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final (from, to) = _dateRange;
      final sales = await _repo.listSales(
        companyId: widget.companyId,
        salesRepId: widget.salesRepId,
        fromDate: from, toDate: to,
        search: _searchQuery.isEmpty ? null : _searchQuery,
      );
      if (!mounted) return;
      setState(() { _sales = sales; _loading = false; });
    } catch (e) {
      if (!mounted) return;
      setState(() { _error = e.toString(); _loading = false; });
    }
  }

  double get _totalAmount => _sales.where((s) => !s.isCancelled).fold(0, (a, b) => a + b.total);
  int get _validCount => _sales.where((s) => !s.isCancelled).length;

  Future<void> _openDetail(SaleSummary summary) async {
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => _SaleDetailPage(
        saleId: summary.id,
        companyId: widget.companyId,
        repository: _repo,
      ),
    ));
    if (mounted) _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _C.bg,
      appBar: AppBar(
        backgroundColor: _C.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: _C.text),
        title: const Text('سجل الفواتير',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17, color: _C.text)),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: _C.border),
        ),
      ),
      body: Column(children: [
        _buildSearch(),
        _buildFilter(),
        _buildKpiStrip(),
        Expanded(child: _buildList()),
      ]),
    );
  }

  Widget _buildSearch() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 6),
      child: TextField(
        controller: _searchCtrl,
        focusNode: _searchFocus,
        style: const TextStyle(fontSize: 14, color: _C.text),
        decoration: InputDecoration(
          hintText: 'ابحث برقم الفاتورة أو اسم العميل',
          hintStyle: TextStyle(fontSize: 13, color: Colors.grey.shade500),
          filled: true, fillColor: _C.surface,
          prefixIcon: const Icon(Icons.search, color: _C.textSecondary),
          suffixIcon: _searchQuery.isEmpty ? null : IconButton(
            icon: const Icon(Icons.close, color: _C.textSecondary),
            onPressed: () {
              _searchCtrl.clear();
              setState(() => _searchQuery = '');
              _load();
            },
          ),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: _C.border)),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: _C.border)),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: _C.primary, width: 1.5)),
          contentPadding: const EdgeInsets.symmetric(vertical: 12),
        ),
        onChanged: (v) => setState(() => _searchQuery = v),
        onSubmitted: (_) => _load(),
        textInputAction: TextInputAction.search,
      ),
    );
  }

  Widget _buildFilter() {
    const labels = {
      _DateFilter.today: 'اليوم',
      _DateFilter.week: 'الأسبوع',
      _DateFilter.month: 'الشهر',
      _DateFilter.all: 'الكل',
    };
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Row(
        children: _DateFilter.values.map((f) {
          final selected = _filter == f;
          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 3),
              child: InkWell(
                borderRadius: BorderRadius.circular(10),
                onTap: () {
                  if (_filter == f) return;
                  setState(() => _filter = f);
                  _load();
                },
                child: Container(
                  height: 38,
                  decoration: BoxDecoration(
                    color: selected ? _C.primary : _C.surface,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                        color: selected ? _C.primary : _C.border),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    labels[f]!,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: selected ? Colors.white : _C.textSecondary,
                    ),
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildKpiStrip() {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: _C.primaryLight,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _C.primary.withOpacity(0.2)),
      ),
      child: Row(children: [
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('الإجمالي',
                style: TextStyle(fontSize: 11, color: _C.primaryDark, fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            Text('${_totalAmount.toStringAsFixed(2)} ج.م',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: _C.primaryDark)),
          ],
        )),
        Container(width: 1, height: 30, color: _C.primary.withOpacity(0.2)),
        const SizedBox(width: 16),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            const Text('عدد الفواتير',
                style: TextStyle(fontSize: 11, color: _C.primaryDark, fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            Text('$_validCount',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: _C.primaryDark)),
          ],
        ),
      ]),
    );
  }

  Widget _buildList() {
    if (_loading) return const Center(child: CircularProgressIndicator(color: _C.primary));
    if (_error != null) {
      return Center(child: Padding(padding: const EdgeInsets.all(24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.error_outline, color: _C.danger, size: 48),
          const SizedBox(height: 12),
          Text(_error!, textAlign: TextAlign.center),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            onPressed: _load,
            icon: const Icon(Icons.refresh),
            label: const Text('إعادة المحاولة'),
          ),
        ]),
      ));
    }
    if (_sales.isEmpty) {
      return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.receipt_long_outlined, size: 64, color: Colors.grey.shade400),
        const SizedBox(height: 12),
        Text('لا توجد فواتير',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.grey.shade600)),
        const SizedBox(height: 4),
        Text(_searchQuery.isEmpty ? 'ابدأ ببيع جديد من نقطة البيع' : 'جرّب تعديل البحث أو الفلتر',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
      ]));
    }
    return RefreshIndicator(
      color: _C.primary,
      onRefresh: _load,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
        itemCount: _sales.length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (_, i) => _SaleCard(
          sale: _sales[i],
          onTap: () => _openDetail(_sales[i]),
        ),
      ),
    );
  }
}

// ============================================================
// Sale Card
// ============================================================
class _SaleCard extends StatelessWidget {
  final SaleSummary sale;
  final VoidCallback onTap;
  const _SaleCard({required this.sale, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final dateFmt = DateFormat('d/M/y · h:mm a', 'ar');
    final (Color statusBg, Color statusFg, String statusLabel) = sale.isCancelled
        ? (_C.dangerLight, _C.danger, 'ملغاة')
        : sale.isPaid
            ? (_C.successLight, _C.success, 'مدفوعة')
            : sale.isPartial
                ? (_C.warningLight, _C.warning, 'مدفوعة جزئياً')
                : (_C.dangerLight, _C.danger, 'آجلة');

    return Material(
      color: _C.surface,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            border: Border.all(color: _C.border),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(children: [
            Row(children: [
              Container(
                width: 42, height: 42,
                decoration: BoxDecoration(
                  color: _C.primaryLight,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.receipt_long, color: _C.primary, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Expanded(child: Text(
                      sale.invoiceNumber ?? 'بدون رقم',
                      style: const TextStyle(fontWeight: FontWeight.bold,
                          fontSize: 14, color: _C.text),
                      maxLines: 1, overflow: TextOverflow.ellipsis,
                    )),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: statusBg,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(statusLabel,
                          style: TextStyle(fontSize: 10.5,
                              fontWeight: FontWeight.bold, color: statusFg)),
                    ),
                  ]),
                  const SizedBox(height: 3),
                  Text(sale.customerName,
                      style: const TextStyle(fontSize: 12.5, color: _C.textSecondary),
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 2),
                  Text(dateFmt.format(sale.saleDate.toLocal()),
                      style: const TextStyle(fontSize: 11, color: _C.textSecondary)),
                ],
              )),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('${sale.total.toStringAsFixed(2)} ج.م',
                      style: const TextStyle(fontWeight: FontWeight.bold,
                          fontSize: 15, color: _C.primary)),
                  const SizedBox(height: 3),
                  Text('${sale.itemCount} صنف',
                      style: const TextStyle(fontSize: 10.5, color: _C.textSecondary)),
                ],
              ),
            ]),
            if (sale.isPartial || (sale.isUnpaid && !sale.isCancelled)) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: sale.isPartial ? _C.warningLight : _C.dangerLight,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(children: [
                  Icon(Icons.info_outline, size: 14,
                      color: sale.isPartial ? _C.warning : _C.danger),
                  const SizedBox(width: 6),
                  Expanded(child: Text(
                    'متبقي: ${sale.remaining.toStringAsFixed(2)} ج.م',
                    style: TextStyle(fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: sale.isPartial ? _C.warning : _C.danger),
                  )),
                ]),
              ),
            ],
          ]),
        ),
      ),
    );
  }
}

// ============================================================
// Sale Detail Page
// ============================================================
class _SaleDetailPage extends StatefulWidget {
  final String saleId;
  final String companyId;
  final SalesHistoryRepository repository;
  const _SaleDetailPage({
    required this.saleId, required this.companyId, required this.repository,
  });

  @override
  State<_SaleDetailPage> createState() => _SaleDetailPageState();
}

class _SaleDetailPageState extends State<_SaleDetailPage> {
  SaleDetail? _sale;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final sale = await widget.repository.getSaleDetail(
        saleId: widget.saleId, companyId: widget.companyId,
      );
      if (!mounted) return;
      setState(() { _sale = sale; _loading = false; });
    } catch (e) {
      if (!mounted) return;
      setState(() { _error = e.toString(); _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _C.bg,
      appBar: AppBar(
        backgroundColor: _C.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: _C.text),
        title: Text(_sale?.invoiceNumber ?? 'تفاصيل الفاتورة',
            style: const TextStyle(fontWeight: FontWeight.bold,
                fontSize: 16, color: _C.text)),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: _C.border),
        ),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) return const Center(child: CircularProgressIndicator(color: _C.primary));
    if (_error != null || _sale == null) {
      return Center(child: Padding(padding: const EdgeInsets.all(24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.error_outline, color: _C.danger, size: 48),
          const SizedBox(height: 12),
          Text(_error ?? 'الفاتورة غير موجودة', textAlign: TextAlign.center),
          const SizedBox(height: 12),
          ElevatedButton(onPressed: _load, child: const Text('إعادة المحاولة')),
        ]),
      ));
    }

    final sale = _sale!;
    final dateFmt = DateFormat('EEEE d MMMM yyyy — h:mm a', 'ar');

    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        // رأس الفاتورة
        _Card(child: Column(children: [
          Row(children: [
            Container(
              width: 44, height: 44,
              decoration: BoxDecoration(
                color: _C.primaryLight,
                borderRadius: BorderRadius.circular(10)),
              child: const Icon(Icons.receipt_long, color: _C.primary),
            ),
            const SizedBox(width: 12),
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(sale.invoiceNumber ?? 'بدون رقم',
                    style: const TextStyle(fontWeight: FontWeight.bold,
                        fontSize: 16, color: _C.text)),
                const SizedBox(height: 3),
                Text(dateFmt.format(sale.saleDate.toLocal()),
                    style: const TextStyle(fontSize: 11.5, color: _C.textSecondary)),
              ],
            )),
          ]),
          const SizedBox(height: 12),
          const Divider(height: 1, color: _C.border),
          const SizedBox(height: 12),
          _InfoRow(icon: Icons.person_outline, label: 'العميل', value: sale.customerName),
          if (sale.customerPhone != null) ...[
            const SizedBox(height: 8),
            _InfoRow(icon: Icons.phone_outlined, label: 'الهاتف', value: sale.customerPhone!),
          ],
        ])),

        const SizedBox(height: 12),

        // البنود
        _Card(child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('المنتجات',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: _C.text)),
            const SizedBox(height: 10),
            for (int i = 0; i < sale.items.length; i++) ...[
              _ItemRow(index: i + 1, item: sale.items[i]),
              if (i < sale.items.length - 1)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 6),
                  child: Divider(height: 1, color: _C.border),
                ),
            ],
          ],
        )),

        const SizedBox(height: 12),

        // الإجماليات
        _Card(child: Column(children: [
          _TotalRow(label: 'المجموع الفرعي', value: sale.subtotal),
          if (sale.discount > 0) ...[
            const SizedBox(height: 8),
            _TotalRow(label: 'الخصم', value: -sale.discount, color: _C.danger),
          ],
          if (sale.taxAmount > 0) ...[
            const SizedBox(height: 8),
            _TotalRow(label: 'الضريبة', value: sale.taxAmount),
          ],
          const SizedBox(height: 10),
          const Divider(height: 1, color: _C.border),
          const SizedBox(height: 10),
          _TotalRow(label: 'الإجمالي', value: sale.total, bold: true, color: _C.primary, fontSize: 16),
          const SizedBox(height: 10),
          const Divider(height: 1, color: _C.border),
          const SizedBox(height: 10),
          _TotalRow(label: 'المدفوع', value: sale.paidAmount, color: _C.success),
          if (sale.remaining > 0.01) ...[
            const SizedBox(height: 8),
            _TotalRow(label: 'المتبقي', value: sale.remaining, color: _C.danger, bold: true),
          ],
        ])),

        if (sale.notes != null && sale.notes!.trim().isNotEmpty) ...[
          const SizedBox(height: 12),
          _Card(child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('ملاحظات',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: _C.text)),
              const SizedBox(height: 6),
              Text(sale.notes!,
                  style: const TextStyle(fontSize: 12.5, color: _C.textSecondary)),
            ],
          )),
        ],

        const SizedBox(height: 20),

        // الأزرار
        Row(children: [
          Expanded(child: OutlinedButton.icon(
            onPressed: () => _snack('قريباً: المرتجع المرتبط'),
            icon: const Icon(Icons.assignment_return_outlined),
            label: const Text('مرتجع'),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(0, 48),
              side: const BorderSide(color: _C.border),
              foregroundColor: _C.primary,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            ),
          )),
          const SizedBox(width: 10),
          Expanded(child: FilledButton.icon(
            onPressed: () => _snack('قريباً: الطباعة'),
            icon: const Icon(Icons.print_outlined),
            label: const Text('طباعة'),
            style: FilledButton.styleFrom(
              minimumSize: const Size(0, 48),
              backgroundColor: _C.primary,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            ),
          )),
        ]),

        const SizedBox(height: 24),
      ],
    );
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }
}

class _Card extends StatelessWidget {
  final Widget child;
  const _Card({required this.child});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _C.surface,
        border: Border.all(color: _C.border),
        borderRadius: BorderRadius.circular(14),
      ),
      child: child,
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label, value;
  const _InfoRow({required this.icon, required this.label, required this.value});
  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Icon(icon, size: 18, color: _C.textSecondary),
      const SizedBox(width: 8),
      Text('$label: ', style: const TextStyle(fontSize: 12.5, color: _C.textSecondary)),
      Expanded(child: Text(value, style: const TextStyle(
          fontSize: 12.5, fontWeight: FontWeight.w600, color: _C.text),
          maxLines: 1, overflow: TextOverflow.ellipsis)),
    ]);
  }
}

class _ItemRow extends StatelessWidget {
  final int index;
  final SaleItemLine item;
  const _ItemRow({required this.index, required this.item});
  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Container(
        width: 24, height: 24,
        decoration: BoxDecoration(color: _C.primaryLight, shape: BoxShape.circle),
        alignment: Alignment.center,
        child: Text('$index', style: const TextStyle(fontSize: 11,
            fontWeight: FontWeight.bold, color: _C.primaryDark)),
      ),
      const SizedBox(width: 10),
      Expanded(child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(item.productName, style: const TextStyle(fontSize: 13,
              fontWeight: FontWeight.w600, color: _C.text),
              maxLines: 1, overflow: TextOverflow.ellipsis),
          Text('${item.quantity.toInt()} ${item.unitName} × ${item.unitPrice.toStringAsFixed(2)}',
              style: const TextStyle(fontSize: 11, color: _C.textSecondary)),
        ],
      )),
      Text('${item.lineTotal.toStringAsFixed(2)} ج.م',
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold,
              color: _C.primary)),
    ]);
  }
}

class _TotalRow extends StatelessWidget {
  final String label;
  final double value;
  final Color? color;
  final bool bold;
  final double fontSize;
  const _TotalRow({
    required this.label, required this.value,
    this.color, this.bold = false, this.fontSize = 13,
  });
  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(fontSize: fontSize,
            fontWeight: bold ? FontWeight.bold : FontWeight.w500,
            color: color ?? _C.text)),
        Text('${value.toStringAsFixed(2)} ج.م',
            style: TextStyle(fontSize: fontSize,
                fontWeight: bold ? FontWeight.bold : FontWeight.w600,
                color: color ?? _C.text)),
      ],
    );
  }
}
