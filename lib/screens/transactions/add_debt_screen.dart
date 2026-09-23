import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../providers/transaction_provider.dart';
import '../../providers/store_provider.dart';
import '../../core/theme.dart';
import '../../data/database/database_helper.dart';
import '../../data/models/transaction_model.dart';
import '../../data/models/customer_model.dart';
import '../../utils/formatters.dart';
import '../../utils/validators.dart';
import '../../widgets/confirm_dialog.dart';

class AddDebtScreen extends StatefulWidget {
  final int? customerId;
  final String? customerName;

  const AddDebtScreen({super.key, this.customerId, this.customerName});

  @override
  State<AddDebtScreen> createState() => _AddDebtScreenState();
}

class _AddDebtScreenState extends State<AddDebtScreen> {
  final _formKey = GlobalKey<FormState>();
  final _db = DatabaseHelper();

  // Customer selection
  Customer? _selectedCustomer;
  final _customerSearchCtrl = TextEditingController();
  List<Customer> _customerResults = [];
  bool _showDropdown = false;
  bool _isSearching = false;

  // Transaction fields
  DateTime _transactionDate = DateTime.now();
  DateTime? _dueDate;
  final _notesCtrl = TextEditingController();

  // Items
  final List<_ItemEntry> _items = [];
  bool _isSaving = false;

  double get _total => _items.fold(0.0, (s, i) => s + i.price);

  @override
  void initState() {
    super.initState();
    if (widget.customerId != null) {
      _loadPreSelectedCustomer();
    } else {
      _items.add(_ItemEntry());
    }
  }

  Future<void> _loadPreSelectedCustomer() async {
    final customer = await _db.getCustomerById(widget.customerId!);
    if (mounted) {
      setState(() {
        _selectedCustomer = customer;
        _items.add(_ItemEntry());
      });
    }
  }

  Future<void> _searchCustomers(String query) async {
    if (query.trim().isEmpty) {
      setState(() {
        _customerResults = [];
        _showDropdown = false;
        _isSearching = false;
      });
      return;
    }
    setState(() => _isSearching = true);
    final results = await _db.getCustomers(query: query.trim());
    if (!mounted) return;
    setState(() {
      _customerResults = results.take(6).toList();
      _showDropdown = _customerResults.isNotEmpty;
      _isSearching = false;
    });
  }

  void _selectCustomer(Customer c) {
    setState(() {
      _selectedCustomer = c;
      _customerSearchCtrl.text = c.name;
      _showDropdown = false;
      _customerResults = [];
    });
    FocusScope.of(context).unfocus();
  }

