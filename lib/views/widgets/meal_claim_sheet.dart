import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../constants/gaps.dart';
import '../../constants/sizes.dart';
import '../../repos/meal_repo.dart';
import '../../utils.dart';
import './meal_date_picker_sheet.dart';
import './meal_types.dart';

enum MealClaimSheetMode { view, edit }

Future<void> showMealClaimSheet({
  required BuildContext context,
  required MealClaimSheetMode mode,
  MealClaimItem? initial,
  ValueChanged<MealClaimItem>? onDeleted,
  ValueChanged<MealClaimItem>? onSaved,
}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder:
        (context) => MealClaimSheet(
          mode: mode,
          initial: initial,
          onDeleted: onDeleted,
          onSaved: onSaved,
        ),
  );
}

class MealClaimSheet extends ConsumerStatefulWidget {
  final MealClaimSheetMode mode;
  final MealClaimItem? initial;
  final ValueChanged<MealClaimItem>? onDeleted;
  final ValueChanged<MealClaimItem>? onSaved;

  const MealClaimSheet({
    super.key,
    required this.mode,
    this.initial,
    this.onDeleted,
    this.onSaved,
  });

  @override
  ConsumerState<MealClaimSheet> createState() => _MealClaimSheetState();
}

class _MealClaimSheetState extends ConsumerState<MealClaimSheet> {
  // Form
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  late MealClaimSheetMode _mode;
  late bool _isNew;
  late MealClaimItem _item;
  Future<MealClaimItem>? _detailFuture;

  late TextEditingController _usedDateController;
  late TextEditingController _approvalController;
  late TextEditingController _merchantController;
  late TextEditingController _amountController;

  @override
  void initState() {
    super.initState();
    _mode = widget.mode;
    _isNew = widget.initial == null;
    _item = widget.initial ?? _buildNewItem();
    if (!_isNew && _item.id != 0) {
      _detailFuture = _fetchDetail();
    }

    _usedDateController = TextEditingController(
      text: DateFormat('yyyy-MM-dd').format(_item.usedDate),
    );
    _approvalController = TextEditingController(text: _item.approvalNo);
    _merchantController = TextEditingController(text: _item.merchantName);
    _amountController = TextEditingController(
      text: _item.totalAmount == 0 ? '' : _item.totalAmount.toString(),
    );
  }

