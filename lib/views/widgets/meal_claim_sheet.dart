import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../constants/gaps.dart';
import '../../constants/sizes.dart';
import '../../repos/meal_repo.dart';
import '../../utils.dart';
import './app_toast.dart';
import './meal_date_picker_sheet.dart';
import './meal_participant_picker_sheet.dart';
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
  bool _deleting = false;
  bool _saving = false;
  bool _autoDistribute = false;
  int? _editingUserId;
  late final ParticipantAmountControllerManager _participantAmountManager;

  // 편집 시작 시점의 원본 스냅샷(취소 시 원복용)
  MealClaimItem? _editOrigin;

  // 대상자 금액 선택 시 포커스를 위한 코드
  final Map<int, FocusNode> _participantFocusNodes = {};

  FocusNode _focusNodeForParticipant(int userId) =>
      _participantFocusNodes.putIfAbsent(userId, () => FocusNode());

  // 총액 입력/표기 시 콤마 포맷을 위한 코드
  late final FocusNode _totalAmountFocusNode;
  int _parseMoney(String s) => int.tryParse(s.replaceAll(',', '').trim()) ?? 0;
  String _formatTotalAmountText(int amount) =>
      amount <= 0 ? '' : formatMealAmount(amount);

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
      text: _formatTotalAmountText(_item.totalAmount),
    );
    _totalAmountFocusNode = FocusNode();
    _totalAmountFocusNode.addListener(_onTotalAmountFocusChanged);
    _participantAmountManager = ParticipantAmountControllerManager();
    _amountController.addListener(_handleTotalAmountChange);
    _participantAmountManager.syncFromParticipants(_item.participants);
  }

  @override
  void dispose() {
    _usedDateController.dispose();
    _approvalController.dispose();
    _merchantController.dispose();
    _amountController.dispose();
    _totalAmountFocusNode
      ..removeListener(_onTotalAmountFocusChanged)
      ..dispose();
    _participantAmountManager.disposeAll();

    for (final n in _participantFocusNodes.values) {
      n.dispose();
    }
    _participantFocusNodes.clear();

    super.dispose();
  }

  bool get _isEdit => _mode == MealClaimSheetMode.edit;

  // Keyboard 외의 영역 클릭시 Keyboard가 사라지도록 처리
  void _onScaffoldTap() {
    FocusScope.of(context).unfocus();
  }

  Future<T?> _openSheetWithFocusReset<T>(Future<T?> Function() open) async {
    // FocusScope의 “마지막 포커스 기억”까지 끊음
    FocusScope.of(context).unfocus(disposition: UnfocusDisposition.scope);

    final result = await open();
    if (!mounted) return result;

    // pop 직후 자동 복원 타이밍을 한 프레임 뒤에 끊어줌
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      FocusScope.of(context).unfocus(disposition: UnfocusDisposition.scope);
    });

    return result;
  }

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
      createdById: 0,
      createdByName: '',
      canEdit: true,
      canDelete: true,
      participantsCount: 0,
      participantsSum: 0,
      participants: const <MealParticipant>[],
    );
  }

  void _syncControllersFromItem(MealClaimItem item) {
    _usedDateController.text = DateFormat('yyyy-MM-dd').format(item.usedDate);
    _approvalController.text = item.approvalNo;
    _merchantController.text = item.merchantName;
    _amountController.text = _formatTotalAmountText(item.totalAmount);
  }

  void _onTotalAmountFocusChanged() {
    final currentText = _amountController.text;
    if (_totalAmountFocusNode.hasFocus) {
      final unformatted = currentText.replaceAll(',', '');
      if (currentText != unformatted) {
        _amountController.value = _amountController.value.copyWith(
          text: unformatted,
          selection: TextSelection.collapsed(offset: unformatted.length),
          composing: TextRange.empty,
        );
      }
      return;
    }

    final formatted = _formatTotalAmountText(_parseMoney(currentText));
    if (currentText != formatted) {
      _amountController.value = _amountController.value.copyWith(
        text: formatted,
        selection: TextSelection.collapsed(offset: formatted.length),
        composing: TextRange.empty,
      );
    }

    _handleTotalAmountChange();
  }

  void _switchToEdit() {
    // 취소 시 원복할 수 있도록 "편집 시작 시점" 원본을 저장
    _editOrigin = _item;
    _syncControllersFromItem(_item);
    setState(() {
      _participantAmountManager.syncFromParticipants(_item.participants);
      _editingUserId = null;
      _mode = MealClaimSheetMode.edit;
    });
  }

  void _switchToView({MealClaimItem? updated}) {
    setState(() {
      if (updated != null) {
        _item = updated;
        _detailFuture = Future.value(updated);
      }
      _mode = MealClaimSheetMode.view;
      _editingUserId = null;
      _isNew = false;
      _editOrigin = null; // 저장/전환 완료 시 스냅샷 해제
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

    final picked = await _openSheetWithFocusReset<DateTime?>(() {
      return showMealDatePickerSheet(
        context: context,
        initialDate: initial,
        firstDate: DateTime(2020, 1, 1),
        lastDate: DateTime(2100, 12, 31),
      );
    });

    if (picked != null) {
      _usedDateController.text = DateFormat('yyyy-MM-dd').format(picked);
      if (mounted) setState(() {});
    }
  }

  MealClaimItem _buildItemFromForm() {
    final usedDate =
        DateTime.tryParse(_usedDateController.text.trim()) ?? _item.usedDate;

    final total = _parseMoney(_amountController.text);
    final ym = '${usedDate.year}${usedDate.month.toString().padLeft(2, '0')}';

    final baseParticipants = _item.participants;
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
      participantsCount: baseParticipants.length,
      participantsSum: participantsSum,
      participants: baseParticipants,
    );
  }

  Future<MealClaimItem> _fetchDetail() async {
    final detail = await ref
        .read(mealRepoProvider)
        .getClaimDetail(claimId: _item.id);

    if (mounted) {
      setState(() {
        _item = detail;
        _participantAmountManager.syncFromParticipants(_item.participants);
      });
    }

    return detail;
  }

  Widget _buildParticipantsSection({required bool editable}) {
    if (editable) {
      return _buildParticipantsContent(_item.participants, editable: true);
    }
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
            '대상자',
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
        Builder(
          builder: (context) {
            final theme = Theme.of(context);
            final sum = _sumParticipants(participants);
            final total = _currentTotalAmount();
            final sumColor = sum == total ? Colors.black54 : Colors.redAccent;

            return Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: Row(
                        children: [
                          Text(
                            '대상자',
                            style: theme.textTheme.labelLarge?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          IconButton(
                            tooltip: '대상자 추가',
                            onPressed: _onPickParticipants,
                            icon: const Icon(Icons.person_add_alt_1, size: 18),
                            style: IconButton.styleFrom(
                              foregroundColor:
                                  Theme.of(context).colorScheme.primary,
                            ),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(
                              minWidth: 32,
                              minHeight: 32,
                            ),
                            visualDensity: VisualDensity.compact,
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: SegmentedButton<bool>(
                          segments: const [
                            ButtonSegment(value: false, label: Text('수동')),
                            ButtonSegment(value: true, label: Text('균등')),
                          ],
                          style: ButtonStyle(
                            visualDensity: VisualDensity.compact,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            padding: WidgetStateProperty.all(
                              const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 6,
                              ),
                            ),
                            minimumSize: WidgetStateProperty.all(
                              const Size(0, 32),
                            ),
                            textStyle: WidgetStateProperty.all(
                              theme.textTheme.bodySmall?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            shape: WidgetStateProperty.all(
                              RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                          ),
                          selected: {_autoDistribute},
                          showSelectedIcon: false,
                          onSelectionChanged: (set) {
                            final next = set.first;
                            if (next == _autoDistribute) return;

                            if (next && _item.participants.isNotEmpty) {
                              final total = _currentTotalAmount();
                              final redistributed = _distributeEvenly(
                                _item.participants,
                                total,
                              );
                              setState(() {
                                _autoDistribute = true;
                                _item = _item.copyWith(
                                  totalAmount: total,
                                  participants: redistributed,
                                  participantsCount: redistributed.length,
                                  participantsSum: _sumParticipants(
                                    redistributed,
                                  ),
                                );
                              });
                              _participantAmountManager.syncFromParticipants(
                                redistributed,
                              );
                              return;
                            }

                            setState(() => _autoDistribute = next);
                          },
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 3,
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: Text(
                          '${formatMealAmount(sum)}원 / ${formatMealAmount(total)}원',
                          maxLines: 1,
                          softWrap: false,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: sumColor,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            );
          },
        ),
        Gaps.v8,
        _ParticipantsEditor(
          participants: participants,
          onRemove: _removeParticipant,
          onSelectEditingUser: _selectEditingUser,
          onStopEditingUser: _stopEditingUser,
          editingUserId: _editingUserId,
          ensureController:
              (p) => _participantAmountManager.controllerFor(p.userId),
          ensureFocusNode: (p) => _focusNodeForParticipant(p.userId),
          onAmountChanged: _onParticipantAmountChanged,
        ),
      ],
    );
  }

  int _currentTotalAmount() {
    final raw = _amountController.text.trim();
    // 사용자가 지워서 빈값이면 0 (fallback 금지)
    if (raw.isEmpty) return 0;

    final parsed = _parseMoney(raw);
    // "수정 모드에서 입력이 0이 되는 케이스"에만 fallback
    // (신규 입력은 _isNew=true라서 fallback 안 됨)
    if (!_isNew && parsed == 0) return _item.totalAmount;
    return parsed;
  }

  int _sumParticipants(List<MealParticipant> participants) {
    return participants.fold<int>(0, (sum, p) => sum + p.amount);
  }

  // 저장 직전에 컨트롤러 텍스트를 기준으로 participants.amount를 확정한다.
  // (IME/포커스 타이밍 이슈로 onChanged가 마지막 입력을 state에 반영하기 전에 저장될 수 있음)
  List<MealParticipant> _participantsFromControllers() {
    return _participantAmountManager.applyControllersToParticipants(
      _item.participants,
    );
  }

  List<MealParticipant> _distributeEvenly(
    List<MealParticipant> participants,
    int totalAmount,
  ) {
    if (participants.isEmpty) return participants;
    final n = participants.length;
    final base = totalAmount ~/ n;
    final remainder = totalAmount % n;
    return List<MealParticipant>.generate(n, (i) {
      final p = participants[i];
      final amount = base + (i < remainder ? 1 : 0);
      return p.copyWith(amount: amount);
    });
  }

  void _handleTotalAmountChange() {
    final total = _currentTotalAmount();
    if (_autoDistribute && _item.participants.isNotEmpty) {
      final next = _distributeEvenly(_item.participants, total);
      setState(() {
        _item = _item.copyWith(
          totalAmount: total,
          participants: next,
          participantsCount: next.length,
          participantsSum: _sumParticipants(next),
        );
      });
      _participantAmountManager.syncFromParticipants(next);
      return;
    }

    setState(() {
      _item = _item.copyWith(totalAmount: total);
    });
  }

  Future<void> _onPickParticipants() async {
    final parsedDate = DateTime.tryParse(_usedDateController.text.trim());
    final usedDateText =
        parsedDate == null ? null : DateFormat('yyyy-MM-dd').format(parsedDate);
    final fallbackYm =
        _item.ym.isNotEmpty
            ? _item.ym
            : DateFormat('yyyyMM').format(_item.usedDate);

    if (usedDateText == null && fallbackYm.trim().isEmpty) {
      AppToast.show(
        context,
        '사용일 또는 월 정보를 먼저 입력해주세요.',
        backgroundColor: Colors.redAccent,
      );
      return;
    }

    try {
      final options = await ref
          .read(mealRepoProvider)
          .getMealOptions(usedDate: usedDateText, ym: fallbackYm);
      if (!mounted) return;
      final result = await _openSheetWithFocusReset<List<MealOptionUser>?>(() {
        return showMealParticipantPickerSheet(
          context: context,
          users: options.users,
          groups: options.groups,
          selectedUserIds:
              _item.participants
                  .map((p) => p.userId)
                  .where((id) => id > 0)
                  .toList(),
        );
      });
      if (!mounted || result == null) return;

      final existingAmounts = {
        for (final p in _item.participants) p.userId: p.amount,
      };
      final participants =
          result
              .where((u) => u.id > 0)
              .map(
                (u) => MealParticipant(
                  userId: u.id,
                  name: u.empName,
                  amount: existingAmounts[u.id] ?? 0,
                ),
              )
              .toList();

      final next =
          _autoDistribute
              ? _distributeEvenly(participants, _currentTotalAmount())
              : participants;
      setState(() {
        _item = _item.copyWith(
          participants: next,
          participantsCount: next.length,
          participantsSum: _sumParticipants(next),
        );
        if (_editingUserId != null &&
            !next.any((p) => p.userId == _editingUserId)) {
          _editingUserId = null;
        }
      });
      _participantAmountManager.syncFromParticipants(next);
    } catch (error) {
      if (!mounted) return;
      AppToast.show(
        context,
        '${humanizeErrorMessage(error)}\n${error.toString()}',
        backgroundColor: Colors.redAccent,
      );
    }
  }

  void _removeParticipant(int userId) {
    final next = _item.participants.where((p) => p.userId != userId).toList();
    final updated =
        _autoDistribute ? _distributeEvenly(next, _currentTotalAmount()) : next;
    setState(() {
      _item = _item.copyWith(
        participants: updated,
        participantsCount: updated.length,
        participantsSum: _sumParticipants(updated),
      );
      if (_editingUserId == userId) {
        _editingUserId = null;
      }
    });
    _participantAmountManager.syncFromParticipants(updated);
  }

  void _onParticipantAmountChanged(int userId, String value) {
    final amount = int.tryParse(value.trim()) ?? 0;
    final next =
        _item.participants
            .map((p) => p.userId == userId ? p.copyWith(amount: amount) : p)
            .toList();
    setState(() {
      _autoDistribute = false;
      _item = _item.copyWith(
        participants: next,
        participantsCount: next.length,
        participantsSum: _sumParticipants(next),
      );
    });
  }

  void _redistributeEvenly() {
    final total = _currentTotalAmount();
    final next = _distributeEvenly(_item.participants, total);
    setState(() {
      _autoDistribute = true;
      _item = _item.copyWith(
        participants: next,
        participantsCount: next.length,
        participantsSum: _sumParticipants(next),
      );
    });
    _participantAmountManager.syncFromParticipants(next);
  }

  void _selectEditingUser(int userId) {
    if (_editingUserId == userId) {
      setState(() {
        _editingUserId = null;
      });
      _participantFocusNodes[userId]?.unfocus();
      return;
    }

    // 총액/승인번호 등 현재 포커스를 먼저 내려서 '첫 탭'이 먹게 만든다
    FocusManager.instance.primaryFocus?.unfocus();

    final controller = _participantAmountManager.controllerFor(userId);
    final node = _focusNodeForParticipant(userId);

    setState(() {
      _editingUserId = userId;
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      // 포커스 강제 (autofocus에 의존하지 않음)
      node.requestFocus();

      // 포커스가 잡힌 다음 프레임에 전체선택 (focus가 selection을 덮어쓰는 걸 방지)
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final len = controller.text.length;
        if (len > 0) {
          controller.selection = TextSelection(
            baseOffset: 0,
            extentOffset: len,
          );
        }
      });
    });
  }

  void _stopEditingUser(int userId) {
    if (_editingUserId != userId) return;
    setState(() {
      _editingUserId = null;
    });
  }

  Future<void> _onSave() async {
    final ok = _formKey.currentState?.validate() ?? false;
    if (!ok) return;

    // 컨트롤러 기준으로 분배금액을 최신화한 뒤, updated를 만든다.
    final rebuiltParticipants = _participantsFromControllers();
    final updated = _buildItemFromForm().copyWith(
      participants: rebuiltParticipants,
      participantsCount: rebuiltParticipants.length,
      participantsSum: _sumParticipants(rebuiltParticipants),
    );

    if (updated.participants.isEmpty) {
      AppToast.show(context, '대상자를 입력해주세요.', backgroundColor: Colors.redAccent);
      return;
    }
    if (updated.participants.any((p) => p.userId <= 0)) {
      AppToast.show(
        context,
        '대상자 정보가 올바르지 않습니다.',
        backgroundColor: Colors.redAccent,
      );
      return;
    }
    if (updated.participants.any((p) => p.amount <= 0)) {
      AppToast.show(
        context,
        '분배 금액은 0원보다 커야 합니다.',
        backgroundColor: Colors.redAccent,
      );
      return;
    }
    final ids = updated.participants.map((p) => p.userId).toList();
    if (ids.toSet().length != ids.length) {
      AppToast.show(
        context,
        '대상자가 중복되었습니다.',
        backgroundColor: Colors.redAccent,
      );
      return;
    }
    if (updated.participantsSum != updated.totalAmount) {
      AppToast.show(
        context,
        '분배 합계가 총액과 일치해야 합니다.',
        backgroundColor: Colors.redAccent,
      );
      return;
    }

    final payload = {
      'used_date': DateFormat('yyyy-MM-dd').format(updated.usedDate),
      'amount': updated.totalAmount,
      'merchant_name': updated.merchantName.trim(),
      'approval_no':
          updated.approvalNo.trim().isEmpty ? null : updated.approvalNo.trim(),
      'participants':
          updated.participants
              .map((p) => {'user_id': p.userId, 'amount': p.amount})
              .toList(),
    };

    setState(() => _saving = true);
    try {
      final isCreate = _isNew || updated.id == 0;
      final repo = ref.read(mealRepoProvider);
      final MealClaimItem serverItem =
          isCreate
              ? await repo.createClaim(payload: payload)
              : await repo.updateClaim(claimId: updated.id, payload: payload);
      if (!mounted) return;
      final resolvedParticipants =
          serverItem.participants.isNotEmpty
              ? serverItem.participants
              : rebuiltParticipants;
      final resolvedItem = serverItem.copyWith(
        participants: resolvedParticipants,
        participantsCount: resolvedParticipants.length,
        participantsSum: _sumParticipants(resolvedParticipants),
      );
      _switchToView(updated: resolvedItem);
      _participantAmountManager.syncFromParticipants(resolvedParticipants);
      widget.onSaved?.call(resolvedItem);
      AppToast.show(context, '저장되었습니다.');
    } catch (error) {
      if (!mounted) return;
      AppToast.show(
        context,
        '${humanizeErrorMessage(error)}\n${error.toString()}',
        backgroundColor: Colors.redAccent,
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _onCancel() {
    if (_isNew) {
      Navigator.of(context).pop();
      return;
    }
    // 취소 = 원복: 편집 시작 시점 원본으로 되돌린 뒤 view로 전환
    final origin = _editOrigin;
    if (origin != null) {
      setState(() {
        _item = origin;
        _detailFuture = Future.value(origin); // view stale 방지
        _mode = MealClaimSheetMode.view;
        _editingUserId = null;
        _isNew = false;
        _editOrigin = null;
      });
      // 컨트롤러/대상자 금액 컨트롤러도 원본 기준으로 동기화
      _syncControllersFromItem(_item);
      _participantAmountManager.syncFromParticipants(_item.participants);
      return;
    }
    _switchToView();
  }

  Future<void> _confirmDelete() async {
    if (_isNew || !_item.canDelete || _deleting) return;
    final result = await showCupertinoDialog<bool>(
      context: context,
      builder: (context) {
        return CupertinoAlertDialog(
          title: const Text('삭제할까요?'),
          content: const Text('이 사용내역을 삭제하면 되돌릴 수 없습니다.'),
          actions: [
            CupertinoDialogAction(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('취소', style: TextStyle(fontSize: 14)),
            ),
            CupertinoDialogAction(
              isDestructiveAction: true,
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('삭제', style: TextStyle(fontSize: 14)),
            ),
          ],
        );
      },
    );
    if (result == true) {
      setState(() => _deleting = true);
      try {
        await ref.read(mealRepoProvider).deleteClaim(claimId: _item.id);
        if (!mounted) return;
        widget.onDeleted?.call(_item);
        Navigator.of(context).pop();
        AppToast.show(context, '삭제되었습니다.');
      } catch (error) {
        if (!mounted) return;
        AppToast.show(
          context,
          '${humanizeErrorMessage(error)}\n${error.toString()}',
          backgroundColor: Colors.redAccent,
        );
      } finally {
        if (mounted) setState(() => _deleting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.92,
      minChildSize: 0.60,
      maxChildSize: 0.92,
      builder: (context, controller) {
        final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
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
          child: GestureDetector(
            onTap: _onScaffoldTap,
            child: ListView(
              controller: controller,
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: EdgeInsets.fromLTRB(
                Sizes.size20,
                Sizes.size20,
                Sizes.size20,
                Sizes.size20 + bottomInset,
              ),
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
                        // 순서: 사용일 → 승인번호 → 가맹점명 → 총액
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
                          decoration: _decoration('승인번호(8자리)'),
                          validator: (v) {
                            final t = (v ?? '').trim();
                            if (t.isEmpty) return '승인번호를 입력해주세요.';
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
                          focusNode: _totalAmountFocusNode,
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                          ],
                          decoration: _decoration('총액', hint: '숫자만 입력'),
                          validator: (v) {
                            final n = _parseMoney(v ?? '');
                            if (n <= 0) {
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

                // 하단 액션
                if (!_isEdit)
                  _ViewActions(
                    canEdit: _item.canEdit,
                    canDelete: !_isNew && _item.canDelete,
                    deleting: _deleting,
                    onEdit: _switchToEdit,
                    onDelete: _confirmDelete,
                  )
                else
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _onCancel,
                          child: const Text(
                            '취소',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                      Gaps.h12,
                      Expanded(
                        child: FilledButton(
                          onPressed: _saving ? null : _onSave,
                          child: const Text(
                            '저장',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                    ],
                  ),

                Gaps.v8,
              ],
            ),
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
    final createdBy = item.createdByName.isEmpty ? '-' : item.createdByName;

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
/// Participants (편집용)
/// =======================
class _ParticipantsEditor extends StatelessWidget {
  final List<MealParticipant> participants;
  final TextEditingController Function(MealParticipant p) ensureController;
  final FocusNode Function(MealParticipant p) ensureFocusNode;
  final void Function(int userId, String value) onAmountChanged;
  final ValueChanged<int> onRemove;
  final ValueChanged<int> onSelectEditingUser;
  final ValueChanged<int> onStopEditingUser;
  final int? editingUserId;

  const _ParticipantsEditor({
    required this.participants,
    required this.ensureController,
    required this.ensureFocusNode,
    required this.onAmountChanged,
    required this.onRemove,
    required this.onSelectEditingUser,
    required this.onStopEditingUser,
    required this.editingUserId,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final gridSpacing = Sizes.size5;
    return Column(
      children: [
        if (participants.isEmpty)
          Padding(
            padding: const EdgeInsets.only(
              top: Sizes.size8,
              bottom: Sizes.size32, // 대상자 없을때는 하단 버튼과 간격 넓게
            ),
            child: Center(
              child: Text(
                '대상자를 추가해주세요.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: Colors.black45,
                ),
              ),
            ),
          ),
        if (participants.isNotEmpty)
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: gridSpacing,
              mainAxisSpacing: gridSpacing,
              childAspectRatio: 4,
            ),
            itemCount: participants.length,
            itemBuilder: (context, index) {
              final p = participants[index];
              final isSelected = editingUserId == p.userId;
              final amountText = '${formatMealAmount(p.amount)}원';
              const double amountBoxW = 70;
              const double amountBoxH = 32;
              return Container(
                // 오른쪽 padding을 줄여서 X 뒤 여백을 줄임
                padding: const EdgeInsets.only(
                  left: 10,
                  right: 1,
                  top: 6,
                  bottom: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.02),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: Colors.black.withValues(alpha: 0.06),
                  ),
                ),
                child: InkWell(
                  borderRadius: BorderRadius.circular(10),
                  onTap: () => onSelectEditingUser(p.userId),
                  // 포커스/탭 시 회색 overlay(잉크) 방지
                  overlayColor: WidgetStateProperty.all(Colors.transparent),
                  splashColor: Colors.transparent,
                  highlightColor: Colors.transparent,
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          p.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      // 금액 박스: 보기/편집 동일 크기, 금액 영역만 탭 가능
                      SizedBox(
                        width: amountBoxW,
                        height: amountBoxH,
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () => onSelectEditingUser(p.userId),
                          child: AnimatedContainer(
                            key: ValueKey('amt-${p.userId}'),
                            duration: const Duration(milliseconds: 120),
                            curve: Curves.easeOut,
                            alignment: Alignment.centerRight,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(10),
                              // 여기 색은 “우리가 정한 그대로”만 보임 (포커스 state-layer 영향 X)
                              color:
                                  isSelected
                                      ? theme.colorScheme.primary.withValues(
                                        alpha: 0.08,
                                      )
                                      : Colors.transparent,
                              border: Border.all(
                                color:
                                    isSelected
                                        ? theme.colorScheme.primary
                                        : Colors.transparent,
                                width: 1.2,
                              ),
                            ),
                            child:
                                isSelected
                                    ? Builder(
                                      builder:
                                          (fieldCtx) => Focus(
                                            onFocusChange: (hasFocus) {
                                              if (!hasFocus) {
                                                onStopEditingUser(p.userId);
                                              }
                                              if (hasFocus) {
                                                // 키보드에 가리기 전에 자동으로 스크롤 올림
                                                WidgetsBinding.instance
                                                    .addPostFrameCallback((_) {
                                                      if (!fieldCtx.mounted) {
                                                        return;
                                                      }
                                                      Scrollable.ensureVisible(
                                                        fieldCtx,
                                                        alignment:
                                                            0.25, // 화면 위쪽 쪽에 오도록 (0~1)
                                                        duration:
                                                            const Duration(
                                                              milliseconds: 180,
                                                            ),
                                                        curve: Curves.easeOut,
                                                      );
                                                    });
                                              }
                                            },
                                            child: TextField(
                                              controller: ensureController(p),
                                              focusNode: ensureFocusNode(p),
                                              keyboardType:
                                                  TextInputType.number,
                                              inputFormatters: [
                                                FilteringTextInputFormatter
                                                    .digitsOnly,
                                              ],
                                              autofocus: false,
                                              textAlign: TextAlign.right,
                                              // 키보드 위 여유(필수): ensureVisible과 함께 쓰면 안정적
                                              scrollPadding: EdgeInsets.only(
                                                bottom:
                                                    MediaQuery.viewInsetsOf(
                                                      fieldCtx,
                                                    ).bottom +
                                                    140,
                                              ),
                                              style: theme.textTheme.bodySmall
                                                  ?.copyWith(
                                                    fontWeight: FontWeight.w700,
                                                    color: Colors.black87,
                                                  ),
                                              decoration: const InputDecoration(
                                                isDense: true,
                                                border: InputBorder.none,
                                                contentPadding: EdgeInsets.zero,
                                              ),
                                              onTap: () {
                                                // 혹시라도 selection이 깨졌을 때(두번째 탭 등) 다시 전체선택
                                                final c = ensureController(p);
                                                final len = c.text.length;
                                                if (len > 0) {
                                                  c.selection = TextSelection(
                                                    baseOffset: 0,
                                                    extentOffset: len,
                                                  );
                                                }
                                              },
                                              onChanged:
                                                  (v) => onAmountChanged(
                                                    p.userId,
                                                    v,
                                                  ),
                                              onSubmitted:
                                                  (_) => onStopEditingUser(
                                                    p.userId,
                                                  ),
                                            ),
                                          ),
                                    )
                                    : Text(
                                      amountText,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: theme.textTheme.bodySmall
                                          ?.copyWith(
                                            fontWeight: FontWeight.w700,
                                            color: Colors.black87,
                                          ),
                                    ),
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () => onRemove(p.userId),
                        icon: const Icon(Icons.close, size: 12),
                        tooltip: '삭제',
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(
                          minWidth: 16,
                          minHeight: 16,
                        ),
                        visualDensity: VisualDensity.compact,
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
      ],
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
  final bool deleting;
  final VoidCallback onEdit;
  final Future<void> Function() onDelete;

  const _ViewActions({
    required this.canEdit,
    required this.canDelete,
    required this.deleting,
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
              onPressed: deleting ? null : () => onDelete(),
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

class ParticipantAmountControllerManager {
  final Map<int, TextEditingController> _controllers = {};

  TextEditingController controllerFor(int userId, {String? initialText}) {
    final controller = _controllers[userId];
    if (controller != null) return controller;
    final created = TextEditingController(text: initialText ?? '');
    _controllers[userId] = created;
    return created;
  }

  void syncFromParticipants(List<MealParticipant> participants) {
    disposeMissing(participants);
    for (final p in participants) {
      final nextText = p.amount.toString();
      final controller = _controllers[p.userId];
      if (controller == null) {
        _controllers[p.userId] = TextEditingController(text: nextText);
        continue;
      }
      // "프로그램이 amount를 바꾼 직후"에만 이 함수가 호출된다는 전제.
      // 사용자가 입력 중일 때 build에서 text를 덮어쓰면 커서 튐이 생길 수 있으니
      // 동기화는 이 함수에서만, 필요한 순간에만 수행한다.
      if (controller.text != nextText) controller.text = nextText;
    }
  }

  List<MealParticipant> applyControllersToParticipants(
    List<MealParticipant> participants,
  ) {
    return participants.map((p) {
      final controller = _controllers[p.userId];
      final n = int.tryParse((controller?.text ?? '').trim()) ?? 0;
      return p.copyWith(amount: n);
    }).toList();
  }

  void disposeMissing(List<MealParticipant> participants) {
    final ids = participants.map((p) => p.userId).toSet();
    final removeIds =
        _controllers.keys.where((id) => !ids.contains(id)).toList();
    for (final id in removeIds) {
      _controllers[id]?.dispose();
      _controllers.remove(id);
    }
  }

  void disposeAll() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    _controllers.clear();
  }
}
