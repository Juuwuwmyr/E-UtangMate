import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';

import '../../providers/store_provider.dart';
import '../../core/theme.dart';
import '../../data/models/store_model.dart';
import '../../utils/validators.dart';

import '../../widgets/confirm_dialog.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  @override
  Widget build(BuildContext context) {
    final store = context.watch<StoreProvider>();

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          // Store profile section
          _SectionHeader('Store Profile'),
          ListTile(
            leading: const Icon(Icons.store_outlined),
            title: const Text('Store Information'),
            subtitle: Text(store.storeName),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const _StoreProfileScreen()),
            ),
          ),
          const Divider(height: 1),

          // App PIN
          _SectionHeader('Security'),
          ListTile(
            leading: const Icon(Icons.lock_outline),
            title: Text(store.hasPinSetup ? 'Change PIN' : 'Set up PIN'),
            subtitle: Text(
              store.hasPinSetup
                  ? 'App is PIN protected'
                  : 'No PIN set – anyone can open the app',
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const _ChangePinScreen()),
            ),
          ),
          if (store.hasPinSetup) ...[
            const Divider(height: 1, indent: 56),
            ListTile(
              leading: const Icon(Icons.lock_open_outlined,
                  color: AppTheme.overdue),
              title: const Text('Remove PIN',
                  style: TextStyle(color: AppTheme.overdue)),
              onTap: () async {
                final ok = await ConfirmDialog.show(
                  context,
                  title: 'Remove PIN',
                  message:
                      'The app will no longer require a PIN to open. Are you sure?',
                  confirmLabel: 'Remove PIN',
                  isDangerous: true,
                );
                if (ok == true && context.mounted) {
                  await context.read<StoreProvider>().removePin();
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('PIN removed')),
                    );
                  }
                }
              },
            ),
          ],
          const Divider(height: 1),

          // Appearance
          _SectionHeader('Appearance'),
          ListTile(
            leading: const Icon(Icons.dark_mode_outlined),
            title: const Text('Dark Mode'),
            trailing: Switch.adaptive(
              value: store.isDarkMode,
              onChanged: (_) => store.toggleDarkMode(),
              activeThumbColor: AppTheme.primary,
            ),
          ),
          const Divider(height: 1),

          // About
          _SectionHeader('About'),
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: const Text('UtangMate'),
            subtitle: const Text('Version 1.0.0'),
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.history_outlined),
            title: const Text('Audit Log'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const _AuditLogScreen()),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader(this.title);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 4),
      child: Text(
        title.toUpperCase(),
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: AppTheme.textSecondary,
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}

// ─── Store Profile Screen ─────────────────────────────────────────────────────

class _StoreProfileScreen extends StatefulWidget {
  const _StoreProfileScreen();

  @override
  State<_StoreProfileScreen> createState() => _StoreProfileScreenState();
}

