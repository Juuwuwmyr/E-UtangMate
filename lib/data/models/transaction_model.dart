enum TransactionStatus { unpaid, partiallyPaid, paid, overdue }

class TransactionItem {
  final int? id;
  final int? transactionId;
  final String itemName;
  final double quantity;
  final String unit;
  final double pricePerUnit;
  final double totalPrice;
  final String? notes;

  const TransactionItem({
    this.id,
    this.transactionId,
    required this.itemName,
    required this.quantity,
    this.unit = 'pcs',
    required this.pricePerUnit,
    required this.totalPrice,
    this.notes,
  });

  TransactionItem copyWith({
    int? id,
    int? transactionId,
    String? itemName,
    double? quantity,
    String? unit,
    double? pricePerUnit,
    double? totalPrice,
    String? notes,
  }) {
    return TransactionItem(
      id: id ?? this.id,
      transactionId: transactionId ?? this.transactionId,
      itemName: itemName ?? this.itemName,
      quantity: quantity ?? this.quantity,
      unit: unit ?? this.unit,
      pricePerUnit: pricePerUnit ?? this.pricePerUnit,
      totalPrice: totalPrice ?? this.totalPrice,
      notes: notes ?? this.notes,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      if (transactionId != null) 'transaction_id': transactionId,
      'item_name': itemName,
      'quantity': quantity,
      'unit': unit,
      'price_per_unit': pricePerUnit,
      'total_price': totalPrice,
      'notes': notes,
    };
  }

  factory TransactionItem.fromMap(Map<String, dynamic> map) {
    return TransactionItem(
      id: map['id'] as int?,
      transactionId: map['transaction_id'] as int?,
      itemName: map['item_name'] as String,
      quantity: (map['quantity'] as num).toDouble(),
      unit: map['unit'] as String? ?? 'pcs',
      pricePerUnit: (map['price_per_unit'] as num).toDouble(),
      totalPrice: (map['total_price'] as num).toDouble(),
      notes: map['notes'] as String?,
    );
  }
}

class DebtTransaction {
  final int? id;
  final String transactionId; // Human-readable TX-00001
  final int customerId;
  final String customerName; // Denormalized for display
  final double totalAmount;
  final double amountPaid;
  final double remainingBalance;
  final TransactionStatus status;
  final DateTime transactionDate;
  final DateTime? dueDate;
  final String? notes;
  final bool isDeleted;
  final DateTime createdAt;
  final DateTime updatedAt;

  // Nested items
  final List<TransactionItem> items;

  const DebtTransaction({
    this.id,
    required this.transactionId,
    required this.customerId,
    required this.customerName,
    required this.totalAmount,
    this.amountPaid = 0.0,
    required this.remainingBalance,
    required this.status,
    required this.transactionDate,
    this.dueDate,
    this.notes,
    this.isDeleted = false,
    required this.createdAt,
    required this.updatedAt,
    this.items = const [],
  });

  DebtTransaction copyWith({
    int? id,
    String? transactionId,
    int? customerId,
    String? customerName,
    double? totalAmount,
    double? amountPaid,
    double? remainingBalance,
    TransactionStatus? status,
    DateTime? transactionDate,
    DateTime? dueDate,
    String? notes,
    bool? isDeleted,
    DateTime? createdAt,
    DateTime? updatedAt,
    List<TransactionItem>? items,
  }) {
    return DebtTransaction(
      id: id ?? this.id,
      transactionId: transactionId ?? this.transactionId,
      customerId: customerId ?? this.customerId,
      customerName: customerName ?? this.customerName,
      totalAmount: totalAmount ?? this.totalAmount,
      amountPaid: amountPaid ?? this.amountPaid,
      remainingBalance: remainingBalance ?? this.remainingBalance,
      status: status ?? this.status,
      transactionDate: transactionDate ?? this.transactionDate,
      dueDate: dueDate ?? this.dueDate,
      notes: notes ?? this.notes,
      isDeleted: isDeleted ?? this.isDeleted,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      items: items ?? this.items,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'transaction_id': transactionId,
      'customer_id': customerId,
      'customer_name': customerName,
      'total_amount': totalAmount,
      'amount_paid': amountPaid,
      'remaining_balance': remainingBalance,
      'status': status.name,
      'transaction_date': transactionDate.toIso8601String(),
      'due_date': dueDate?.toIso8601String(),
      'notes': notes,
      'is_deleted': isDeleted ? 1 : 0,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  factory DebtTransaction.fromMap(Map<String, dynamic> map) {
    return DebtTransaction(
      id: map['id'] as int?,
      transactionId: map['transaction_id'] as String,
      customerId: map['customer_id'] as int,
      customerName: map['customer_name'] as String? ?? '',
      totalAmount: (map['total_amount'] as num).toDouble(),
      amountPaid: (map['amount_paid'] as num?)?.toDouble() ?? 0.0,
      remainingBalance: (map['remaining_balance'] as num).toDouble(),
      status: TransactionStatus.values.firstWhere(
        (e) => e.name == (map['status'] as String? ?? 'unpaid'),
        orElse: () => TransactionStatus.unpaid,
      ),
      transactionDate: DateTime.parse(map['transaction_date'] as String),
      dueDate: map['due_date'] != null
          ? DateTime.parse(map['due_date'] as String)
          : null,
      notes: map['notes'] as String?,
      isDeleted: (map['is_deleted'] as int? ?? 0) == 1,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
      items: (map['items'] as List<dynamic>?)
              ?.map((i) => TransactionItem.fromMap(i as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }

  bool get isOverdue =>
      dueDate != null &&
      dueDate!.isBefore(DateTime.now()) &&
      status != TransactionStatus.paid;

  int get daysOverdue {
    if (!isOverdue) return 0;
    return DateTime.now().difference(dueDate!).inDays;
  }

  int get daysUntilDue {
    if (dueDate == null) return -1;
    return dueDate!.difference(DateTime.now()).inDays;
  }

  bool get isDueSoon => daysUntilDue >= 0 && daysUntilDue <= 3;
}
