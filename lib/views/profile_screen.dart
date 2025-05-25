import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../constants/constants.dart';
import '../repos/authentication_repo.dart';
import '../view_models/settings_view_model.dart';
import '../router.dart';
import '../constants/gaps.dart';
import '../constants/sizes.dart';
import '../utils.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ProfileScreenState createState() => ProfileScreenState();
}

class ProfileScreenState extends ConsumerState<ProfileScreen> {
  void _onShowModal(BuildContext context, WidgetRef ref) {
    showCupertinoDialog(
      context: context,
      builder:
          (context) => CupertinoAlertDialog(
            title: const Text("정말 로그아웃하시겠어요?"),
            actions: [
              CupertinoDialogAction(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text("아니오"),
              ),
              CupertinoDialogAction(
                onPressed: () {
                  ref.read(authRepo).logout();
                  context.go(RouteURL.login);
                },
                isDestructiveAction: true,
                child: const Text("예"),
              ),
            ],
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = isDarkMode(ref);
    return Scaffold(
      backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
      body: SafeArea(
        child: DefaultTabController(
          initialIndex: 0,
          length: 0,
          child: NestedScrollView(
            headerSliverBuilder: (context, innerBoxIsScrolled) {
              return [
                SliverAppBar(
                  centerTitle: true,
                  titleSpacing: 0,
                  title: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Image.asset(logo, width: 133, height: 50),
                      Text(
                        "근태관리",
                        style: TextStyle(color: Colors.grey.shade700),
                      ),
                    ],
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: Sizes.size16,
                    ),
                    child: Column(
                      children: [
                        Gaps.v10,
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  "이름",
                                  style: TextStyle(
                                    fontSize: Sizes.size28,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                Gaps.v3,
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: Sizes.size12,
                                        vertical: Sizes.size5,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.grey.shade100,
                                        borderRadius: BorderRadius.circular(
                                          Sizes.size40,
                                        ),
                                      ),
                                      child: Text(
                                        "이메일",
                                        style: TextStyle(
                                          fontSize: Sizes.size16,
                                          color: Colors.grey.shade500,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                Gaps.v10,
                              ],
                            ),
                          ],
                        ),
                        Gaps.v6,
                        Divider(thickness: 0.5),
                        SwitchListTile.adaptive(
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: Sizes.size20,
                          ),
                          value: ref.watch(settingsProvider).darkMode,
                          onChanged:
                              (value) => ref
                                  .read(settingsProvider.notifier)
                                  .setDarkMode(value),
                          title: const Text(
                            "다크모드",
                            style: TextStyle(fontSize: Sizes.size18),
                          ),
                          secondary: Icon(
                            isDark
                                ? Icons.dark_mode_outlined
                                : Icons.light_mode_outlined,
                          ),
                        ),
                        ListTile(
                          leading: Icon(Icons.logout),
                          title: const Text(
                            "로그아웃",
                            style: TextStyle(fontSize: Sizes.size18),
                          ),
                          textColor: Colors.red,
                          onTap: () => _onShowModal(context, ref),
                        ),
                      ],
                    ),
                  ),
                ),
                // SliverPersistentHeader(
                //   delegate: PersistentTabBar(),
                //   pinned: true,
                // ),
              ];
            },
            body: TabBarView(children: [
                        ],
                      ),
          ),
        ),
      ),
    );
  }
}