class _StoreProfileScreenState extends State<_StoreProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameCtrl;
  late final TextEditingController _addressCtrl;
  late final TextEditingController _phoneCtrl;
  late final TextEditingController _emailCtrl;
  late final TextEditingController _tinCtrl;
  late final TextEditingController _symbolCtrl;
  late final TextEditingController _currencyCtrl;
  String? _logoPath;
  bool _isSaving = false;

  static const _currencies = [
    ('PHP', '₱', 'Philippine Peso'),
    ('USD', '\$', 'US Dollar'),
    ('EUR', '€', 'Euro'),
    ('GBP', '£', 'British Pound'),
    ('JPY', '¥', 'Japanese Yen'),
    ('SGD', 'S\$', 'Singapore Dollar'),
    ('AUD', 'A\$', 'Australian Dollar'),
  ];

  @override
  void initState() {
    super.initState();
    final store = context.read<StoreProvider>().store;
    _nameCtrl = TextEditingController(text: store?.name ?? '');
    _addressCtrl = TextEditingController(text: store?.address ?? '');
    _phoneCtrl = TextEditingController(text: store?.phone ?? '');
    _emailCtrl = TextEditingController(text: store?.email ?? '');
    _tinCtrl = TextEditingController(text: store?.tin ?? '');
    _currencyCtrl =
        TextEditingController(text: store?.currency ?? 'PHP');
    _symbolCtrl =
        TextEditingController(text: store?.currencySymbol ?? '₱');
    _logoPath = store?.logoPath;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _addressCtrl.dispose();
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    _tinCtrl.dispose();
    _currencyCtrl.dispose();
    _symbolCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickLogo() async {
    final picker = ImagePicker();
    final file = await picker.pickImage(
        source: ImageSource.gallery, maxWidth: 256, maxHeight: 256);
    if (file != null && mounted) {
      setState(() => _logoPath = file.path);
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);
    final store = context.read<StoreProvider>().store;
    final now = DateTime.now();
    final updated = Store(
      id: store?.id,
      name: _nameCtrl.text.trim(),
      address: _addressCtrl.text.trim().isEmpty ? null : _addressCtrl.text.trim(),
      phone: _phoneCtrl.text.trim().isEmpty ? null : _phoneCtrl.text.trim(),
      email: _emailCtrl.text.trim().isEmpty ? null : _emailCtrl.text.trim(),
      tin: _tinCtrl.text.trim().isEmpty ? null : _tinCtrl.text.trim(),
      logoPath: _logoPath,
      currency: _currencyCtrl.text.trim().isEmpty ? 'PHP' : _currencyCtrl.text.trim(),
      currencySymbol: _symbolCtrl.text.trim().isEmpty ? '₱' : _symbolCtrl.text.trim(),
      createdAt: store?.createdAt ?? now,
      updatedAt: now,
    );
    await context.read<StoreProvider>().updateStore(updated);
    if (!mounted) return;
    setState(() => _isSaving = false);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Store information saved'),
          backgroundColor: AppTheme.paid),
    );
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Store Information'),
        actions: [
          TextButton(
            onPressed: _isSaving ? null : _save,
            child: const Text('Save',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
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
              // Logo
              Center(
                child: GestureDetector(
                  onTap: _pickLogo,
                  child: Stack(
                    children: [
                      Container(
                        width: 88,
                        height: 88,
                        decoration: BoxDecoration(
                          color: AppTheme.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: AppTheme.divider),
                          image: _logoPath != null && File(_logoPath!).existsSync()
                              ? DecorationImage(
                                  image: FileImage(File(_logoPath!)),
                                  fit: BoxFit.cover)
                              : null,
                        ),
                        child: _logoPath == null
                            ? const Icon(Icons.store_outlined,
                                size: 40, color: AppTheme.primary)
                            : null,
                      ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: Container(
                          padding: const EdgeInsets.all(5),
                          decoration: BoxDecoration(
                            color: AppTheme.primary,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2),
                          ),
                          child: const Icon(Icons.camera_alt,
                              size: 12, color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              TextFormField(
                controller: _nameCtrl,
                decoration: const InputDecoration(
                    labelText: 'Store Name *',
                    prefixIcon: Icon(Icons.store_outlined)),
                validator: (v) => AppValidators.required(v, 'Store name'),
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _addressCtrl,
                maxLines: 2,
                decoration: const InputDecoration(
                    labelText: 'Address',
                    prefixIcon: Icon(Icons.location_on_outlined),
                    alignLabelWithHint: true),
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _phoneCtrl,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                    labelText: 'Phone Number',
                    prefixIcon: Icon(Icons.phone_outlined)),
                validator: AppValidators.phone,
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _emailCtrl,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                    labelText: 'Email',
                    prefixIcon: Icon(Icons.email_outlined)),
                validator: AppValidators.email,
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _tinCtrl,
                decoration: const InputDecoration(
                    labelText: 'TIN (optional)',
                    prefixIcon: Icon(Icons.badge_outlined)),
              ),
              const SizedBox(height: 24),
              const Text('CURRENCY',
                  style: TextStyle(
                      fontSize: 11, fontWeight: FontWeight.w700,
                      color: AppTheme.textSecondary, letterSpacing: 0.8)),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                initialValue: _currencies.any((c) => c.$1 == _currencyCtrl.text)
                    ? _currencyCtrl.text
                    : 'PHP',
                decoration: const InputDecoration(
                    labelText: 'Currency',
                    prefixIcon: Icon(Icons.currency_exchange_outlined)),
                items: _currencies
                    .map((c) => DropdownMenuItem(
                          value: c.$1,
                          child: Text('${c.$1} – ${c.$2} – ${c.$3}'),
                        ))
                    .toList(),
                onChanged: (v) {
                  if (v != null) {
                    final match = _currencies.firstWhere((c) => c.$1 == v);
                    setState(() {
                      _currencyCtrl.text = match.$1;
                      _symbolCtrl.text = match.$2;
                    });
                  }
                },
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _symbolCtrl,
                decoration: const InputDecoration(
                    labelText: 'Currency Symbol',
                    prefixIcon: Icon(Icons.attach_money_outlined),
                    hintText: '₱'),
                validator: (v) => AppValidators.required(v, 'Currency symbol'),
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _isSaving ? null : _save,
                  icon: const Icon(Icons.save_outlined),
                  label: const Text('Save Store Information'),
                  style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14)),
                ),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Change PIN Screen ────────────────────────────────────────────────────────

class _ChangePinScreen extends StatefulWidget {
  const _ChangePinScreen();

  @override
  State<_ChangePinScreen> createState() => _ChangePinScreenState();
}

class _ChangePinScreenState extends State<_ChangePinScreen> {
  final _formKey = GlobalKey<FormState>();
  final _currentCtrl = TextEditingController();
  final _newCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  bool _isSaving = false;
  bool _showCurrent = false;
  bool _showNew = false;
  bool _showConfirm = false;

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);
    final store = context.read<StoreProvider>();

    // Verify current PIN first
    if (store.hasPinSetup) {
      final ok = await store.verifyPin(_currentCtrl.text);
      if (!ok) {
        if (!mounted) return;
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Current PIN is incorrect'),
              backgroundColor: AppTheme.overdue),
        );
        return;
      }
    }

    await store.setPin(_newCtrl.text);
    if (!mounted) return;
    setState(() => _isSaving = false);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('PIN updated successfully'),
          backgroundColor: AppTheme.paid),
    );
    Navigator.of(context).pop();
  }

  @override
  void dispose() {
    _currentCtrl.dispose();
    _newCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hasPinSetup = context.select<StoreProvider, bool>((p) => p.hasPinSetup);

    return Scaffold(
      appBar: AppBar(title: Text(hasPinSetup ? 'Change PIN' : 'Set PIN')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              const SizedBox(height: 16),
              const Icon(Icons.lock_outline,
                  size: 56, color: AppTheme.primary),
              const SizedBox(height: 24),

              if (hasPinSetup) ...[
                TextFormField(
                  controller: _currentCtrl,
                  obscureText: !_showCurrent,
                  keyboardType: TextInputType.number,
                  maxLength: 8,
                  decoration: InputDecoration(
                    labelText: 'Current PIN',
                    prefixIcon: const Icon(Icons.lock_outlined),
                    suffixIcon: IconButton(
                      icon: Icon(_showCurrent
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined),
                      onPressed: () =>
                          setState(() => _showCurrent = !_showCurrent),
                    ),
                  ),
                  validator: (v) => AppValidators.pin(v),
                ),
                const SizedBox(height: 8),
              ],

              TextFormField(
                controller: _newCtrl,
                obscureText: !_showNew,
                keyboardType: TextInputType.number,
                maxLength: 8,
                decoration: InputDecoration(
                  labelText: 'New PIN',
                  prefixIcon: const Icon(Icons.lock_outlined),
                  suffixIcon: IconButton(
                    icon: Icon(_showNew
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined),
                    onPressed: () => setState(() => _showNew = !_showNew),
                  ),
                ),
                validator: (v) => AppValidators.pin(v),
              ),
              const SizedBox(height: 8),

              TextFormField(
                controller: _confirmCtrl,
                obscureText: !_showConfirm,
                keyboardType: TextInputType.number,
                maxLength: 8,
                decoration: InputDecoration(
                  labelText: 'Confirm New PIN',
                  prefixIcon: const Icon(Icons.lock_outlined),
                  suffixIcon: IconButton(
                    icon: Icon(_showConfirm
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined),
                    onPressed: () =>
                        setState(() => _showConfirm = !_showConfirm),
                  ),
                ),
                validator: (v) =>
                    AppValidators.pinConfirm(v, _newCtrl.text),
              ),
              const SizedBox(height: 32),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _isSaving ? null : _save,
                  icon: const Icon(Icons.save_outlined),
                  label: Text(hasPinSetup ? 'Update PIN' : 'Set PIN'),
                  style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Audit Log Screen ─────────────────────────────────────────────────────────

class _AuditLogScreen extends StatelessWidget {
  const _AuditLogScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Audit Log')),
      body: const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.history_outlined, size: 48, color: AppTheme.textHint),
              SizedBox(height: 12),
              Text('Audit Log',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
              SizedBox(height: 8),
              Text(
                'Every create, update, and delete action is logged here. This tracks all changes to customer records, transactions, and payments.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppTheme.textSecondary),
              ),
            ],
          ),
        ),
      ),
    );
  }
}


