import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../app_refresh_service.dart';
import '../constants/gaps.dart';
import '../constants/sizes.dart';
import '../utils.dart';
import './widgets/common_app_bar.dart';
import './widgets/meal_month_header.dart';
import './widgets/meal_summary_card.dart';
import './widgets/meal_my_claim_list.dart';
import './widgets/meal_claim_sheet.dart';
import './widgets/meal_types.dart';
import '../view_models/meal_items_view_model.dart';

class MealScreen extends ConsumerStatefulWidget {
  const MealScreen({super.key});

  @override
  ConsumerState<MealScreen> createState() => _MealScreenState();
}

class _MealScreenState extends ConsumerState<MealScreen> {
  late String _yearMonth;
  final int _refreshTick = 0;
  int _selectedIndex = 0;
  bool _sortDesc = true;

  @override
  void initState() {
    super.initState();
    _yearMonth = DateFormat('yyyyMM').format(DateTime.now());
  }

  List<MealClaimItem> _myClaims(List<MealClaimItem> items) {
    final filtered = items.toList();
    filtered.sort((a, b) {
      final date =
          _sortDesc
              ? b.usedDate.compareTo(a.usedDate)
              : a.usedDate.compareTo(b.usedDate);
      if (date != 0) return date;
      return _sortDesc ? b.id.compareTo(a.id) : a.id.compareTo(b.id);
    });
    return filtered;
  }

  void _changeMonth(int diff) {
    final year = int.parse(_yearMonth.substring(0, 4));
    final month = int.parse(_yearMonth.substring(4, 6));
    final next = DateTime(year, month + diff, 1);
    setState(() {
      _yearMonth = DateFormat('yyyyMM').format(next);
    });
  }

  List<MealClaimItem> _useClaims(List<MealClaimItem> items) {
    final sorted = [...items];
    sorted.sort((a, b) {
      final date =
          _sortDesc
              ? b.usedDate.compareTo(a.usedDate)
              : a.usedDate.compareTo(b.usedDate);
      if (date != 0) return date;
      return _sortDesc ? b.id.compareTo(a.id) : a.id.compareTo(b.id);
    });
    return sorted;
  }

  void _switchToUseTab() {
    setState(() {
      _selectedIndex = 1;
    });
  }