  @override
  void dispose() {
    _usedDateController.dispose();
    _approvalController.dispose();
    _merchantController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  bool get _isEdit => _mode == MealClaimSheetMode.edit;

  MealClaimItem _buildNewItem() {
    final now = DateTime.now();
    final usedDate = DateTime(now.year, now.month, now.day);
    final ym = DateFormat('yyyyMM').format(DateTime(now.year, now.month, 1));

    return MealClaimItem(
      id: 0,
      ym: ym,
      usedDate: usedDate,
      merchantName: '',
      approvalNo: '',
      totalAmount: 0,
      myAmount: 0,
      createdByName: '나',
      canEdit: true,
      canDelete: true,
      participantsCount: 1,
      participantsSum: 0,
      participants: const [MealParticipant(name: '나', amount: 0)],
    );
  }

  void _switchToEdit() {
    setState(() => _mode = MealClaimSheetMode.edit);
  }

  void _switchToView({MealClaimItem? updated}) {
    setState(() {
      if (updated != null) _item = updated;
      _mode = MealClaimSheetMode.view;
      _isNew = false;
    });
  }

  // 로그인 폼 톤과 맞춘 Decoration
  InputDecoration _decoration(String label, {String? hint, Widget? suffix}) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      suffixIcon: suffix,
      filled: true,
      fillColor: Colors.black.withValues(alpha: 0.03),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(
          color: Colors.black.withValues(alpha: 0.10),
          width: 1,
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Theme.of(context).primaryColor, width: 2),
      ),
    );
  }

  Future<void> _pickUsedDate() async {
    final initial =
        DateTime.tryParse(_usedDateController.text.trim()) ?? _item.usedDate;

    final picked = await showMealDatePickerSheet(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020, 1, 1),
      lastDate: DateTime(2100, 12, 31),
    );

    if (picked != null) {
      _usedDateController.text = DateFormat('yyyy-MM-dd').format(picked);
      if (mounted) setState(() {});
    }
  }

  MealClaimItem _buildItemFromForm() {
    final usedDate =
        DateTime.tryParse(_usedDateController.text.trim()) ?? _item.usedDate;

    final total = int.tryParse(_amountController.text.trim()) ?? 0;
    final ym = '${usedDate.year}${usedDate.month.toString().padLeft(2, '0')}';

    final baseParticipants =
        _item.participants.isEmpty
            ? const [MealParticipant(name: '나', amount: 0)]
            : _item.participants;

    final myAmount =
        baseParticipants
            .firstWhere(
              (p) => p.name == '나',
              orElse: () => const MealParticipant(name: '나', amount: 0),
            )
            .amount;
    final participantsSum = baseParticipants.fold<int>(
      0,
      (sum, p) => sum + p.amount,
    );

    return _item.copyWith(
      ym: ym,
      usedDate: usedDate,
      approvalNo: _approvalController.text.trim(),
      merchantName: _merchantController.text.trim(),
      totalAmount: total,
      myAmount: myAmount,
      participantsCount: baseParticipants.length,
      participantsSum: participantsSum,
      participants: baseParticipants,
    );
  }

  Future<MealClaimItem> _fetchDetail() async {
    final detail = await ref
        .read(mealRepoProvider)
        .getClaimDetail(claimId: _item.id);

    return detail;
  }

  Widget _buildParticipantsSection({required bool editable}) {
    if (_detailFuture == null) {
      return _buildParticipantsContent(_item.participants, editable: editable);
    }

    return FutureBuilder<MealClaimItem>(
      future: _detailFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildParticipantsLoading();
        }
        if (snapshot.hasError) {
          return _buildParticipantsError(snapshot.error);
        }
        final detail = snapshot.data ?? _item;
        return _buildParticipantsContent(
          detail.participants,
          editable: editable,
        );
      },
    );
  }

  Widget _buildParticipantsLoading() {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: Sizes.size12),
      child: Center(child: CircularProgressIndicator()),
    );
  }

  Widget _buildParticipantsError(Object? error) {
    if (error == null) {
      return const Text('대상자 정보를 불러오지 못했습니다.');
    }
    return Text(
      '${humanizeErrorMessage(error)}\n${error.toString()}',
      style: const TextStyle(color: Colors.redAccent),
    );
  }

  Widget _buildParticipantsContent(
    List<MealParticipant> participants, {
    required bool editable,
  }) {
    if (!editable) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '대상자 분배',
            style: Theme.of(
              context,
            ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w800),
          ),
          Gaps.v8,
          ...participants.map(
            (p) => Padding(
              padding: const EdgeInsets.symmetric(vertical: Sizes.size4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(p.name),
                  Text('${formatMealAmount(p.amount)}원'),
                ],
              ),
            ),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: Text(
            '대상자',
            style: Theme.of(
              context,
            ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w800),
          ),
        ),
        Gaps.v8,
        _ParticipantsCard(
          participants: participants,
          onAdd: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('대상자 추가는 다음 단계에서 구현합니다.')),
            );
          },
        ),
      ],
    );
  }

  void _onSave() {
    final ok = _formKey.currentState?.validate() ?? false;
    if (!ok) return;

    final updated = _buildItemFromForm();
    widget.onSaved?.call(updated);
    _switchToView(updated: updated);
  }

  void _onCancel() {
    if (_isNew) {
      Navigator.of(context).pop();
      return;
    }
    _switchToView();
  }

  Future<void> _confirmDelete() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('삭제 확인'),
          content: const Text('이 내역을 삭제하시겠습니까?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('아니오'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('삭제'),
            ),
          ],
        );
      },
    );

    if (result == true) {
      widget.onDeleted?.call(_item);
      if (mounted) Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.92,
      minChildSize: 0.60,
      maxChildSize: 0.92,
      builder: (context, controller) {
        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.10),
                blurRadius: 18,
                offset: const Offset(0, -8),
              ),
            ],
          ),
          child: ListView(
            controller: controller,
            padding: const EdgeInsets.all(Sizes.size20),
            children: [
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
              Gaps.v16,

              // 헤더
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _isEdit ? (_isNew ? '식대 입력' : '식대 수정') : '식대 상세',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              Gaps.v12,

              // 콘텐츠
              if (!_isEdit)
                _ViewContent(
                  item: _item,
                  participantsSection: _buildParticipantsSection(
                    editable: false,
                  ),
                )
              else
                Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      // ✅ 순서: 사용일 → 승인번호 → 가맹점명 → 총액
                      GestureDetector(
                        onTap: _pickUsedDate,
                        child: AbsorbPointer(
                          child: TextFormField(
                            controller: _usedDateController,
                            decoration: _decoration(
                              '사용일',
                              suffix: Icon(
                                Icons.calendar_month,
                                color: Colors.grey.shade600,
                              ),
                            ),
                            validator: (v) {
                              final text = (v ?? '').trim();
                              if (DateTime.tryParse(text) == null) {
                                return '사용일을 선택해주세요.';
                              }
                              return null;
                            },
                          ),
                        ),
                      ),
                      Gaps.v12,

                      TextFormField(
                        controller: _approvalController,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(8),
                        ],
                        decoration: _decoration('승인번호(8자리)', hint: '선택'),
                        validator: (v) {
                          final t = (v ?? '').trim();
                          if (t.isEmpty) return null; // 선택 항목
                          if (t.length != 8) return '승인번호는 8자리입니다.';
                          return null;
                        },
                      ),
                      Gaps.v12,

                      TextFormField(
                        controller: _merchantController,
                        decoration: _decoration('가맹점명'),
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) {
                            return '가맹점명을 입력해주세요.';
                          }
                          return null;
                        },
                      ),
                      Gaps.v12,

                      TextFormField(
                        controller: _amountController,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        decoration: _decoration('총액', hint: '숫자만 입력'),
                        validator: (v) {
                          final t = (v ?? '').trim();
                          final n = int.tryParse(t);
                          if (n == null || n <= 0) {
                            return '총액을 입력해주세요.';
                          }
                          return null;
                        },
                      ),

                      Gaps.v20,

                      _buildParticipantsSection(editable: true),
                    ],
                  ),
                ),

              Gaps.v24,

              // 하단 액션
              if (!_isEdit)
                _ViewActions(
                  canEdit: _item.canEdit,
                  canDelete: _item.canDelete,
                  onEdit: _switchToEdit,
                  onDelete: _confirmDelete,
                )
              else
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _onCancel,
                        child: const Text('취소'),
                      ),
                    ),
                    Gaps.h12,
                    Expanded(
                      child: FilledButton(
                        onPressed: _onSave,
                        child: const Text('저장'),
                      ),
                    ),
                  ],
                ),

              Gaps.v8,
            ],
          ),
        );
      },
    );
  }
}

