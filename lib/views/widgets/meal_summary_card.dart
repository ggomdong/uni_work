import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../constants/gaps.dart';
import '../../constants/sizes.dart';
import '../../models/meal_summary_model.dart';
import '../../view_models/meal_summary_view_model.dart';
import './meal_types.dart';

class MealSummaryCard extends ConsumerWidget {
  final String? ym;
  final VoidCallback onUsedTap;

  const MealSummaryCard({
    super.key,
    this.ym,
    required this.onUsedTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summaryAsync = ref.watch(mealSummaryProvider(ym));

    return summaryAsync.when(
      data: (summary) => _SummaryRow(
        summary: summary,
        onUsedTap: onUsedTap,
      ),
      loading: () => const _SummaryRow(
        summary: MealSummaryModel(
          ym: null,
          totalAmount: 0,
          usedAmount: 0,
          balance: 0,
          claimCount: 0,
        ),
        onUsedTap: null,
        isLoading: true,
      ),
      error: (error, stack) => const Text('요약 정보를 불러오지 못했습니다.'),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final MealSummaryModel summary;
  final VoidCallback? onUsedTap;
  final bool isLoading;

  const _SummaryRow({
    required this.summary,
    required this.onUsedTap,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    final usedLabel = isLoading ? '사용' : '사용 (${summary.claimCount}건)';

    return Row(
      children: [
        Expanded(
          child: _SummaryMini(
            label: '발생',
            value: isLoading
                ? '...'
                : '${formatMealAmount(summary.totalAmount)}원',
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
                label: usedLabel,
                value: isLoading
                    ? '...'
                    : '${formatMealAmount(summary.usedAmount)}원',
                highlight: true,
              ),
            ),
          ),
        ),
        Expanded(
          child: _SummaryMini(
            label: '잔액',
            value:
                isLoading ? '...' : '${formatMealAmount(summary.balance)}원',
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
