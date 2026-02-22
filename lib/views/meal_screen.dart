import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:intl/intl.dart';
import '../constants/gaps.dart';
import '../constants/sizes.dart';
import './widgets/common_app_bar.dart';
import './widgets/meal_month_header.dart';
import './widgets/meal_summary_card.dart';
import './widgets/meal_my_claim_list.dart';
import './widgets/meal_claim_sheet.dart';
import './widgets/meal_types.dart';

class MealScreen extends StatefulWidget {
  const MealScreen({super.key});

  @override
  State<MealScreen> createState() => _MealScreenState();
}

class _MealScreenState extends State<MealScreen> {
  String _yearMonth = '202602';
  late List<MealClaimItem> _items;
  late MealSummary _summary;
  int _refreshTick = 0;
  int _selectedIndex = 0;
  bool _sortDesc = true;

  @override
  void initState() {
    super.initState();
    _loadDummyData();
  }

  void _loadDummyData() {
    _items = _buildDummyItems();
    _summary = _buildSummary();
  }

  List<MealClaimItem> get _myClaims {
    final filtered = _items.where((e) => e.createdByName == '나').toList();
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

  MealSummary _buildSummary() {
    const totalAmount = 300000;
    final usedAmount = _items.fold<int>(0, (sum, e) => sum + e.myAmount);
    return MealSummary(
      ym: _yearMonth,
      totalAmount: totalAmount,
      usedAmount: usedAmount,
      balance: totalAmount - usedAmount,
      claimCount: _items.length,
    );
  }

  void _refreshSummary() {
    setState(() {
      _summary = _buildSummary();
    });
  }

  void _changeMonth(int diff) {
    final year = int.parse(_yearMonth.substring(0, 4));
    final month = int.parse(_yearMonth.substring(4, 6));
    final next = DateTime(year, month + diff, 1);
    setState(() {
      _yearMonth = DateFormat('yyyyMM').format(next);
      _summary = _buildSummary();
    });
  }

  List<MealClaimItem> get _useClaims {
    final sorted = [..._items];
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

  void _onRefresh() {
    setState(() {
      _refreshTick++;
      _loadDummyData();
    });
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('새로고침 완료 ($_refreshTick)')));
  }

