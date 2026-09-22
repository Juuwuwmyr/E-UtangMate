import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_slidable/flutter_slidable.dart';

import '../../providers/customer_provider.dart';
import '../../providers/store_provider.dart';
import '../../core/theme.dart';
import '../../data/models/customer_model.dart';
import '../../utils/constants.dart';
import '../../utils/formatters.dart';
import '../../widgets/app_search_bar.dart';
import '../../widgets/customer_avatar.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/confirm_dialog.dart';
import '../../widgets/loading_overlay.dart';

class CustomerListScreen extends StatefulWidget {
  const CustomerListScreen({super.key});

  @override
  State<CustomerListScreen> createState() => _CustomerListScreenState();
}

class _CustomerListScreenState extends State<CustomerListScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<CustomerProvider>().loadCustomers();
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<CustomerProvider>();
    final store = context.watch<StoreProvider>();
    final sym = store.currencySymbol;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Customers'),
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.person_add_outlined),
            onPressed: () =>
                Navigator.of(context).pushNamed(AppRoutes.addCustomer).then(
                      (_) => provider.loadCustomers(),
                    ),
          ),
        ],
      ),
      body: Column(
        children: [
          // Search + filter bar
          Container(
            color: Theme.of(context).appBarTheme.backgroundColor,
            padding:
                const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Column(
              children: [
                AppSearchBar(
                  hintText: 'Search name, phone, or ID...',
                  onChanged: provider.setSearch,
                ),
                const SizedBox(height: 10),
                _FilterChips(
                    current: provider.filter,
                    onChanged: provider.setFilter),
              ],
            ),
          ),

          // Sort row
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
            child: Row(
              children: [
                Text(
                  '${AppFormatter.number(provider.customers.length)} customer${provider.customers.length != 1 ? 's' : ''}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const Spacer(),
                _SortDropdown(
                  current: provider.sort,
                  desc: provider.sortDesc,
                  onChanged: (s) => provider.setSort(s),
                ),
              ],
            ),
          ),

          const Divider(height: 1),

          // List
          Expanded(
            child: provider.isLoading
                ? const AppLoadingIndicator()
                : provider.customers.isEmpty
                    ? EmptyState(
                        icon: Icons.people_outline,
                        title: provider.searchQuery.isNotEmpty
                            ? 'No customers found'
                            : 'No customers yet',
                        subtitle: provider.searchQuery.isNotEmpty
                            ? 'Try a different search term'
                            : 'Add your first customer to get started',
                        actionLabel: provider.searchQuery.isEmpty
                            ? 'Add Customer'
                            : null,
                        onAction: provider.searchQuery.isEmpty
                            ? () => Navigator.of(context)
                                .pushNamed(AppRoutes.addCustomer)
                                .then((_) => provider.loadCustomers())
                            : null,
                      )
                    : RefreshIndicator(
                        onRefresh: () => provider.loadCustomers(),
                        child: ListView.separated(
                          padding: const EdgeInsets.fromLTRB(0, 8, 0, 100),
                          itemCount: provider.customers.length,
                          separatorBuilder: (_, _) =>
                              const Divider(height: 1, indent: 72),
                          itemBuilder: (context, index) {
                            final c = provider.customers[index];
                            return _CustomerListTile(
                              customer: c,
                              symbol: sym,
                              onTap: () => Navigator.of(context)
                                  .pushNamed(AppRoutes.customerDetail,
                                      arguments: c.id)
                                  .then((_) => provider.loadCustomers()),
                              onAddDebt: () => Navigator.of(context)
                                  .pushNamed(AppRoutes.addDebt, arguments: {
                                    'customerId': c.id,
                                    'customerName': c.name,
                                  })
                                  .then((_) => provider.loadCustomers()),
                              onArchive: () async {
                                final confirm = await ConfirmDialog.show(
                                  context,
                                  title: 'Archive Customer',
                                  message:
                                      'Archive ${c.name}? They will be hidden from the main list but their records are preserved.',
                                  confirmLabel: 'Archive',
                                  isDangerous: true,
                                  icon: Icons.archive_outlined,
                                );
                                if (confirm == true && context.mounted) {
                                  await provider.archiveCustomer(c.id!);
                                }
                              },
                            );
                          },
                        ),
                      ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () =>
            Navigator.of(context).pushNamed(AppRoutes.addCustomer).then(
                  (_) => provider.loadCustomers(),
                ),
        child: const Icon(Icons.person_add_outlined),
      ),
    );
  }
}

// ─── Customer List Tile ───────────────────────────────────────────────────────

class _CustomerListTile extends StatelessWidget {
  final Customer customer;
  final String symbol;
  final VoidCallback onTap;
  final VoidCallback onAddDebt;
  final VoidCallback onArchive;

  const _CustomerListTile({
    required this.customer,
    required this.symbol,
    required this.onTap,
    required this.onAddDebt,
    required this.onArchive,
  });

