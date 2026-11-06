import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../data/collections_repository.dart';
import '../../domain/collection_models.dart';
import '../widgets/new_payment_sheet.dart';

class CollectionsPage extends StatefulWidget {
  final String companyId;
  final String salesRepId;
  const CollectionsPage({
    super.key,
    required this.companyId,
    required this.salesRepId,
  });

  @override
  State<CollectionsPage> createState() => _CollectionsPageState();
}

enum _Filter { today, week, month, all }

class _CollectionsPageState extends State<CollectionsPage> {
  late final CollectionsRepository _repo;
  _Filter _filter = _Filter.today;
  bool _loading = true;
  String? _error;
  List<CollectionEntry> _entries = const [];

  @override
  void initState() {
    super.initState();
    _repo = CollectionsRepository(Supabase.instance.client);
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
      final entries = await _repo.listCollections(
        companyId: widget.companyId,
        salesRepId: widget.salesRepId,
        from: from,
        to: to,
      );
      if (!mounted) return;
      setState(() {
        _entries = entries;
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

  double get _total => _entries.fold(0.0, (s, e) => s + e.amount);

  Future<void> _openNewPayment() async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => NewPaymentSheet(
        companyId: widget.companyId,
        repo: _repo,
      ),
    );
    if (saved == true) _load();
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: _C.bg,
        floatingActionButton: FloatingActionButton.extended(
          onPressed: _openNewPayment,
          backgroundColor: _C.primary,
          icon: const Icon(Icons.add, color: Colors.white),
          label: const Text('تسجيل دفعة',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
        ),
        body: Column(
          children: [
            _Header(total: _total, count: _entries.length),
            _FilterStrip(
              current: _filter,
              onChanged: (f) {
                setState(() => _filter = f);
                _load();
              },
            ),
            Expanded(child: _buildBody()),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: _C.primary));
    }
    if (_error != null) {
      return _ErrorView(message: _error!, onRetry: _load);
    }
    if (_entries.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.payments_outlined, size: 56, color: _C.textSecondary),
              SizedBox(height: 12),
              Text('لا توجد تحصيلات في هذه الفترة',
                  style: TextStyle(color: _C.textSecondary, fontSize: 15)),
            ],
          ),
        ),
      );
    }
    return RefreshIndicator(
      color: _C.primary,
      onRefresh: _load,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
        itemCount: _entries.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (_, i) => _CollectionTile(entry: _entries[i]),
      ),
    );
  }
}

// ─── Header ─────────────────────────────────────────────────────────────────

class _Header extends StatelessWidget {
  final double total;
  final int count;
  const _Header({required this.total, required this.count});

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
              const Text('التحصيلات',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w700)),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _StatChip(label: 'إجمالي', value: _fmtMoney(total)),
              const SizedBox(width: 10),
              _StatChip(label: 'عدد الدفعات', value: '$count'),
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
        color: Colors.white.withValues(alpha: 0.18),
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

// ─── Filter strip ───────────────────────────────────────────────────────────

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
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                ),
                side: BorderSide(color: selected ? _C.primary : _C.border),
                backgroundColor: Colors.white,
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}

// ─── List tile ──────────────────────────────────────────────────────────────

class _CollectionTile extends StatelessWidget {
  final CollectionEntry entry;
  const _CollectionTile({required this.entry});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _C.border),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: _C.successLight,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.payments, color: _C.success),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(entry.customerName ?? 'عميل محذوف',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text(
                  '${entry.methodLabel} · ${_fmtDateTime(entry.createdAt)}',
                  style: const TextStyle(fontSize: 12, color: _C.textSecondary),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            _fmtMoney(entry.amount),
            style: const TextStyle(
                fontSize: 16, fontWeight: FontWeight.w800, color: _C.success),
          ),
        ],
      ),
    );
  }
}

// ─── Error view ─────────────────────────────────────────────────────────────

class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorView({required this.message, required this.onRetry});
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48, color: _C.danger),
            const SizedBox(height: 12),
            Text(message,
                textAlign: TextAlign.center,
                style: const TextStyle(color: _C.textSecondary, fontSize: 13)),
            const SizedBox(height: 12),
            ElevatedButton(onPressed: onRetry, child: const Text('إعادة المحاولة')),
          ],
        ),
      ),
    );
  }
}

// ─── Helpers + colors ───────────────────────────────────────────────────────

String _fmtMoney(double v) {
  final f = NumberFormat('#,##0.00', 'en');
  return '${f.format(v)} ج.م';
}

String _fmtDateTime(DateTime d) {
  final df = DateFormat('yyyy/MM/dd HH:mm', 'en');
  return df.format(d);
}

class _C {
  static const primary = Color(0xFF00897B);
  static const primaryDark = Color(0xFF00695C);
  static const primaryLight = Color(0xFFE0F2F1);
  static const success = Color(0xFF2E7D32);
  static const successLight = Color(0xFFE8F5E9);
  static const danger = Color(0xFFC62828);
  static const surface = Colors.white;
  static const border = Color(0xFFE0E0E0);
  static const text = Color(0xFF1A1A1A);
  static const textSecondary = Color(0xFF757575);
  static const bg = Color(0xFFFAFAFA);
}
