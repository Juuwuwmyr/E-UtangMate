enum CustomerStatus { active, archived }

class Customer {
  final int? id;
  final String customerId; // Human-readable ID e.g. CUST-0001
  final String name;
  final String? phone;
  final String? address;
  final String? email;
  final String? photoPath;
  final String? notes;
  final double? creditLimit;
  final CustomerStatus status;
  final DateTime createdAt;
  final DateTime updatedAt;

  // Computed fields (populated by queries, not stored)
  final double totalDebt;
  final double totalPaid;
  final double outstandingBalance;
  final int unpaidTransactions;
  final int overdueTransactions;
  final DateTime? lastPaymentDate;
  final DateTime? lastTransactionDate;

  const Customer({
    this.id,
    required this.customerId,
    required this.name,
    this.phone,
    this.address,
    this.email,
    this.photoPath,
    this.notes,
    this.creditLimit,
    this.status = CustomerStatus.active,
    required this.createdAt,
    required this.updatedAt,
    this.totalDebt = 0.0,
    this.totalPaid = 0.0,
    this.outstandingBalance = 0.0,
    this.unpaidTransactions = 0,
    this.overdueTransactions = 0,
    this.lastPaymentDate,
    this.lastTransactionDate,
  });

  Customer copyWith({
    int? id,
    String? customerId,
    String? name,
    String? phone,
    String? address,
    String? email,
    String? photoPath,
    String? notes,
    double? creditLimit,
    CustomerStatus? status,
    DateTime? createdAt,
    DateTime? updatedAt,
    double? totalDebt,
    double? totalPaid,
    double? outstandingBalance,
    int? unpaidTransactions,
    int? overdueTransactions,
    DateTime? lastPaymentDate,
    DateTime? lastTransactionDate,
  }) {
    return Customer(
      id: id ?? this.id,
      customerId: customerId ?? this.customerId,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      address: address ?? this.address,
      email: email ?? this.email,
      photoPath: photoPath ?? this.photoPath,
      notes: notes ?? this.notes,
      creditLimit: creditLimit ?? this.creditLimit,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      totalDebt: totalDebt ?? this.totalDebt,
      totalPaid: totalPaid ?? this.totalPaid,
      outstandingBalance: outstandingBalance ?? this.outstandingBalance,
      unpaidTransactions: unpaidTransactions ?? this.unpaidTransactions,
      overdueTransactions: overdueTransactions ?? this.overdueTransactions,
      lastPaymentDate: lastPaymentDate ?? this.lastPaymentDate,
      lastTransactionDate: lastTransactionDate ?? this.lastTransactionDate,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'customer_id': customerId,
      'name': name,
      'phone': phone,
      'address': address,
      'email': email,
      'photo_path': photoPath,
      'notes': notes,
      'credit_limit': creditLimit,
      'status': status.name,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  factory Customer.fromMap(Map<String, dynamic> map) {
    return Customer(
      id: map['id'] as int?,
      customerId: map['customer_id'] as String,
      name: map['name'] as String,
      phone: map['phone'] as String?,
      address: map['address'] as String?,
      email: map['email'] as String?,
      photoPath: map['photo_path'] as String?,
      notes: map['notes'] as String?,
      creditLimit: map['credit_limit'] != null
          ? (map['credit_limit'] as num).toDouble()
          : null,
      status: CustomerStatus.values.firstWhere(
        (e) => e.name == (map['status'] as String? ?? 'active'),
        orElse: () => CustomerStatus.active,
      ),
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
      totalDebt: (map['total_debt'] as num?)?.toDouble() ?? 0.0,
      totalPaid: (map['total_paid'] as num?)?.toDouble() ?? 0.0,
      outstandingBalance:
          (map['outstanding_balance'] as num?)?.toDouble() ?? 0.0,
      unpaidTransactions: map['unpaid_transactions'] as int? ?? 0,
      overdueTransactions: map['overdue_transactions'] as int? ?? 0,
      lastPaymentDate: map['last_payment_date'] != null
          ? DateTime.parse(map['last_payment_date'] as String)
          : null,
      lastTransactionDate: map['last_transaction_date'] != null
          ? DateTime.parse(map['last_transaction_date'] as String)
          : null,
    );
  }

  bool get hasDebt => outstandingBalance > 0;
  bool get isArchived => status == CustomerStatus.archived;
  bool get isOverCreditLimit =>
      creditLimit != null && outstandingBalance > creditLimit!;
}
