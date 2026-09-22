import 'package:intl/intl.dart';

class AppFormatter {
  static String currency(double amount, {String symbol = '₱'}) {
    final formatter = NumberFormat('#,##0.00', 'en_PH');
    return '$symbol${formatter.format(amount)}';
  }

  static String shortCurrency(double amount, {String symbol = '₱'}) {
    if (amount >= 1000000) {
      return '$symbol${(amount / 1000000).toStringAsFixed(1)}M';
    } else if (amount >= 1000) {
      return '$symbol${(amount / 1000).toStringAsFixed(1)}K';
    }
    return currency(amount, symbol: symbol);
  }

  static String date(DateTime date) {
    return DateFormat('MMM d, yyyy').format(date);
  }

  static String dateTime(DateTime date) {
    return DateFormat('MMM d, yyyy h:mm a').format(date);
  }

  static String shortDate(DateTime date) {
    return DateFormat('MM/dd/yyyy').format(date);
  }

  static String timeAgo(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return AppFormatter.date(date);
  }

  static String monthYear(DateTime date) {
    return DateFormat('MMM yyyy').format(date);
  }

  static String monthShort(DateTime date) {
    return DateFormat('MMM').format(date);
  }

  static String overdueLabel(int days) {
    if (days <= 0) return 'Due today';
    if (days == 1) return '1 day overdue';
    return '$days days overdue';
  }

  static String dueSoonLabel(int days) {
    if (days <= 0) return 'Due today';
    if (days == 1) return 'Due tomorrow';
    return 'Due in $days days';
  }

  static String number(int n) {
    return NumberFormat('#,###').format(n);
  }
}
