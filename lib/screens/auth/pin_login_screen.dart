import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/store_provider.dart';
import '../../core/theme.dart';
import '../../utils/constants.dart';

class PinLoginScreen extends StatefulWidget {
  const PinLoginScreen({super.key});

  @override
  State<PinLoginScreen> createState() => _PinLoginScreenState();
}

class _PinLoginScreenState extends State<PinLoginScreen>
    with SingleTickerProviderStateMixin {
  String _pin = '';
  bool _hasError = false;
  bool _isVerifying = false;
  late AnimationController _shakeController;
  late Animation<double> _shakeAnimation;

  static const int _pinLength = 4;

  @override
  void initState() {
    super.initState();
    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _shakeAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _shakeController, curve: Curves.elasticIn),
    );
  }

  @override
  void dispose() {
    _shakeController.dispose();
    super.dispose();
  }

  void _onKeyPressed(String key) {
    if (_pin.length >= _pinLength || _isVerifying) return;
    setState(() {
      _pin += key;
      _hasError = false;
    });
    if (_pin.length == _pinLength) {
      _verifyPin();
    }
  }

  void _onDelete() {
    if (_pin.isEmpty) return;
    setState(() => _pin = _pin.substring(0, _pin.length - 1));
  }

  Future<void> _verifyPin() async {
    setState(() => _isVerifying = true);
    final store = context.read<StoreProvider>();
    final ok = await store.verifyPin(_pin);
    if (!mounted) return;
    if (ok) {
      Navigator.of(context).pushReplacementNamed(AppRoutes.dashboard);
    } else {
      setState(() {
        _hasError = true;
        _isVerifying = false;
        _pin = '';
      });
      _shakeController.forward(from: 0);
    }
  }

  @override
  Widget build(BuildContext context) {
    final storeName =
        context.select<StoreProvider, String>((p) => p.storeName);

    return Scaffold(
      backgroundColor: AppTheme.primary,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            children: [
              const SizedBox(height: 60),
              // Logo
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Icon(
                  Icons.account_balance_wallet_rounded,
                  size: 38,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                storeName,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Enter your PIN to continue',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.75),
                  fontSize: 14,
                ),
              ),

              const SizedBox(height: 48),

              // PIN dots
              AnimatedBuilder(
                animation: _shakeAnimation,
                builder: (context, child) {
                  final offset =
                      _shakeController.isAnimating ? _shakeOffset() : 0.0;
                  return Transform.translate(
                    offset: Offset(offset, 0),
                    child: child,
                  );
                },
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(_pinLength, (i) {
                    final filled = i < _pin.length;
                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      margin: const EdgeInsets.symmetric(horizontal: 10),
                      width: 18,
                      height: 18,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: filled
                            ? (_hasError
                                ? Colors.redAccent
                                : Colors.white)
                            : Colors.white.withValues(alpha: 0.3),
                        border: Border.all(
                          color: _hasError
                              ? Colors.redAccent
                              : Colors.white.withValues(alpha: 0.6),
                          width: 2,
                        ),
                      ),
                    );
                  }),
                ),
              ),

              if (_hasError) ...[
                const SizedBox(height: 12),
                const Text(
                  'Incorrect PIN. Try again.',
                  style: TextStyle(color: Colors.redAccent, fontSize: 13),
                ),
              ],

              const Spacer(),

              // Keypad
              _PinKeypad(
                onKey: _onKeyPressed,
                onDelete: _onDelete,
                isLoading: _isVerifying,
              ),

              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  double _shakeOffset() {
    final value = _shakeAnimation.value;
    return 20 * (value < 0.5 ? value * 2 : (1 - value) * 2) *
        (value < 0.25 || (value > 0.5 && value < 0.75) ? -1 : 1);
  }
}

// ─── PIN Setup Screen ─────────────────────────────────────────────────────────

class PinSetupScreen extends StatefulWidget {
  const PinSetupScreen({super.key});

  @override
  State<PinSetupScreen> createState() => _PinSetupScreenState();
}

class _PinSetupScreenState extends State<PinSetupScreen> {
  String _pin = '';
  String _confirmPin = '';
  bool _isConfirming = false;
  bool _hasError = false;
  bool _isSaving = false;

  static const int _pinLength = 4;

  void _onKeyPressed(String key) {
    if (_isSaving) return;
    final current = _isConfirming ? _confirmPin : _pin;
    if (current.length >= _pinLength) return;

    setState(() {
      _hasError = false;
      if (_isConfirming) {
        _confirmPin += key;
      } else {
        _pin += key;
      }
    });

    final updated = _isConfirming ? _confirmPin : _pin;
    if (updated.length == _pinLength) {
      if (_isConfirming) {
        _finalize();
      } else {
        Future.delayed(const Duration(milliseconds: 200), () {
          if (mounted) setState(() => _isConfirming = true);
        });
      }
    }
  }

