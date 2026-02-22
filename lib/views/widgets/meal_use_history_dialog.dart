import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../constants/gaps.dart';
import '../../constants/sizes.dart';
import './meal_types.dart';

Future<void> showMealUseHistoryDialog({
  required BuildContext context,
  required List<MealClaimItem> items,
  required ValueChanged<MealClaimItem> onItemTap,
}) {
  final sorted = [...items]
    ..sort((a, b) {
      final date = a.usedDate.compareTo(b.usedDate);
      if (date != 0) return date;
      return a.id.compareTo(b.id);
    });

  return showDialog(
    context: context,
    builder: (context) {
      return Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(Sizes.size16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '내 사용 내역',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              Gaps.v12,
              SizedBox(
                height: 420,
                child: ListView.separated(
                  itemCount: sorted.length,
                  separatorBuilder: (_, __) => Gaps.v8,
                  itemBuilder: (context, index) {
                    final item = sorted[index];
                    final dateText =
                        DateFormat('yyyy-MM-dd').format(item.usedDate);

                    return InkWell(
                      onTap: () {
                        Navigator.of(context).pop();
                        onItemTap(item);
                      },
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.all(Sizes.size12),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Colors.black.withValues(alpha: 0.08),
                          ),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item.merchantName,
                                    style: Theme.of(
                                      context,
                                    ).textTheme.bodyMedium?.copyWith(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  Gaps.v4,
                                  Text(
                                    '$dateText · 본인부담 ${formatMealAmount(item.myAmount)}원',
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodySmall
                                        ?.copyWith(
                                          color: Colors.black54,
                                        ),
                                  ),
                                ],
                              ),
                            ),
                            const Icon(
                              Icons.chevron_right,
                              size: 20,
                              color: Colors.black45,
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
              Gaps.v12,
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('닫기'),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}
