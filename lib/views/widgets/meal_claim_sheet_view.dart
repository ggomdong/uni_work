import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../constants/gaps.dart';
import '../../constants/sizes.dart';
import '../../models/meal_claim_item.dart';
import '../../utils/meal_utils.dart';

class MealClaimViewContent extends StatelessWidget {
  final MealClaimItem item;
  final Widget participantsSection;

  const MealClaimViewContent({
    super.key,
    required this.item,
    required this.participantsSection,
  });

  @override
  Widget build(BuildContext context) {
    final dateText = DateFormat('yyyy-MM-dd').format(item.usedDate);
    final createdBy = item.createdByName.isEmpty ? '-' : item.createdByName;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _MealClaimInfoRow(label: '사용일', value: dateText),
        _MealClaimInfoRow(
          label: '승인번호',
          value: item.approvalNo.isEmpty ? '-' : item.approvalNo,
          isSubtle: true,
        ),
        _MealClaimInfoRow(label: '가맹점명', value: item.merchantName),
        _MealClaimInfoRow(
          label: '총액',
          value: '${formatMealAmount(item.totalAmount)}원',
        ),
        _MealClaimInfoRow(
          label: '본인부담',
          value: '${formatMealAmount(item.myAmount)}원',
        ),
        Gaps.v16,
        participantsSection,
        Gaps.v16,
        _MealClaimInfoRow(label: '입력자', value: createdBy),
      ],
    );
  }
}

class _MealClaimInfoRow extends StatelessWidget {
  final String label;
  final String value;
  final bool isSubtle;

  const _MealClaimInfoRow({
    required this.label,
    required this.value,
    this.isSubtle = false,
  });

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.bodyMedium;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: Sizes.size6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: style?.copyWith(color: Colors.black54)),
          Flexible(
            child: Text(
              value,
              style: style?.copyWith(
                color: isSubtle ? Colors.black45 : Colors.black87,
                fontWeight: FontWeight.w700,
              ),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }
}

class MealClaimViewActions extends StatelessWidget {
  final bool canEdit;
  final bool canDelete;
  final bool deleting;
  final VoidCallback onEdit;
  final Future<void> Function() onDelete;

  const MealClaimViewActions({
    super.key,
    required this.canEdit,
    required this.canDelete,
    required this.deleting,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    if (!canEdit && !canDelete) {
      return const SizedBox.shrink();
    }

    return Row(
      children: [
        if (canEdit)
          Expanded(
            child: OutlinedButton(onPressed: onEdit, child: const Text('수정')),
          ),
        if (canEdit && canDelete) Gaps.h12,
        if (canDelete)
          Expanded(
            child: OutlinedButton(
              onPressed: deleting ? null : () => onDelete(),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.redAccent,
              ),
              child: const Text('삭제'),
            ),
          ),
      ],
    );
  }
}
