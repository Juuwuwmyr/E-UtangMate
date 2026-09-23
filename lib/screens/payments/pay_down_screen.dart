import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../providers/store_provider.dart';
import '../../providers/transaction_provider.dart';
import '../../core/theme.dart';
import '../../data/database/database_helper.dart';
import '../../data/models/customer_model.dart';
import '../../data/models/payment_model.dart';
import '../../data/models/transaction_model.dart';
import '../../utils/formatters.dart';

/// Lets the store owner enter one lump-sum payment that covers
/// multiple unpaid debts for the same customer at once.
class PayDownScreen extends StatefulWidget {
  final Customer customer;
  final List<DebtTransaction> unpaidTransactions;

  const PayDownScreen({
    super.key,
    required this.customer,
    required this.unpaidTransactions,
  });

  @override
  State<PayDownScreen> createState() => _PayDownScreenState();
}

class _PayDownScreenState extends State<PayDownScreen> {
  final _amountCtrl = TextEditingController();
  final _refCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  final _db = DatabaseHelper();

  PaymentMethod _method = PaymentMethod.cash;
  DateTime _paymentDate = DateTime.now();
  bool _isSaving = false;

  // Which transactions are selected
  late final List<bool> _selected;

  @override
  void initState() {
    super.initState();
    // Default: all selected
    _selected = List.filled(widget.unpaidTransactions.length, true);
    _amountCtrl.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _refCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  List<DebtTransaction> get _selectedTx => [
        for (int i = 0; i < widget.unpaidTransactions.length; i++)
          if (_selected[i]) widget.unpaidTransactions[i]
      ];

  double get _selectedTotal =>
      _selectedTx.fold(0.0, (s, t) => s + t.remainingBalance);

  double get _enteredAmount =>
      double.tryParse(_amountCtrl.text.replaceAll(',', '')) ?? 0;

  void _setPayAll() {
    _amountCtrl.text = _selectedTotal.toStringAsFixed(2);
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _paymentDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: ColorScheme.fromSeed(seedColor: AppTheme.primary),
        ),
        child: child!,
      ),
    );
    if (picked != null && mounted) setState(() => _paymentDate = picked);
  }

  Future<void> _save() async {
    if (_selectedTx.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Select at least one debt to pay down'),
          backgroundColor: AppTheme.overdue,
        ),
      );
      return;
    }

    final amount = _enteredAmount;
    if (amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Enter the payment amount'),
          backgroundColor: AppTheme.overdue,
        ),
      );
      return;
    }

    if (amount > _selectedTotal) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              'Amount exceeds selected balance (${AppFormatter.currency(_selectedTotal)})'),
          backgroundColor: AppTheme.overdue,
        ),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      // Sort oldest-first so we pay down the most overdue debts first
      final ordered = [..._selectedTx]
        ..sort((a, b) => a.transactionDate.compareTo(b.transactionDate));

      await _db.insertMultiPayment(
        customerId: widget.customer.id!,
        customerName: widget.customer.name,
        transactions: ordered,
        totalAmount: amount,
        paymentMethod: _method,
        referenceNumber:
            _refCtrl.text.trim().isEmpty ? null : _refCtrl.text.trim(),
        notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
        paymentDate: _paymentDate,
      );

      if (!mounted) return;

      // Refresh transaction list
      await context
          .read<TransactionProvider>()
          .loadTransactionsByCustomer(widget.customer.id!);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              '${AppFormatter.currency(amount)} paid across ${_selectedTx.length} debt${_selectedTx.length > 1 ? 's' : ''}'),
          backgroundColor: AppTheme.paid,
        ),
      );
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: ${e.toString()}'),
          backgroundColor: AppTheme.overdue,
        ),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final sym =
        context.select<StoreProvider, String>((p) => p.currencySymbol);
    final isFullPay = _enteredAmount >= _selectedTotal && _selectedTotal > 0;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Pay Down Debts'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Customer + total info banner
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppTheme.primary, AppTheme.primaryDark],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.person, color: Colors.white70, size: 16),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        widget.customer.name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          AppFormatter.currency(_selectedTotal, symbol: sym),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const Text('Selected balance',
                            style: TextStyle(
                                color: Colors.white70, fontSize: 12)),
                      ],
                    ),
                    Text(
                      '${_selectedTx.length} debt${_selectedTx.length != 1 ? 's' : ''}',
                      style: const TextStyle(
                          color: Colors.white70, fontSize: 13),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // Debt selection checklist
          _sectionLabel('Select Debts to Pay'),
          const SizedBox(height: 8),
          Card(
            child: Column(
              children: [
                // Select all toggle
                CheckboxListTile(
                  value: _selected.every((s) => s),
                  tristate: true,
                  onChanged: (v) {
                    setState(() {
                      final allOn = v == true;
                      for (int i = 0; i < _selected.length; i++) {
                        _selected[i] = allOn;
                      }
                    });
                  },
                  title: const Text('Select All',
                      style: TextStyle(fontWeight: FontWeight.w600)),
                  dense: true,
                  controlAffinity: ListTileControlAffinity.leading,
                  activeColor: AppTheme.primary,
                ),
                const Divider(height: 1),
                ...List.generate(widget.unpaidTransactions.length, (i) {
                  final t = widget.unpaidTransactions[i];
                  return CheckboxListTile(
                    value: _selected[i],
                    onChanged: (v) =>
                        setState(() => _selected[i] = v ?? false),
                    controlAffinity: ListTileControlAffinity.leading,
                    activeColor: AppTheme.primary,
                    dense: true,
                    title: Text(
                      t.transactionId,
                      style: const TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 13),
                    ),
                    subtitle: Text(
                      AppFormatter.date(t.transactionDate) +
                          (t.isOverdue
                              ? '  ⚠ ${AppFormatter.overdueLabel(t.daysOverdue)}'
                              : t.isDueSoon
                                  ? '  ⏰ ${AppFormatter.dueSoonLabel(t.daysUntilDue)}'
                                  : ''),
                      style: TextStyle(
                        fontSize: 11,
                        color: t.isOverdue
                            ? AppTheme.overdue
                            : AppTheme.textSecondary,
                      ),
                    ),
                    secondary: Text(
                      AppFormatter.currency(t.remainingBalance, symbol: sym),
                      style: TextStyle(
                        color: t.isOverdue
                            ? AppTheme.overdue
                            : AppTheme.primary,
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                  );
                }),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // Amount input
          _sectionLabel('Payment Amount'),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: TextField(
                  controller: _amountCtrl,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[\d\.,]'))
                  ],
                  autofocus: false,
                  style: const TextStyle(
                      fontSize: 22, fontWeight: FontWeight.w700),
                  decoration: InputDecoration(
                    hintText: '0.00',
                    prefixText: '$sym ',
                    prefixStyle: const TextStyle(
                        fontSize: 22, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: OutlinedButton(
                  onPressed: _setPayAll,
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 16),
                  ),
                  child: const Text('Pay\nAll',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 12)),
                ),
              ),
            ],
          ),

          // Distribution preview
          if (_enteredAmount > 0 && _selectedTx.isNotEmpty) ...[
            const SizedBox(height: 10),
            _DistributionPreview(
              transactions: [..._selectedTx]
                ..sort(
                    (a, b) => a.transactionDate.compareTo(b.transactionDate)),
              totalPayment: _enteredAmount,
              sym: sym,
            ),
          ],

          if (isFullPay) ...[
            const SizedBox(height: 8),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppTheme.paid.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                    color: AppTheme.paid.withValues(alpha: 0.3)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.check_circle, color: AppTheme.paid, size: 16),
                  SizedBox(width: 8),
                  Text(
                    'Full payment — all selected debts will be cleared',
                    style: TextStyle(
                        color: AppTheme.paid,
                        fontSize: 12,
                        fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 20),

          // Payment method
          _sectionLabel('Payment Method'),
          const SizedBox(height: 10),
          _MethodSelector(
            selected: _method,
            onChanged: (m) => setState(() => _method = m),
          ),

          const SizedBox(height: 20),

          // Date
          _sectionLabel('Payment Date'),
          const SizedBox(height: 8),
          GestureDetector(
            onTap: _pickDate,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: Theme.of(context).brightness == Brightness.dark
                    ? AppTheme.darkCard
                    : Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.divider),
              ),
              child: Row(
                children: [
                  const Icon(Icons.calendar_today_outlined,
                      size: 18, color: AppTheme.textSecondary),
                  const SizedBox(width: 10),
                  Text(AppFormatter.date(_paymentDate)),
                  const Spacer(),
                  const Icon(Icons.edit_outlined,
                      size: 16, color: AppTheme.textHint),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Reference (for non-cash)
          if (_method != PaymentMethod.cash) ...[
            _sectionLabel('Reference Number'),
            const SizedBox(height: 8),
            TextField(
              controller: _refCtrl,
              textCapitalization: TextCapitalization.characters,
              decoration: const InputDecoration(
                hintText: 'Reference number',
                prefixIcon: Icon(Icons.tag_outlined),
              ),
            ),
            const SizedBox(height: 16),
          ],

          // Notes
          _sectionLabel('Notes (optional)'),
          const SizedBox(height: 8),
          TextField(
            controller: _notesCtrl,
            maxLines: 2,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              hintText: 'e.g. partial payment for multiple debts',
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
                backgroundColor:
                    isFullPay ? AppTheme.paid : AppTheme.primary,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: _isSaving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : Text(
                      _enteredAmount > 0
                          ? 'Record ${AppFormatter.currency(_enteredAmount, symbol: sym)}'
                          : 'Record Payment',
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w700),
                      overflow: TextOverflow.ellipsis,
                    ),
            ),
          ),

          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _sectionLabel(String text) => Text(
        text.toUpperCase(),
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: AppTheme.textSecondary,
          letterSpacing: 0.8,
        ),
      );
}

