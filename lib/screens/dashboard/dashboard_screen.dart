import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';

import '../../providers/dashboard_provider.dart';
import '../../providers/store_provider.dart';
import '../../providers/transaction_provider.dart';
import '../../core/theme.dart';
import '../../utils/constants.dart';
import '../../utils/formatters.dart';
import '../../widgets/info_card.dart';
import '../../widgets/loading_overlay.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    await context.read<DashboardProvider>().loadDashboard();
    if (mounted) {
      await context.read<TransactionProvider>().loadOverdueTransactions();
    }
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<StoreProvider>();
    final dashboard = context.watch<DashboardProvider>();
    final txProvider = context.watch<TransactionProvider>();
    final sym = store.currencySymbol;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(store.storeName,
                style: const TextStyle(
                    fontSize: 18, fontWeight: FontWeight.w700)),
            Text(AppFormatter.date(DateTime.now()),
                style: TextStyle(
                    fontSize: 12,
                    color: Colors.white.withValues(alpha: 0.8),
                    fontWeight: FontWeight.w400)),
          ],
        ),
        actions: [
          // Overdue badge
          if (txProvider.overdueCount > 0)
            Padding(
              padding: const EdgeInsets.only(right: 4),
              child: IconButton(
                onPressed: () =>
                    Navigator.of(context).pushNamed(AppRoutes.reminders),
                icon: Badge(
                  label: Text('${txProvider.overdueCount}'),
                  child: const Icon(Icons.notifications_outlined),
                ),
              ),
            ),
          IconButton(
            onPressed: () =>
                Navigator.of(context).pushNamed(AppRoutes.settings),
            icon: const Icon(Icons.settings_outlined),
          ),
        ],
      ),
      body: dashboard.isLoading
          ? const AppLoadingIndicator()
          : RefreshIndicator(
              onRefresh: _load,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Quick action banner
                    _QuickActionBanner(),
                    const SizedBox(height: 20),

                    // Primary stats row
                    Row(
                      children: [
                        Expanded(
                          child: InfoCard(
                            label: 'Outstanding',
                            amount: dashboard.totalOutstanding,
                            color: AppTheme.overdue,
                            icon: Icons.account_balance_wallet_outlined,
                            currencySymbol: sym,
                            onTap: () => Navigator.of(context)
                                .pushNamed(AppRoutes.customers),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: InfoCard(
                            label: 'Collected',
                            amount: dashboard.totalCollected,
                            color: AppTheme.paid,
                            icon: Icons.payments_outlined,
                            currencySymbol: sym,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: InfoCard(
                            label: 'Overdue',
                            amount: dashboard.overdueAmount,
                            color: const Color(0xFFB71C1C),
                            icon: Icons.warning_amber_outlined,
                            currencySymbol: sym,
                            subtitle: '${dashboard.overdueCount} transactions',
                            onTap: () => Navigator.of(context)
                                .pushNamed(AppRoutes.reminders),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: InfoCard(
                            label: "Today's Payments",
                            amount: dashboard.paymentsToday,
                            color: AppTheme.accent,
                            icon: Icons.today_outlined,
                            currencySymbol: sym,
                            subtitle: 'New debt: ${AppFormatter.currency(dashboard.debtToday, symbol: sym)}',
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: CountCard(
                            label: 'Total Customers',
                            count: dashboard.totalCustomers,
                            color: AppTheme.primary,
                            icon: Icons.people_outline,
                            onTap: () => Navigator.of(context)
                                .pushNamed(AppRoutes.customers),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: CountCard(
                            label: 'With Debt',
                            count: dashboard.customersWithDebt,
                            color: AppTheme.partiallyPaid,
                            icon: Icons.person_outline,
                            onTap: () => Navigator.of(context)
                                .pushNamed(AppRoutes.customers),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 24),

                    // Chart
                    if (dashboard.monthlyStats.isNotEmpty) ...[
                      _SectionHeader(
                        title: 'Last 6 Months',
                        onSeeAll: () => Navigator.of(context)
                            .pushNamed(AppRoutes.reports),
                      ),
                      const SizedBox(height: 12),
                      _MonthlyChart(
                          stats: dashboard.monthlyStats, symbol: sym),
                      const SizedBox(height: 24),
                    ],

                    // Overdue alerts
                    if (txProvider.overdueCount > 0) ...[
                      _SectionHeader(
                        title: 'Overdue Debts',
                        onSeeAll: () => Navigator.of(context)
                            .pushNamed(AppRoutes.reminders),
                      ),
                      const SizedBox(height: 12),
                      ...txProvider.overdueTransactions
                          .take(3)
                          .map((t) => _OverdueListItem(
                              transaction: t, symbol: sym)),
                      if (txProvider.overdueCount > 3)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Center(
                            child: TextButton(
                              onPressed: () => Navigator.of(context)
                                  .pushNamed(AppRoutes.reminders),
                              child: Text(
                                  'View all ${txProvider.overdueCount} overdue'),
                            ),
                          ),
                        ),
                      const SizedBox(height: 8),
                    ],

                    // Due soon alerts
                    if (txProvider.dueSoonCount > 0) ...[
                      _SectionHeader(title: 'Due Soon (Next 3 Days)'),
                      const SizedBox(height: 12),
                      ...txProvider.dueSoonTransactions
                          .take(3)
                          .map((t) => _OverdueListItem(
                              transaction: t,
                              symbol: sym,
                              isDueSoon: true)),
                      const SizedBox(height: 16),
                    ],

                    const SizedBox(height: 80),
                  ],
                ),
              ),
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () =>
            Navigator.of(context).pushNamed(AppRoutes.addCustomer),
        icon: const Icon(Icons.person_add_outlined),
        label: const Text('Add Customer'),
      ),
    );
  }
}

// ─── Quick Action Banner ──────────────────────────────────────────────────────

class _QuickActionBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppTheme.primary, AppTheme.primaryDark],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'What do you want to do?',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _QuickBtn(
                      label: 'Add Debt',
                      icon: Icons.add_circle_outline,
                      onTap: () => Navigator.of(context)
                          .pushNamed(AppRoutes.addDebt),
                    ),
                    _QuickBtn(
                      label: 'Find Customer',
                      icon: Icons.search,
                      onTap: () => Navigator.of(context)
                          .pushNamed(AppRoutes.customers),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const Icon(
            Icons.account_balance_wallet_rounded,
            size: 48,
            color: Colors.white24,
          ),
        ],
      ),
    );
  }
}

