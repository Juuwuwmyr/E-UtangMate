import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../providers/customer_provider.dart';
import '../../providers/transaction_provider.dart';
import '../../providers/store_provider.dart';
import '../../core/theme.dart';
import '../../data/models/customer_model.dart';
import '../../data/models/transaction_model.dart';
import '../../utils/constants.dart';
import '../../utils/formatters.dart';
import '../../widgets/customer_avatar.dart';
import '../../widgets/status_badge.dart';
import '../../widgets/confirm_dialog.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/loading_overlay.dart';

class CustomerDetailScreen extends StatefulWidget {
  final int customerId;
  const CustomerDetailScreen({super.key, required this.customerId});

  @override
  State<CustomerDetailScreen> createState() => _CustomerDetailScreenState();
}

class _CustomerDetailScreenState extends State<CustomerDetailScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    await context.read<CustomerProvider>().loadCustomer(widget.customerId);
    if (mounted) {
      await context
          .read<TransactionProvider>()
          .loadTransactionsByCustomer(widget.customerId);
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final customerProvider = context.watch<CustomerProvider>();
    final txProvider = context.watch<TransactionProvider>();
    final store = context.watch<StoreProvider>();
    final customer = customerProvider.selectedCustomer;
    final sym = store.currencySymbol;

    if (customerProvider.isLoading && customer == null) {
      return const Scaffold(body: AppLoadingIndicator());
    }

    if (customer == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Customer')),
        body: const Center(child: Text('Customer not found')),
      );
    }

    return Scaffold(
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) => [
          _CustomerSliverAppBar(
            customer: customer,
            sym: sym,
            onEdit: () => Navigator.of(context)
                .pushNamed(AppRoutes.editCustomer, arguments: customer)
                .then((_) => _load()),
            onAddDebt: () => Navigator.of(context)
                .pushNamed(AppRoutes.addDebt, arguments: {
                  'customerId': customer.id,
                  'customerName': customer.name,
                })
                .then((_) => _load()),
          ),
          SliverPersistentHeader(
            pinned: true,
            delegate: _TabBarDelegate(
              TabBar(
                controller: _tabController,
                tabs: const [
                  Tab(text: 'Transactions'),
                  Tab(text: 'Summary'),
                ],
                labelColor: AppTheme.primary,
                unselectedLabelColor: AppTheme.textSecondary,
                indicatorColor: AppTheme.primary,
                indicatorWeight: 3,
              ),
            ),
          ),
        ],
        body: TabBarView(
          controller: _tabController,
          children: [
            // Tab 1: Transaction history
            _TransactionTab(
              customer: customer,
              transactions: txProvider.transactions,
              isLoading: txProvider.isLoading,
              sym: sym,
              onRefresh: _load,
              onAddDebt: () => Navigator.of(context)
                  .pushNamed(AppRoutes.addDebt, arguments: {
                    'customerId': customer.id,
                    'customerName': customer.name,
                  })
                  .then((_) => _load()),
            ),
            // Tab 2: Summary
            _SummaryTab(customer: customer, sym: sym),
          ],
        ),
      ),
    );
  }
}

// ─── Sliver App Bar ───────────────────────────────────────────────────────────

class _CustomerSliverAppBar extends StatelessWidget {
  final Customer customer;
  final String sym;
  final VoidCallback onEdit;
  final VoidCallback onAddDebt;

  const _CustomerSliverAppBar({
    required this.customer,
    required this.sym,
    required this.onEdit,
    required this.onAddDebt,
  });

