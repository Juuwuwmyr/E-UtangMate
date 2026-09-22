class AppValidators {
  static String? required(String? value, [String fieldName = 'This field']) {
    if (value == null || value.trim().isEmpty) {
      return '$fieldName is required';
    }
    return null;
  }

  static String? phone(String? value) {
    if (value == null || value.trim().isEmpty) return null; // optional
    final cleaned = value.replaceAll(RegExp(r'[\s\-\(\)]'), '');
    if (!RegExp(r'^(\+63|0)?[0-9]{10,11}$').hasMatch(cleaned)) {
      return 'Enter a valid Philippine phone number';
    }
    return null;
  }

  static String? email(String? value) {
    if (value == null || value.trim().isEmpty) return null; // optional
    if (!RegExp(r'^[\w.+-]+@[\w-]+\.[a-zA-Z]{2,}$').hasMatch(value.trim())) {
      return 'Enter a valid email address';
    }
    return null;
  }

  static String? amount(String? value, {double? max, double? min}) {
    if (value == null || value.trim().isEmpty) {
      return 'Amount is required';
    }
    final parsed = double.tryParse(value.replaceAll(',', ''));
    if (parsed == null) {
      return 'Enter a valid amount';
    }
    if (parsed <= 0) {
      return 'Amount must be greater than 0';
    }
    if (min != null && parsed < min) {
      return 'Amount must be at least ₱${min.toStringAsFixed(2)}';
    }
    if (max != null && parsed > max) {
      return 'Amount cannot exceed ₱${max.toStringAsFixed(2)}';
    }
    return null;
  }

  static String? quantity(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Quantity is required';
    }
    final parsed = double.tryParse(value);
    if (parsed == null || parsed <= 0) {
      return 'Enter a valid quantity';
    }
    return null;
  }

  static String? pin(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'PIN is required';
    }
    if (value.length < 4) {
      return 'PIN must be at least 4 digits';
    }
    if (!RegExp(r'^\d+$').hasMatch(value)) {
      return 'PIN must contain numbers only';
    }
    return null;
  }

  static String? pinConfirm(String? value, String pin) {
    if (value != pin) return 'PINs do not match';
    return null;
  }
}
