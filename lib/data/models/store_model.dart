class Store {
  final int? id;
  final String name;
  final String? address;
  final String? phone;
  final String? email;
  final String? logoPath;
  final String currency;
  final String currencySymbol;
  final String? tin;
  final String? notes;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Store({
    this.id,
    required this.name,
    this.address,
    this.phone,
    this.email,
    this.logoPath,
    this.currency = 'PHP',
    this.currencySymbol = '₱',
    this.tin,
    this.notes,
    required this.createdAt,
    required this.updatedAt,
  });

  Store copyWith({
    int? id,
    String? name,
    String? address,
    String? phone,
    String? email,
    String? logoPath,
    String? currency,
    String? currencySymbol,
    String? tin,
    String? notes,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Store(
      id: id ?? this.id,
      name: name ?? this.name,
      address: address ?? this.address,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      logoPath: logoPath ?? this.logoPath,
      currency: currency ?? this.currency,
      currencySymbol: currencySymbol ?? this.currencySymbol,
      tin: tin ?? this.tin,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'name': name,
      'address': address,
      'phone': phone,
      'email': email,
      'logo_path': logoPath,
      'currency': currency,
      'currency_symbol': currencySymbol,
      'tin': tin,
      'notes': notes,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  factory Store.fromMap(Map<String, dynamic> map) {
    return Store(
      id: map['id'] as int?,
      name: map['name'] as String,
      address: map['address'] as String?,
      phone: map['phone'] as String?,
      email: map['email'] as String?,
      logoPath: map['logo_path'] as String?,
      currency: map['currency'] as String? ?? 'PHP',
      currencySymbol: map['currency_symbol'] as String? ?? '₱',
      tin: map['tin'] as String?,
      notes: map['notes'] as String?,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }

  factory Store.defaultStore() {
    final now = DateTime.now();
    return Store(
      name: 'My Store',
      currency: 'PHP',
      currencySymbol: '₱',
      createdAt: now,
      updatedAt: now,
    );
  }
}