  void _openClaimSheet({
    MealClaimItem? item,
    MealClaimSheetMode mode = MealClaimSheetMode.view,
  }) {
    showMealClaimSheet(
      context: context,
      mode: mode,
      initial: item,
      onDeleted: (deleted) {
        setState(() {
          _items.removeWhere((e) => e.id == deleted.id);
        });
        _refreshSummary();
      },
      onSaved: (saved) {
        if (saved.id == 0) {
          final nextId =
              _items.isEmpty
                  ? 1
                  : _items.map((e) => e.id).reduce((a, b) => a > b ? a : b) + 1;
          final inserted = saved.copyWith(id: nextId);
          setState(() {
            _items.insert(0, inserted);
          });
        } else {
          setState(() {
            final index = _items.indexWhere((e) => e.id == saved.id);
            if (index != -1) {
              _items[index] = saved;
            }
          });
        }
        _refreshSummary();
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
                        _summary = _buildSummary();
                      });
                      Navigator.of(popupContext, rootNavigator: true).pop();
                    },
                    onClose: () =>
                        Navigator.of(popupContext, rootNavigator: true).pop(),
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
                _summary = _buildSummary();
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
                  MealSummaryCard(
                    summary: _summary,
                    onUsedTap: _switchToUseTab,
                  ),
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
            MealMyClaimList(
              items: _selectedIndex == 0 ? _myClaims : _useClaims,
              onItemTap: (item) => _openClaimSheet(item: item),
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
        child: const Icon(Icons.restaurant_menu, color: Colors.white),
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
                IconButton(
                  onPressed: onClose,
                  icon: const Icon(Icons.close),
                ),
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

List<MealClaimItem> _buildDummyItems() {
  return [
    MealClaimItem(
      id: 120,
      ym: '202602',
      usedDate: DateTime(2026, 2, 1),
      merchantName: '담소식당',
      approvalNo: '10293847',
      totalAmount: 56000,
      myAmount: 28000,
      createdByName: '나',
      canEdit: true,
      canDelete: true,
      participants: const [
        MealParticipant(name: '나', amount: 28000),
        MealParticipant(name: '김영희', amount: 28000),
      ],
    ),
    MealClaimItem(
      id: 119,
      ym: '202602',
      usedDate: DateTime(2026, 2, 2),
      merchantName: '분식공간',
      approvalNo: '48392015',
      totalAmount: 32000,
      myAmount: 16000,
      createdByName: '박지민',
      canEdit: false,
      canDelete: false,
      participants: const [
        MealParticipant(name: '나', amount: 16000),
        MealParticipant(name: '박지민', amount: 16000),
      ],
    ),
    MealClaimItem(
      id: 118,
      ym: '202602',
      usedDate: DateTime(2026, 2, 3),
      merchantName: '현대백반',
      approvalNo: '73019284',
      totalAmount: 45000,
      myAmount: 15000,
      createdByName: '나',
      canEdit: true,
      canDelete: true,
      participants: const [
        MealParticipant(name: '나', amount: 15000),
        MealParticipant(name: '이수진', amount: 15000),
        MealParticipant(name: '오민석', amount: 15000),
      ],
    ),
    MealClaimItem(
      id: 117,
      ym: '202602',
      usedDate: DateTime(2026, 2, 4),
      merchantName: '서촌국수',
      approvalNo: '39582714',
      totalAmount: 27000,
      myAmount: 9000,
      createdByName: '오민석',
      canEdit: false,
      canDelete: false,
      participants: const [
        MealParticipant(name: '나', amount: 9000),
        MealParticipant(name: '오민석', amount: 9000),
        MealParticipant(name: '한지우', amount: 9000),
      ],
    ),
    MealClaimItem(
      id: 116,
      ym: '202602',
      usedDate: DateTime(2026, 2, 5),
      merchantName: '라운지카페',
      approvalNo: '56018392',
      totalAmount: 18000,
      myAmount: 18000,
      createdByName: '나',
      canEdit: true,
      canDelete: true,
      participants: const [MealParticipant(name: '나', amount: 18000)],
    ),
    MealClaimItem(
      id: 115,
      ym: '202602',
      usedDate: DateTime(2026, 2, 7),
      merchantName: '국밥집',
      approvalNo: '28491037',
      totalAmount: 36000,
      myAmount: 12000,
      createdByName: '김영희',
      canEdit: false,
      canDelete: false,
      participants: const [
        MealParticipant(name: '나', amount: 12000),
        MealParticipant(name: '김영희', amount: 12000),
        MealParticipant(name: '정현우', amount: 12000),
      ],
    ),
    MealClaimItem(
      id: 114,
      ym: '202602',
      usedDate: DateTime(2026, 2, 9),
      merchantName: '파스타룸',
      approvalNo: '40291857',
      totalAmount: 78000,
      myAmount: 26000,
      createdByName: '나',
      canEdit: true,
      canDelete: false,
      participants: const [
        MealParticipant(name: '나', amount: 26000),
        MealParticipant(name: '박지민', amount: 26000),
        MealParticipant(name: '한지우', amount: 26000),
      ],
    ),
    MealClaimItem(
      id: 113,
      ym: '202602',
      usedDate: DateTime(2026, 2, 10),
      merchantName: '도시락박스',
      approvalNo: '82019453',
      totalAmount: 24000,
      myAmount: 12000,
      createdByName: '한지우',
      canEdit: false,
      canDelete: false,
      participants: const [
        MealParticipant(name: '나', amount: 12000),
        MealParticipant(name: '한지우', amount: 12000),
      ],
    ),
    MealClaimItem(
      id: 112,
      ym: '202602',
      usedDate: DateTime(2026, 2, 12),
      merchantName: '가든샐러드',
      approvalNo: '50291736',
      totalAmount: 33000,
      myAmount: 11000,
      createdByName: '나',
      canEdit: true,
      canDelete: true,
      participants: const [
        MealParticipant(name: '나', amount: 11000),
        MealParticipant(name: '정현우', amount: 11000),
        MealParticipant(name: '이수진', amount: 11000),
      ],
    ),
    MealClaimItem(
      id: 111,
      ym: '202602',
      usedDate: DateTime(2026, 2, 13),
      merchantName: '스시하우스',
      approvalNo: '12930458',
      totalAmount: 92000,
      myAmount: 23000,
      createdByName: '정현우',
      canEdit: false,
      canDelete: false,
      participants: const [
        MealParticipant(name: '나', amount: 23000),
        MealParticipant(name: '정현우', amount: 23000),
        MealParticipant(name: '김영희', amount: 23000),
        MealParticipant(name: '오민석', amount: 23000),
      ],
    ),
    MealClaimItem(
      id: 110,
      ym: '202602',
      usedDate: DateTime(2026, 2, 14),
      merchantName: '브런치테이블',
      approvalNo: '64190283',
      totalAmount: 52000,
      myAmount: 26000,
      createdByName: '나',
      canEdit: true,
      canDelete: true,
      participants: const [
        MealParticipant(name: '나', amount: 26000),
        MealParticipant(name: '박지민', amount: 26000),
      ],
    ),
    MealClaimItem(
      id: 109,
      ym: '202602',
      usedDate: DateTime(2026, 2, 15),
      merchantName: '고기한상',
      approvalNo: '75820391',
      totalAmount: 84000,
      myAmount: 21000,
      createdByName: '이수진',
      canEdit: false,
      canDelete: false,
      participants: const [
        MealParticipant(name: '나', amount: 21000),
        MealParticipant(name: '이수진', amount: 21000),
        MealParticipant(name: '정현우', amount: 21000),
        MealParticipant(name: '김영희', amount: 21000),
      ],
    ),
  ];
}
