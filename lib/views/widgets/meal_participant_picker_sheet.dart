import 'package:flutter/material.dart';

import '../../constants/gaps.dart';
import '../../constants/sizes.dart';
import './app_toast.dart';
import './meal_types.dart';

Future<List<MealOptionUser>?> showMealParticipantPickerSheet({
  required BuildContext context,
  required List<MealOptionUser> users,
  required List<MealOptionGroup> groups,
  required List<int> selectedUserIds,
}) {
  return showModalBottomSheet<List<MealOptionUser>>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (context) {
      return SafeArea(
        top: false,
        child: FractionallySizedBox(
          heightFactor: 0.9,
          child: _MealParticipantPickerSheet(
            users: users,
            groups: groups,
            selectedUserIds: selectedUserIds,
          ),
        ),
      );
    },
  );
}

class _MealParticipantPickerSheet extends StatefulWidget {
  final List<MealOptionUser> users;
  final List<MealOptionGroup> groups;
  final List<int> selectedUserIds;

  const _MealParticipantPickerSheet({
    required this.users,
    required this.groups,
    required this.selectedUserIds,
  });

  @override
  State<_MealParticipantPickerSheet> createState() =>
      _MealParticipantPickerSheetState();
}

class _MealParticipantPickerSheetState
    extends State<_MealParticipantPickerSheet> {
  late final TextEditingController _searchController;
  late final Set<int> _selectedIds;
  late final ScrollController _usersScrollController;
  String _query = '';
  int _selectedGroupIndex = 0;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    _usersScrollController = ScrollController();
    _selectedIds = {...widget.selectedUserIds};
    _searchController.addListener(() {
      setState(() {
        _query = _searchController.text.trim().toLowerCase();
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _usersScrollController.dispose();
    super.dispose();
  }

  bool _matchesQuery(MealOptionUser user) {
    if (_query.isEmpty) return true;
    final name = user.empName.toLowerCase();
    final position = user.position.toLowerCase();
    return name.contains(_query) || position.contains(_query);
  }

  int _selectedCountForGroup({
    required int index,
    required List<MealOptionGroup> groups,
  }) {
    Iterable<int> ids;
    if (index == 0) {
      ids = widget.users.map((u) => u.id);
    } else {
      ids = groups[index - 1].members.map((m) => m.id);
    }
    var count = 0;
    for (final id in ids) {
      if (_selectedIds.contains(id)) count++;
    }
    return count;
  }

  void _clearSelection() {
    setState(() {
      _selectedIds.clear();
    });
  }

  void _toggleUser(int userId, bool selected) {
    setState(() {
      if (selected) {
        _selectedIds.add(userId);
      } else {
        _selectedIds.remove(userId);
      }
    });
  }

  void _confirm() {
    if (_selectedIds.isEmpty) {
      AppToast.show(
        context,
        '대상자를 1명 이상 선택해주세요.',
        backgroundColor: Colors.redAccent,
      );
      return;
    }
    final selected =
        widget.users.where((u) => _selectedIds.contains(u.id)).toList();
    Navigator.of(context).pop(selected);
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final theme = Theme.of(context);
    final groups = widget.groups
        .where((g) => g.members.isNotEmpty)
        .toList(growable: false);
    final safeGroupIndex =
        _selectedGroupIndex <= groups.length ? _selectedGroupIndex : 0;
    final currentUsers =
        safeGroupIndex == 0 ? widget.users : groups[safeGroupIndex - 1].members;
    final filtered = currentUsers
      .where((u) => _matchesQuery(u))
      .toList(growable: false)..sort((a, b) => a.empName.compareTo(b.empName));

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.10),
            blurRadius: 18,
            offset: const Offset(0, -8),
          ),
        ],
      ),
      child: Column(
        children: [
          Gaps.v16,
          Center(
            child: Container(
              width: 48,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(999),
              ),
            ),
          ),
          Gaps.v12,
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: Sizes.size20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '대상자 선택',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
          ),
          Gaps.v8,
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: Sizes.size20),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: '이름/직위 검색',
                prefixIcon: const Icon(Icons.search),
                suffixIcon:
                    _query.isEmpty
                        ? null
                        : IconButton(
                          onPressed: () => _searchController.clear(),
                          icon: const Icon(Icons.cancel),
                          tooltip: '검색어 지우기',
                        ),
                filled: true,
                fillColor: Colors.black.withValues(alpha: 0.03),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: Colors.black.withValues(alpha: 0.10),
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: theme.primaryColor, width: 2),
                ),
              ),
            ),
          ),
          Gaps.v4,
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: Sizes.size10),
            child: Row(
              children: [
                const Spacer(),
                TextButton(
                  onPressed: _selectedIds.isEmpty ? null : _clearSelection,
                  child: const Text('전체 선택 해제'),
                ),
              ],
            ),
          ),
          Expanded(
            child: Row(
              children: [
                SizedBox(
                  width: size.width * 0.4,
                  child: ListView.separated(
                    primary: false,
                    physics: const ClampingScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(
                      Sizes.size16,
                      0,
                      Sizes.size8,
                      0,
                    ),
                    itemBuilder: (context, index) {
                      final bool selected = safeGroupIndex == index;
                      final String title;
                      final int count;
                      final selectedCount = _selectedCountForGroup(
                        index: index,
                        groups: groups,
                      );
                      if (index == 0) {
                        title = '전체';
                        count = widget.users.length;
                      } else {
                        final group = groups[index - 1];
                        title = group.dept.isEmpty ? '부서' : group.dept;
                        count = group.members.length;
                      }
                      return Material(
                        color:
                            selected
                                ? theme.colorScheme.primaryContainer
                                : Colors.transparent,
                        borderRadius: BorderRadius.circular(10),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(10),
                          onTap: () {
                            setState(() {
                              _selectedGroupIndex = index;
                            });
                            // 부서 변경 시 우측 리스트 스크롤을 맨 위로 (프레임 이후 안전하게)
                            WidgetsBinding.instance.addPostFrameCallback((_) {
                              if (!mounted) return;
                              if (_usersScrollController.hasClients) {
                                _usersScrollController.jumpTo(0);
                              }
                            });
                          },
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: Sizes.size12,
                              vertical: Sizes.size10,
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    '$title ($count)',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                                if (selectedCount > 0) ...[
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: theme.colorScheme.primary
                                          .withValues(alpha: 0.10),
                                      borderRadius: BorderRadius.circular(999),
                                    ),
                                    child: Text(
                                      '$selectedCount',
                                      style: theme.textTheme.labelSmall
                                          ?.copyWith(
                                            fontWeight: FontWeight.w800,
                                            color: theme.colorScheme.primary,
                                          ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                    separatorBuilder: (_, __) => Gaps.v8,
                    itemCount: groups.length + 1,
                  ),
                ),
                // Row 안에서 Divider가 높이를 제대로 가지도록 강제
                const SizedBox(
                  height: double.infinity,
                  child: VerticalDivider(width: 1, thickness: 1),
                ),
                Expanded(
                  child: Scrollbar(
                    controller: _usersScrollController,
                    thumbVisibility: true,
                    child: ListView.separated(
                      controller: _usersScrollController,
                      primary: false,
                      physics: const ClampingScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(
                        Sizes.size8,
                        0,
                        Sizes.size16,
                        0,
                      ),
                      itemCount: filtered.length,
                      separatorBuilder:
                          (_, __) => Divider(
                            color: Colors.black.withValues(alpha: 0.06),
                            height: 1,
                          ),
                      itemBuilder: (context, index) {
                        final user = filtered[index];
                        final checked = _selectedIds.contains(user.id);
                        final position = user.position.trim();

                        // 체크박스 제거: 행 전체 탭으로 선택  선택 시 배경/체크 아이콘 표시
                        return Material(
                          color:
                              checked
                                  ? theme.colorScheme.primaryContainer
                                      .withValues(alpha: 0.6)
                                  : Colors.transparent,
                          borderRadius: BorderRadius.circular(10),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(10),
                            onTap: () => _toggleUser(user.id, !checked),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 8,
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Row(
                                      children: [
                                        Gaps.h6,
                                        Flexible(
                                          child: Text(
                                            user.empName,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: theme.textTheme.bodyMedium
                                                ?.copyWith(
                                                  fontWeight: FontWeight.w700,
                                                  fontSize: 14,
                                                  color:
                                                      checked
                                                          ? theme
                                                              .colorScheme
                                                              .onPrimaryContainer
                                                          : theme
                                                              .colorScheme
                                                              .onSurface,
                                                ),
                                          ),
                                        ),
                                        if (position.isNotEmpty) ...[
                                          Gaps.h12,
                                          Text(
                                            position,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: theme.textTheme.bodySmall
                                                ?.copyWith(
                                                  fontSize: 12,
                                                  color:
                                                      checked
                                                          ? theme
                                                              .colorScheme
                                                              .onPrimaryContainer
                                                              .withValues(
                                                                alpha: 0.85,
                                                              )
                                                          : theme
                                                              .colorScheme
                                                              .onSurfaceVariant,
                                                ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                  if (checked) ...[
                                    Icon(
                                      Icons.check,
                                      size: 14,
                                      color:
                                          theme.colorScheme.onPrimaryContainer,
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _selectedIds.isEmpty ? null : _confirm,
                child: Text('선택 완료 (${_selectedIds.length}명)'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
