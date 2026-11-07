import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../data/pos_repository.dart';
import '../../domain/pos_models.dart';
import '../dialogs/pos_unit_selector_sheet.dart';
import '../dialogs/pos_payment_sheet.dart'; // سنفترض وجوده أو إنشائه
import '../widgets/pos_scanner_page.dart'; // سنفترض وجوده

class _C {
  static const primary = Color(0xFF00897B);
  static const primaryDark = Color(0xFF00695C);
  static const primaryLight = Color(0xFFE0F2F1);
  static const success = Color(0xFF2E7D32);
  static const successLight = Color(0xFFE8F5E9);
  static const warning = Color(0xFFE65100);
  static const danger = Color(0xFFC62828);
  static const dangerLight = Color(0xFFFFEBEE);
  static const surface = Colors.white;
  static const surfaceGray = Color(0xFFF5F5F5);
  static const border = Color(0xFFE0E0E0);
  static const text = Color(0xFF1A1A1A);
  static const textSecondary = Color(0xFF757575);
  static const bg = Color(0xFFFAFAFA);
}

class PosPage extends StatefulWidget {
  final String companyId;
  final String branchId;

  const PosPage({
    super.key,
    required this.companyId,
    required this.branchId,
  });

  @override
  State<PosPage> createState() => _PosPageState();
}

class _PosPageState extends State<PosPage> {
  late final PosRepository _repo;
  final _searchCtrl = TextEditingController();

  List<PosProduct> _products = [];
  List<PosCustomer> _customers = [];
  List<PosCartLine> _cart = [];
  PosCustomer? _selectedCustomer;