// ─── Distribution Preview ─────────────────────────────────────────────────────

class _DistributionPreview extends StatelessWidget {
  final List<DebtTransaction> transactions;
  final double totalPayment;
  final String sym;

  const _DistributionPreview({
    required this.transactions,
    required this.totalPayment,
    required this.sym,
  });

  @override
  Widget build(BuildContext context) {
    // Simulate how the payment is distributed oldest-first
    double remaining = totalPayment;
    final rows = <(DebtTransaction, double, double)>[];
    for (final t in transactions) {
      if (remaining <= 0) break;
      final apply =
          remaining >= t.remainingBalance ? t.remainingBalance : remaining;
      remaining -= apply;
      final newBal = t.remainingBalance - apply;
      rows.add((t, apply, newBal));
    }

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.primary.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(10),
        border:
            Border.all(color: AppTheme.primary.withValues(alpha: 0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(12, 10, 12, 6),
            child: Text(
              'HOW IT WILL BE APPLIED',
              style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textSecondary,
                  letterSpacing: 0.8),
            ),
          ),
          const Divider(height: 1),
          ...rows.map((r) {
            final (tx, applied, newBal) = r;
            return Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(tx.transactionId,
                            style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 12)),
                        Text(
                          '${AppFormatter.currency(tx.remainingBalance, symbol: sym)} → '
                          '${AppFormatter.currency(newBal, symbol: sym)}',
                          style: TextStyle(
                            fontSize: 11,
                            color: newBal <= 0
                                ? AppTheme.paid
                                : AppTheme.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '- ${AppFormatter.currency(applied, symbol: sym)}',
                        style: const TextStyle(
                            color: AppTheme.paid,
                            fontWeight: FontWeight.w700,
                            fontSize: 13),
                      ),
                      if (newBal <= 0)
                        const Text('Cleared ✓',
                            style: TextStyle(
                                fontSize: 10, color: AppTheme.paid)),
                    ],
                  ),
                ],
              ),
            );
          }),
          if (remaining > 0) ...[
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(10),
              child: Text(
                '${AppFormatter.currency(remaining, symbol: sym)} unused (exceeds selected balance)',
                style: const TextStyle(
                    fontSize: 11, color: AppTheme.overdue),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ─── Method Selector ──────────────────────────────────────────────────────────

class _MethodSelector extends StatelessWidget {
  final PaymentMethod selected;
  final ValueChanged<PaymentMethod> onChanged;

  const _MethodSelector(
      {required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final methods = [
      (PaymentMethod.cash, Icons.money_outlined, 'Cash'),
      (PaymentMethod.gcash, Icons.phone_android_outlined, 'GCash'),
      (PaymentMethod.bankTransfer, Icons.account_balance_outlined, 'Bank'),
      (PaymentMethod.other, Icons.more_horiz_outlined, 'Other'),
    ];
    return Row(
      children: methods.map((m) {
        final (method, icon, label) = m;
        final isSel = selected == method;
        return Expanded(
          child: Padding(
            padding: const EdgeInsets.only(right: 6),
            child: GestureDetector(
              onTap: () => onChanged(method),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: isSel
                      ? AppTheme.primary
                      : AppTheme.primary.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isSel ? AppTheme.primary : AppTheme.divider,
                  ),
                ),
                child: Column(
                  children: [
                    Icon(icon,
                        size: 20,
                        color: isSel
                            ? Colors.white
                            : AppTheme.textSecondary),
                    const SizedBox(height: 4),
                    Text(label,
                        style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: isSel
                                ? Colors.white
                                : AppTheme.textSecondary)),
                  ],
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}
