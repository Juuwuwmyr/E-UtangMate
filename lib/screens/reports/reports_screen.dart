import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:csv/csv.dart';

import '../../providers/store_provider.dart';
import '../../data/database/database_helper.dart';
import '../../data/models/transaction_model.dart';
import '../../data/models/payment_model.dart';
import '../../data/models/customer_model.dart';
import '../../core/theme.dart';
import '../../utils/formatters.dart';
import '../../widgets/loading_overlay.dart';

enum ReportPeriod { today, thisWeek, thisMonth, lastMonth, custom }
enum ReportType { transactions, payments, outstanding, customerSummary }

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _db = DatabaseHelper();

  ReportPeriod _period = ReportPeriod.thisMonth;
  DateTime _customStart = DateTime.now().subtract(const Duration(days: 30));
  DateTime _customEnd = DateTime.now();

  List<DebtTransaction> _transactions = [];
  List<Payment> _payments = [];
  List<Customer> _outstandingCustomers = [];

  bool _isLoading = false;
  bool _isExporting = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadReport());
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  (DateTime, DateTime) _getDateRange() {
    final now = DateTime.now();
    switch (_period) {
      case ReportPeriod.today:
        final start = DateTime(now.year, now.month, now.day);
        final end = DateTime(now.year, now.month, now.day, 23, 59, 59);
        return (start, end);
      case ReportPeriod.thisWeek:
        final start = now.subtract(Duration(days: now.weekday - 1));
        final s = DateTime(start.year, start.month, start.day);
        return (s, DateTime(s.year, s.month, s.day + 6, 23, 59, 59));
      case ReportPeriod.thisMonth:
        final start = DateTime(now.year, now.month, 1);
        final end = DateTime(now.year, now.month + 1, 0, 23, 59, 59);
        return (start, end);
      case ReportPeriod.lastMonth:
        final start = DateTime(now.year, now.month - 1, 1);
        final end = DateTime(now.year, now.month, 0, 23, 59, 59);
        return (start, end);
      case ReportPeriod.custom:
        return (_customStart,
            DateTime(_customEnd.year, _customEnd.month, _customEnd.day, 23, 59, 59));
    }
  }

  Future<void> _loadReport() async {
    setState(() => _isLoading = true);
    try {
      final range = _getDateRange();
      final start = range.$1;
      final end = range.$2;
      final txFuture = _db.getTransactionsByDateRange(start, end);
      final payFuture = _db.getPaymentsByDateRange(start, end);
      final outstandingFuture = _db.getCustomersWithOutstandingBalance();
      final results = await Future.wait([txFuture, payFuture, outstandingFuture]);
      setState(() {
        _transactions = results[0] as List<DebtTransaction>;
        _payments = results[1] as List<Payment>;
        _outstandingCustomers = results[2] as List<Customer>;
      });
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _pickCustomRange() async {
    final now = DateTime.now();
    final start = await showDatePicker(
      context: context,
      initialDate: _customStart,
      firstDate: DateTime(2020),
      lastDate: now,
      helpText: 'Select start date',
    );
    if (start == null || !mounted) return;
    final end = await showDatePicker(
      context: context,
      initialDate: _customEnd.isBefore(start) ? start : _customEnd,
      firstDate: start,
      lastDate: now,
      helpText: 'Select end date',
    );
    if (end == null || !mounted) return;
    setState(() {
      _customStart = start;
      _customEnd = end;
      _period = ReportPeriod.custom;
    });
    _loadReport();
  }

  Future<void> _exportCSV(int tab) async {
    setState(() => _isExporting = true);
    try {
      List<List<dynamic>> rows = [];
      String filename = '';

      if (tab == 0) {
        filename = 'transactions_${DateTime.now().millisecondsSinceEpoch}.csv';
        rows = [
          ['Transaction ID', 'Customer', 'Date', 'Total', 'Paid', 'Balance', 'Status', 'Due Date'],
          ..._transactions.map((t) => [
                t.transactionId,
                t.customerName,
                AppFormatter.dateTime(t.transactionDate),
                t.totalAmount.toStringAsFixed(2),
                t.amountPaid.toStringAsFixed(2),
                t.remainingBalance.toStringAsFixed(2),
                t.status.name,
                t.dueDate != null ? AppFormatter.date(t.dueDate!) : '',
              ]),
        ];
      } else if (tab == 1) {
        filename = 'payments_${DateTime.now().millisecondsSinceEpoch}.csv';
        rows = [
          ['Payment ID', 'Customer', 'Transaction ID', 'Amount', 'Method', 'Reference', 'Date'],
          ..._payments.map((p) => [
                p.paymentId,
                p.customerName,
                p.txTransactionId,
                p.amount.toStringAsFixed(2),
                p.paymentMethodLabel,
                p.referenceNumber ?? '',
                AppFormatter.dateTime(p.paymentDate),
              ]),
        ];
      } else {
        filename = 'outstanding_${DateTime.now().millisecondsSinceEpoch}.csv';
        rows = [
          ['Customer ID', 'Name', 'Phone', 'Total Debt', 'Total Paid', 'Outstanding', 'Overdue Transactions'],
          ..._outstandingCustomers.map((c) => [
                c.customerId,
                c.name,
                c.phone ?? '',
                c.totalDebt.toStringAsFixed(2),
                c.totalPaid.toStringAsFixed(2),
                c.outstandingBalance.toStringAsFixed(2),
                c.overdueTransactions.toString(),
              ]),
        ];
      }

      final csv = const ListToCsvConverter().convert(rows);
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/$filename');
      await file.writeAsString(csv);
      await Share.shareXFiles(
        [XFile(file.path)],
        subject: 'UtangMate Report Export',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Export failed: $e'), backgroundColor: AppTheme.overdue),
        );
      }
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final sym = context.select<StoreProvider, String>((p) => p.currencySymbol);
    final dateRange = _getDateRange();
    final start = dateRange.$1;
    final end = dateRange.$2;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Reports'),
        automaticallyImplyLeading: false,
        actions: [
          if (_isExporting)
            const Padding(
              padding: EdgeInsets.all(16),
              child: SizedBox(width: 20, height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)),
            )
          else
            IconButton(
              icon: const Icon(Icons.download_outlined),
              onPressed: () => _exportCSV(_tabController.index),
              tooltip: 'Export CSV',
            ),
          IconButton(
            icon: const Icon(Icons.refresh_outlined),
            onPressed: _loadReport,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          tabs: const [
            Tab(text: 'Transactions'),
            Tab(text: 'Payments'),
            Tab(text: 'Outstanding'),
          ],
        ),
      ),
      body: Column(
        children: [
          // Period selector
          Container(
            color: Theme.of(context).brightness == Brightness.dark
                ? AppTheme.darkSurface
                : Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  height: 36,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: [
                      _PeriodChip(ReportPeriod.today, 'Today', _period, (p) {
                        setState(() => _period = p);
                        _loadReport();
                      }),
                      _PeriodChip(ReportPeriod.thisWeek, 'This Week', _period, (p) {
                        setState(() => _period = p);
                        _loadReport();
                      }),
                      _PeriodChip(ReportPeriod.thisMonth, 'This Month', _period, (p) {
                        setState(() => _period = p);
                        _loadReport();
                      }),
                      _PeriodChip(ReportPeriod.lastMonth, 'Last Month', _period, (p) {
                        setState(() => _period = p);
                        _loadReport();
                      }),
                      GestureDetector(
                        onTap: _pickCustomRange,
                        child: Container(
                          margin: const EdgeInsets.only(right: 6),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                          decoration: BoxDecoration(
                            color: _period == ReportPeriod.custom
                                ? AppTheme.primary
                                : AppTheme.primary.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: _period == ReportPeriod.custom
                                  ? AppTheme.primary
                                  : AppTheme.divider,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.date_range_outlined,
                                  size: 14,
                                  color: _period == ReportPeriod.custom
                                      ? Colors.white
                                      : AppTheme.textSecondary),
                              const SizedBox(width: 4),
                              Text(
                                _period == ReportPeriod.custom
                                    ? '${AppFormatter.shortDate(_customStart)} – ${AppFormatter.shortDate(_customEnd)}'
                                    : 'Custom',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: _period == ReportPeriod.custom
                                      ? Colors.white
                                      : AppTheme.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '${AppFormatter.date(start)} – ${AppFormatter.date(end)}',
                  style: const TextStyle(fontSize: 11, color: AppTheme.textHint),
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          Expanded(
            child: _isLoading
                ? const AppLoadingIndicator()
                : TabBarView(
                    controller: _tabController,
                    children: [
                      _TransactionsReport(
                          transactions: _transactions, sym: sym),
                      _PaymentsReport(payments: _payments, sym: sym),
                      _OutstandingReport(
                          customers: _outstandingCustomers, sym: sym),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

// ─── Period Chip ──────────────────────────────────────────────────────────────

class _PeriodChip extends StatelessWidget {
  final ReportPeriod value;
  final String label;
  final ReportPeriod selected;
  final ValueChanged<ReportPeriod> onTap;

  const _PeriodChip(this.value, this.label, this.selected, this.onTap);

  @override
  Widget build(BuildContext context) {
    final isSelected = selected == value;
    return GestureDetector(
      onTap: () => onTap(value),
      child: Container(
        margin: const EdgeInsets.only(right: 6),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primary : AppTheme.primary.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isSelected ? AppTheme.primary : AppTheme.divider),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            color: isSelected ? Colors.white : AppTheme.textSecondary,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}

// ─── Transactions Report ──────────────────────────────────────────────────────

class _TransactionsReport extends StatelessWidget {
  final List<DebtTransaction> transactions;
  final String sym;

  const _TransactionsReport({required this.transactions, required this.sym});

  @override
  Widget build(BuildContext context) {
    if (transactions.isEmpty) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.receipt_long_outlined, size: 48, color: AppTheme.textHint),
            SizedBox(height: 12),
            Text('No transactions for this period',
                style: TextStyle(color: AppTheme.textSecondary)),
          ],
        ),
      );
    }

    final total = transactions.fold(0.0, (s, t) => s + t.totalAmount);
    final paid = transactions.fold(0.0, (s, t) => s + t.amountPaid);
    final outstanding = transactions.fold(0.0, (s, t) => s + t.remainingBalance);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Summary row
        Row(
          children: [
            _MiniStat('Total Debt', AppFormatter.currency(total, symbol: sym),
                AppTheme.primary),
            const SizedBox(width: 8),
            _MiniStat('Collected', AppFormatter.currency(paid, symbol: sym),
                AppTheme.paid),
            const SizedBox(width: 8),
            _MiniStat('Outstanding', AppFormatter.currency(outstanding, symbol: sym),
                AppTheme.overdue),
          ],
        ),
        const SizedBox(height: 12),
        Text('${transactions.length} transaction${transactions.length != 1 ? 's' : ''}',
            style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
        const SizedBox(height: 8),
        ...transactions.map((t) => _TxReportTile(t: t, sym: sym)),
      ],
    );
  }
}

class _TxReportTile extends StatelessWidget {
  final DebtTransaction t;
  final String sym;
  const _TxReportTile({required this.t, required this.sym});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Container(
              width: 4, height: 40,
              decoration: BoxDecoration(
                color: AppTheme.statusColor(t.status.name),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(t.customerName,
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                  Text('${t.transactionId} • ${AppFormatter.date(t.transactionDate)}',
                      style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(AppFormatter.currency(t.totalAmount, symbol: sym),
                    style: const TextStyle(fontWeight: FontWeight.w700)),
                if (t.remainingBalance > 0)
                  Text('bal: ${AppFormatter.currency(t.remainingBalance, symbol: sym)}',
                      style: TextStyle(fontSize: 11, color: AppTheme.overdue)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Payments Report ──────────────────────────────────────────────────────────

class _PaymentsReport extends StatelessWidget {
  final List<Payment> payments;
  final String sym;

  const _PaymentsReport({required this.payments, required this.sym});

  @override
  Widget build(BuildContext context) {
    if (payments.isEmpty) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.payments_outlined, size: 48, color: AppTheme.textHint),
            SizedBox(height: 12),
            Text('No payments for this period',
                style: TextStyle(color: AppTheme.textSecondary)),
          ],
        ),
      );
    }

    final total = payments.fold(0.0, (s, p) => s + p.amount);

    // Group by method
    final byMethod = <PaymentMethod, double>{};
    for (final p in payments) {
      byMethod[p.paymentMethod] = (byMethod[p.paymentMethod] ?? 0) + p.amount;
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Total Collected',
                        style: TextStyle(fontWeight: FontWeight.w600)),
                    Text(AppFormatter.currency(total, symbol: sym),
                        style: const TextStyle(
                            fontSize: 20, fontWeight: FontWeight.w800,
                            color: AppTheme.paid)),
                  ],
                ),
                const Divider(height: 20),
                ...byMethod.entries.map((e) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        children: [
                          Icon(_methodIcon(e.key), size: 16,
                              color: AppTheme.textSecondary),
                          const SizedBox(width: 8),
                          Expanded(child: Text(e.key.name)),
                          Text(AppFormatter.currency(e.value, symbol: sym),
                              style: const TextStyle(fontWeight: FontWeight.w600)),
                        ],
                      ),
                    )),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text('${payments.length} payment${payments.length != 1 ? 's' : ''}',
            style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
        const SizedBox(height: 8),
        ...payments.map((p) => Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                leading: CircleAvatar(
                  radius: 18,
                  backgroundColor: AppTheme.paid.withValues(alpha: 0.12),
                  child: Icon(_methodIcon(p.paymentMethod),
                      size: 16, color: AppTheme.paid),
                ),
                title: Text(p.customerName,
                    style: const TextStyle(fontWeight: FontWeight.w600)),
                subtitle: Text(
                    '${p.paymentId} • ${AppFormatter.date(p.paymentDate)}',
                    style: const TextStyle(fontSize: 12)),
                trailing: Text(
                  AppFormatter.currency(p.amount, symbol: sym),
                  style: const TextStyle(
                      color: AppTheme.paid,
                      fontWeight: FontWeight.w700,
                      fontSize: 14),
                ),
              ),
            )),
      ],
    );
  }

  IconData _methodIcon(PaymentMethod m) {
    switch (m) {
      case PaymentMethod.cash: return Icons.money_outlined;
      case PaymentMethod.gcash: return Icons.phone_android_outlined;
      case PaymentMethod.bankTransfer: return Icons.account_balance_outlined;
      case PaymentMethod.other: return Icons.more_horiz;
    }
  }
}

// ─── Outstanding Report ───────────────────────────────────────────────────────

class _OutstandingReport extends StatelessWidget {
  final List<Customer> customers;
  final String sym;

  const _OutstandingReport({required this.customers, required this.sym});

  @override
  Widget build(BuildContext context) {
    if (customers.isEmpty) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.check_circle_outline, size: 48, color: AppTheme.paid),
            SizedBox(height: 12),
            Text('No outstanding balances!',
                style: TextStyle(color: AppTheme.paid, fontWeight: FontWeight.w600)),
          ],
        ),
      );
    }

    final totalOutstanding =
        customers.fold(0.0, (s, c) => s + c.outstandingBalance);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(children: [
          _MiniStat('${customers.length} Customers', '', AppTheme.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(AppFormatter.currency(totalOutstanding, symbol: sym),
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w800,
                            color: AppTheme.overdue)),
                    const Text('Total Outstanding',
                        style: TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
                  ],
                ),
              ),
            ),
          ),
        ]),
        const SizedBox(height: 8),
        ...customers.map((c) => Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                leading: CircleAvatar(
                  radius: 18,
                  backgroundColor: AppTheme.primary.withValues(alpha: 0.1),
                  child: Text(c.name[0].toUpperCase(),
                      style: const TextStyle(
                          color: AppTheme.primary,
                          fontWeight: FontWeight.w700)),
                ),
                title: Text(c.name,
                    style: const TextStyle(fontWeight: FontWeight.w600)),
                subtitle: Text(
                    '${c.unpaidTransactions} unpaid${c.overdueTransactions > 0 ? ' • ${c.overdueTransactions} overdue' : ''}',
                    style: TextStyle(
                        fontSize: 12,
                        color: c.overdueTransactions > 0
                            ? AppTheme.overdue
                            : AppTheme.textSecondary)),
                trailing: Text(
                  AppFormatter.currency(c.outstandingBalance, symbol: sym),
                  style: TextStyle(
                    color: c.overdueTransactions > 0
                        ? AppTheme.overdue
                        : AppTheme.primary,
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
              ),
            )),
      ],
    );
  }
}

class _MiniStat extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _MiniStat(this.label, this.value, this.color);

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (value.isNotEmpty)
                Text(value,
                    style: TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w700,
                        color: color)),
              Text(label,
                  style: const TextStyle(
                      fontSize: 11, color: AppTheme.textSecondary)),
            ],
          ),
        ),
      ),
    );
  }
}
