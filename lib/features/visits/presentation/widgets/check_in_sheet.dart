import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import '../../data/visits_repository.dart';
import '../../domain/visit_models.dart';

class CheckInSheet extends StatefulWidget {
  final String companyId;
  final String salesRepId;
  final VisitsRepository repo;

  const CheckInSheet({
    super.key,
    required this.companyId,
    required this.salesRepId,
    required this.repo,
  });

  @override
  State<CheckInSheet> createState() => _CheckInSheetState();
}

class _CheckInSheetState extends State<CheckInSheet> {
  VisitCustomer? _customer;
  String _purpose = 'general';
  final _notesCtrl = TextEditingController();

  bool _locating = false;
  double? _lat;
  double? _lng;
  String? _locationError;

  bool _saving = false;

  @override
  void dispose() {
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _captureLocation() async {
    setState(() {
      _locating = true;
      _locationError = null;
    });
    try {
      final enabled = await Geolocator.isLocationServiceEnabled();
      if (!enabled) {
        throw 'خدمة الموقع غير مفعلة';
      }
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.denied ||
          perm == LocationPermission.deniedForever) {
        throw 'تم رفض صلاحية الموقع';
      }
      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.medium,
        timeLimit: const Duration(seconds: 15),
      );
      if (!mounted) return;
      setState(() {
        _lat = pos.latitude;
        _lng = pos.longitude;
        _locating = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _locationError = e.toString();
        _locating = false;
      });
    }
  }

  Future<void> _pickCustomer() async {
    final picked = await showModalBottomSheet<VisitCustomer?>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _CustomerPicker(
        companyId: widget.companyId,
        repo: widget.repo,
      ),
    );
    if (picked != null) setState(() => _customer = picked);
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await widget.repo.createVisit(
        companyId: widget.companyId,
        salesRepId: widget.salesRepId,
        customerId: _customer?.id,
        purpose: _purpose,
        notes: _notesCtrl.text,
        latitude: _lat,
        longitude: _lng,
      );
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('فشل الحفظ: $e'),
          backgroundColor: _C.danger,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: Container(
        decoration: const BoxDecoration(
          color: _C.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _handle(),
                _title(),
                const Divider(height: 1, color: _C.border),
                const SizedBox(height: 12),
                _customerField(),
                const SizedBox(height: 12),
                _label('الغرض من الزيارة'),
                const SizedBox(height: 6),
                _purposeChips(),
                const SizedBox(height: 12),
                _label('الموقع'),
                const SizedBox(height: 6),
                _locationBlock(),
                const SizedBox(height: 12),
                _label('ملاحظات (اختياري)'),
                const SizedBox(height: 6),
                TextField(
                  controller: _notesCtrl,
                  maxLines: 2,
                  decoration: _inputDec('ملاحظات'),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _saving ? null : _save,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _C.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(28),
                      ),
                      elevation: 0,
                    ),
                    child: _saving
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white),
                          )
                        : const Text('تسجيل الزيارة',
                            style: TextStyle(
                                fontSize: 15, fontWeight: FontWeight.w800)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _handle() => Center(
        child: Container(
          margin: const EdgeInsets.only(top: 10, bottom: 4),
          width: 42,
          height: 4,
          decoration: BoxDecoration(
            color: _C.border,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
      );

  Widget _title() => Padding(
        padding: const EdgeInsets.fromLTRB(0, 6, 0, 10),
        child: Row(
          children: [
            const Expanded(
              child: Text('تسجيل زيارة',
                  style: TextStyle(
                      fontSize: 18, fontWeight: FontWeight.w800)),
            ),
            IconButton(
              onPressed: () => Navigator.of(context).maybePop(),
              icon: const Icon(Icons.close, color: _C.textSecondary),
            ),
          ],
        ),
      );

  Widget _customerField() {
    return InkWell(
      onTap: _pickCustomer,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: _C.primaryLight,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _C.primary.withOpacity(0.3)),
        ),
        child: Row(
          children: [
            const Icon(Icons.person, color: _C.primaryDark),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('العميل',
                      style: TextStyle(
                          fontSize: 11, color: _C.textSecondary)),
                  Text(
                    _customer?.name ?? 'اختر عميلاً (اختياري)',
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: _customer != null
                            ? _C.primaryDark
                            : _C.textSecondary),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            if (_customer != null)
              IconButton(
                onPressed: () => setState(() => _customer = null),
                icon: const Icon(Icons.close, size: 18),
              )
            else
              const Icon(Icons.chevron_left, color: _C.primaryDark),
          ],
        ),
      ),
    );
  }

  Widget _purposeChips() {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: kVisitPurposes.map((p) {
        final selected = _purpose == p;
        return ChoiceChip(
          label: Text(purposeLabelOf(p),
              style: TextStyle(
                  fontSize: 12,
                  color: selected ? _C.primaryDark : _C.text,
                  fontWeight:
                      selected ? FontWeight.w700 : FontWeight.w500)),
          selected: selected,
          onSelected: (_) => setState(() => _purpose = p),
          selectedColor: _C.primaryLight,
          side: BorderSide(color: selected ? _C.primary : _C.border),
          backgroundColor: Colors.white,
          visualDensity: VisualDensity.compact,
        );
      }).toList(),
    );
  }

  Widget _locationBlock() {
    if (_lat != null && _lng != null) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: _C.success.withOpacity(0.08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: _C.success.withOpacity(0.3)),
        ),
        child: Row(
          children: [
            const Icon(Icons.check_circle, color: _C.success, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                '${_lat!.toStringAsFixed(5)}, ${_lng!.toStringAsFixed(5)}',
                style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: _C.success),
              ),
            ),
            TextButton(
              onPressed: () => setState(() {
                _lat = null;
                _lng = null;
              }),
              style: TextButton.styleFrom(
                padding: EdgeInsets.zero,
                minimumSize: const Size(0, 24),
              ),
              child: const Text('إزالة',
                  style: TextStyle(fontSize: 11, color: _C.textSecondary)),
            ),
          ],
        ),
      );
    }
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _C.surfaceGray,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _C.border),
      ),
      child: Column(
        children: [
          if (_locationError != null) ...[
            Row(
              children: [
                const Icon(Icons.info_outline,
                    color: _C.warning, size: 16),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(_locationError!,
                      style: const TextStyle(
                          fontSize: 11, color: _C.warning)),
                ),
              ],
            ),
            const SizedBox(height: 8),
          ],
          Row(
            children: [
              const Icon(Icons.location_off,
                  color: _C.textSecondary, size: 18),
              const SizedBox(width: 8),
              const Expanded(
                child: Text('الموقع غير مسجل',
                    style: TextStyle(
                        fontSize: 12, color: _C.textSecondary)),
              ),
              TextButton(
                onPressed: _locating ? null : _captureLocation,
                child: _locating
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: _C.primary),
                      )
                    : const Text('تحديد الموقع'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _label(String t) => Text(t,
      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700));

  InputDecoration _inputDec(String hint) => InputDecoration(
        hintText: hint,
        filled: true,
        fillColor: _C.surfaceGray,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
      );
}

// ─── Customer picker ────────────────────────────────────────────────────────

class _CustomerPicker extends StatefulWidget {
  final String companyId;
  final VisitsRepository repo;
  const _CustomerPicker({required this.companyId, required this.repo});

  @override
  State<_CustomerPicker> createState() => _CustomerPickerState();
}

class _CustomerPickerState extends State<_CustomerPicker> {
  final _ctrl = TextEditingController();
  bool _loading = true;
  List<VisitCustomer> _list = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final list = await widget.repo.searchCustomers(
        companyId: widget.companyId,
        query: _ctrl.text,
      );
      if (!mounted) return;
      setState(() {
        _list = list;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.7,
      decoration: const BoxDecoration(
        color: _C.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          children: [
            Container(
              margin: const EdgeInsets.only(top: 10, bottom: 4),
              width: 42,
              height: 4,
              decoration: BoxDecoration(
                color: _C.border,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
              child: Row(
                children: [
                  const Text('اختيار عميل',
                      style: TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w800)),
                  const Spacer(),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close,
                        color: _C.textSecondary),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: _C.border),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: TextField(
                controller: _ctrl,
                onChanged: (_) => _load(),
                decoration: InputDecoration(
                  hintText: 'ابحث بالاسم أو الهاتف',
                  prefixIcon: const Icon(Icons.search),
                  filled: true,
                  fillColor: _C.surfaceGray,
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
            Expanded(
              child: _loading
                  ? const Center(
                      child: CircularProgressIndicator(color: _C.primary))
                  : _list.isEmpty
                      ? const Center(
                          child: Text('لا يوجد عملاء',
                              style: TextStyle(color: _C.textSecondary)))
                      : ListView.separated(
                          padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                          itemCount: _list.length,
                          separatorBuilder: (_, __) =>
                              const Divider(height: 1),
                          itemBuilder: (_, i) {
                            final c = _list[i];
                            return ListTile(
                              onTap: () => Navigator.pop(context, c),
                              title: Text(c.name,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w700)),
                              subtitle: c.phone != null
                                  ? Text(c.phone!)
                                  : null,
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }
}

class _C {
  static const primary = Color(0xFF00897B);
  static const primaryDark = Color(0xFF00695C);
  static const primaryLight = Color(0xFFE0F2F1);
  static const success = Color(0xFF2E7D32);
  static const warning = Color(0xFFE65100);
  static const danger = Color(0xFFC62828);
  static const surface = Colors.white;
  static const surfaceGray = Color(0xFFF5F5F5);
  static const border = Color(0xFFE0E0E0);
  static const text = Color(0xFF1A1A1A);
  static const textSecondary = Color(0xFF757575);
}
