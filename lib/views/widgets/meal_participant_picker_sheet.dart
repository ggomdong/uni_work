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
  String _query = '';

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
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
    super.dispose();
  }

  bool _matchesQuery(MealOptionUser user) {
    if (_query.isEmpty) return true;
    return user.empName.toLowerCase().contains(_query) ||
        user.dept.toLowerCase().contains(_query);
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

  void _toggleGroup(MealOptionGroup group) {
    final ids = group.members.map((m) => m.id).toList();
    final allSelected = ids.every(_selectedIds.contains);
    setState(() {
      if (allSelected) {
        for (final id in ids) {
          _selectedIds.remove(id);
        }
      } else {
        for (final id in ids) {
          _selectedIds.add(id);
        }
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
    final theme = Theme.of(context);
    final filtered = widget.users
        .where((u) => _matchesQuery(u))
        .toList(growable: false);

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
                hintText: '이름/부서 검색',
                prefixIcon: const Icon(Icons.search),
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
          // if (widget.groups.isNotEmpty) ...[
          //   Gaps.v12,
          //   Padding(
          //     padding: const EdgeInsets.symmetric(horizontal: Sizes.size20),
          //     child: Text(
          //       '부서별 전체 선택',
          //       style: theme.textTheme.labelLarge?.copyWith(
          //         fontWeight: FontWeight.w700,
          //       ),
          //     ),
          //   ),
          //   Gaps.v8,
          //   SizedBox(
          //     height: 120,
          //     child: ListView.separated(
          //       padding: const EdgeInsets.symmetric(horizontal: Sizes.size16),
          //       itemBuilder: (context, index) {
          //         final group = widget.groups[index];
          //         final ids = group.members.map((m) => m.id).toList();
          //         final allSelected =
          //             ids.isNotEmpty && ids.every(_selectedIds.contains);
          //         final title = group.dept.isEmpty ? '부서' : group.dept;
          //         return Row(
          //           children: [
          //             Expanded(
          //               child: Text(
          //                 '$title (${group.members.length})',
          //                 style: const TextStyle(fontWeight: FontWeight.w600),
          //               ),
          //             ),
          //             TextButton(
          //               onPressed: () => _toggleGroup(group),
          //               child: Text(allSelected ? '전체 해제' : '전체 선택'),
          //             ),
          //           ],
          //         );
          //       },
          //       separatorBuilder: (_, __) => Divider(
          //         color: Colors.black.withValues(alpha: 0.06),
          //         height: 1,
          //       ),
          //       itemCount: widget.groups.length,
          //     ),
          //   ),
          // ],
          Gaps.v8,
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: Sizes.size16),
              itemBuilder: (context, index) {
                final user = filtered[index];
                final checked = _selectedIds.contains(user.id);
                final subtitle =
                    '${user.dept.isEmpty ? '-' : user.dept} · ${user.position.isEmpty ? '-' : user.position}';
                return CheckboxListTile(
                  value: checked,
                  controlAffinity: ListTileControlAffinity.leading,
                  onChanged: (value) => _toggleUser(user.id, value ?? false),
                  title: Text(
                    user.empName,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  subtitle: Text(subtitle),
                  contentPadding: EdgeInsets.zero,
                );
              },
              separatorBuilder:
                  (_, __) => Divider(
                    color: Colors.black.withValues(alpha: 0.06),
                    height: 1,
                  ),
              itemCount: filtered.length,
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    '선택 ${_selectedIds.length}명',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                FilledButton(onPressed: _confirm, child: const Text('확인')),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
