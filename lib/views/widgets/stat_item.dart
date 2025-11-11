import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../utils.dart';
import '../../constants/gaps.dart';

// 초슬림 StatItem (값 한 줄만)
class StatItemMini extends ConsumerWidget {
  final IconData icon;
  final String title;
  final String value; // 예: "1회, 00:34:05"
  /// 지각/조퇴/연장/휴근 시간(=초 합계)이 존재할 때만 긴 값("n회, HH:MM:SS")을 표시하므로
  /// isLong이 true일 때만 가로 압축/자간 조정 적용
  final bool isLong;
  final Color color;

  const StatItemMini({
    super.key,
    required this.icon,
    required this.title,
    required this.value,
    required this.isLong,
    required this.color,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = isDarkMode(ref);
    final bg = isDark ? const Color(0xFF15171A) : Colors.white;
    final border = isDark ? const Color(0xFF2A2E33) : const Color(0xFFE9EDF1);

    // 값 텍스트 위젯: isLong일 때만 장평/자간 조정
    final valueText = Text(
      value,
      maxLines: 1,
      softWrap: false,
      // 말줄임 대신 FittedBox가 크기를 줄여 넣어주므로 visible로 둔다
      overflow: TextOverflow.visible,
      textAlign: TextAlign.right,
      style: const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w700,
      ).copyWith(
        // 긴 값일 때만 약한 음수 자간으로 살짝 조밀하게
        letterSpacing: isLong ? -0.2 : 0.0,
        height: 1.0,
      ),
    );

    // isLong이면 가로만 살짝 압축(장평), 아니면 그대로
    final compressedValue =
        isLong
            ? Transform(
              transform: Matrix4.diagonal3Values(0.92, 1.0, 1.0), // 가로 92%
              alignment: Alignment.centerRight,
              child: valueText,
            )
            : valueText;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: border),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: color), // 작은 아이콘
          Gaps.h2,
          Text(
            title,
            style: TextStyle(
              color: Colors.grey.shade600,
              fontSize: 10, // 가독 유지 최소 사이즈
              fontWeight: FontWeight.w700,
            ),
          ),
          Gaps.h6,
          Expanded(
            child: Tooltip(
              // 길면 툴팁으로 전체 보기
              message: value,
              child: Align(
                alignment: Alignment.centerRight,
                child: FittedBox(
                  fit: BoxFit.scaleDown, // 남으면 자동 축소(최소한으로)
                  alignment: Alignment.centerRight,
                  child: compressedValue, // isLong일 때만 장평 적용
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class StatGrid extends StatelessWidget {
  final List<Widget> items; // StatItemCompact 6개 권장
  const StatGrid({super.key, required this.items});

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 3,
      mainAxisSpacing: 8,
      crossAxisSpacing: 8,
      // 가로 대비 높이 비율(너비/높이). 숫자 ↑ → 더 낮은 높이
      childAspectRatio: 3.6, // 3.2~3.8 사이로 취향 조절
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      children: items,
    );
  }
}


// class StatItemAnimated extends StatelessWidget {
//   final IconData icon;
//   final String title;
//   final double? rate;
//   final Color color;

//   const StatItemAnimated({
//     super.key,
//     required this.icon,
//     required this.title,
//     required this.rate,
//     required this.color,
//   });

//   @override
//   Widget build(BuildContext context) {
//     return Container(
//       width: 100,
//       padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
//       decoration: BoxDecoration(
//         color: color.withValues(alpha: 0.05),
//         border: Border.all(color: color.withValues(alpha: 0.3)),
//         borderRadius: BorderRadius.circular(12),
//       ),
//       child: Column(
//         mainAxisSize: MainAxisSize.min,
//         children: [
//           Row(
//             mainAxisAlignment: MainAxisAlignment.center,
//             children: [
//               Icon(icon, color: color),
//               Gaps.h4,
//               Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
//             ],
//           ),
//           Gaps.v4,
//           rate != null
//               ? TweenAnimationBuilder<double>(
//                 tween: Tween(begin: 0, end: rate!),
//                 duration: const Duration(milliseconds: 800),
//                 builder:
//                     (context, value, _) => Text(
//                       "${value.toStringAsFixed(2)} %",
//                       style: TextStyle(
//                         color: color,
//                         fontSize: Sizes.size16,
//                         fontWeight: FontWeight.w600,
//                       ),
//                     ),
//               )
//               : Text(
//                 "-",
//                 style: TextStyle(
//                   color: color,
//                   fontSize: Sizes.size16,
//                   fontWeight: FontWeight.w600,
//                 ),
//               ),
//         ],
//       ),
//     );
//   }
// }


