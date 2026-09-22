import 'package:flutter/foundation.dart';
import '../data/database/database_helper.dart';
import '../data/models/transaction_model.dart';

class TransactionProvider extends ChangeNotifier {
  final DatabaseHelper _db = DatabaseHelper();

  List<DebtTransaction> _transactions = [];
  List<DebtTransaction> _overdueTransactions = [];
  List<DebtTransaction> _dueSoonTransactions = [];
  DebtTransaction? _selectedTransaction;
  bool _isLoading = false;
  bool _isSaving = false;
  String? _error;

  List<DebtTransaction> get transactions => _transactions;
  List<DebtTransaction> get overdueTransactions => _overdueTransactions;
  List<DebtTransaction> get dueSoonTransactions => _dueSoonTransactions;
  DebtTransaction? get selectedTransaction => _selectedTransaction;
  bool get isLoading => _isLoading;
  bool get isSaving => _isSaving;
  String? get error => _error;

  int get overdueCount => _overdueTransactions.length;
  int get dueSoonCount => _dueSoonTransactions.length;

  double get totalOverdueAmount => _overdueTransactions.fold(
      0.0, (sum, t) => sum + t.remainingBalance);

  Future<void> loadTransactionsByCustomer(int customerId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      _transactions = await _db.getTransactionsByCustomer(customerId);
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadTransaction(int id) async {
    _isLoading = true;
    notifyListeners();
    try {
      _selectedTransaction = await _db.getTransactionById(id);
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadOverdueTransactions() async {
    try {
      await _db.refreshOverdueStatuses();
      _overdueTransactions = await _db.getOverdueTransactions();
      _dueSoonTransactions = await _db.getDueSoonTransactions(3);
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  Future<DebtTransaction?> addTransaction(
    DebtTransaction transaction,
    List<TransactionItem> items,
  ) async {
    _isSaving = true;
    _error = null;
    notifyListeners();
    try {
      final created = await _db.insertTransaction(transaction, items);
      // Do NOT reload the list here — the screen pops immediately and
      // the caller (CustomerDetailScreen) reloads on its own via .then((_) => _load())
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

  Future<bool> deleteTransaction(int id) async {
    _isSaving = true;
    _error = null;
    notifyListeners();
    try {
      await _db.softDeleteTransaction(id);
      _transactions.removeWhere((t) => t.id == id);
      if (_selectedTransaction?.id == id) _selectedTransaction = null;
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    } finally {
      _isSaving = false;
      notifyListeners();
    }
  }

  Future<List<DebtTransaction>> getTransactionsByDateRange(
      DateTime start, DateTime end) async {
    try {
      return await _db.getTransactionsByDateRange(start, end);
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return [];
    }
  }

  void clearSelectedTransaction() {
    _selectedTransaction = null;
    notifyListeners();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}
