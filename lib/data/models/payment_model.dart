enum PaymentMethod { cash, gcash, bankTransfer, other }

class Payment {
  final int? id;
  final String paymentId; // Human-readable PAY-00001
  final int transactionId;
  final int customerId;
  final String customerName; // Denormalized for display
  final String txTransactionId; // Human-readable transaction ref
  final double amount;
  final PaymentMethod paymentMethod;
  final String? referenceNumber;
  final String? notes;
  final DateTime paymentDate;
  final bool isDeleted;
  final DateTime createdAt;

  const Payment({
    this.id,
    required this.paymentId,
    required this.transactionId,
    required this.customerId,
    required this.customerName,
    required this.txTransactionId,
    required this.amount,
    required this.paymentMethod,
    this.referenceNumber,
    this.notes,
    required this.paymentDate,
    this.isDeleted = false,
    required this.createdAt,
  });

  Payment copyWith({
    int? id,
    String? paymentId,
    int? transactionId,
    int? customerId,
    String? customerName,
    String? txTransactionId,
    double? amount,
    PaymentMethod? paymentMethod,
    String? referenceNumber,
    String? notes,
    DateTime? paymentDate,
    bool? isDeleted,
    DateTime? createdAt,
  }) {
    return Payment(
      id: id ?? this.id,
      paymentId: paymentId ?? this.paymentId,
      transactionId: transactionId ?? this.transactionId,
      customerId: customerId ?? this.customerId,
      customerName: customerName ?? this.customerName,
      txTransactionId: txTransactionId ?? this.txTransactionId,
      amount: amount ?? this.amount,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      referenceNumber: referenceNumber ?? this.referenceNumber,
      notes: notes ?? this.notes,
      paymentDate: paymentDate ?? this.paymentDate,
      isDeleted: isDeleted ?? this.isDeleted,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'payment_id': paymentId,
      'transaction_id': transactionId,
      'customer_id': customerId,
      'customer_name': customerName,
      'tx_transaction_id': txTransactionId,
      'amount': amount,
      'payment_method': paymentMethod.name,
      'reference_number': referenceNumber,
      'notes': notes,
      'payment_date': paymentDate.toIso8601String(),
      'is_deleted': isDeleted ? 1 : 0,
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory Payment.fromMap(Map<String, dynamic> map) {
    return Payment(
      id: map['id'] as int?,
      paymentId: map['payment_id'] as String,
      transactionId: map['transaction_id'] as int,
      customerId: map['customer_id'] as int,
      customerName: map['customer_name'] as String? ?? '',
      txTransactionId: map['tx_transaction_id'] as String? ?? '',
      amount: (map['amount'] as num).toDouble(),
      paymentMethod: PaymentMethod.values.firstWhere(
        (e) => e.name == (map['payment_method'] as String? ?? 'cash'),
        orElse: () => PaymentMethod.cash,
      ),
      referenceNumber: map['reference_number'] as String?,
      notes: map['notes'] as String?,
      paymentDate: DateTime.parse(map['payment_date'] as String),
      isDeleted: (map['is_deleted'] as int? ?? 0) == 1,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }

  String get paymentMethodLabel {
    switch (paymentMethod) {
      case PaymentMethod.cash:
        return 'Cash';
      case PaymentMethod.gcash:
        return 'GCash';
      case PaymentMethod.bankTransfer:
        return 'Bank Transfer';
      case PaymentMethod.other:
        return 'Other';
    }
  }
}
