import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../constants/gaps.dart';
import '../../constants/sizes.dart';
import './meal_types.dart';

class MealClaimCard extends StatelessWidget {
  final MealClaimItem item;
  final VoidCallback? onTap;

  const MealClaimCard({super.key, required this.item, this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dateText = DateFormat('yyyy-MM-dd').format(item.usedDate);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(Sizes.size14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.black.withValues(alpha: 0.08)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    item.merchantName,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Text(
                  dateText,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: Colors.black54,
                  ),
                ),
              ],
            ),
            Gaps.v6,
            Row(
              children: [
                Text(
                  '총액 ${formatMealAmount(item.totalAmount)}원',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Gaps.h12,
                Text(
                  '본인부담 ${formatMealAmount(item.myAmount)}원',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ],
            ),
            Gaps.v6,
            Row(
              children: [
                Text(
                  '대상자 ${item.participantsCount}명 / '
                  '${formatMealAmount(item.participantsSum)}원',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: Colors.black54,
                  ),
                ),
                Gaps.h12,
                Text(
                  '승인번호 ${item.approvalNo}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: Colors.black45,
                  ),
                ),
                const Spacer(),
                Icon(Icons.chevron_right, size: 20, color: Colors.black45),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