  @override
  Widget build(BuildContext context) {
    final balance = customer.outstandingBalance;
    final isOverdue = customer.overdueTransactions > 0;

    return Slidable(
      key: ValueKey(customer.id),
      endActionPane: ActionPane(
        motion: const DrawerMotion(),
        extentRatio: 0.5,
        children: [
          SlidableAction(
            onPressed: (_) => onAddDebt(),
            backgroundColor: AppTheme.primary,
            foregroundColor: Colors.white,
            icon: Icons.add_card_outlined,
            label: 'Add Debt',
          ),
          SlidableAction(
            onPressed: (_) => onArchive(),
            backgroundColor: AppTheme.textSecondary,
            foregroundColor: Colors.white,
            icon: Icons.archive_outlined,
            label: 'Archive',
          ),
        ],
      ),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              CustomerAvatar(
                  name: customer.name,
                  photoPath: customer.photoPath,
                  radius: 24),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            customer.name,
                            style: const TextStyle(
                                fontWeight: FontWeight.w600, fontSize: 15),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (isOverdue)
                          Container(
                            margin: const EdgeInsets.only(left: 6),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppTheme.overdue
                                  .withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              'OVERDUE',
                              style: TextStyle(
                                  color: AppTheme.overdue,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      customer.phone ?? customer.customerId,
                      style: const TextStyle(
                          fontSize: 12, color: AppTheme.textSecondary),
                    ),
                    if (customer.lastPaymentDate != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        'Last paid: ${AppFormatter.date(customer.lastPaymentDate!)}',
                        style: const TextStyle(
                            fontSize: 11, color: AppTheme.textHint),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    AppFormatter.currency(balance, symbol: symbol),
                    style: TextStyle(
                      color: balance > 0
                          ? (isOverdue ? AppTheme.overdue : AppTheme.primary)
                          : AppTheme.paid,
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    balance > 0 ? 'outstanding' : 'settled',
                    style: TextStyle(
                      color: balance > 0
                          ? AppTheme.textSecondary
                          : AppTheme.paid,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 4),
              const Icon(Icons.chevron_right,
                  size: 18, color: AppTheme.textHint),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Filter Chips ─────────────────────────────────────────────────────────────

class _FilterChips extends StatelessWidget {
  final CustomerFilter current;
  final ValueChanged<CustomerFilter> onChanged;

  const _FilterChips({required this.current, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final filters = [
      (CustomerFilter.all, 'All'),
      (CustomerFilter.hasDebt, 'Has Debt'),
      (CustomerFilter.overdue, 'Overdue'),
      (CustomerFilter.paid, 'Paid'),
      (CustomerFilter.archived, 'Archived'),
    ];

    return SizedBox(
      height: 34,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: filters.length,
        separatorBuilder: (_, _) => const SizedBox(width: 6),
        itemBuilder: (context, i) {
          final (filter, label) = filters[i];
          final selected = current == filter;
          return FilterChip(
            label: Text(label),
            selected: selected,
            onSelected: (_) => onChanged(filter),
            selectedColor: Colors.white.withValues(alpha: 0.3),
            checkmarkColor: Colors.white,
            labelStyle: TextStyle(
              color: selected
                  ? Colors.white
                  : Colors.white.withValues(alpha: 0.85),
              fontSize: 12,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            ),
            backgroundColor: Colors.white.withValues(alpha: 0.08),
            side: BorderSide(
                color: selected
                    ? Colors.white.withValues(alpha: 0.8)
                    : Colors.white.withValues(alpha: 0.4),
                width: selected ? 1.5 : 1.0),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20)),
            padding:
                const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            showCheckmark: false,
          );
        },
      ),
    );
  }
}

// ─── Sort Dropdown ────────────────────────────────────────────────────────────

class _SortDropdown extends StatelessWidget {
  final CustomerSort current;
  final bool desc;
  final ValueChanged<CustomerSort> onChanged;

  const _SortDropdown(
      {required this.current, required this.desc, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<CustomerSort>(
      initialValue: current,
      onSelected: onChanged,
      itemBuilder: (_) => const [
        PopupMenuItem(value: CustomerSort.name, child: Text('Name')),
        PopupMenuItem(
            value: CustomerSort.balance, child: Text('Balance')),
        PopupMenuItem(
            value: CustomerSort.recent, child: Text('Recently Added')),
        PopupMenuItem(
            value: CustomerSort.lastPayment,
            child: Text('Last Payment')),
      ],
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Sort: ${_sortLabel(current)}',
            style: const TextStyle(
                fontSize: 12, color: AppTheme.textSecondary),
          ),
          Icon(
            desc ? Icons.arrow_downward : Icons.arrow_upward,
            size: 14,
            color: AppTheme.textSecondary,
          ),
        ],
      ),
    );
  }

  String _sortLabel(CustomerSort s) {
    switch (s) {
      case CustomerSort.name:
        return 'Name';
      case CustomerSort.balance:
        return 'Balance';
      case CustomerSort.recent:
        return 'Recent';
      case CustomerSort.lastPayment:
        return 'Last Payment';
    }
  }
}
