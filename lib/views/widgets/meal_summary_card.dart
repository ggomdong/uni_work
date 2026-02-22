import 'package:flutter/material.dart';
import '../../constants/gaps.dart';
import '../../constants/sizes.dart';
import './meal_types.dart';

class MealSummaryCard extends StatelessWidget {
  final MealSummary summary;
  final VoidCallback onUsedTap;

  const MealSummaryCard({
    super.key,
    required this.summary,
    required this.onUsedTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      children: [
        Expanded(
          child: _SummaryMini(
            label: '발생',
            value: '${formatMealAmount(summary.totalAmount)}원',
          ),
        ),
        Expanded(
          child: InkWell(
            onTap: onUsedTap,
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                vertical: Sizes.size4,
                horizontal: Sizes.size6,
              ),
              child: _SummaryMini(
                label: '사용 (${summary.claimCount}건)',
                value: '${formatMealAmount(summary.usedAmount)}원',
                highlight: true,
              ),
            ),
          ),
        ),
        Expanded(
          child: _SummaryMini(
            label: '잔액',
            value: '${formatMealAmount(summary.balance)}원',
            emphasize: true,
          ),
        ),
      ],
    );
  }
}

class _SummaryMini extends StatelessWidget {
  final String label;
  final String value;
  final bool highlight;
  final bool emphasize;

  const _SummaryMini({
    required this.label,
    required this.value,
    this.highlight = false,
    this.emphasize = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = highlight ? theme.primaryColor : Colors.black87;
    final valueStyle =
        emphasize
            ? theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
              color: color,
            )
            : theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
              color: color,
            );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(color: Colors.black54),
        ),
        Gaps.v4,
        Text(value, style: valueStyle),
      ],
    );
  }
}
