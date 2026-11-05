import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../widgets/pos_customer_bar.dart';
import '../widgets/pos_search_field.dart';
import '../widgets/pos_results_list.dart';
import '../widgets/pos_cart_list.dart';
import '../widgets/pos_bottom_panel.dart';
import '../dialogs/pos_unit_selector_sheet.dart';
import '../dialogs/pos_customer_picker_sheet.dart';
import '../dialogs/pos_payment_dialog.dart';
import '../widgets/pos_scanner_page.dart';

class PosPage extends StatefulWidget {
  final String companyId;
  final String branchId;
  const PosPage({super.key, required this.companyId, required this.branchId});

  @override
  State<PosPage> createState() => _PosPageState();
}

class _PosPageState extends State<PosPage> {
  List<Map<String, dynamic>> _products = [];
  List<Map<String, dynamic>> _filteredProducts = [];
  Map<String, double> _stockMap = {};
  List<Map<String, dynamic>> _customers = [];

  final _searchCtrl = TextEditingController();
  final _searchFocus = FocusNode();
  Timer? _debounce;
  bool _loading = true;
  bool _isSearching = false;

  List<Map<String, dynamic>> _cart = [];
  Map<String, dynamic>? _selectedCustomer;
  double _discount = 0;

  @override
  void initState() {
    super.initState();
    _loadData();
    _searchCtrl.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtrl.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    try {
      final client = Supabase.instance.client;

      // 1. جلب المنتجات
      final prods = await client
          .from('products')
          .select('id, name, selling_price, min_selling_price, max_selling_price, default_unit_id')
          .eq('company_id', widget.companyId)
          .eq('is_active', true);

      // 2. جلب جميع الوحدات المتاحة (لتحويل المعرفات إلى أسماء)
      final unitsData = await client
          .from('units')
          .select('id, name')
          .eq('company_id', widget.companyId);
      
      final Map<String, String> unitNames = {};
      for (var u in unitsData) {
        unitNames[u['id'] as String] = u['name'] as String;
      }

      // 3. جلب وحدات المنتجات الإضافية
      final productUnitsData = await client
          .from('product_units')
          .select('id, product_id, unit_id, conversion_factor, selling_price, min_selling_price, max_selling_price')
          .eq('company_id', widget.companyId);

      // 4. جلب المخزون
      final stock = await client
          .from('inventory_balances')
          .select('product_id, quantity_on_hand')
          .eq('branch_id', widget.branchId);

      final Map<String, double> sMap = {};
      for (var s in stock) {
        if (s['product_id'] != null && s['quantity_on_hand'] != null) {
          sMap[s['product_id']] = (s['quantity_on_hand'] as num).toDouble();
        }
      }

      // 5. جلب العملاء
      final custs = await client
          .from('customers')
          .select('id, name, phone, balance')
          .eq('company_id', widget.companyId)
          .order('name');

      // دمج البيانات برمجياً
      final List<Map<String, dynamic>> fullProducts = [];
      for (var p in prods) {
        final String pId = p['id'] as String;
        
        final extras = productUnitsData.where((pu) => pu['product_id'] == pId).map((pu) {
          return {
            'id': pu['id'],
            'unit_id': pu['unit_id'],
            'unit_name': unitNames[pu['unit_id']] ?? 'وحدة',
            'conversion_factor': pu['conversion_factor'],
            'selling_price': pu['selling_price'],
            'min_selling_price': pu['min_selling_price'],
            'max_selling_price': pu['max_selling_price'],
          };
        }).toList();

        fullProducts.add({
          'id': pId,
          'name': p['name'],
          'selling_price': p['selling_price'],
          'min_selling_price': p['min_selling_price'],
          'max_selling_price': p['max_selling_price'],
          'default_unit_id': p['default_unit_id'],
          'base_unit_name': unitNames[p['default_unit_id']] ?? 'قطعة',
          'product_units': extras,
        });
      }

      if (mounted) {
        setState(() {
          _products = fullProducts;
          _filteredProducts = _products;
          _stockMap = sMap;
          _customers = (custs as List).cast<Map<String, dynamic>>();
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خطأ: $e')));
      }
    }
  }

  void _onSearchChanged() {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      final q = _searchCtrl.text.toLowerCase().trim();
      setState(() {
        _isSearching = q.isNotEmpty;
        _filteredProducts = _products.where((p) {
          final name = (p['name'] ?? '').toString().toLowerCase();
          return name.contains(q);
        }).toList();
      });
    });
  }

