import 'dart:async';

import 'package:flutter/foundation.dart';
import '../data/database/database_helper.dart';
import '../data/models/customer_model.dart';

enum CustomerFilter { all, hasDebt, paid, overdue, archived }

enum CustomerSort { name, balance, recent, lastPayment }

class CustomerProvider extends ChangeNotifier {
  final DatabaseHelper _db = DatabaseHelper();

  List<Customer> _customers = [];
  Customer? _selectedCustomer;
  bool _isLoading = false;
  bool _isSaving = false;
  String? _error;

  String _searchQuery = '';
  Timer? _searchDebounce;
  CustomerFilter _filter = CustomerFilter.all;
  CustomerSort _sort = CustomerSort.name;
  bool _sortDesc = false;

  List<Customer> get customers => _customers;
  Customer? get selectedCustomer => _selectedCustomer;
  bool get isLoading => _isLoading;
  bool get isSaving => _isSaving;
  String? get error => _error;
  String get searchQuery => _searchQuery;
  CustomerFilter get filter => _filter;
  CustomerSort get sort => _sort;
  bool get sortDesc => _sortDesc;

  int get totalCustomers => _customers.length;
  int get customersWithDebt =>
      _customers.where((c) => c.outstandingBalance > 0).length;

  Future<void> loadCustomers() async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      _customers = await _db.getCustomers(
        query: _searchQuery.isEmpty ? null : _searchQuery,
        statusFilter: _filter == CustomerFilter.archived ? 'archived' : null,
        debtFilter: _filterToString(_filter),
        sortBy: _sortToString(_sort),
        sortDesc: _sortDesc,
      );
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadCustomer(int id) async {
    _isLoading = true;
    notifyListeners();
    try {
      _selectedCustomer = await _db.getCustomerById(id);
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<Customer?> addCustomer(Customer customer) async {
    _isSaving = true;
    _error = null;
    notifyListeners();
    try {
      final created = await _db.insertCustomer(customer);
      await loadCustomers();
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

  Future<bool> updateCustomer(Customer customer) async {
    _isSaving = true;
    _error = null;
    notifyListeners();
    try {
      await _db.updateCustomer(customer);
      // Refresh selected customer
      if (_selectedCustomer?.id == customer.id) {
        _selectedCustomer = await _db.getCustomerById(customer.id!);
      }
      await loadCustomers();
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

  Future<bool> archiveCustomer(int id) async {
    _isSaving = true;
    _error = null;
    notifyListeners();
    try {
      await _db.archiveCustomer(id);
      await loadCustomers();
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

  void setSearch(String query) {
    _searchQuery = query;
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 300), loadCustomers);
  }

  void setFilter(CustomerFilter filter) {
    _filter = filter;
    loadCustomers();
  }

  void setSort(CustomerSort sort, {bool? desc}) {
    if (_sort == sort) {
      _sortDesc = desc ?? !_sortDesc;
    } else {
      _sort = sort;
      _sortDesc = desc ?? false;
    }
    loadCustomers();
  }

  void clearSelectedCustomer() {
    _selectedCustomer = null;
    notifyListeners();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    super.dispose();
  }

  String? _filterToString(CustomerFilter filter) {
    switch (filter) {
      case CustomerFilter.hasDebt:
        return 'hasDebt';
      case CustomerFilter.paid:
        return 'paid';
      case CustomerFilter.overdue:
        return 'overdue';
      default:
        return null;
    }
  }

  String? _sortToString(CustomerSort sort) {
    switch (sort) {
      case CustomerSort.balance:
        return 'balance';
      case CustomerSort.recent:
        return 'recent';
      case CustomerSort.lastPayment:
        return 'lastPayment';
      default:
        return null;
    }
  }
}