/// =======================
/// View Mode (조회)
/// =======================
class _ViewContent extends StatelessWidget {
  final MealClaimItem item;
  final Widget participantsSection;

  const _ViewContent({required this.item, required this.participantsSection});

  @override
  Widget build(BuildContext context) {
    final dateText = DateFormat('yyyy-MM-dd').format(item.usedDate);

    const myName = '김지민';
    final createdBy =
        item.createdByName == '나'
            ? (myName.isNotEmpty ? '나($myName)' : '나')
            : item.createdByName;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _InfoRow(label: '사용일', value: dateText),
        _InfoRow(
          label: '승인번호',
          value: item.approvalNo.isEmpty ? '-' : item.approvalNo,
          isSubtle: true,
        ),
        _InfoRow(label: '가맹점명', value: item.merchantName),
        _InfoRow(label: '총액', value: '${formatMealAmount(item.totalAmount)}원'),
        _InfoRow(label: '본인부담', value: '${formatMealAmount(item.myAmount)}원'),
        Gaps.v16,
        participantsSection,
        Gaps.v16,
        _InfoRow(label: '입력자', value: createdBy),
      ],
    );
  }
}

/// =======================
/// Participants (표시용)
/// =======================
class _ParticipantsCard extends StatelessWidget {
  final List<MealParticipant> participants;
  final VoidCallback onAdd;

  const _ParticipantsCard({required this.participants, required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(Sizes.size12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.black.withValues(alpha: 0.08)),
      ),
      child: Column(
        children: [
          for (final p in participants) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [Text(p.name), Text('${formatMealAmount(p.amount)}원')],
            ),
            Gaps.v8,
          ],
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.person_add_alt_1, size: 18),
              label: const Text('대상자 추가'),
            ),
          ),
        ],
      ),
    );
  }
}

/// =======================
/// Common rows/buttons
/// =======================
class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  final bool isSubtle;

  const _InfoRow({
    required this.label,
    required this.value,
    this.isSubtle = false,
  });

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.bodyMedium;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: Sizes.size6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: style?.copyWith(color: Colors.black54)),
          Flexible(
            child: Text(
              value,
              style: style?.copyWith(
                color: isSubtle ? Colors.black45 : Colors.black87,
                fontWeight: FontWeight.w700,
              ),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }
}

class _ViewActions extends StatelessWidget {
  final bool canEdit;
  final bool canDelete;
  final VoidCallback onEdit;
  final Future<void> Function() onDelete;

  const _ViewActions({
    required this.canEdit,
    required this.canDelete,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    if (!canEdit && !canDelete) {
      return const SizedBox.shrink();
    }

    return Row(
      children: [
        if (canEdit)
          Expanded(
            child: OutlinedButton(onPressed: onEdit, child: const Text('수정')),
          ),
        if (canEdit && canDelete) Gaps.h12,
        if (canDelete)
          Expanded(
            child: OutlinedButton(
              onPressed: () => onDelete(),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.redAccent,
              ),
              child: const Text('삭제'),
            ),
          ),
      ],
    );
  }
}