  bool _loading = true;
  String? _error;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _repo = PosRepository(Supabase.instance.client);
    _loadData();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await Future.wait([
        _repo.loadProducts(companyId: widget.companyId, branchId: widget.branchId),
        _repo.loadCustomers(companyId: widget.companyId),
      ]);
      if (!mounted) return;
      setState(() {
        _products = results[0] as List<PosProduct>;
        _customers = results[1] as List<PosCustomer>;
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

  // ─── Cart Logic ───
  double get _grandTotal => _cart.fold(0.0, (s, line) => s + line.lineTotal);
  int get _totalItems => _cart.fold(0, (s, line) => s + line.quantity.toInt());

  void _addToCart(PosProduct product) async {
    final unit = await showModalBottomSheet<PosProductUnit>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => PosUnitSelectorSheet(product: product),
    );
    if (unit == null) return;

    setState(() {
      final existingIndex = _cart.indexWhere(
        (l) => l.product.id == product.id && l.unit.id == unit.id,
      );
      if (existingIndex >= 0) {
        _cart[existingIndex].quantity += 1;
      } else {
        _cart.add(PosCartLine(
          product: product,
          unit: unit,
          quantity: 1,
          unitPrice: unit.effectivePrice,
        ));
      }
    });
  }

  void _removeFromCart(int index) {
    setState(() {
      if (_cart[index].quantity > 1) {
        _cart[index].quantity -= 1;
      } else {
        _cart.removeAt(index);
      }
    });
  }

  // ─── UI ───
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _C.bg,
      appBar: _buildAppBar(),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: _C.primary))
          : _error != null
              ? _buildError()
              : _buildBody(),
      bottomNavigationBar: _cart.isEmpty ? null : _buildCartSummaryBar(),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: _C.surface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      iconTheme: const IconThemeData(color: _C.text),
      title: const Text('نقطة البيع',
          style: TextStyle(fontWeight: FontWeight.bold, color: _C.text, fontSize: 18)),
      actions: [
        IconButton(
          onPressed: () async {
            final barcode = await Navigator.push<String>(
              context,
              MaterialPageRoute(builder: (_) => const PosScannerPage()),
            );
            if (barcode != null) {
              _searchCtrl.text = barcode;
              setState(() => _searchQuery = barcode);
            }
          },
          icon: const Icon(Icons.qr_code_scanner, color: _C.primary),
          tooltip: 'مسح باركود',
        ),
      ],
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(60),
        child: Container(
          color: _C.surface,
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: TextField(
            controller: _searchCtrl,
            decoration: InputDecoration(
              hintText: 'ابحث بالاسم أو الباركود...',
              prefixIcon: const Icon(Icons.search, color: _C.textSecondary),
              filled: true,
              fillColor: _C.surfaceGray,
              contentPadding: const EdgeInsets.symmetric(vertical: 12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
            onChanged: (v) => setState(() => _searchQuery = v),
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    final filteredProducts = _products.where((p) {
      final q = _searchQuery.toLowerCase();
      return p.name.toLowerCase().contains(q) ||
          (p.barcode ?? '').contains(q) ||
          (p.sku ?? '').toLowerCase().contains(q);
    }).toList();

    if (filteredProducts.isEmpty && _searchQuery.isNotEmpty) {
      return const Center(child: Text('لا توجد نتائج مطابقة', style: TextStyle(color: _C.textSecondary)));
    }

    return Column(
      children: [
        _buildCustomerBar(),
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.all(12),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              childAspectRatio: 1.4,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
            ),
            itemCount: filteredProducts.length,
            itemBuilder: (_, i) => _ProductCard(
              product: filteredProducts[i],
              onTap: () => _addToCart(filteredProducts[i]),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCustomerBar() {
    return InkWell(
      onTap: _showCustomerPicker,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: _selectedCustomer != null ? _C.primaryLight : Colors.white,
          border: const Border(bottom: BorderSide(color: _C.border)),
        ),
        child: Row(
          children: [
            Icon(
              Icons.person,
              color: _selectedCustomer != null ? _C.primaryDark : _C.textSecondary,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                _selectedCustomer?.name ?? 'تحديد عميل (اختياري)',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: _selectedCustomer != null ? FontWeight.bold : FontWeight.normal,
                  color: _selectedCustomer != null ? _C.primaryDark : _C.textSecondary,
                ),
              ),
            ),
            if (_selectedCustomer != null)
              IconButton(
                icon: const Icon(Icons.close, size: 18, color: _C.primaryDark),
                onPressed: () => setState(() => _selectedCustomer = null),
              )
            else
              const Icon(Icons.chevron_left, color: _C.textSecondary),
          ],
        ),
      ),
    );
  }

  Widget _buildCartSummaryBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      decoration: BoxDecoration(
        color: _C.surface,
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, -4)),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            // زر عرض السلة
            InkWell(
              onTap: _showCartSheet,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: _C.primaryLight,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _C.primary.withOpacity(0.3)),
                ),
                child: Column(
                  children: [
                    Text('$_totalItems', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: _C.primaryDark)),
                    const Text('عناصر', style: TextStyle(fontSize: 10, color: _C.primaryDark)),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 12),
            // زر الدفع
            Expanded(
              child: SizedBox(
                height: 56,
                child: ElevatedButton(
                  onPressed: _showPaymentSheet,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _C.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('الدفع', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      Text('${_grandTotal.toStringAsFixed(2)} ج.م', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Sheets ───
  void _showCustomerPicker() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        height: MediaQuery.of(context).size.height * 0.6,
        decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
        child: Column(
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('اختيار عميل', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ),
            Expanded(
              child: ListView.builder(
                itemCount: _customers.length,
                itemBuilder: (_, i) => ListTile(
                  title: Text(_customers[i].name),
                  subtitle: Text(_customers[i].phone ?? ''),
                  onTap: () {
                    setState(() => _selectedCustomer = _customers[i]);
                    Navigator.pop(context);
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showCartSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => StatefulBuilder(
        builder: (context, setModalState) {
          return Container(
            height: MediaQuery.of(context).size.height * 0.7,
            decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
            child: Column(
              children: [
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('سلة المشتريات', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ),
                const Divider(height: 1),
                Expanded(
                  child: ListView.separated(
                    itemCount: _cart.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (_, i) {
                      final line = _cart[i];
                      return ListTile(
                        title: Text(line.product.name),
                        subtitle: Text('${line.unitPrice.toStringAsFixed(2)} × ${line.unit.name}'),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.remove_circle_outline, color: _C.danger),
                              onPressed: () {
                                _removeFromCart(i);
                                setModalState(() {});
                              },
                            ),
                            Text('${line.quantity}', style: const TextStyle(fontWeight: FontWeight.bold)),
                            IconButton(
                              icon: const Icon(Icons.add_circle_outline, color: _C.primary),
                              onPressed: () {
                                setState(() => line.quantity += 1);
                                setModalState(() {});
                              },
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _showPaymentSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => PosPaymentSheet(
        cart: _cart,
        customer: _selectedCustomer,
        companyId: widget.companyId,
        branchId: widget.branchId,
        repo: _repo,
        onSuccess: () {
          setState(() {
            _cart.clear();
            _selectedCustomer = null;
          });
        },
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline, color: _C.danger, size: 48),
          const SizedBox(height: 12),
          Text(_error!, textAlign: TextAlign.center),
          const SizedBox(height: 12),
          ElevatedButton(onPressed: _loadData, child: const Text('إعادة المحاولة')),
        ],
      ),
    );
  }
}

// ─── Product Card Widget ───
class _ProductCard extends StatelessWidget {
  final PosProduct product;
  final VoidCallback onTap;

  const _ProductCard({required this.product, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final hasStock = product.stockQty > 0;
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: hasStock ? onTap : null,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _C.border),
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 4, offset: const Offset(0, 2)),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  product.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: _C.text),
                ),
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${product.defaultPrice.toStringAsFixed(2)} ج.م',
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: _C.primary),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: hasStock ? _C.successLight : _C.dangerLight,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      hasStock ? '${product.stockQty.toInt()} متاح' : 'نفذ',
                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: hasStock ? _C.success : _C.danger),
                    ),
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
