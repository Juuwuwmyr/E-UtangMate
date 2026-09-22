enum AuditAction {
  customerCreated,
  customerUpdated,
  customerArchived,
  transactionCreated,
  transactionUpdated,
  transactionDeleted,
  paymentCreated,
  paymentDeleted,
  settingsUpdated,
  pinChanged,
  backupCreated,
  dataRestored,
}

class AuditLog {
  final int? id;
  final AuditAction action;
  final String entityType; // customer, transaction, payment, etc.
  final String? entityId;
  final String description;
  final String? oldValue;
  final String? newValue;
  final DateTime createdAt;

  const AuditLog({
    this.id,
    required this.action,
    required this.entityType,
    this.entityId,
    required this.description,
    this.oldValue,
    this.newValue,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'action': action.name,
      'entity_type': entityType,
      'entity_id': entityId,
      'description': description,
      'old_value': oldValue,
      'new_value': newValue,
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory AuditLog.fromMap(Map<String, dynamic> map) {
    return AuditLog(
      id: map['id'] as int?,
      action: AuditAction.values.firstWhere(
        (e) => e.name == (map['action'] as String),
        orElse: () => AuditAction.settingsUpdated,
      ),
      entityType: map['entity_type'] as String,
      entityId: map['entity_id'] as String?,
      description: map['description'] as String,
      oldValue: map['old_value'] as String?,
      newValue: map['new_value'] as String?,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }
}
