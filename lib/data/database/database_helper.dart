import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/customer_model.dart';
import '../models/transaction_model.dart';
import '../models/payment_model.dart';
import '../models/store_model.dart';
import '../models/audit_log_model.dart';

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  static Database? _database;

  DatabaseHelper._internal();
  factory DatabaseHelper() => _instance;

  static const String _dbName = 'utang_mate.db';
  static const int _dbVersion = 1;

  // Table names
  static const String tableStore = 'stores';
  static const String tableCustomers = 'customers';
  static const String tableTransactions = 'transactions';
  static const String tableTransactionItems = 'transaction_items';
  static const String tablePayments = 'payments';
  static const String tableAuditLogs = 'audit_logs';
  static const String tableSequences = 'sequences';

  Future<Database> get database async {
    _database ??= await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, _dbName);
    return await openDatabase(
      path,
      version: _dbVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
        await db.execute('PRAGMA journal_mode = WAL');
      },
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    // Sequences table for human-readable IDs
    await db.execute('''
      CREATE TABLE $tableSequences (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL UNIQUE,
        current_value INTEGER NOT NULL DEFAULT 0
      )
    ''');

    // Seed sequences
    await db.insert(tableSequences, {'name': 'customer', 'current_value': 0});
    await db.insert(tableSequences, {'name': 'transaction', 'current_value': 0});
    await db.insert(tableSequences, {'name': 'payment', 'current_value': 0});

    // Store table
    await db.execute('''
      CREATE TABLE $tableStore (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        address TEXT,
        phone TEXT,
        email TEXT,
        logo_path TEXT,
        currency TEXT NOT NULL DEFAULT 'PHP',
        currency_symbol TEXT NOT NULL DEFAULT '₱',
        tin TEXT,
        notes TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');

    // Seed default store
    final now = DateTime.now().toIso8601String();
    await db.insert(tableStore, {
      'name': 'My Store',
      'currency': 'PHP',
      'currency_symbol': '₱',
      'created_at': now,
      'updated_at': now,
    });

    // Customers table
    await db.execute('''
      CREATE TABLE $tableCustomers (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        customer_id TEXT NOT NULL UNIQUE,
        name TEXT NOT NULL,
        phone TEXT,
        address TEXT,
        email TEXT,
        photo_path TEXT,
        notes TEXT,
        credit_limit REAL,
        status TEXT NOT NULL DEFAULT 'active',
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');
    await db.execute('CREATE INDEX idx_customers_name ON $tableCustomers(name)');
    await db.execute('CREATE INDEX idx_customers_phone ON $tableCustomers(phone)');
    await db.execute('CREATE INDEX idx_customers_status ON $tableCustomers(status)');

    // Transactions table
    await db.execute('''
      CREATE TABLE $tableTransactions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        transaction_id TEXT NOT NULL UNIQUE,
        customer_id INTEGER NOT NULL,
        customer_name TEXT NOT NULL,
        total_amount REAL NOT NULL CHECK(total_amount >= 0),
        amount_paid REAL NOT NULL DEFAULT 0 CHECK(amount_paid >= 0),
        remaining_balance REAL NOT NULL CHECK(remaining_balance >= 0),
        status TEXT NOT NULL DEFAULT 'unpaid',
        transaction_date TEXT NOT NULL,
        due_date TEXT,
        notes TEXT,
        is_deleted INTEGER NOT NULL DEFAULT 0,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        FOREIGN KEY (customer_id) REFERENCES $tableCustomers(id)
      )
    ''');
    await db.execute('CREATE INDEX idx_tx_customer ON $tableTransactions(customer_id)');
    await db.execute('CREATE INDEX idx_tx_status ON $tableTransactions(status)');
    await db.execute('CREATE INDEX idx_tx_date ON $tableTransactions(transaction_date)');
    await db.execute('CREATE INDEX idx_tx_due_date ON $tableTransactions(due_date)');

    // Transaction items
    await db.execute('''
      CREATE TABLE $tableTransactionItems (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        transaction_id INTEGER NOT NULL,
        item_name TEXT NOT NULL,
        quantity REAL NOT NULL CHECK(quantity > 0),
        unit TEXT NOT NULL DEFAULT 'pcs',
        price_per_unit REAL NOT NULL CHECK(price_per_unit >= 0),
        total_price REAL NOT NULL CHECK(total_price >= 0),
        notes TEXT,
        FOREIGN KEY (transaction_id) REFERENCES $tableTransactions(id)
      )
    ''');
    await db.execute('CREATE INDEX idx_items_tx ON $tableTransactionItems(transaction_id)');

    // Payments table
    await db.execute('''
      CREATE TABLE $tablePayments (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        payment_id TEXT NOT NULL UNIQUE,
        transaction_id INTEGER NOT NULL,
        customer_id INTEGER NOT NULL,
        customer_name TEXT NOT NULL,
        tx_transaction_id TEXT NOT NULL,
        amount REAL NOT NULL CHECK(amount > 0),
        payment_method TEXT NOT NULL DEFAULT 'cash',
        reference_number TEXT,
        notes TEXT,
        payment_date TEXT NOT NULL,
        is_deleted INTEGER NOT NULL DEFAULT 0,
        created_at TEXT NOT NULL,
        FOREIGN KEY (transaction_id) REFERENCES $tableTransactions(id),
        FOREIGN KEY (customer_id) REFERENCES $tableCustomers(id)
      )
    ''');
    await db.execute('CREATE INDEX idx_pay_tx ON $tablePayments(transaction_id)');
    await db.execute('CREATE INDEX idx_pay_customer ON $tablePayments(customer_id)');
    await db.execute('CREATE INDEX idx_pay_date ON $tablePayments(payment_date)');

    // Audit logs
    await db.execute('''
      CREATE TABLE $tableAuditLogs (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        action TEXT NOT NULL,
        entity_type TEXT NOT NULL,
        entity_id TEXT,
        description TEXT NOT NULL,
        old_value TEXT,
        new_value TEXT,
        created_at TEXT NOT NULL
      )
    ''');
    await db.execute('CREATE INDEX idx_audit_entity ON $tableAuditLogs(entity_type, entity_id)');
    await db.execute('CREATE INDEX idx_audit_date ON $tableAuditLogs(created_at)');
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    // Handle future migrations here
  }

  // ─── Sequence Helpers ────────────────────────────────────────────────────

  Future<String> _nextCustomerId(Database db) async {
    final next = await _incrementSequence(db, 'customer');
    return 'CUST-${next.toString().padLeft(4, '0')}';
  }

  Future<String> _nextTransactionId(Database db) async {
    final next = await _incrementSequence(db, 'transaction');
    return 'TX-${next.toString().padLeft(5, '0')}';
  }

  Future<String> _nextPaymentId(Database db) async {
    final next = await _incrementSequence(db, 'payment');
    return 'PAY-${next.toString().padLeft(5, '0')}';
  }

  Future<int> _incrementSequence(Database db, String name) async {
    await db.rawUpdate(
      'UPDATE $tableSequences SET current_value = current_value + 1 WHERE name = ?',
      [name],
    );
    final result = await db.query(
      tableSequences,
      where: 'name = ?',
      whereArgs: [name],
    );
    return result.first['current_value'] as int;
  }

  // ─── Store ────────────────────────────────────────────────────────────────

  Future<Store?> getStore() async {
    final db = await database;
    final maps = await db.query(tableStore, limit: 1);
    if (maps.isEmpty) return null;
    return Store.fromMap(maps.first);
  }

  Future<void> updateStore(Store store) async {
    final db = await database;
    await db.update(
      tableStore,
      store.copyWith(updatedAt: DateTime.now()).toMap(),
      where: 'id = ?',
      whereArgs: [store.id],
    );
  }

  // ─── Customers ────────────────────────────────────────────────────────────

  Future<Customer> insertCustomer(Customer customer) async {
    final db = await database;
    final now = DateTime.now();
    final customerId = await _nextCustomerId(db);
    final toInsert = customer.copyWith(
      customerId: customerId,
      createdAt: now,
      updatedAt: now,
    );
    final id = await db.insert(tableCustomers, toInsert.toMap());
    await _insertAuditLog(db, AuditLog(
      action: AuditAction.customerCreated,
      entityType: 'customer',
      entityId: customerId,
      description: 'Customer created: ${customer.name}',
      createdAt: now,
    ));
    return toInsert.copyWith(id: id);
  }

  Future<void> updateCustomer(Customer customer) async {
    final db = await database;
    final now = DateTime.now();
    await db.update(
      tableCustomers,
      customer.copyWith(updatedAt: now).toMap(),
      where: 'id = ?',
      whereArgs: [customer.id],
    );
    await _insertAuditLog(db, AuditLog(
      action: AuditAction.customerUpdated,
      entityType: 'customer',
      entityId: customer.customerId,
      description: 'Customer updated: ${customer.name}',
      createdAt: now,
    ));
  }

  Future<void> archiveCustomer(int id) async {
    final db = await database;
    final now = DateTime.now();
    await db.update(
      tableCustomers,
      {'status': 'archived', 'updated_at': now.toIso8601String()},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<Customer?> getCustomerById(int id) async {
    final db = await database;
    final maps = await db.rawQuery('''
      SELECT 
        c.*,
        COALESCE(SUM(CASE WHEN t.is_deleted = 0 THEN t.total_amount ELSE 0 END), 0) AS total_debt,
        COALESCE(SUM(CASE WHEN t.is_deleted = 0 THEN t.amount_paid ELSE 0 END), 0) AS total_paid,
        COALESCE(SUM(CASE WHEN t.is_deleted = 0 THEN t.remaining_balance ELSE 0 END), 0) AS outstanding_balance,
        COUNT(CASE WHEN t.is_deleted = 0 AND t.status != 'paid' THEN 1 END) AS unpaid_transactions,
        COUNT(CASE WHEN t.is_deleted = 0 AND t.status = 'overdue' THEN 1 END) AS overdue_transactions,
        (SELECT MAX(p.payment_date) FROM $tablePayments p WHERE p.customer_id = c.id AND p.is_deleted = 0) AS last_payment_date,
        MAX(CASE WHEN t.is_deleted = 0 THEN t.transaction_date END) AS last_transaction_date
      FROM $tableCustomers c
      LEFT JOIN $tableTransactions t ON t.customer_id = c.id
      WHERE c.id = ?
      GROUP BY c.id
    ''', [id]);
    if (maps.isEmpty) return null;
    return Customer.fromMap(maps.first);
  }

  // Remove unused baseQuery variable
  Future<List<Customer>> getCustomers({
    String? query,
    String? statusFilter,
    String? debtFilter,
    String? sortBy,
    bool sortDesc = false,
  }) async {
    final db = await database;
    String where = "c.status != 'archived'";
    final args = <dynamic>[];

    if (statusFilter == 'archived') {
      where = "c.status = 'archived'";
    }

    String having = '';
    if (query != null && query.isNotEmpty) {
      where += ' AND (c.name LIKE ? OR c.phone LIKE ? OR c.customer_id LIKE ?)';
      args.addAll(['%$query%', '%$query%', '%$query%']);
    }

    // Build debt filter as HAVING clause
    switch (debtFilter) {
      case 'hasDebt':
        having = 'HAVING outstanding_balance > 0';
        break;
      case 'paid':
        having = 'HAVING outstanding_balance = 0 AND total_debt > 0';
        break;
      case 'overdue':
        having = 'HAVING overdue_transactions > 0';
        break;
      case 'noDebt':
        having = 'HAVING outstanding_balance = 0';
        break;
    }

    String orderBy = 'c.name ASC';
    if (sortBy == 'balance') {
      orderBy = 'outstanding_balance ${sortDesc ? 'DESC' : 'ASC'}';
    } else if (sortBy == 'recent') {
      orderBy = 'c.created_at ${sortDesc ? 'DESC' : 'ASC'}';
    } else if (sortBy == 'lastPayment') {
      orderBy = 'last_payment_date ${sortDesc ? 'DESC' : 'ASC'}';
    }

    final sql = '''
      SELECT 
        c.*,
        COALESCE(SUM(CASE WHEN t.is_deleted = 0 THEN t.total_amount ELSE 0 END), 0) AS total_debt,
        COALESCE(SUM(CASE WHEN t.is_deleted = 0 THEN t.amount_paid ELSE 0 END), 0) AS total_paid,
        COALESCE(SUM(CASE WHEN t.is_deleted = 0 THEN t.remaining_balance ELSE 0 END), 0) AS outstanding_balance,
        COUNT(CASE WHEN t.is_deleted = 0 AND t.status != 'paid' THEN 1 END) AS unpaid_transactions,
        COUNT(CASE WHEN t.is_deleted = 0 AND t.status = 'overdue' THEN 1 END) AS overdue_transactions,
        (SELECT MAX(p.payment_date) FROM $tablePayments p WHERE p.customer_id = c.id AND p.is_deleted = 0) AS last_payment_date,
        MAX(CASE WHEN t.is_deleted = 0 THEN t.transaction_date END) AS last_transaction_date
      FROM $tableCustomers c
      LEFT JOIN $tableTransactions t ON t.customer_id = c.id
      WHERE $where
      GROUP BY c.id
      $having
      ORDER BY $orderBy
    ''';

    final maps = await db.rawQuery(sql, args.isEmpty ? null : args);
    return maps.map((m) => Customer.fromMap(m)).toList();
  }

  // ─── Transactions ─────────────────────────────────────────────────────────

  Future<DebtTransaction> insertTransaction(
    DebtTransaction transaction,
    List<TransactionItem> items,
  ) async {
    final db = await database;
    return await db.transaction((txn) async {
      final now = DateTime.now();
      final txId = await _nextTransactionId(db);
      final toInsert = transaction.copyWith(
        transactionId: txId,
        createdAt: now,
        updatedAt: now,
        status: TransactionStatus.unpaid,
        amountPaid: 0,
        remainingBalance: transaction.totalAmount,
      );

      final id = await txn.insert(tableTransactions, toInsert.toMap());

      for (final item in items) {
        await txn.insert(
          tableTransactionItems,
          item.copyWith(transactionId: id).toMap(),
        );
      }

      await _insertAuditLog(db, AuditLog(
        action: AuditAction.transactionCreated,
        entityType: 'transaction',
        entityId: txId,
        description:
            'Transaction created: $txId for ${transaction.customerName} - ₱${transaction.totalAmount.toStringAsFixed(2)}',
        createdAt: now,
      ));

      return toInsert.copyWith(id: id, items: items);
    });
  }

  Future<List<DebtTransaction>> getTransactionsByCustomer(int customerId) async {
    final db = await database;
    final maps = await db.query(
      tableTransactions,
      where: 'customer_id = ? AND is_deleted = 0',
      whereArgs: [customerId],
      orderBy: 'transaction_date DESC',
    );

    final transactions = <DebtTransaction>[];
    for (final map in maps) {
      final items = await _getTransactionItems(db, map['id'] as int);
      transactions.add(DebtTransaction.fromMap({...map, 'items': null})
          .copyWith(items: items));
    }
    return transactions;
  }

  Future<DebtTransaction?> getTransactionById(int id) async {
    final db = await database;
    final maps = await db.query(
      tableTransactions,
      where: 'id = ? AND is_deleted = 0',
      whereArgs: [id],
    );
    if (maps.isEmpty) return null;
    final items = await _getTransactionItems(db, id);
    return DebtTransaction.fromMap(maps.first).copyWith(items: items);
  }

  Future<List<TransactionItem>> _getTransactionItems(
      Database db, int transactionId) async {
    final maps = await db.query(
      tableTransactionItems,
      where: 'transaction_id = ?',
      whereArgs: [transactionId],
    );
    return maps.map((m) => TransactionItem.fromMap(m)).toList();
  }

  Future<List<DebtTransaction>> getOverdueTransactions() async {
    final db = await database;
    final now = DateTime.now().toIso8601String();
    final maps = await db.rawQuery('''
      SELECT t.*, c.name AS customer_name_full
      FROM $tableTransactions t
      JOIN $tableCustomers c ON c.id = t.customer_id
      WHERE t.is_deleted = 0 
        AND t.status != 'paid'
        AND t.due_date IS NOT NULL
        AND t.due_date < ?
      ORDER BY t.due_date ASC
    ''', [now]);
    return maps.map((m) => DebtTransaction.fromMap(m)).toList();
  }

  Future<List<DebtTransaction>> getDueSoonTransactions(int days) async {
    final db = await database;
    final now = DateTime.now();
    final future = now.add(Duration(days: days)).toIso8601String();
    final maps = await db.rawQuery('''
      SELECT t.*
      FROM $tableTransactions t
      WHERE t.is_deleted = 0 
        AND t.status != 'paid'
        AND t.due_date IS NOT NULL
        AND t.due_date >= ?
        AND t.due_date <= ?
      ORDER BY t.due_date ASC
    ''', [now.toIso8601String(), future]);
    return maps.map((m) => DebtTransaction.fromMap(m)).toList();
  }

  /// Soft delete a transaction (for audit trail)
  Future<void> softDeleteTransaction(int id) async {
    final db = await database;
    final now = DateTime.now();
    await db.update(
      tableTransactions,
      {'is_deleted': 1, 'updated_at': now.toIso8601String()},
      where: 'id = ?',
      whereArgs: [id],
    );
    await _insertAuditLog(db, AuditLog(
      action: AuditAction.transactionDeleted,
      entityType: 'transaction',
      entityId: id.toString(),
      description: 'Transaction soft-deleted',
      createdAt: now,
    ));
  }

  // ─── Payments ─────────────────────────────────────────────────────────────

  Future<Payment> insertPayment(Payment payment) async {
    final db = await database;
    return await db.transaction((txn) async {
      // Get current transaction state
      final txMaps = await txn.query(
        tableTransactions,
        where: 'id = ? AND is_deleted = 0',
        whereArgs: [payment.transactionId],
      );
      if (txMaps.isEmpty) throw Exception('Transaction not found');

      final currentRemaining =
          (txMaps.first['remaining_balance'] as num).toDouble();

      if (payment.amount > currentRemaining) {
        throw Exception(
            'Payment amount (${payment.amount}) exceeds remaining balance ($currentRemaining)');
      }

      final now = DateTime.now();
      final payId = await _nextPaymentId(db);
      final toInsert = payment.copyWith(paymentId: payId, createdAt: now);
      final id = await txn.insert(tablePayments, toInsert.toMap());

      // Update transaction balance
      final newRemaining = currentRemaining - payment.amount;
      final newAmountPaid =
          (txMaps.first['amount_paid'] as num).toDouble() + payment.amount;

      String status;
      final dueDate = txMaps.first['due_date'] as String?;
      if (newRemaining <= 0) {
        status = 'paid';
      } else if (dueDate != null &&
          DateTime.parse(dueDate).isBefore(DateTime.now())) {
        status = 'overdue';
      } else {
        status = newAmountPaid > 0 ? 'partiallyPaid' : 'unpaid';
      }

      await txn.update(
        tableTransactions,
        {
          'amount_paid': newAmountPaid,
          'remaining_balance': newRemaining,
          'status': status,
          'updated_at': now.toIso8601String(),
        },
        where: 'id = ?',
        whereArgs: [payment.transactionId],
      );

      await _insertAuditLog(db, AuditLog(
        action: AuditAction.paymentCreated,
        entityType: 'payment',
        entityId: payId,
        description:
            'Payment of ₱${payment.amount.toStringAsFixed(2)} recorded for ${payment.customerName}',
        createdAt: now,
      ));

      return toInsert.copyWith(id: id);
    });
  }

  Future<List<Payment>> getPaymentsByTransaction(int transactionId) async {
    final db = await database;
    final maps = await db.query(
      tablePayments,
      where: 'transaction_id = ? AND is_deleted = 0',
      whereArgs: [transactionId],
      orderBy: 'payment_date DESC',
    );
    return maps.map((m) => Payment.fromMap(m)).toList();
  }

  Future<List<Payment>> getPaymentsByCustomer(int customerId) async {
    final db = await database;
    final maps = await db.query(
      tablePayments,
      where: 'customer_id = ? AND is_deleted = 0',
      whereArgs: [customerId],
      orderBy: 'payment_date DESC',
    );
    return maps.map((m) => Payment.fromMap(m)).toList();
  }

  Future<List<Payment>> getPaymentsByDateRange(
      DateTime start, DateTime end) async {
    final db = await database;
    final maps = await db.query(
      tablePayments,
      where: 'payment_date >= ? AND payment_date <= ? AND is_deleted = 0',
      whereArgs: [start.toIso8601String(), end.toIso8601String()],
      orderBy: 'payment_date DESC',
    );
    return maps.map((m) => Payment.fromMap(m)).toList();
  }

  // ─── Dashboard Stats ──────────────────────────────────────────────────────

  Future<Map<String, dynamic>> getDashboardStats() async {
    final db = await database;
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day).toIso8601String();
    final todayEnd =
        DateTime(now.year, now.month, now.day, 23, 59, 59).toIso8601String();

    final customerCount = Sqflite.firstIntValue(await db.rawQuery(
          "SELECT COUNT(*) FROM $tableCustomers WHERE status = 'active'")) ??
        0;

    final customersWithDebt = Sqflite.firstIntValue(await db.rawQuery('''
      SELECT COUNT(DISTINCT customer_id) 
      FROM $tableTransactions 
      WHERE is_deleted = 0 AND remaining_balance > 0
    ''')) ?? 0;

    final totalOutstanding = await db.rawQuery('''
      SELECT COALESCE(SUM(remaining_balance), 0) AS total
      FROM $tableTransactions
      WHERE is_deleted = 0 AND status != 'paid'
    ''');

    final totalCollected = await db.rawQuery('''
      SELECT COALESCE(SUM(amount), 0) AS total
      FROM $tablePayments
      WHERE is_deleted = 0
    ''');

    final overdueAmount = await db.rawQuery('''
      SELECT COALESCE(SUM(remaining_balance), 0) AS total
      FROM $tableTransactions
      WHERE is_deleted = 0 AND status = 'overdue'
    ''');

    final paymentsToday = await db.rawQuery('''
      SELECT COALESCE(SUM(amount), 0) AS total
      FROM $tablePayments
      WHERE is_deleted = 0 AND payment_date >= ? AND payment_date <= ?
    ''', [todayStart, todayEnd]);

    final debtToday = await db.rawQuery('''
      SELECT COALESCE(SUM(total_amount), 0) AS total
      FROM $tableTransactions
      WHERE is_deleted = 0 AND transaction_date >= ? AND transaction_date <= ?
    ''', [todayStart, todayEnd]);

    final overdueCount = Sqflite.firstIntValue(await db.rawQuery('''
      SELECT COUNT(*) FROM $tableTransactions
      WHERE is_deleted = 0 AND status = 'overdue'
    ''')) ?? 0;

    return {
      'totalCustomers': customerCount,
      'customersWithDebt': customersWithDebt,
      'totalOutstanding':
          (totalOutstanding.first['total'] as num?)?.toDouble() ?? 0.0,
      'totalCollected':
          (totalCollected.first['total'] as num?)?.toDouble() ?? 0.0,
      'overdueAmount':
          (overdueAmount.first['total'] as num?)?.toDouble() ?? 0.0,
      'paymentsToday':
          (paymentsToday.first['total'] as num?)?.toDouble() ?? 0.0,
      'debtToday': (debtToday.first['total'] as num?)?.toDouble() ?? 0.0,
      'overdueCount': overdueCount,
    };
  }

  Future<List<Map<String, dynamic>>> getMonthlyStats(int months) async {
    final db = await database;
    final result = <Map<String, dynamic>>[];
    final now = DateTime.now();

    for (int i = months - 1; i >= 0; i--) {
      final month = DateTime(now.year, now.month - i, 1);
      final monthEnd = DateTime(month.year, month.month + 1, 1)
          .subtract(const Duration(seconds: 1));

      final debts = await db.rawQuery('''
        SELECT COALESCE(SUM(total_amount), 0) AS total
        FROM $tableTransactions
        WHERE is_deleted = 0 
          AND transaction_date >= ? AND transaction_date <= ?
      ''', [month.toIso8601String(), monthEnd.toIso8601String()]);

      final payments = await db.rawQuery('''
        SELECT COALESCE(SUM(amount), 0) AS total
        FROM $tablePayments
        WHERE is_deleted = 0
          AND payment_date >= ? AND payment_date <= ?
      ''', [month.toIso8601String(), monthEnd.toIso8601String()]);

      result.add({
        'month': month,
        'debt': (debts.first['total'] as num?)?.toDouble() ?? 0.0,
        'payment': (payments.first['total'] as num?)?.toDouble() ?? 0.0,
      });
    }
    return result;
  }

  // ─── Reports ──────────────────────────────────────────────────────────────

  Future<List<DebtTransaction>> getTransactionsByDateRange(
      DateTime start, DateTime end) async {
    final db = await database;
    final maps = await db.rawQuery('''
      SELECT t.*
      FROM $tableTransactions t
      WHERE t.is_deleted = 0 
        AND t.transaction_date >= ? 
        AND t.transaction_date <= ?
      ORDER BY t.transaction_date DESC
    ''', [start.toIso8601String(), end.toIso8601String()]);
    return maps.map((m) => DebtTransaction.fromMap(m)).toList();
  }

  Future<List<Customer>> getCustomersWithOutstandingBalance() async {
    final db = await database;
    final maps = await db.rawQuery('''
      SELECT 
        c.*,
        COALESCE(SUM(CASE WHEN t.is_deleted = 0 THEN t.total_amount ELSE 0 END), 0) AS total_debt,
        COALESCE(SUM(CASE WHEN t.is_deleted = 0 THEN t.amount_paid ELSE 0 END), 0) AS total_paid,
        COALESCE(SUM(CASE WHEN t.is_deleted = 0 THEN t.remaining_balance ELSE 0 END), 0) AS outstanding_balance,
        COUNT(CASE WHEN t.is_deleted = 0 AND t.status != 'paid' THEN 1 END) AS unpaid_transactions,
        COUNT(CASE WHEN t.is_deleted = 0 AND t.status = 'overdue' THEN 1 END) AS overdue_transactions
      FROM $tableCustomers c
      LEFT JOIN $tableTransactions t ON t.customer_id = c.id
      WHERE c.status = 'active'
      GROUP BY c.id
      HAVING outstanding_balance > 0
      ORDER BY outstanding_balance DESC
    ''');
    return maps.map((m) => Customer.fromMap(m)).toList();
  }

  // ─── Audit Logs ───────────────────────────────────────────────────────────

  Future<void> _insertAuditLog(Database db, AuditLog log) async {
    await db.insert(tableAuditLogs, log.toMap());
  }

  Future<List<AuditLog>> getRecentAuditLogs({int limit = 50}) async {
    final db = await database;
    final maps = await db.query(
      tableAuditLogs,
      orderBy: 'created_at DESC',
      limit: limit,
    );
    return maps.map((m) => AuditLog.fromMap(m)).toList();
  }

  // ─── Utility ──────────────────────────────────────────────────────────────

  /// Recalculate all overdue statuses based on current date
  Future<void> refreshOverdueStatuses() async {
    final db = await database;
    final now = DateTime.now().toIso8601String();
    // Mark overdue
    await db.rawUpdate('''
      UPDATE $tableTransactions
      SET status = 'overdue', updated_at = ?
      WHERE is_deleted = 0
        AND status NOT IN ('paid')
        AND due_date IS NOT NULL
        AND due_date < ?
    ''', [now, now]);
  }

  Future<void> closeDatabase() async {
    if (_database != null) {
      await _database!.close();
      _database = null;
    }
  }
}
