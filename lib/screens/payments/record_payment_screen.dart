import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../providers/payment_provider.dart';
import '../../providers/store_provider.dart';
import '../../core/theme.dart';
import '../../data/models/payment_model.dart';
import '../../utils/formatters.dart';
import '../../utils/validators.dart';

class RecordPaymentScreen extends StatefulWidget {
  final int transactionId;
  final int customerId;
  final String customerName;
  final String txTransactionId;
  final double remainingBalance;

  const RecordPaymentScreen({
    super.key,
    required this.transactionId,
    required this.customerId,
    required this.customerName,
    required this.txTransactionId,
    required this.remainingBalance,
  });

  @override
  State<RecordPaymentScreen> createState() =>
      _RecordPaymentScreenState();
}

class _RecordPaymentScreenState extends State<RecordPaymentScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amountCtrl = TextEditingController();
  final _refCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();

  PaymentMethod _method = PaymentMethod.cash;
  DateTime _paymentDate = DateTime.now();
  bool _isSaving = false;
  bool _isFullPayment = false;

  @override
  void initState() {
    super.initState();
    _amountCtrl.addListener(_onAmountChanged);
  }

  void _onAmountChanged() {
    final val =
        double.tryParse(_amountCtrl.text.replaceAll(',', '')) ?? 0;
    setState(() {
      _isFullPayment = val >= widget.remainingBalance;
    });
  }

  void _setFullPayment() {
    _amountCtrl.text =
        widget.remainingBalance.toStringAsFixed(2);
    setState(() => _isFullPayment = true);
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
    if (picked != null && mounted) {
      setState(() => _paymentDate = picked);
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();

    final amount =
        double.parse(_amountCtrl.text.replaceAll(',', ''));

    // Prevent overpayment
    if (amount > widget.remainingBalance) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              'Payment (${AppFormatter.currency(amount)}) exceeds remaining balance (${AppFormatter.currency(widget.remainingBalance)})'),
          backgroundColor: AppTheme.overdue,
        ),
      );
      return;
    }

    setState(() => _isSaving = true);

    final now = DateTime.now();
    final payment = Payment(
      paymentId: '',
      transactionId: widget.transactionId,
      customerId: widget.customerId,
      customerName: widget.customerName,
      txTransactionId: widget.txTransactionId,
      amount: amount,
      paymentMethod: _method,
      referenceNumber: _refCtrl.text.trim().isEmpty
          ? null
          : _refCtrl.text.trim(),
      notes:
          _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
      paymentDate: _paymentDate,
      createdAt: now,
    );

    final result =
        await context.read<PaymentProvider>().addPayment(payment);

    if (!mounted) return;
    setState(() => _isSaving = false);

    if (result != null) {
      final newBalance = widget.remainingBalance - amount;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(newBalance <= 0
              ? '✓ Full payment recorded. Debt cleared!'
              : '✓ Payment of ${AppFormatter.currency(amount)} recorded. Remaining: ${AppFormatter.currency(newBalance)}'),
          backgroundColor: AppTheme.paid,
          duration: const Duration(seconds: 4),
        ),
      );
      Navigator.of(context).pop(result);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              context.read<PaymentProvider>().error ?? 'Failed to save payment'),
          backgroundColor: AppTheme.overdue,
        ),
      );
    }
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _refCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sym =
        context.select<StoreProvider, String>((p) => p.currencySymbol);
    final enteredAmount =
        double.tryParse(_amountCtrl.text.replaceAll(',', '')) ?? 0;
    final newBalance = (widget.remainingBalance - enteredAmount)
        .clamp(0.0, widget.remainingBalance);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Record Payment'),
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
            // Transaction info banner
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [AppTheme.primary, AppTheme.primaryDark],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      const Icon(Icons.person, color: Colors.white70, size: 18),
                      const SizedBox(width: 8),
                      Text(
                        widget.customerName,
                        style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 16),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Icon(Icons.receipt_outlined,
                          color: Colors.white70, size: 16),
                      const SizedBox(width: 8),
                      Text(
                        widget.txTransactionId,
                        style: const TextStyle(
                            color: Colors.white70, fontSize: 13),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Remaining Balance',
                              style: TextStyle(
                                  color: Colors.white70, fontSize: 12)),
                          Text(
                            AppFormatter.currency(widget.remainingBalance,
                                symbol: sym),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              fontFeatures: [FontFeature.tabularFigures()],
                            ),
                          ),
                        ],
                      ),
                      if (enteredAmount > 0)
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            const Text('After Payment',
                                style: TextStyle(
                                    color: Colors.white70, fontSize: 12)),
                            Text(
                              AppFormatter.currency(newBalance, symbol: sym),
                              style: TextStyle(
                                color: newBalance <= 0
                                    ? Colors.greenAccent
                                    : Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                  if (_isFullPayment && enteredAmount > 0) ...[
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.greenAccent.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                            color: Colors.greenAccent.withValues(alpha: 0.5)),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.check_circle,
                              color: Colors.greenAccent, size: 16),
                          SizedBox(width: 6),
                          Text('Full payment — Debt will be cleared',
                              style: TextStyle(
                                  color: Colors.greenAccent,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Amount
            const _SectionLabel('Payment Amount'),
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _amountCtrl,
                    keyboardType: const TextInputType.numberWithOptions(
                        decimal: true),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(
                          RegExp(r'[\d\.,]'))
                    ],
                    autofocus: true,
                    style: const TextStyle(
                        fontSize: 22, fontWeight: FontWeight.w700),
                    decoration: InputDecoration(
                      hintText: '0.00',
                      prefixText: '$sym ',
                      prefixStyle: const TextStyle(
                          fontSize: 22, fontWeight: FontWeight.w700),
                    ),
                    validator: (v) => AppValidators.amount(v,
                        max: widget.remainingBalance),
                  ),
                ),
                const SizedBox(width: 10),
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: OutlinedButton(
                    onPressed: _setFullPayment,
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 16),
                    ),
                    child: const Text('Full\nPayment',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 12)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Payment method
            const _SectionLabel('Payment Method'),
            const SizedBox(height: 10),
            _PaymentMethodSelector(
              selected: _method,
              onChanged: (m) => setState(() => _method = m),
            ),
            const SizedBox(height: 20),

            // Payment date
            const _SectionLabel('Payment Date'),
            const SizedBox(height: 8),
            GestureDetector(
              onTap: _pickDate,
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 14),
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
            const SizedBox(height: 20),

            // Reference number (GCash, Bank Transfer)
            if (_method != PaymentMethod.cash) ...[
              const _SectionLabel('Reference Number'),
              const SizedBox(height: 8),
              TextFormField(
                controller: _refCtrl,
                keyboardType: TextInputType.text,
                textCapitalization: TextCapitalization.characters,
                decoration: InputDecoration(
                  hintText:
                      _method == PaymentMethod.gcash
                          ? 'GCash reference number'
                          : 'Bank transaction reference',
                  prefixIcon: const Icon(Icons.tag_outlined),
                ),
              ),
              const SizedBox(height: 20),
            ],

            // Notes
            const _SectionLabel('Notes (optional)'),
            const SizedBox(height: 8),
            TextFormField(
              controller: _notesCtrl,
              maxLines: 2,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                hintText: 'e.g. Payment received in person',
                prefixIcon: Icon(Icons.notes_outlined),
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 32),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isSaving ? null : _save,
                icon: _isSaving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.payments_outlined),
                label: Text(
                  enteredAmount > 0
                      ? 'Record ${AppFormatter.currency(enteredAmount, symbol: sym)} Payment'
                      : 'Record Payment',
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor:
                      _isFullPayment ? AppTheme.paid : AppTheme.primary,
                  padding: const EdgeInsets.symmetric(vertical: 16),
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

// ─── Payment Method Selector ──────────────────────────────────────────────────

class _PaymentMethodSelector extends StatelessWidget {
  final PaymentMethod selected;
  final ValueChanged<PaymentMethod> onChanged;

  const _PaymentMethodSelector(
      {required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final methods = [
      (PaymentMethod.cash, Icons.money_outlined, 'Cash'),
      (PaymentMethod.gcash, Icons.phone_android_outlined, 'GCash'),
      (PaymentMethod.bankTransfer, Icons.account_balance_outlined,
          'Bank Transfer'),
      (PaymentMethod.other, Icons.more_horiz_outlined, 'Other'),
    ];

    return Row(
      children: methods.map((m) {
        final (method, icon, label) = m;
        final isSelected = selected == method;
        return Expanded(
          child: Padding(
            padding: const EdgeInsets.only(right: 6),
            child: GestureDetector(
              onTap: () => onChanged(method),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppTheme.primary
                      : AppTheme.primary.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isSelected
                        ? AppTheme.primary
                        : AppTheme.divider,
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      icon,
                      size: 20,
                      color: isSelected
                          ? Colors.white
                          : AppTheme.textSecondary,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: isSelected
                            ? Colors.white
                            : AppTheme.textSecondary,
                      ),
                      textAlign: TextAlign.center,
                    ),
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

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

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
