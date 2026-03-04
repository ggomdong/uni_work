import 'package:flutter/material.dart';
import '../../constants/constants.dart';

class CommonAppBar extends StatelessWidget implements PreferredSizeWidget {
  /// 메뉴별 문구(설명). null/빈값이면 표시하지 않음.
  final String? label;
  final List<Widget>? actions;

  const CommonAppBar({super.key, this.label, this.actions});

  @override
  Widget build(BuildContext context) {
    final hasLabel = (label != null && label!.trim().isNotEmpty);

    return AppBar(
      centerTitle: true,
      automaticallyImplyLeading: false,
      actions: actions,
      // actions/leading의 폭 영향을 없애기 위해 title은 비워둡니다.
      title: const SizedBox.shrink(),

      // 진짜 중앙에 로고+텍스트를 그립니다.
      flexibleSpace: SafeArea(
        child: Center(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Image.asset(logo, width: 133, height: 50),
              if (hasLabel)
                Text(
                  label!.trim(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.grey.shade700,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Size get preferredSize => Size.fromHeight(kToolbarHeight);
}