  @override
  Widget build(BuildContext context) {
    final balance = customer.outstandingBalance;
    final isOverdue = customer.overdueTransactions > 0;

    return SliverAppBar(
      expandedHeight: 260,
      pinned: true,
      backgroundColor: AppTheme.primary,
      foregroundColor: Colors.white,
      actions: [
        IconButton(
          icon: const Icon(Icons.edit_outlined),
          onPressed: onEdit,
          tooltip: 'Edit customer',
        ),
        PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert),
          onSelected: (v) => _handleMenu(context, v),
          itemBuilder: (_) => [
            if (customer.phone != null) ...[
              const PopupMenuItem(
                  value: 'call', child: Text('📞 Call')),
              const PopupMenuItem(
                  value: 'sms', child: Text('💬 Send SMS')),
              const PopupMenuItem(
                  value: 'whatsapp', child: Text('WhatsApp')),
            ],
            const PopupMenuItem(
                value: 'reminder', child: Text('📋 Copy Reminder')),
            const PopupMenuDivider(),
            const PopupMenuItem(
                value: 'archive',
                child: Text('Archive',
                    style: TextStyle(color: AppTheme.textSecondary))),
          ],
        ),
      ],
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [AppTheme.primary, AppTheme.primaryDark],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: SafeArea(
            child: Padding(
              padding:
                  const EdgeInsets.fromLTRB(20, 60, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      CustomerAvatar(
                          name: customer.name,
                          photoPath: customer.photoPath,
                          radius: 32),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              customer.name,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.w700,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (customer.phone != null) ...[
                              const SizedBox(height: 2),
                              Text(
                                customer.phone!,
                                style: TextStyle(
                                    color:
                                        Colors.white.withValues(alpha: 0.8),
                                    fontSize: 13),
                              ),
                            ],
                            const SizedBox(height: 2),
                            Text(
                              customer.customerId,
                              style: TextStyle(
                                  color:
                                      Colors.white.withValues(alpha: 0.6),
                                  fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  // Balance row
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              AppFormatter.currency(balance, symbol: sym),
                              style: TextStyle(
                                color: isOverdue
                                    ? Colors.redAccent[100]
                                    : Colors.white,
                                fontSize: 28,
                                fontWeight: FontWeight.w800,
                                fontFeatures: const [
                                  FontFeature.tabularFigures()
                                ],
                              ),
                            ),
                            Text(
                              'Outstanding Balance',
                              style: TextStyle(
                                  color:
                                      Colors.white.withValues(alpha: 0.7),
                                  fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                      ElevatedButton.icon(
                        onPressed: onAddDebt,
                        style: ElevatedButton.styleFrom(
                          backgroundColor:
                              Colors.white.withValues(alpha: 0.2),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          side: BorderSide(
                              color:
                                  Colors.white.withValues(alpha: 0.4)),
                        ),
                        icon: const Icon(Icons.add, size: 18),
                        label: const Text('Add Debt'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _handleMenu(BuildContext context, String action) async {
    switch (action) {
      case 'call':
        await launchUrl(Uri.parse('tel:${customer.phone}'));
        break;
      case 'sms':
        await launchUrl(Uri.parse('sms:${customer.phone}'));
        break;
      case 'whatsapp':
        final phone =
            customer.phone?.replaceAll(RegExp(r'[^\d]'), '') ?? '';
        final intlPhone = phone.startsWith('0') ? '63${phone.substring(1)}' : phone;
        await launchUrl(
            Uri.parse('https://wa.me/$intlPhone'));
        break;
      case 'reminder':
        final balance = customer.outstandingBalance;
        final msg =
            'Hi ${customer.name}, this is a friendly reminder that you have an outstanding balance of ${AppFormatter.currency(balance)} at our store. Please settle at your earliest convenience. Thank you!';
        // Copy to clipboard
        await _copyToClipboard(context, msg);
        break;
      case 'archive':
        final confirm = await ConfirmDialog.show(
          context,
          title: 'Archive Customer',
          message:
              'Archive ${customer.name}? Their records will be preserved.',
          confirmLabel: 'Archive',
          isDangerous: true,
        );
        if (confirm == true && context.mounted) {
          await context.read<CustomerProvider>().archiveCustomer(customer.id!);
          if (context.mounted) Navigator.of(context).pop();
        }
        break;
    }
  }

  Future<void> _copyToClipboard(BuildContext context, String text) async {
    // Uses flutter clipboard
    await Clipboard.setData(ClipboardData(text: text));
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Reminder message copied to clipboard')),
      );
    }
  }
}

// ─── Tab Bar Delegate ─────────────────────────────────────────────────────────

class _TabBarDelegate extends SliverPersistentHeaderDelegate {
  final TabBar tabBar;
  const _TabBarDelegate(this.tabBar);

  @override
  double get minExtent => tabBar.preferredSize.height;
  @override
  double get maxExtent => tabBar.preferredSize.height;

  @override
  Widget build(
      BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: tabBar,
    );
  }

  @override
  bool shouldRebuild(_TabBarDelegate oldDelegate) => false;
}

// ─── Transaction Tab ──────────────────────────────────────────────────────────

class _TransactionTab extends StatelessWidget {
  final Customer customer;
  final List<DebtTransaction> transactions;
  final bool isLoading;
  final String sym;
  final Future<void> Function() onRefresh;
  final VoidCallback onAddDebt;

  const _TransactionTab({
    required this.customer,
    required this.transactions,
    required this.isLoading,
    required this.sym,
    required this.onRefresh,
    required this.onAddDebt,
  });

  @override
  Widget build(BuildContext context) {
    if (isLoading) return const AppLoadingIndicator();

    if (transactions.isEmpty) {
      return EmptyState(
        icon: Icons.receipt_long_outlined,
        title: 'No transactions yet',
        subtitle: 'Add the first debt transaction for this customer',
        actionLabel: 'Add Debt',
        onAction: onAddDebt,
      );
    }

    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
        itemCount: transactions.length,
        separatorBuilder: (_, _) => const SizedBox(height: 10),
        itemBuilder: (context, i) => _TransactionCard(
          transaction: transactions[i],
          sym: sym,
          onPayment: () => Navigator.of(context)
              .pushNamed(AppRoutes.recordPayment, arguments: {
                'transactionId': transactions[i].id,
                'customerId': customer.id,
                'customerName': customer.name,
                'txTransactionId': transactions[i].transactionId,
                'remainingBalance': transactions[i].remainingBalance,
              })
              .then((_) => onRefresh()),
          onDelete: () async {
            final confirm = await ConfirmDialog.show(
              context,
              title: 'Delete Transaction',
              message:
                  'Delete ${transactions[i].transactionId}? This cannot be undone. (Record is archived, not permanently removed.)',
              confirmLabel: 'Delete',
              isDangerous: true,
              icon: Icons.delete_outline,
            );
            if (confirm == true && context.mounted) {
              await context
                  .read<TransactionProvider>()
                  .deleteTransaction(transactions[i].id!);
              onRefresh();
            }
          },
        ),
      ),
    );
  }
}

class _TransactionCard extends StatefulWidget {
  final DebtTransaction transaction;
  final String sym;
  final VoidCallback onPayment;
  final VoidCallback onDelete;

  const _TransactionCard({
    required this.transaction,
    required this.sym,
    required this.onPayment,
    required this.onDelete,
  });

  @override
  State<_TransactionCard> createState() => _TransactionCardState();
}

class _TransactionCardState extends State<_TransactionCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final t = widget.transaction;
    final isPaid = t.status == TransactionStatus.paid;

    return Card(
      child: Column(
        children: [
          // Header row
          InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  // Status indicator
                  Container(
                    width: 4,
                    height: 44,
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
                        Row(
                          children: [
                            Text(
                              t.transactionId,
                              style: const TextStyle(
                                  fontSize: 13,
                                  color: AppTheme.textSecondary),
                            ),
                            const SizedBox(width: 8),
                            StatusBadge(status: t.status, small: true),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          AppFormatter.dateTime(t.transactionDate),
                          style: const TextStyle(
                              fontSize: 12, color: AppTheme.textHint),
                        ),
                        if (t.dueDate != null) ...[
                          const SizedBox(height: 2),
                          Text(
                            t.isOverdue
                                ? '⚠ ${AppFormatter.overdueLabel(t.daysOverdue)}'
                                : t.isDueSoon
                                    ? '⏰ ${AppFormatter.dueSoonLabel(t.daysUntilDue)}'
                                    : 'Due: ${AppFormatter.date(t.dueDate!)}',
                            style: TextStyle(
                              fontSize: 11,
                              color: t.isOverdue
                                  ? AppTheme.overdue
                                  : t.isDueSoon
                                      ? AppTheme.partiallyPaid
                                      : AppTheme.textHint,
                              fontWeight: t.isOverdue || t.isDueSoon
                                  ? FontWeight.w600
                                  : FontWeight.normal,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        AppFormatter.currency(t.totalAmount, symbol: widget.sym),
                        style: const TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w700),
                      ),
                      if (!isPaid) ...[
                        const SizedBox(height: 2),
                        Text(
                          'Balance: ${AppFormatter.currency(t.remainingBalance, symbol: widget.sym)}',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppTheme.overdue,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    _expanded
                        ? Icons.expand_less
                        : Icons.expand_more,
                    color: AppTheme.textSecondary,
                  ),
                ],
              ),
            ),
          ),

          // Expandable items
          if (_expanded) ...[
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Items list
                  if (t.items.isNotEmpty) ...[
                    const Text('Items',
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textSecondary)),
                    const SizedBox(height: 8),
                    ...t.items.map((item) => Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Row(
                            children: [
                              const Icon(Icons.circle,
                                  size: 6, color: AppTheme.textHint),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  '${item.itemName} × ${item.quantity} ${item.unit}',
                                  style: const TextStyle(fontSize: 13),
                                ),
                              ),
                              Text(
                                AppFormatter.currency(item.totalPrice,
                                    symbol: widget.sym),
                                style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                        )),
                    const Divider(),
                  ],

                  // Payment summary
                  _InfoRow('Total', AppFormatter.currency(t.totalAmount, symbol: widget.sym)),
                  _InfoRow('Paid', AppFormatter.currency(t.amountPaid, symbol: widget.sym),
                      valueColor: AppTheme.paid),
                  _InfoRow('Balance',
                      AppFormatter.currency(t.remainingBalance, symbol: widget.sym),
                      valueColor: t.remainingBalance > 0
                          ? AppTheme.overdue
                          : AppTheme.paid),

                  if (t.notes != null && t.notes!.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.notes,
                            size: 14, color: AppTheme.textHint),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(t.notes!,
                              style: const TextStyle(
                                  fontSize: 12,
                                  color: AppTheme.textSecondary)),
                        ),
                      ],
                    ),
                  ],

                  const SizedBox(height: 10),

                  // Action buttons
                  Row(
                    children: [
                      if (!isPaid)
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: widget.onPayment,
                            icon: const Icon(Icons.payment, size: 16),
                            label: const Text('Record Payment'),
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                  vertical: 10),
                              textStyle: const TextStyle(fontSize: 13),
                            ),
                          ),
                        ),
                      if (!isPaid) const SizedBox(width: 8),
                      OutlinedButton(
                        onPressed: widget.onDelete,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppTheme.overdue,
                          side: BorderSide(
                              color: AppTheme.overdue.withValues(alpha: 0.5)),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 10),
                        ),
                        child: const Icon(Icons.delete_outline, size: 18),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;

  const _InfoRow(this.label, this.value, {this.valueColor});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: const TextStyle(
                  fontSize: 13, color: AppTheme.textSecondary)),
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: valueColor,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Summary Tab ──────────────────────────────────────────────────────────────