  double get _subtotal => _cart.fold(0, (sum, item) => sum + (item['price'] * item['qty']));
  double get _total => _subtotal - _discount;
  double get _customerBalance => (_selectedCustomer?['balance'] as num?)?.toDouble() ?? 0.0;

  void _addToCart(Map<String, dynamic> line) {
    setState(() {
      final i = _cart.indexWhere((item) => item['product_id'] == line['product_id'] && item['unit_id'] == line['unit_id']);
      if (i >= 0) {
        _cart[i]['qty'] += line['qty'];
      } else {
        _cart.add(line);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('نقطة البيع'),
        actions: [
          if (_cart.isNotEmpty)
            IconButton(icon: const Icon(Icons.delete_sweep, color: Colors.red), onPressed: () => setState(() => _cart.clear())),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                PosCustomerBar(
                  customer: _selectedCustomer,
                  balance: _customerBalance,
                  onTap: () async {
                    final sel = await showModalBottomSheet<Map<String, dynamic>>(
                      context: context, isScrollControlled: true,
                      builder: (_) => PosCustomerPickerSheet(customers: _customers),
                    );
                    if (sel != null) setState(() => _selectedCustomer = sel);
                  },
                  onClear: () => setState(() => _selectedCustomer = null),
                ),
                PosSearchField(
                  controller: _searchCtrl,
                  focusNode: _searchFocus,
                  onScan: () async {
                    final res = await Navigator.push<String>(context, MaterialPageRoute(builder: (_) => const PosScannerPage()));
                    if (res != null) _searchCtrl.text = res;
                  },
                  onClear: () {
                    _searchCtrl.clear();
                    _searchFocus.unfocus();
                  },
                ),
                Expanded(
                  child: _isSearching
                      ? Column(
                          children: [
                            const _SectionLabel(icon: Icons.search, label: 'نتائج البحث'),
                            Flexible(
                              flex: 2,
                              child: PosResultsList(
                                products: _filteredProducts,
                                stockMap: _stockMap,
                                onTap: (p) async {
                                  final r = await showModalBottomSheet<Map<String, dynamic>>(
                                    context: context, isScrollControlled: true,
                                    builder: (_) => PosUnitSelectorSheet(product: p, stock: _stockMap[p['id']] ?? 0),
                                  );
                                  if (r != null) { _addToCart(r); _searchCtrl.clear(); _searchFocus.unfocus(); }
                                },
                              ),
                            ),
                            const Divider(height: 1),
                            const _SectionLabel(icon: Icons.shopping_cart_outlined, label: 'السلة'),
                            Flexible(
                              flex: 3,
                              child: PosCartList(
                                cart: _cart,
                                onUpdateQty: (i, q) => setState(() => _cart[i]['qty'] = q),
                                onUpdatePrice: (i, p) => setState(() => _cart[i]['price'] = p),
                                onRemove: (i) => setState(() => _cart.removeAt(i)),
                              ),
                            ),
                          ],
                        )
                      : PosCartList(
                          cart: _cart,
                          onUpdateQty: (i, q) => setState(() => _cart[i]['qty'] = q),
                          onUpdatePrice: (i, p) => setState(() => _cart[i]['price'] = p),
                          onRemove: (i) => setState(() => _cart.removeAt(i)),
                        ),
                ),
                if (!_isSearching && _cart.isNotEmpty)
                  PosBottomPanel(
                    subtotal: _subtotal,
                    discount: _discount,
                    total: _total,
                    onDiscountChanged: (v) => setState(() => _discount = v),
                    onPay: () async {
                      final ok = await showModalBottomSheet<bool>(
                        context: context, isScrollControlled: true,
                        builder: (_) => PosPaymentDialog(
                          companyId: widget.companyId,
                          cart: _cart,
                          customer: _selectedCustomer,
                          discount: _discount,
                          total: _total,
                          customerBalance: _customerBalance,
                        ),
                      );
                      if (ok == true) {
                        setState(() { _cart.clear(); _discount = 0; _selectedCustomer = null; });
                        _loadData();
                      }
                    },
                  ),
              ],
            ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final IconData icon;
  final String label;
  const _SectionLabel({required this.icon, required this.label});
  
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 2),
      child: Row(
        children: [
          Icon(icon, size: 14, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 6),
          Text(label, style: Theme.of(context).textTheme.labelSmall?.copyWith(color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.bold)),
          const Spacer(),
          Container(width: 24, height: 2, color: Theme.of(context).colorScheme.primary.withOpacity(0.3)),
        ],
      ),
    );
  }
}
