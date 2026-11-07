class CompanyInfo {
  final String id;
  final String name;
  final String? phone;
  final String? email;
  final String? address;
  final String? taxNumber;
  final String? commercialRegister;

  const CompanyInfo({
    required this.id,
    required this.name,
    this.phone,
    this.email,
    this.address,
    this.taxNumber,
    this.commercialRegister,
  });

  factory CompanyInfo.fromJson(Map<String, dynamic> j) => CompanyInfo(
        id: j['id'] as String,
        name: (j['name'] as String?) ?? 'شركة',
        phone: j['phone'] as String?,
        email: j['email'] as String?,
        address: j['address'] as String?,
        taxNumber: j['tax_number'] as String?,
        commercialRegister: j['commercial_register'] as String?,
      );
}
