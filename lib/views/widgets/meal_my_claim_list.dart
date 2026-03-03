import 'package:flutter/material.dart';
import '../../constants/gaps.dart';
import '../../models/meal_claim_item.dart';
import './meal_claim_card.dart';

class MealMyClaimList extends StatelessWidget {
  final List<MealClaimItem> items;
  final ValueChanged<MealClaimItem> onItemTap;

  const MealMyClaimList({
    super.key,
    required this.items,
    required this.onItemTap,
  });

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(child: Text('내가 입력한 내역이 없습니다.')),
      );
    }

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemBuilder:
          (context, index) => MealClaimCard(
            item: items[index],
            onTap: () => onItemTap(items[index]),
          ),
      separatorBuilder: (_, __) => Gaps.v12,
      itemCount: items.length,
    );
  }
}
