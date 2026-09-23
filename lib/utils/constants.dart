class AppRoutes {
  static const String splash = '/';
  static const String pin = '/pin';
  static const String pinSetup = '/pin-setup';
  static const String dashboard = '/dashboard';
  static const String customers = '/customers';
  static const String customerDetail = '/customer-detail';
  static const String addCustomer = '/add-customer';
  static const String editCustomer = '/edit-customer';
  static const String addDebt = '/add-debt';
  static const String recordPayment = '/record-payment';
  static const String transactionDetail = '/transaction-detail';
  static const String reports = '/reports';
  static const String settings = '/settings';
  static const String reminders = '/reminders';
  static const String payDown = '/pay-down';
}

class AppColors {
  // Brand
  static const int primaryValue = 0xFF1565C0;
  static const int accentValue = 0xFF00897B;

  // Status colors (as hex ints for MaterialColor use)
  static const int paidValue = 0xFF2E7D32;
  static const int partialValue = 0xFFF57F17;
  static const int unpaidValue = 0xFF1565C0;
  static const int overdueValue = 0xFFC62828;
}

class AppStrings {
  static const String appName = 'UtangMate';
  static const String tagline = 'Simple Debt Tracker';
  static const String defaultCurrency = 'PHP';
  static const String defaultCurrencySymbol = '₱';

  // Status labels
  static const String paid = 'Paid';
  static const String partiallyPaid = 'Partial';
  static const String unpaid = 'Unpaid';
  static const String overdue = 'Overdue';

  // Payment methods
  static const String cash = 'Cash';
  static const String gcash = 'GCash';
  static const String bankTransfer = 'Bank Transfer';
  static const String other = 'Other';
}

class AppDurations {
  static const snackbar = Duration(seconds: 3);
  static const animation = Duration(milliseconds: 300);
  static const debounce = Duration(milliseconds: 400);
}
