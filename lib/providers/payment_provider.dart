import 'package:flutter/foundation.dart';
import '../data/database/database_helper.dart';
import '../data/models/payment_model.dart';

class PaymentProvider extends ChangeNotifier {
  final DatabaseHelper _db = DatabaseHelper();

  List<Payment> _payments = [];
  bool _isLoading = false;
  bool _isSaving = false;
  String? _error;

  List<Payment> get payments => _payments;
  bool get isLoading => _isLoading;
  bool get isSaving => _isSaving;
  String? get error => _error;

  double get totalPayments =>
      _payments.fold(0.0, (sum, p) => sum + p.amount);

  Future<void> loadPaymentsByTransaction(int transactionId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      _payments = await _db.getPaymentsByTransaction(transactionId);
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadPaymentsByCustomer(int customerId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      _payments = await _db.getPaymentsByCustomer(customerId);
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<Payment?> addPayment(Payment payment) async {
    _isSaving = true;
    _error = null;
    notifyListeners();
    try {
      final created = await _db.insertPayment(payment);
      // Refresh current list
      await loadPaymentsByTransaction(payment.transactionId);
      return created;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return null;
    } finally {
      _isSaving = false;
      notifyListeners();
    }
  }

  Future<List<Payment>> getPaymentsByDateRange(
      DateTime start, DateTime end) async {
    try {
      return await _db.getPaymentsByDateRange(start, end);
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return [];
    }
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}