class _SummaryTab extends StatelessWidget {
  final Customer customer;
  final String sym;

  const _SummaryTab({required this.customer, required this.sym});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Balance overview card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Balance Overview',
                      style: TextStyle(
                          fontWeight: FontWeight.w700, fontSize: 15)),
                  const SizedBox(height: 16),
                  _StatRow(
                    label: 'Total Borrowed',
                    value: AppFormatter.currency(customer.totalDebt,
                        symbol: sym),
                    icon: Icons.trending_up,
                    color: AppTheme.primary,
                  ),
                  const Divider(height: 20),
                  _StatRow(
                    label: 'Total Paid',
                    value: AppFormatter.currency(customer.totalPaid,
                        symbol: sym),
                    icon: Icons.check_circle_outline,
                    color: AppTheme.paid,
                  ),
                  const Divider(height: 20),
                  _StatRow(
                    label: 'Outstanding Balance',
                    value: AppFormatter.currency(
                        customer.outstandingBalance, symbol: sym),
                    icon: Icons.account_balance_wallet_outlined,
                    color: customer.outstandingBalance > 0
                        ? AppTheme.overdue
                        : AppTheme.paid,
                    isBold: true,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Transaction stats
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Transaction Stats',
                      style: TextStyle(
                          fontWeight: FontWeight.w700, fontSize: 15)),
                  const SizedBox(height: 16),
                  _StatRow(
                    label: 'Unpaid Transactions',
                    value: '${customer.unpaidTransactions}',
                    icon: Icons.receipt_outlined,
                    color: AppTheme.unpaid,
                  ),
                  const Divider(height: 20),
                  _StatRow(
                    label: 'Overdue Transactions',
                    value: '${customer.overdueTransactions}',
                    icon: Icons.warning_amber_outlined,
                    color: customer.overdueTransactions > 0
                        ? AppTheme.overdue
                        : AppTheme.textSecondary,
                  ),
                  const Divider(height: 20),
                  _StatRow(
                    label: 'Last Transaction',
                    value: customer.lastTransactionDate != null
                        ? AppFormatter.date(customer.lastTransactionDate!)
                        : 'None',
                    icon: Icons.calendar_today_outlined,
                    color: AppTheme.textSecondary,
                  ),
                  const Divider(height: 20),
                  _StatRow(
                    label: 'Last Payment',
                    value: customer.lastPaymentDate != null
                        ? AppFormatter.date(customer.lastPaymentDate!)
                        : 'None',
                    icon: Icons.payments_outlined,
                    color: AppTheme.accent,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Customer info
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Customer Info',
                      style: TextStyle(
                          fontWeight: FontWeight.w700, fontSize: 15)),
                  const SizedBox(height: 16),
                  if (customer.phone != null)
                    _ContactRow(
                        Icons.phone_outlined, 'Phone', customer.phone!),
                  if (customer.address != null)
                    _ContactRow(
                        Icons.home_outlined, 'Address', customer.address!),
                  if (customer.email != null)
                    _ContactRow(
                        Icons.email_outlined, 'Email', customer.email!),
                  if (customer.creditLimit != null)
                    _ContactRow(
                        Icons.credit_card_outlined,
                        'Credit Limit',
                        AppFormatter.currency(customer.creditLimit!,
                            symbol: sym)),
                  _ContactRow(Icons.badge_outlined, 'Customer ID',
                      customer.customerId),
                  _ContactRow(
                    Icons.calendar_month_outlined,
                    'Member Since',
                    AppFormatter.date(customer.createdAt),
                  ),
                  if (customer.notes != null &&
                      customer.notes!.isNotEmpty) ...[
                    const Divider(height: 20),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.notes_outlined,
                            size: 18, color: AppTheme.textSecondary),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Notes',
                                  style: TextStyle(
                                      fontSize: 12,
                                      color: AppTheme.textSecondary)),
                              const SizedBox(height: 2),
                              Text(customer.notes!,
                                  style: const TextStyle(fontSize: 14)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 80),
        ],
      ),
    );
  }
}

class _StatRow extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final bool isBold;

  const _StatRow({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    this.isBold = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: color, size: 18),
        ),
        const SizedBox(width: 12),
        Expanded(
            child: Text(label,
                style: const TextStyle(color: AppTheme.textSecondary))),
        Text(
          value,
          style: TextStyle(
            fontSize: isBold ? 16 : 14,
            fontWeight: isBold ? FontWeight.w800 : FontWeight.w600,
            color: color,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ],
    );
  }
}

class _ContactRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _ContactRow(this.icon, this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: AppTheme.textSecondary),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: const TextStyle(
                        fontSize: 11, color: AppTheme.textSecondary)),
                const SizedBox(height: 1),
                Text(value, style: const TextStyle(fontSize: 14)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