class _QuickBtn extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  const _QuickBtn(
      {required this.label, required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.18),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: Colors.white),
            const SizedBox(width: 6),
            Text(label,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }
}

// ─── Section Header ───────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String title;
  final VoidCallback? onSeeAll;

  const _SectionHeader({required this.title, this.onSeeAll});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleLarge),
        if (onSeeAll != null)
          TextButton(
              onPressed: onSeeAll,
              child: const Text('See all')),
      ],
    );
  }
}

// ─── Monthly Chart ────────────────────────────────────────────────────────────

class _MonthlyChart extends StatefulWidget {
  final List<Map<String, dynamic>> stats;
  final String symbol;

  const _MonthlyChart({required this.stats, required this.symbol});

  @override
  State<_MonthlyChart> createState() => _MonthlyChartState();
}

class _MonthlyChartState extends State<_MonthlyChart> {
  int _touchedIndex = -1;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final maxVal = widget.stats.fold<double>(0, (m, s) {
      final d = (s['debt'] as double);
      final p = (s['payment'] as double);
      return [m, d, p].reduce((a, b) => a > b ? a : b);
    });

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 16, 16, 8),
        child: Column(
          children: [
            // Legend
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _LegendDot(color: AppTheme.overdue, label: 'Debt'),
                const SizedBox(width: 20),
                _LegendDot(color: AppTheme.paid, label: 'Payments'),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 180,
              child: BarChart(
                BarChartData(
                  maxY: maxVal * 1.2 + 1,
                  barTouchData: BarTouchData(
                    touchTooltipData: BarTouchTooltipData(
                      getTooltipColor: (_) =>
                          isDark ? AppTheme.darkCard : Colors.white,
                      getTooltipItem: (group, _, rod, rI) {
                        final isDebt = rI == 0;
                        return BarTooltipItem(
                          '${isDebt ? 'Debt' : 'Payment'}\n${AppFormatter.currency(rod.toY, symbol: widget.symbol)}',
                          TextStyle(
                            color: isDebt ? AppTheme.overdue : AppTheme.paid,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        );
                      },
                    ),
                    touchCallback: (event, response) {
                      setState(() {
                        _touchedIndex =
                            response?.spot?.touchedBarGroupIndex ?? -1;
                      });
                    },
                  ),
                  titlesData: FlTitlesData(
                    show: true,
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (val, meta) {
                          final idx = val.toInt();
                          if (idx < 0 || idx >= widget.stats.length) {
                            return const SizedBox.shrink();
                          }
                          return Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              AppFormatter.monthShort(
                                  widget.stats[idx]['month'] as DateTime),
                              style: TextStyle(
                                fontSize: 11,
                                color: AppTheme.textSecondary,
                              ),
                            ),
                          );
                        },
                        reservedSize: 28,
                      ),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 56,
                        getTitlesWidget: (val, meta) {
                          if (val == 0) return const SizedBox.shrink();
                          return Text(
                            AppFormatter.shortCurrency(val,
                                symbol: widget.symbol),
                            style: TextStyle(
                                fontSize: 10, color: AppTheme.textSecondary),
                          );
                        },
                      ),
                    ),
                    topTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false)),
                  ),
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    getDrawingHorizontalLine: (val) => FlLine(
                      color: isDark
                          ? const Color(0xFF2D3042)
                          : AppTheme.divider,
                      strokeWidth: 1,
                    ),
                  ),
                  borderData: FlBorderData(show: false),
                  barGroups: List.generate(widget.stats.length, (i) {
                    final s = widget.stats[i];
                    final isTouched = i == _touchedIndex;
                    return BarChartGroupData(
                      x: i,
                      barRods: [
                        BarChartRodData(
                          toY: (s['debt'] as double),
                          color: isTouched
                              ? AppTheme.overdue
                              : AppTheme.overdue.withValues(alpha: 0.75),
                          width: 10,
                          borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(4)),
                        ),
                        BarChartRodData(
                          toY: (s['payment'] as double),
                          color: isTouched
                              ? AppTheme.paid
                              : AppTheme.paid.withValues(alpha: 0.75),
                          width: 10,
                          borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(4)),
                        ),
                      ],
                      barsSpace: 4,
                    );
                  }),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;

  const _LegendDot({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
            width: 10,
            height: 10,
            decoration:
                BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 6),
        Text(label,
            style: TextStyle(
                fontSize: 12, color: AppTheme.textSecondary)),
      ],
    );
  }
}

