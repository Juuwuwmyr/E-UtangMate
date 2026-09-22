import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../data/database/database_helper.dart';
import '../data/models/store_model.dart';

class StoreProvider extends ChangeNotifier {
  final DatabaseHelper _db = DatabaseHelper();

  Store? _store;
  bool _isLoading = false;
  String? _error;

  // PIN state
  bool _hasPinSetup = false;
  bool _isAuthenticated = false;
  bool _isDarkMode = false;

  Store? get store => _store;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get hasPinSetup => _hasPinSetup;
  bool get isAuthenticated => _isAuthenticated;
  bool get isDarkMode => _isDarkMode;

  String get currencySymbol => _store?.currencySymbol ?? '₱';
  String get storeName => _store?.name ?? 'My Store';

  Future<void> init() async {
    _isLoading = true;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      _hasPinSetup = prefs.getString('app_pin') != null;
      _isDarkMode = prefs.getBool('dark_mode') ?? false;
      // If no PIN is set, consider authenticated by default
      if (!_hasPinSetup) _isAuthenticated = true;
      _store = await _db.getStore();
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> verifyPin(String pin) async {
    final prefs = await SharedPreferences.getInstance();
    final storedPin = prefs.getString('app_pin');
    if (storedPin == pin) {
      _isAuthenticated = true;
      notifyListeners();
      return true;
    }
    return false;
  }

  Future<void> setPin(String pin) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('app_pin', pin);
    _hasPinSetup = true;
    _isAuthenticated = true;
    notifyListeners();
  }

  Future<void> removePin() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('app_pin');
    _hasPinSetup = false;
    notifyListeners();
  }

  void lockApp() {
    if (_hasPinSetup) {
      _isAuthenticated = false;
      notifyListeners();
    }
  }

  Future<void> updateStore(Store store) async {
    try {
      await _db.updateStore(store);
      _store = store;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  Future<void> toggleDarkMode() async {
    _isDarkMode = !_isDarkMode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('dark_mode', _isDarkMode);
    notifyListeners();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}
