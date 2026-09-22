import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../providers/transaction_provider.dart';
import '../../providers/store_provider.dart';
import '../../core/theme.dart';
import '../../data/models/transaction_model.dart';
import '../../utils/constants.dart';
import '../../utils/formatters.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/loading_overlay.dart';

class RemindersScreen extends StatefulWidget {
  const RemindersScreen({super.key});

  @override
  State<RemindersScreen> createState() => _RemindersScreenState();
}

class _RemindersScreenState extends State<RemindersScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<TransactionProvider>().loadOverdueTransactions();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final txProvider = context.watch<TransactionProvider>();
    final sym =
        context.select<StoreProvider, String>((p) => p.currencySymbol);
    final storeName =
        context.select<StoreProvider, String>((p) => p.storeName);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Reminders'),
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_outlined),
            onPressed: () =>
                txProvider.loadOverdueTransactions(),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          tabs: [
            Tab(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('Overdue'),
                  if (txProvider.overdueCount > 0) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.redAccent,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text('${txProvider.overdueCount}',
                          style: const TextStyle(fontSize: 11)),
                    ),
                  ],
                ],
              ),
            ),
            Tab(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('Due Soon'),
                  if (txProvider.dueSoonCount > 0) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppTheme.partiallyPaid,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text('${txProvider.dueSoonCount}',
                          style: const TextStyle(fontSize: 11)),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
      body: txProvider.isLoading
          ? const AppLoadingIndicator()
          : TabBarView(
              controller: _tabController,
              children: [
                // Overdue tab
                _ReminderList(
                  transactions: txProvider.overdueTransactions,
                  sym: sym,
                  storeName: storeName,
                  isOverdue: true,
                  emptyIcon: Icons.check_circle_outline,
                  emptyTitle: 'No overdue debts',
                  emptySubtitle: 'All debts are within their due dates.',
                ),
                // Due soon tab
                _ReminderList(
                  transactions: txProvider.dueSoonTransactions,
                  sym: sym,
                  storeName: storeName,
                  isOverdue: false,
                  emptyIcon: Icons.event_available_outlined,
                  emptyTitle: 'No upcoming due dates',
                  emptySubtitle: 'No payments due in the next 3 days.',
                ),
              ],
            ),
    );
  }
}

// ─── Reminder List ────────────────────────────────────────────────────────────

class _ReminderList extends StatelessWidget {
  final List<DebtTransaction> transactions;
  final String sym;
  final String storeName;
  final bool isOverdue;
  final IconData emptyIcon;
  final String emptyTitle;
  final String? emptySubtitle;

  const _ReminderList({
    required this.transactions,
    required this.sym,
    required this.storeName,
    required this.isOverdue,
    required this.emptyIcon,
    required this.emptyTitle,
    this.emptySubtitle,
  });

  @override
  Widget build(BuildContext context) {
    if (transactions.isEmpty) {
      return EmptyState(
        icon: emptyIcon,
        title: emptyTitle,
        subtitle: emptySubtitle,
      );
    }

    final totalAmount =
        transactions.fold(0.0, (s, t) => s + t.remainingBalance);

    return RefreshIndicator(
      onRefresh: () =>
          context.read<TransactionProvider>().loadOverdueTransactions(),
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Summary banner
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: (isOverdue ? AppTheme.overdue : AppTheme.partiallyPaid)
                  .withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: (isOverdue
                        ? AppTheme.overdue
                        : AppTheme.partiallyPaid)
                    .withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  isOverdue ? Icons.warning_amber : Icons.schedule,
                  color: isOverdue ? AppTheme.overdue : AppTheme.partiallyPaid,
                  size: 22,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${transactions.length} ${isOverdue ? 'overdue' : 'due soon'} transaction${transactions.length != 1 ? 's' : ''}',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: isOverdue
                              ? AppTheme.overdue
                              : AppTheme.partiallyPaid,
                        ),
                      ),
                      Text(
                        'Total: ${AppFormatter.currency(totalAmount, symbol: sym)}',
                        style: const TextStyle(
                            fontSize: 12,
                            color: AppTheme.textSecondary),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          ...transactions.map((t) => _ReminderCard(
                transaction: t,
                sym: sym,
                storeName: storeName,
                isOverdue: isOverdue,
              )),
        ],
      ),
    );
  }
}

// ─── Reminder Card ────────────────────────────────────────────────────────────

class _ReminderCard extends StatelessWidget {
  final DebtTransaction transaction;
  final String sym;
  final String storeName;
  final bool isOverdue;

