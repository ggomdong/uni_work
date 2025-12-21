import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../constants/gaps.dart';
import '../models/profile_model.dart';
import '../repos/authentication_repo.dart';
import '../view_models/profile_view_model.dart';
import './widgets/common_app_bar.dart';
import './widgets/error_view.dart';
import '../router.dart';
import '../utils.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  void _onShowModal(BuildContext context, WidgetRef ref) {
    showCupertinoDialog(
      context: context,
      builder:
          (context) => CupertinoAlertDialog(
            title: const Text("정말 로그아웃하시겠어요?", style: TextStyle(fontSize: 14)),
            actions: [
              CupertinoDialogAction(
                onPressed: () => context.pop(),
                child: const Text("아니오", style: TextStyle(fontSize: 14)),
              ),
              CupertinoDialogAction(
                onPressed: () {
                  ref.read(authRepo).logout();
                  context.go(RouteURL.login);
                },
                isDestructiveAction: true,
                child: const Text("예", style: TextStyle(fontSize: 14)),
              ),
            ],
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // final isDark = isDarkMode(ref);
    final state = ref.watch(profileViewModelProvider);
    final vm = ref.read(profileViewModelProvider.notifier);

    return Scaffold(
      appBar: CommonAppBar(
        actions: [
          IconButton(
            tooltip: "새로고침",
            onPressed: () => vm.refresh(),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: SafeArea(
        child: state.when(
          data: (profile) {
            if (profile == null) {
              return _Empty(onRetry: vm.refresh);
            }
            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Gaps.v32,
                _HeaderCard(profile: profile),
                Gaps.v16,
                _InfoTile(
                  label: '부서',
                  value: profile.dept,
                  icon: Icons.apartment,
                ),
                Gaps.v8,
                _InfoTile(
                  label: '직위',
                  value: profile.position,
                  icon: Icons.badge,
                ),
                Gaps.v8,
                _InfoTile(
                  label: '이름',
                  value: profile.empName,
                  icon: Icons.person,
                ),
                Gaps.v8,
                _InfoTile(
                  label: 'ID(휴대폰번호)',
                  value: profile.username,
                  icon: Icons.phone_iphone,
                ),
                Gaps.v8,
                _InfoTile(
                  label: 'E-mail',
                  value: profile.email,
                  icon: Icons.alternate_email,
                ),
                Gaps.v24,
                SizedBox(
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: Theme.of(context).primaryColor,
                      foregroundColor: Colors.white,
                    ),
                    onPressed: () => _onShowModal(context, ref),
                    icon: const Icon(Icons.logout),
                    label: const Text(
                      '로그아웃',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                Gaps.v5,
                TextButton(
                  onPressed: () => openPrivacy(ref),
                  child: const Text('개인정보처리방침', style: TextStyle(fontSize: 12)),
                ),
              ],
            );
          },
          loading: () => const _Loading(),
          error:
              (e, st) => ErrorView(
                title: '프로필 정보를 불러오지 못했습니다',
                icon: Icons.person_off_outlined,
                error: e,
                stackTrace: st,
                onRetry: vm.refresh,
              ),
        ),
      ),
    );
  }
}

class _HeaderCard extends StatelessWidget {
  final ProfileModel profile;
  const _HeaderCard({required this.profile});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primary = theme.primaryColor;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            primary.withValues(alpha: 0.12),
            primary.withValues(alpha: 0.04),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: primary.withValues(alpha: 0.15)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: primary,
            radius: 28,
            child: Text(
              profile.empName.isNotEmpty
                  ? profile.empName.characters.first
                  : '?',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
            ),
          ),
          Gaps.h16,
          Expanded(
            child: Wrap(
              runSpacing: 6,
              spacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  profile.empName,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                _Chip(text: profile.dept),
                _Chip(text: profile.position),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String text;
  const _Chip({required this.text});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: theme.primaryColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: theme.primaryColor.withValues(alpha: 0.18)),
      ),
      child: Text(
        text,
        style: theme.textTheme.labelMedium?.copyWith(
          fontWeight: FontWeight.w600,
          color: theme.colorScheme.primary,
        ),
      ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  const _InfoTile({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: theme.primaryColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: theme.primaryColor.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: theme.primaryColor),
          Gaps.h12,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.hintColor,
                  ),
                ),
                Gaps.v2,
                Text(
                  value.isNotEmpty ? value : '-',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Loading extends StatelessWidget {
  const _Loading();

  @override
  Widget build(BuildContext context) {
    return const Center(child: CircularProgressIndicator());
  }
}

class _Error extends StatelessWidget {
  final VoidCallback onRetry;
  final String? message;
  const _Error({required this.onRetry, this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 40),
            Gaps.v12,
            Text(
              '프로필 정보를 불러오지 못했습니다.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            if (message != null) ...[
              Gaps.v6,
              Text(message!, style: Theme.of(context).textTheme.labelSmall),
            ],
            Gaps.v12,
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('다시 시도'),
            ),
          ],
        ),
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  final VoidCallback onRetry;
  const _Empty({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.person_off_outlined, size: 40),
            Gaps.v12,
            const Text('표시할 프로필 정보가 없습니다.'),
            Gaps.v12,
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('새로고침'),
            ),
          ],
        ),
      ),
    );
  }
}