// ─── Overdue List Item ────────────────────────────────────────────────────────

class _OverdueListItem extends StatelessWidget {
  final dynamic transaction;
  final String symbol;
  final bool isDueSoon;

  const _OverdueListItem(
      {required this.transaction,
      required this.symbol,
      this.isDueSoon = false});

  @override
  Widget build(BuildContext context) {
    final color = isDueSoon ? AppTheme.partiallyPaid : AppTheme.overdue;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color.withValues(alpha: 0.12),
          child: Icon(
              isDueSoon ? Icons.schedule_outlined : Icons.warning_amber,
              color: color,
              size: 20),
        ),
        title: Text(transaction.customerName,
            style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(
          isDueSoon
              ? AppFormatter.dueSoonLabel(transaction.daysUntilDue)
              : AppFormatter.overdueLabel(transaction.daysOverdue),
          style: TextStyle(color: color, fontSize: 12),
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              AppFormatter.currency(transaction.remainingBalance,
                  symbol: symbol),
              style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.w700,
                  fontSize: 14),
            ),
            Text(transaction.transactionId,
                style: const TextStyle(
                    fontSize: 11, color: AppTheme.textSecondary)),
          ],
        ),
        onTap: () => Navigator.of(context).pushNamed(
          AppRoutes.customerDetail,
          arguments: transaction.customerId,
        ),
      ),
    );
  }
}
