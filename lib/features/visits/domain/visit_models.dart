class VisitEntry {
  final String id;
  final String? customerId;
  final String? customerName;
  final DateTime visitDate;
  final double? latitude;
  final double? longitude;
  final String purpose;
  final String? notes;

  const VisitEntry({
    required this.id,
    this.customerId,
    this.customerName,
    required this.visitDate,
    this.latitude,
    this.longitude,
    required this.purpose,
    this.notes,
  });

  factory VisitEntry.fromJson(Map<String, dynamic> j) => VisitEntry(
        id: j['id'] as String,
        customerId: j['customer_id'] as String?,
        customerName: j['customer_name'] as String?,
        visitDate: DateTime.parse(j['visit_date'] as String),
        latitude: (j['latitude'] as num?)?.toDouble(),
        longitude: (j['longitude'] as num?)?.toDouble(),
        purpose: (j['purpose'] as String?) ?? 'general',
        notes: j['notes'] as String?,
      );

  bool get hasLocation => latitude != null && longitude != null;
  String get purposeLabel => purposeLabelOf(purpose);
}

class VisitCustomer {
  final String id;
  final String name;
  final String? phone;

  const VisitCustomer({
    required this.id,
    required this.name,
    this.phone,
  });

  factory VisitCustomer.fromJson(Map<String, dynamic> j) => VisitCustomer(
        id: j['id'] as String,
        name: (j['name'] ?? j['customer_name'] ?? '') as String,
        phone: j['phone'] as String?,
      );
}

const kVisitPurposes = <String>[
  'general',
  'collection',
  'followup',
  'complaint',
  'delivery',
  'other',
];

String purposeLabelOf(String p) => switch (p) {
      'general' => 'زيارة عامة',
      'collection' => 'تحصيل',
      'followup' => 'متابعة',
      'complaint' => 'شكوى',
      'delivery' => 'تسليم',
      'other' => 'أخرى',
      _ => p,
    };