  Future<void> _pickDate(bool isDue) async {
    final now = DateTime.now();
    final initial = isDue
        ? (_dueDate ?? now.add(const Duration(days: 30)))
        : _transactionDate;

    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: isDue ? now : DateTime(2020),
      lastDate: DateTime(2100),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: ColorScheme.fromSeed(seedColor: AppTheme.primary),
        ),
        child: child!,
      ),
    );
    if (picked != null && mounted) {
      setState(() {
        if (isDue) {
          _dueDate = picked;
        } else {
          _transactionDate = picked;
        }
      });
    }
  }

  Future<void> _save() async {
    if (_selectedCustomer == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a customer first'),
          backgroundColor: AppTheme.overdue,
        ),
      );
      return;
    }

    final validItems = _items.where((i) => i.isValid).toList();
    if (validItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Add at least one item with a name and price'),
          backgroundColor: AppTheme.overdue,
        ),
      );
      return;
    }

    if (!_formKey.currentState!.validate()) return;

    final txProvider = context.read<TransactionProvider>();
    final customer = _selectedCustomer!;

    // Credit limit check
    if (customer.creditLimit != null) {
      final newBalance = customer.outstandingBalance + _total;
      if (newBalance > customer.creditLimit!) {
        if (!mounted) return;
        final confirm = await ConfirmDialog.show(
          context,
          title: 'Credit Limit Exceeded',
          message: 'Limit: ${AppFormatter.currency(customer.creditLimit!)}\n'
              'New balance: ${AppFormatter.currency(newBalance)}\n'
              'Over by: ${AppFormatter.currency(newBalance - customer.creditLimit!)}\n\n'
              'Continue anyway?',
          confirmLabel: 'Continue',
          isDangerous: true,
          icon: Icons.warning_amber_outlined,
        );
        if (confirm != true) return;
      }
    }

    setState(() => _isSaving = true);

    final now = DateTime.now();
    final transaction = DebtTransaction(
      transactionId: '',
      customerId: customer.id!,
      customerName: customer.name,
      totalAmount: _total,
      remainingBalance: _total,
      status: TransactionStatus.unpaid,
      transactionDate: _transactionDate,
      dueDate: _dueDate,
      notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
      createdAt: now,
      updatedAt: now,
    );

    // quantity=1, unit='pcs' as defaults since we removed those fields
    final items = validItems
        .map((i) => TransactionItem(
              itemName: i.nameCtrl.text.trim(),
              quantity: 1,
              unit: 'pcs',
              pricePerUnit: i.price,
              totalPrice: i.price,
            ))
        .toList();

    final result = await txProvider.addTransaction(transaction, items);

    if (!mounted) return;
    setState(() => _isSaving = false);

    if (result != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              'Saved! ${AppFormatter.currency(_total)} for ${customer.name}'),
          backgroundColor: AppTheme.paid,
        ),
      );
      Navigator.of(context).pop(result);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(txProvider.error ?? 'Failed to save. Try again.'),
          backgroundColor: AppTheme.overdue,
        ),
      );
    }
  }

  @override
  void dispose() {
    _customerSearchCtrl.dispose();
    _notesCtrl.dispose();
    for (final item in _items) {
      item.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sym = context.select<StoreProvider, String>((p) => p.currencySymbol);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Add Debt'),
        actions: [
          if (_isSaving)
            const Padding(
              padding: EdgeInsets.all(16),
              child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white)),
            )
          else
            TextButton(
              onPressed: _save,
              child: const Text('Save',
                  style: TextStyle(
                      color: Colors.white, fontWeight: FontWeight.w600)),
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // ── Customer ──────────────────────────────────────────────
            const _Label('Customer'),
            const SizedBox(height: 8),
            if (widget.customerId != null)
              _selectedCustomer != null
                  ? _CustomerBanner(customer: _selectedCustomer!)
                  : Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppTheme.primary.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: AppTheme.primary.withValues(alpha: 0.2)),
                      ),
                      child: const Row(
                        children: [
                          SizedBox(
                              width: 16,
                              height: 16,
                              child:
                                  CircularProgressIndicator(strokeWidth: 2)),
                          SizedBox(width: 10),
                          Text('Loading customer...'),
                        ],
                      ),
                    )
            else ...[
              TextFormField(
                controller: _customerSearchCtrl,
                onChanged: _searchCustomers,
                decoration: InputDecoration(
                  hintText: 'Search customer by name...',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _isSearching
                      ? const Padding(
                          padding: EdgeInsets.all(12),
                          child: SizedBox(
                              width: 16,
                              height: 16,
                              child:
                                  CircularProgressIndicator(strokeWidth: 2)),
                        )
                      : _selectedCustomer != null
                          ? const Icon(Icons.check_circle,
                              color: AppTheme.paid)
                          : null,
                ),
              ),
              if (_selectedCustomer != null) ...[
                const SizedBox(height: 6),
                _CustomerBanner(customer: _selectedCustomer!),
              ],
              if (_showDropdown)
                Card(
                  margin: const EdgeInsets.only(top: 4),
                  child: Column(
                    children: _customerResults
                        .map((c) => ListTile(
                              dense: true,
                              leading: CircleAvatar(
                                radius: 16,
                                backgroundColor:
                                    AppTheme.primary.withValues(alpha: 0.1),
                                child: Text(c.name[0].toUpperCase(),
                                    style: const TextStyle(
                                        color: AppTheme.primary,
                                        fontWeight: FontWeight.w700,
                                        fontSize: 13)),
                              ),
                              title: Text(c.name,
                                  overflow: TextOverflow.ellipsis),
                              subtitle: Text(c.customerId,
                                  overflow: TextOverflow.ellipsis),
                              trailing: c.outstandingBalance > 0
                                  ? Text(
                                      AppFormatter.currency(
                                          c.outstandingBalance,
                                          symbol: sym),
                                      style: const TextStyle(
                                          color: AppTheme.overdue,
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600),
                                    )
                                  : null,
                              onTap: () => _selectCustomer(c),
                            ))
                        .toList(),
                  ),
                ),
            ],

            const SizedBox(height: 20),

            // ── Dates ─────────────────────────────────────────────────
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const _Label('Date'),
                      const SizedBox(height: 6),
                      _DateField(
                        date: _transactionDate,
                        onTap: () => _pickDate(false),
                        icon: Icons.calendar_today_outlined,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const _Label('Due Date (optional)'),
                      const SizedBox(height: 6),
                      _DateField(
                        date: _dueDate,
                        onTap: () => _pickDate(true),
                        icon: Icons.event_outlined,
                        placeholder: 'None',
                        onClear: _dueDate != null
                            ? () => setState(() => _dueDate = null)
                            : null,
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),

            // ── Items ─────────────────────────────────────────────────
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const _Label('Items'),
                TextButton.icon(
                  onPressed: () => setState(() => _items.add(_ItemEntry())),
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('Add Item'),
                  style: TextButton.styleFrom(
                      padding: EdgeInsets.zero,
                      visualDensity: VisualDensity.compact),
                ),
              ],
            ),
            const SizedBox(height: 8),

            ..._items.asMap().entries.map((e) => _ItemRow(
                  key: ValueKey(e.key),
                  entry: e.value,
                  index: e.key,
                  symbol: sym,
                  canDelete: _items.length > 1,
                  onDelete: () => setState(() => _items.removeAt(e.key)),
                  onChanged: () => setState(() {}),
                )),

            // ── Total ─────────────────────────────────────────────────
            Container(
              margin: const EdgeInsets.only(top: 4),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: AppTheme.primary.withValues(alpha: 0.07),
                borderRadius: BorderRadius.circular(12),
                border:
                    Border.all(color: AppTheme.primary.withValues(alpha: 0.2)),
              ),
              child: Row(
                children: [
                  const Text('Total',
                      style: TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w600)),
                  const Spacer(),
                  Text(
                    AppFormatter.currency(_total, symbol: sym),
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.primary,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // ── Notes ─────────────────────────────────────────────────
            const _Label('Notes (optional)'),
            const SizedBox(height: 6),
            TextFormField(
              controller: _notesCtrl,
              maxLines: 2,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                hintText: 'e.g. bought on credit for fiesta',
                prefixIcon: Icon(Icons.notes_outlined),
                alignLabelWithHint: true,
              ),
            ),

            const SizedBox(height: 28),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isSaving ? null : _save,
                style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16)),
                child: _isSaving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : Text(
                        _total > 0
                            ? 'Save  ${AppFormatter.currency(_total, symbol: sym)}'
                            : 'Save Debt',
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w700),
                        overflow: TextOverflow.ellipsis,
                      ),
              ),
            ),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}

