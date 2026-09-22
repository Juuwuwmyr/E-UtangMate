import 'package:flutter/material.dart';
import '../utils/formatters.dart';

class AmountDisplay extends StatelessWidget {
  final double amount;
  final String symbol;
  final Color? color;
  final double fontSize;
  final FontWeight fontWeight;
  final bool showSign;

  const AmountDisplay({
    super.key,
    required this.amount,
    this.symbol = '₱',
    this.color,
    this.fontSize = 16,
    this.fontWeight = FontWeight.w700,
    this.showSign = false,
  });

  @override
  Widget build(BuildContext context) {
    final formatted = AppFormatter.currency(amount.abs(), symbol: symbol);
    final prefix = showSign && amount >= 0 ? '+' : (amount < 0 ? '-' : '');

    return Text(
      '$prefix$formatted',
      style: TextStyle(
        color: color ?? Theme.of(context).colorScheme.primary,
        fontSize: fontSize,
        fontWeight: fontWeight,
        fontFeatures: const [FontFeature.tabularFigures()],
      ),
    );
  }
}
