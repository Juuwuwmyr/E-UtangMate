import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';

import '../../providers/customer_provider.dart';
import '../../core/theme.dart';
import '../../data/models/customer_model.dart';
import '../../utils/validators.dart';
import '../../widgets/confirm_dialog.dart';
import '../../widgets/customer_avatar.dart';

class AddEditCustomerScreen extends StatefulWidget {
  final Customer? customer; // null = adding new

  const AddEditCustomerScreen({super.key, this.customer});

  @override
  State<AddEditCustomerScreen> createState() =>
      _AddEditCustomerScreenState();
}

class _AddEditCustomerScreenState extends State<AddEditCustomerScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameFocus = FocusNode();
  final _phoneFocus = FocusNode();
  final _addressFocus = FocusNode();
  final _emailFocus = FocusNode();
  final _notesFocus = FocusNode();
  final _limitFocus = FocusNode();

  late final TextEditingController _nameCtrl;
  late final TextEditingController _phoneCtrl;
  late final TextEditingController _addressCtrl;
  late final TextEditingController _emailCtrl;
  late final TextEditingController _notesCtrl;
  late final TextEditingController _limitCtrl;

  String? _photoPath;
  bool _isSaving = false;

  bool get _isEditing => widget.customer != null;

  @override
  void initState() {
    super.initState();
    final c = widget.customer;
    _nameCtrl = TextEditingController(text: c?.name ?? '');
    _phoneCtrl = TextEditingController(text: c?.phone ?? '');
    _addressCtrl = TextEditingController(text: c?.address ?? '');
    _emailCtrl = TextEditingController(text: c?.email ?? '');
    _notesCtrl = TextEditingController(text: c?.notes ?? '');
    _limitCtrl = TextEditingController(
        text: c?.creditLimit?.toStringAsFixed(2) ?? '');
    _photoPath = c?.photoPath;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _addressCtrl.dispose();
    _emailCtrl.dispose();
    _notesCtrl.dispose();
    _limitCtrl.dispose();
    _nameFocus.dispose();
    _phoneFocus.dispose();
    _addressFocus.dispose();
    _emailFocus.dispose();
    _notesFocus.dispose();
    _limitFocus.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto(ImageSource source) async {
    Navigator.of(context).pop();
    try {
      final picker = ImagePicker();
      final file = await picker.pickImage(
          source: source, maxWidth: 512, maxHeight: 512, imageQuality: 85);
      if (file != null) {
        setState(() => _photoPath = file.path);
      }
    } catch (_) {}
  }

  void _showPhotoOptions() {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined),
              title: const Text('Take a photo'),
              onTap: () => _pickPhoto(ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Choose from gallery'),
              onTap: () => _pickPhoto(ImageSource.gallery),
            ),
            if (_photoPath != null)
              ListTile(
                leading: const Icon(Icons.delete_outline,
                    color: AppTheme.overdue),
                title: const Text('Remove photo',
                    style: TextStyle(color: AppTheme.overdue)),
                onTap: () {
                  setState(() => _photoPath = null);
                  Navigator.of(ctx).pop();
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

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();

    setState(() => _isSaving = true);

    final provider = context.read<CustomerProvider>();
    final now = DateTime.now();

    final customer = Customer(
      id: widget.customer?.id,
      customerId: widget.customer?.customerId ?? '',
      name: _nameCtrl.text.trim(),
      phone: _phoneCtrl.text.trim().isEmpty ? null : _phoneCtrl.text.trim(),
      address:
          _addressCtrl.text.trim().isEmpty ? null : _addressCtrl.text.trim(),
      email: _emailCtrl.text.trim().isEmpty ? null : _emailCtrl.text.trim(),
      photoPath: _photoPath,
      notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
      creditLimit: _limitCtrl.text.trim().isEmpty
          ? null
          : double.tryParse(_limitCtrl.text.replaceAll(',', '')),
      createdAt: widget.customer?.createdAt ?? now,
      updatedAt: now,
    );

    bool success;
    if (_isEditing) {
      success = await provider.updateCustomer(customer);
    } else {
      final result = await provider.addCustomer(customer);
      success = result != null;
    }

    if (!mounted) return;
    setState(() => _isSaving = false);

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_isEditing
              ? 'Customer updated successfully'
              : 'Customer added successfully'),
          backgroundColor: AppTheme.paid,
        ),
      );
      Navigator.of(context).pop(true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(provider.error ?? 'Something went wrong'),
          backgroundColor: AppTheme.overdue,
        ),
      );
    }
  }

  Future<bool> _onWillPop() async {
    if (_nameCtrl.text.isNotEmpty ||
        _phoneCtrl.text.isNotEmpty ||
        _addressCtrl.text.isNotEmpty) {
      final confirm = await ConfirmDialog.show(
        context,
        title: 'Discard Changes?',
        message: 'You have unsaved changes. Are you sure you want to go back?',
        confirmLabel: 'Discard',
        isDangerous: true,
      );
      return confirm == true;
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        if (await _onWillPop()) {
          if (!mounted) return;
          // ignore: use_build_context_synchronously
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(_isEditing ? 'Edit Customer' : 'New Customer'),
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
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Photo
                Center(
                  child: Stack(
                    children: [
                      GestureDetector(
                        onTap: _showPhotoOptions,
                        child: CustomerAvatar(
                            name: _nameCtrl.text.isEmpty
                                ? '?'
                                : _nameCtrl.text,
                            photoPath: _photoPath,
                            radius: 44),
                      ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: GestureDetector(
                          onTap: _showPhotoOptions,
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: AppTheme.primary,
                              shape: BoxShape.circle,
                              border: Border.all(
                                  color: Colors.white, width: 2),
                            ),
                            child: const Icon(Icons.camera_alt,
                                size: 14, color: Colors.white),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 28),

                _SectionLabel('Basic Information'),
                const SizedBox(height: 12),

                // Name
                TextFormField(
                  controller: _nameCtrl,
                  focusNode: _nameFocus,
                  textInputAction: TextInputAction.next,
                  textCapitalization: TextCapitalization.words,
                  onChanged: (_) => setState(() {}),
                  onFieldSubmitted: (_) =>
                      FocusScope.of(context).requestFocus(_phoneFocus),
                  decoration: const InputDecoration(
                    labelText: 'Full Name *',
                    prefixIcon: Icon(Icons.person_outline),
                    hintText: 'e.g. Juan Dela Cruz',
                  ),
                  validator: (v) =>
                      AppValidators.required(v, 'Full name'),
                ),
                const SizedBox(height: 16),

                // Phone
                TextFormField(
                  controller: _phoneCtrl,
                  focusNode: _phoneFocus,
                  textInputAction: TextInputAction.next,
                  keyboardType: TextInputType.phone,
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(
                        RegExp(r'[\d\+\-\(\)\s]'))
                  ],
                  onFieldSubmitted: (_) =>
                      FocusScope.of(context).requestFocus(_addressFocus),
                  decoration: const InputDecoration(
                    labelText: 'Phone Number',
                    prefixIcon: Icon(Icons.phone_outlined),
                    hintText: '09XX XXX XXXX',
                  ),
                  validator: AppValidators.phone,
                ),
                const SizedBox(height: 16),

                // Address
                TextFormField(
                  controller: _addressCtrl,
                  focusNode: _addressFocus,
                  textInputAction: TextInputAction.next,
                  textCapitalization: TextCapitalization.sentences,
                  maxLines: 2,
                  onFieldSubmitted: (_) =>
                      FocusScope.of(context).requestFocus(_emailFocus),
                  decoration: const InputDecoration(
                    labelText: 'Address',
                    prefixIcon: Icon(Icons.home_outlined),
                    hintText: 'Street, Barangay, City',
                    alignLabelWithHint: true,
                  ),
                ),
                const SizedBox(height: 16),

                // Email
                TextFormField(
                  controller: _emailCtrl,
                  focusNode: _emailFocus,
                  textInputAction: TextInputAction.next,
                  keyboardType: TextInputType.emailAddress,
                  onFieldSubmitted: (_) =>
                      FocusScope.of(context).requestFocus(_limitFocus),
                  decoration: const InputDecoration(
                    labelText: 'Email',
                    prefixIcon: Icon(Icons.email_outlined),
                    hintText: 'optional',
                  ),
                  validator: AppValidators.email,
                ),
                const SizedBox(height: 24),

                _SectionLabel('Credit Settings'),
                const SizedBox(height: 12),

                // Credit limit
                TextFormField(
                  controller: _limitCtrl,
                  focusNode: _limitFocus,
                  textInputAction: TextInputAction.next,
                  keyboardType: const TextInputType.numberWithOptions(
                      decimal: true),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(
                        RegExp(r'[\d\.,]'))
                  ],
                  onFieldSubmitted: (_) =>
                      FocusScope.of(context).requestFocus(_notesFocus),
                  decoration: const InputDecoration(
                    labelText: 'Credit Limit',
                    prefixIcon: Icon(Icons.credit_card_outlined),
                    prefixText: '₱ ',
                    hintText: 'Leave blank for no limit',
                  ),
                ),
                const SizedBox(height: 24),

                _SectionLabel('Notes'),
                const SizedBox(height: 12),

                // Notes
                TextFormField(
                  controller: _notesCtrl,
                  focusNode: _notesFocus,
                  textInputAction: TextInputAction.done,
                  textCapitalization: TextCapitalization.sentences,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Notes',
                    prefixIcon: Icon(Icons.notes_outlined),
                    hintText: 'Any additional info about this customer',
                    alignLabelWithHint: true,
                  ),
                ),

                const SizedBox(height: 32),

                // Save button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _isSaving ? null : _save,
                    icon: _isSaving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white))
                        : const Icon(Icons.save_outlined),
                    label: Text(_isEditing ? 'Update Customer' : 'Add Customer'),
                  ),
                ),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ),
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