  Future<void> _onRefresh() async {
    await _refreshAll(ym: _yearMonth);
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('식대 정보를 갱신했어요.')));
  }

  Future<void> _refreshAll({required String ym}) async {
    final createdQuery = _mealQueryParam(ym: ym, type: MealItemsType.created);
    final usedQuery = _mealQueryParam(ym: ym, type: MealItemsType.used);
    final ymRecord = (
      year: int.parse(ym.substring(0, 4)),
      month: int.parse(ym.substring(4, 6)),
    );
    await ref
        .read(appRefreshServiceProvider)
        .refreshAll(ym: ymRecord, mealQueries: [createdQuery, usedQuery]);
  }

  String _mealQueryParam({required String ym, required MealItemsType type}) {
    return '$ym|${type.name}';
  }

  void _openClaimSheet({
    MealClaimItem? item,
    MealClaimSheetMode mode = MealClaimSheetMode.view,
  }) {
    final oldYm = item?.ym ?? _yearMonth;
    showMealClaimSheet(
      context: context,
      mode: mode,
      initial: item,
      onDeleted: (deleted) {
        unawaited(
          _refreshAll(ym: deleted.ym.isEmpty ? _yearMonth : deleted.ym),
        );
      },
      onSaved: (saved) {
        final newYm = saved.ym.isEmpty ? _yearMonth : saved.ym;
        unawaited(
          Future.wait([
            _refreshAll(ym: newYm),
            if (oldYm != newYm) _refreshAll(ym: oldYm),
          ]),
        );
      },
    );
  }

  void _onPickMonth() {
    _openMonthPicker();
  }

  List<String> _buildSelectableMonths() {
    // 시작: 2025-01 고정
    const startYear = 2025;
    const startMonth = 1;

    // 끝: 실제 현재월(오늘 기준)
    final now = DateTime.now();
    final end = DateTime(now.year, now.month, 1);

    final start = DateTime(startYear, startMonth, 1);

    // start ~ end 월 개수 계산
    final totalMonths =
        (end.year - start.year) * 12 + (end.month - start.month) + 1;

    // 월 리스트 생성 (오래된->최신). UI에서 최신이 위면 reverse 하거나 정렬.
    return List.generate(totalMonths, (i) {
      final d = DateTime(start.year, start.month + i, 1);
      return DateFormat('yyyyMM').format(d);
    });
  }

  void _openMonthPicker() {
    final months = _buildSelectableMonths().reversed.toList();
    final platform = Theme.of(context).platform;
    if (platform == TargetPlatform.iOS) {
      showCupertinoModalPopup<void>(
        context: context,
        builder: (popupContext) {
          return SafeArea(
            top: false,
            child: Align(
              alignment: Alignment.bottomCenter,
              child: FractionallySizedBox(
                heightFactor: 0.8,
                child: Material(
                  color: Colors.transparent,
                  child: _MonthPickerSheet(
                    months: months,
                    current: _yearMonth,
                    onSelect: (ym) {
                      setState(() {
                        _yearMonth = ym;
                      });
                      Navigator.of(popupContext, rootNavigator: true).pop();
                    },
                    onClose:
                        () =>
                            Navigator.of(
                              popupContext,
                              rootNavigator: true,
                            ).pop(),
                  ),
                ),
              ),
            ),
          );
        },
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return SafeArea(
          child: _MonthPickerSheet(
            months: months,
            current: _yearMonth,
            onSelect: (ym) {
              setState(() {
                _yearMonth = ym;
              });
              Navigator.of(context).pop();
            },
            onClose: () => Navigator.of(context).pop(),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final query = MealItemsQuery(
      ym: _yearMonth,
      type: _selectedIndex == 0 ? MealItemsType.created : MealItemsType.used,
    );
    final itemsAsync = ref.watch(mealItemsProvider(query));

    return Scaffold(
      appBar: CommonAppBar(
        actions: [
          IconButton(
            tooltip: '새로고침',
            onPressed: _onRefresh,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(Sizes.size16),
          children: [
            Gaps.v32,
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: Sizes.size16,
                vertical: Sizes.size12,
              ),
              decoration: BoxDecoration(
                color: Theme.of(context).primaryColor.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: Theme.of(context).primaryColor.withValues(alpha: 0.2),
                ),
              ),
              child: Column(
                children: [
                  MealMonthHeader(
                    yearMonth: _yearMonth,
                    onPrev: () => _changeMonth(-1),
                    onNext: () => _changeMonth(1),
                    onPick: _onPickMonth,
                  ),
                  const Divider(height: Sizes.size16),
                  MealSummaryCard(ym: _yearMonth, onUsedTap: _switchToUseTab),
                ],
              ),
            ),
            Gaps.v12,
            Row(
              children: [
                Expanded(
                  child: CupertinoSlidingSegmentedControl<int>(
                    groupValue: _selectedIndex,
                    children: const {
                      0: Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        child: Text('입력내역'),
                      ),
                      1: Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        child: Text('사용내역'),
                      ),
                    },
                    onValueChanged: (value) {
                      if (value == null) return;
                      setState(() {
                        _selectedIndex = value;
                      });
                    },
                  ),
                ),
                Gaps.h8,
                IconButton(
                  tooltip: _sortDesc ? '최신순' : '오래된순',
                  onPressed: () {
                    setState(() {
                      _sortDesc = !_sortDesc;
                    });
                  },
                  icon: const Icon(Icons.swap_vert),
                ),
              ],
            ),
            Gaps.v20,
            itemsAsync.when(
              data: (items) {
                final list =
                    _selectedIndex == 0 ? _myClaims(items) : _useClaims(items);
                return MealMyClaimList(
                  items: list,
                  onItemTap: (item) => _openClaimSheet(item: item),
                );
              },
              loading:
                  () => const Center(
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: Sizes.size20),
                      child: CircularProgressIndicator(),
                    ),
                  ),
              error:
                  (error, stack) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: Sizes.size12),
                    child: Text(
                      '${humanizeErrorMessage(error)}\n${error.toString()}',
                      style: const TextStyle(color: Colors.redAccent),
                    ),
                  ),
            ),
            Gaps.v20,
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openClaimSheet(mode: MealClaimSheetMode.edit),
        backgroundColor: Theme.of(context).primaryColor,
        elevation: 3,
        shape: const CircleBorder(),
        tooltip: '입력',
        child: const Icon(
          Icons.add,
          color: Colors.white,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

class _MonthPickerSheet extends StatelessWidget {
  final List<String> months;
  final String current;
  final ValueChanged<String> onSelect;
  final VoidCallback onClose;

  const _MonthPickerSheet({
    required this.months,
    required this.current,
    required this.onSelect,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return _SheetShell(
      title: '월 선택',
      onClose: onClose,
      child: Expanded(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: Sizes.size20),
          child: ListView.separated(
            itemCount: months.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final ym = months[index];
              final isSelected = ym == current;
              return ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(
                  formatYearMonthDisplay(ym),
                  style: TextStyle(
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
                trailing:
                    isSelected
                        ? Icon(
                          Icons.check,
                          color: Theme.of(context).primaryColor,
                        )
                        : null,
                onTap: () => onSelect(ym),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _SheetShell extends StatelessWidget {
  final String title;
  final VoidCallback onClose;
  final Widget child;

  const _SheetShell({
    required this.title,
    required this.onClose,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          Gaps.v8,
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          Gaps.v16,
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: Sizes.size20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                IconButton(onPressed: onClose, icon: const Icon(Icons.close)),
              ],
            ),
          ),
          Gaps.v8,
          child,
          Gaps.v12,
        ],
      ),
    );
  }
}
