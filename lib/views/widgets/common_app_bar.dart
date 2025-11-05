import 'package:flutter/material.dart';
import '../../constants/constants.dart';

class CommonAppBar extends StatelessWidget implements PreferredSizeWidget {
  final List<Widget>? actions;

  const CommonAppBar({super.key, this.actions});

  @override
  Widget build(BuildContext context) {
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
              Text(
                "근태관리",
                style: TextStyle(
                  color: Colors.grey.shade700,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
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
