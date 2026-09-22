import 'package:flutter/material.dart';
import '../core/theme.dart';
import '../data/models/transaction_model.dart';

class StatusBadge extends StatelessWidget {
  final TransactionStatus status;
  final bool small;

  const StatusBadge({super.key, required this.status, this.small = false});

  @override
  Widget build(BuildContext context) {
    final label = _label(status);
    final color = AppTheme.statusColor(status.name);
    final bg = AppTheme.statusBgColor(status.name);

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: small ? 8 : 10,
        vertical: small ? 3 : 5,
      ),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: small ? 11 : 12,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.3,
        ),
      ),
    );
  }

  String _label(TransactionStatus s) {
    switch (s) {
      case TransactionStatus.paid:
        return 'Paid';
      case TransactionStatus.partiallyPaid:
        return 'Partial';
      case TransactionStatus.overdue:
        return 'Overdue';
      case TransactionStatus.unpaid:
        return 'Unpaid';
    }
  }
}