// ─── Customer Banner ──────────────────────────────────────────────────────────

class _CustomerBanner extends StatelessWidget {
  final Customer customer;
  const _CustomerBanner({required this.customer});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.primary.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.person, color: AppTheme.primary, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              customer.name,
              style: const TextStyle(
                  fontWeight: FontWeight.w600, fontSize: 15),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (customer.outstandingBalance > 0) ...[
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  AppFormatter.currency(customer.outstandingBalance),
                  style: const TextStyle(
                      color: AppTheme.overdue,
                      fontWeight: FontWeight.w700,
                      fontSize: 12),
                ),
                const Text('balance',
                    style:
                        TextStyle(fontSize: 10, color: AppTheme.textHint)),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

// ─── Date Field ───────────────────────────────────────────────────────────────

class _DateField extends StatelessWidget {
  final DateTime? date;
  final VoidCallback onTap;
  final IconData icon;
  final String? placeholder;
  final VoidCallback? onClear;

  const _DateField({
    required this.date,
    required this.onTap,
    required this.icon,
    this.placeholder,
    this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 13),
        decoration: BoxDecoration(
          color: Theme.of(context).brightness == Brightness.dark
              ? AppTheme.darkCard
              : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.divider),
        ),
        child: Row(
          children: [
            Icon(icon, size: 16, color: AppTheme.textSecondary),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                date != null
                    ? AppFormatter.shortDate(date!)
                    : (placeholder ?? 'Select'),
                style: TextStyle(
                  fontSize: 12,
                  color: date != null ? null : AppTheme.textHint,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (onClear != null)
              GestureDetector(
                onTap: onClear,
                child: const Icon(Icons.close,
                    size: 14, color: AppTheme.textSecondary),
              ),
          ],
        ),
      ),
    );
  }
}

