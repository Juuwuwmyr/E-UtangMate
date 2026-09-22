import 'package:flutter/foundation.dart';
import '../data/database/database_helper.dart';

class DashboardProvider extends ChangeNotifier {
  final DatabaseHelper _db = DatabaseHelper();

  Map<String, dynamic> _stats = {};
  List<Map<String, dynamic>> _monthlyStats = [];
  bool _isLoading = false;
  String? _error;

  Map<String, dynamic> get stats => _stats;
  List<Map<String, dynamic>> get monthlyStats => _monthlyStats;
  bool get isLoading => _isLoading;
  String? get error => _error;

  int get totalCustomers => _stats['totalCustomers'] as int? ?? 0;
  int get customersWithDebt => _stats['customersWithDebt'] as int? ?? 0;
  double get totalOutstanding => _stats['totalOutstanding'] as double? ?? 0.0;
  double get totalCollected => _stats['totalCollected'] as double? ?? 0.0;
  double get overdueAmount => _stats['overdueAmount'] as double? ?? 0.0;
  double get paymentsToday => _stats['paymentsToday'] as double? ?? 0.0;
  double get debtToday => _stats['debtToday'] as double? ?? 0.0;
  int get overdueCount => _stats['overdueCount'] as int? ?? 0;

  Future<void> loadDashboard() async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      await _db.refreshOverdueStatuses();
      _stats = await _db.getDashboardStats();
      _monthlyStats = await _db.getMonthlyStats(6);
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}