  void _onDelete() {
    setState(() {
      _hasError = false;
      if (_isConfirming) {
        if (_confirmPin.isNotEmpty) {
          _confirmPin = _confirmPin.substring(0, _confirmPin.length - 1);
        } else {
          _isConfirming = false;
          _pin = '';
        }
      } else {
        if (_pin.isNotEmpty) {
          _pin = _pin.substring(0, _pin.length - 1);
        }
      }
    });
  }

  Future<void> _finalize() async {
    if (_pin != _confirmPin) {
      setState(() {
        _hasError = true;
        _confirmPin = '';
      });
      return;
    }
    setState(() => _isSaving = true);
    await context.read<StoreProvider>().setPin(_pin);
    if (!mounted) return;
    Navigator.of(context).pushReplacementNamed(AppRoutes.dashboard);
  }

  void _skipPin() {
    // Mark as authenticated without PIN
    context.read<StoreProvider>().setPin('');
    Navigator.of(context).pushReplacementNamed(AppRoutes.dashboard);
  }

  @override
  Widget build(BuildContext context) {
    final currentPin = _isConfirming ? _confirmPin : _pin;

    return Scaffold(
      backgroundColor: AppTheme.primary,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            children: [
              const SizedBox(height: 60),
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Icon(
                  Icons.lock_outline_rounded,
                  size: 38,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                _isConfirming ? 'Confirm your PIN' : 'Set up your PIN',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _isConfirming
                    ? 'Re-enter your PIN to confirm'
                    : 'Choose a 4-digit PIN to secure your data',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.75),
                  fontSize: 14,
                ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 48),

              // PIN dots
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(_pinLength, (i) {
                  final filled = i < currentPin.length;
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.symmetric(horizontal: 10),
                    width: 18,
                    height: 18,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: filled
                          ? (_hasError ? Colors.redAccent : Colors.white)
                          : Colors.white.withValues(alpha: 0.3),
                      border: Border.all(
                        color: _hasError
                            ? Colors.redAccent
                            : Colors.white.withValues(alpha: 0.6),
                        width: 2,
                      ),
                    ),
                  );
                }),
              ),

              if (_hasError) ...[
                const SizedBox(height: 12),
                const Text(
                  'PINs do not match. Try again.',
                  style: TextStyle(color: Colors.redAccent, fontSize: 13),
                ),
              ],

              const Spacer(),

              _PinKeypad(
                onKey: _onKeyPressed,
                onDelete: _onDelete,
                isLoading: _isSaving,
              ),

              const SizedBox(height: 16),
              TextButton(
                onPressed: _skipPin,
                child: Text(
                  'Skip for now',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.65),
                    fontSize: 14,
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Shared PIN Keypad ────────────────────────────────────────────────────────

class _PinKeypad extends StatelessWidget {
  final ValueChanged<String> onKey;
  final VoidCallback onDelete;
  final bool isLoading;

  const _PinKeypad({
    required this.onKey,
    required this.onDelete,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildRow(['1', '2', '3']),
        const SizedBox(height: 12),
        _buildRow(['4', '5', '6']),
        const SizedBox(height: 12),
        _buildRow(['7', '8', '9']),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            const SizedBox(width: 76), // empty left
            _KeyButton(label: '0', onTap: () => onKey('0'), isLoading: isLoading),
            _DeleteButton(onTap: onDelete, isLoading: isLoading),
          ],
        ),
      ],
    );
  }

  Widget _buildRow(List<String> keys) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: keys
          .map((k) => _KeyButton(
              label: k, onTap: () => onKey(k), isLoading: isLoading))
          .toList(),
    );
  }
}

class _KeyButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final bool isLoading;

  const _KeyButton(
      {required this.label, required this.onTap, this.isLoading = false});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: isLoading ? null : onTap,
      child: Container(
        width: 76,
        height: 76,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white.withValues(alpha: 0.12),
        ),
        child: Center(
          child: Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }
}

class _DeleteButton extends StatelessWidget {
  final VoidCallback onTap;
  final bool isLoading;

  const _DeleteButton({required this.onTap, this.isLoading = false});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: isLoading ? null : onTap,
      child: Container(
        width: 76,
        height: 76,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white.withValues(alpha: 0.08),
        ),
        child: const Center(
          child: Icon(
            Icons.backspace_outlined,
            color: Colors.white,
            size: 26,
          ),
        ),
      ),
    );
  }
}