// ─── Section Label ────────────────────────────────────────────────────────────

class _Label extends StatelessWidget {
  final String text;
  const _Label(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        color: AppTheme.textSecondary,
        letterSpacing: 0.8,
      ),
    );
  }
}

// ─── Item Entry ───────────────────────────────────────────────────────────────

class _ItemEntry {
  final nameCtrl = TextEditingController();
  final priceCtrl = TextEditingController();

  double get price =>
      double.tryParse(priceCtrl.text.replaceAll(',', '')) ?? 0;

  bool get isValid =>
      nameCtrl.text.trim().isNotEmpty && price > 0;

  void dispose() {
    nameCtrl.dispose();
    priceCtrl.dispose();
  }
}

// ─── Item Row ─────────────────────────────────────────────────────────────────

class _ItemRow extends StatelessWidget {
  final _ItemEntry entry;
  final int index;
  final String symbol;
  final bool canDelete;
  final VoidCallback onDelete;
  final VoidCallback onChanged;

  const _ItemRow({
    super.key,
    required this.entry,
    required this.index,
    required this.symbol,
    required this.canDelete,
    required this.onDelete,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row
            Row(
              children: [
                Text('Item ${index + 1}',
                    style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textSecondary)),
                const Spacer(),
                if (canDelete)
                  GestureDetector(
                    onTap: onDelete,
                    child: const Icon(Icons.remove_circle_outline,
                        color: AppTheme.overdue, size: 18),
                  ),
              ],
            ),
            const SizedBox(height: 6),

            // Name + Price side by side
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Item name
                Expanded(
                  flex: 3,
                  child: TextFormField(
                    controller: entry.nameCtrl,
                    textCapitalization: TextCapitalization.sentences,
                    onChanged: (_) => onChanged(),
                    decoration: const InputDecoration(
                      hintText: 'Item name',
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(
                          horizontal: 10, vertical: 11),
                    ),
                    validator: (v) =>
                        v == null || v.trim().isEmpty ? 'Required' : null,
                  ),
                ),
                const SizedBox(width: 8),

                // Price
                Expanded(
                  flex: 2,
                  child: TextFormField(
                    controller: entry.priceCtrl,
                    keyboardType: const TextInputType.numberWithOptions(
                        decimal: true),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[\d\.,]'))
                    ],
                    onChanged: (_) => onChanged(),
                    decoration: InputDecoration(
                      hintText: 'Price',
                      prefixText: '$symbol ',
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 11),
                    ),
                    validator: AppValidators.amount,
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
