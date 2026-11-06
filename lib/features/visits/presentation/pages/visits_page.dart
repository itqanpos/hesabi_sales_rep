import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../data/visits_repository.dart';
import '../../domain/visit_models.dart';
import '../widgets/check_in_sheet.dart';

class VisitsPage extends StatefulWidget {
  final String companyId;
  final String salesRepId;
  const VisitsPage({
    super.key,
    required this.companyId,
    required this.salesRepId,
  });

  @override
  State<VisitsPage> createState() => _VisitsPageState();
}

enum _Filter { today, week, month, all }

class _VisitsPageState extends State<VisitsPage> {
  late final VisitsRepository _repo;
  _Filter _filter = _Filter.today;
  bool _loading = true;
  String? _error;
  List<VisitEntry> _entries = const [];

  @override
  void initState() {
    super.initState();
    _repo = VisitsRepository(Supabase.instance.client);
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
      final list = await _repo.listVisits(
        companyId: widget.companyId,
        salesRepId: widget.salesRepId,
        from: from,
        to: to,
      );
      if (!mounted) return;
      setState(() {
        _entries = list;
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

  Future<void> _openCheckIn() async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => CheckInSheet(
        companyId: widget.companyId,
        salesRepId: widget.salesRepId,
        repo: _repo,
      ),
    );
    if (saved == true) _load();
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: ui.TextDirection.rtl,
      child: Scaffold(
        backgroundColor: _C.bg,
        floatingActionButton: FloatingActionButton.extended(
          onPressed: _openCheckIn,
          backgroundColor: _C.purple,
          icon: const Icon(Icons.location_on, color: Colors.white),
          label: const Text('تسجيل زيارة',
              style: TextStyle(
                  color: Colors.white, fontWeight: FontWeight.w700)),
        ),
        body: Column(
          children: [
            _Header(count: _entries.length),
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
              Icon(Icons.location_off_outlined,
                  size: 56, color: _C.textSecondary),
              SizedBox(height: 12),
              Text('لا توجد زيارات في هذه الفترة',
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
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
        itemCount: _entries.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (_, i) => _VisitTile(entry: _entries[i]),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final int count;
  const _Header({required this.count});

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.of(context).padding.top;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(20, top + 16, 20, 20),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [_C.purple, Color(0xFF4A148C)],
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
              const Text('الزيارات',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w700)),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.18),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('عدد الزيارات',
                    style: TextStyle(
                        color: Colors.white70, fontSize: 11)),
                const SizedBox(height: 2),
                Text('$count',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w700)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

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
                selectedColor: _C.purple.withOpacity(0.15),
                labelStyle: TextStyle(
                  color: selected ? _C.purple : _C.text,
                  fontWeight:
                      selected ? FontWeight.w700 : FontWeight.w500,
                ),
                side: BorderSide(
                    color: selected ? _C.purple : _C.border),
                backgroundColor: Colors.white,
                visualDensity: VisualDensity.compact,
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}

class _VisitTile extends StatelessWidget {
  final VisitEntry entry;
  const _VisitTile({required this.entry});

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
                  color: _C.purple.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.place,
                    color: _C.purple, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      entry.customerName ?? 'بدون عميل',
                      style: const TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w700),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _fmtDateTime(entry.visitDate),
                      style: const TextStyle(
                          fontSize: 11, color: _C.textSecondary),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: _C.purple.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  entry.purposeLabel,
                  style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: _C.purple),
                ),
              ),
            ],
          ),
          if (entry.notes != null && entry.notes!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: _C.surfaceGray,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(entry.notes!,
                  style: const TextStyle(
                      fontSize: 12, color: _C.textSecondary)),
            ),
          ],
          if (entry.hasLocation) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.my_location,
                    size: 12, color: _C.success),
                const SizedBox(width: 4),
                Text(
                  '${entry.latitude!.toStringAsFixed(4)}, ${entry.longitude!.toStringAsFixed(4)}',
                  style: const TextStyle(
                      fontSize: 11, color: _C.success),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

String _fmtDateTime(DateTime d) =>
    DateFormat('yyyy/MM/dd HH:mm', 'en').format(d);

class _C {
  static const primary = Color(0xFF00897B);
  static const success = Color(0xFF2E7D32);
  static const danger = Color(0xFFC62828);
  static const purple = Color(0xFF6A1B9A);
  static const surfaceGray = Color(0xFFF5F5F5);
  static const border = Color(0xFFE0E0E0);
  static const text = Color(0xFF1A1A1A);
  static const textSecondary = Color(0xFF757575);
  static const bg = Color(0xFFFAFAFA);
}