  const _ReminderCard({
    required this.transaction,
    required this.sym,
    required this.storeName,
    required this.isOverdue,
  });

  String _buildReminderMessage() {
    final t = transaction;
    final balance = AppFormatter.currency(t.remainingBalance, symbol: sym);
    final duePart = t.dueDate != null
        ? isOverdue
            ? ' This was due ${AppFormatter.date(t.dueDate!)} (${AppFormatter.overdueLabel(t.daysOverdue)}).'
            : ' This is due on ${AppFormatter.date(t.dueDate!)}.'
        : '';
    return 'Hi ${t.customerName}! This is a friendly reminder from $storeName. '
        'You have an outstanding balance of $balance (Ref: ${t.transactionId}).$duePart '
        'Please settle at your earliest convenience. Thank you!';
  }

  void _copyMessage(BuildContext context) {
    final msg = _buildReminderMessage();
    Clipboard.setData(ClipboardData(text: msg));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Reminder message copied to clipboard')),
    );
  }

  void _showMessageOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.sms_outlined),
              title: const Text('Send via SMS'),
              onTap: () {
                Navigator.of(ctx).pop();
                _sendSMS(context, transaction.customerName);
              },
            ),
            ListTile(
              leading: const Icon(Icons.chat_outlined, color: Color(0xFF25D366)),
              title: const Text('Send via WhatsApp'),
              onTap: () {
                Navigator.of(ctx).pop();
                _sendWhatsApp(context, null);
              },
            ),
            ListTile(
              leading: const Icon(Icons.close),
              title: const Text('Cancel'),
              onTap: () => Navigator.of(ctx).pop(),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _sendSMS(BuildContext context, String? phone) async {
    if (phone == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No phone number on file for this customer')),
      );
      return;
    }
    final msg = Uri.encodeComponent(_buildReminderMessage());
    await launchUrl(Uri.parse('sms:$phone?body=$msg'));
  }

  Future<void> _sendWhatsApp(BuildContext context, String? phone) async {
    if (phone == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No phone number on file')),
      );
      return;
    }
    final cleaned = phone.replaceAll(RegExp(r'[^\d]'), '');
    final intlPhone =
        cleaned.startsWith('0') ? '63${cleaned.substring(1)}' : cleaned;
    final msg = Uri.encodeComponent(_buildReminderMessage());
    await launchUrl(Uri.parse('https://wa.me/$intlPhone?text=$msg'));
  }

  @override
  Widget build(BuildContext context) {
    final t = transaction;
    final color = isOverdue ? AppTheme.overdue : AppTheme.partiallyPaid;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: color.withValues(alpha: 0.12),
                  child: Icon(isOverdue ? Icons.warning_amber : Icons.schedule,
                      color: color, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        t.customerName,
                        style: const TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w700),
                      ),
                      Text(
                        isOverdue
                            ? AppFormatter.overdueLabel(t.daysOverdue)
                            : AppFormatter.dueSoonLabel(t.daysUntilDue),
                        style: TextStyle(
                            color: color,
                            fontSize: 12,
                            fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      AppFormatter.currency(t.remainingBalance, symbol: sym),
                      style: TextStyle(
                          color: color,
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                          fontFeatures: const [FontFeature.tabularFigures()]),
                    ),
                    Text(t.transactionId,
                        style: const TextStyle(
                            fontSize: 11, color: AppTheme.textHint)),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Reminder message preview
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppTheme.surface,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppTheme.divider),
              ),
              child: Text(
                _buildReminderMessage(),
                style: const TextStyle(
                    fontSize: 12, color: AppTheme.textSecondary),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(height: 10),

            // Action buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _copyMessage(context),
                    icon: const Icon(Icons.copy_outlined, size: 14),
                    label: const Text('Copy', style: TextStyle(fontSize: 12)),
                    style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 8)),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _showMessageOptions(context),
                    icon: const Icon(Icons.send_outlined, size: 14),
                    label: const Text('Send', style: TextStyle(fontSize: 12)),
                    style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 8)),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      final txProvider = context.read<TransactionProvider>();
                      Navigator.of(context).pushNamed(
                        AppRoutes.recordPayment,
                        arguments: {
                          'transactionId': t.id,
                          'customerId': t.customerId,
                          'customerName': t.customerName,
                          'txTransactionId': t.transactionId,
                          'remainingBalance': t.remainingBalance,
                        },
                      ).then((_) => txProvider.loadOverdueTransactions());
                    },
                    icon: const Icon(Icons.payment, size: 14),
                    label: const Text('Pay', style: TextStyle(fontSize: 12)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.paid,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
