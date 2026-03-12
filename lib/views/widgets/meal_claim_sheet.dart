import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../constants/gaps.dart';
import '../../constants/sizes.dart';
import '../../models/meal_claim_item.dart';
import '../../models/meal_options.dart';
import '../../models/meal_option_user.dart';
import '../../models/meal_participant.dart';
import '../../repos/meal_repo.dart';
import '../../utils.dart';
import '../../utils/meal_utils.dart';
import './app_toast.dart';
import './meal_claim_sheet_participants.dart';
import './meal_claim_sheet_view.dart';
import './meal_date_picker_sheet.dart';
import './meal_participant_picker_sheet.dart';
import './participant_amount_controller_manager.dart';

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
  /// ----- State & Lifecycle -----
  // Form
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  late MealClaimSheetMode _mode;
  late bool _isNew;
  late MealClaimItem _item;
  Future<MealClaimItem>? _detailFuture;
  bool _deleting = false;
  bool _saving = false;
  int? _editingUserId;
  late final ParticipantAmountControllerManager _participantAmountManager;
  MealOptions? _cachedMealOptions;
  String? _cachedMealOptionsDateKey;

  // 편집 시작 시점의 원본 스냅샷(취소 시 원복용)
  MealClaimItem? _editOrigin;

  // 대상자 금액 선택 시 포커스를 위한 코드
  final Map<int, FocusNode> _participantFocusNodes = {};

  FocusNode _focusNodeForParticipant(int userId) =>
      _participantFocusNodes.putIfAbsent(userId, () => FocusNode());

  // alertDialog 등을 닫은 후, 최종 포커스했던 곳으로 이동을 방지하기 위한 변수
  late final FocusNode _focusParkingNode;

  late TextEditingController _usedDateController;
  late TextEditingController _approvalController;
  late TextEditingController _merchantController;

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
    _participantAmountManager = ParticipantAmountControllerManager();
    _participantAmountManager.syncFromParticipants(_item.participants);

    _focusParkingNode = FocusNode(debugLabel: 'meal_sheet_focus_parking');
  }

  @override
  void dispose() {
    _usedDateController.dispose();
    _approvalController.dispose();
    _merchantController.dispose();
    _participantAmountManager.disposeAll();

    for (final n in _participantFocusNodes.values) {
      n.dispose();
    }
    _participantFocusNodes.clear();

    _focusParkingNode.dispose();

    super.dispose();
  }

  bool get _isEdit => _mode == MealClaimSheetMode.edit;

  /// ----- Focus & Keyboard & Sheet -----

  void _onScaffoldTap() {
    FocusScope.of(context).unfocus();
  }

  void _parkFocus() {
    // last-focused 복원 자체를 끊어버림
    FocusScope.of(context).unfocus(disposition: UnfocusDisposition.scope);
    FocusScope.of(context).requestFocus(_focusParkingNode);
    SystemChannels.textInput.invokeMethod('TextInput.hide');
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

  /// ----- Edit Snapshot & Dirty -----
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

  void _syncControllersFromItem(MealClaimItem item) {
    _usedDateController.text = DateFormat('yyyy-MM-dd').format(item.usedDate);
    _approvalController.text = item.approvalNo;
    _merchantController.text = item.merchantName;
  }

  MealClaimItem _buildDraftFromControllers() {
    final usedDate =
        DateTime.tryParse(_usedDateController.text.trim()) ?? _item.usedDate;
    final ym = '${usedDate.year}${usedDate.month.toString().padLeft(2, '0')}';

    final rebuiltParticipants = _participantsFromControllers();
    final participantsSum = _sumParticipants(rebuiltParticipants);

    return _item.copyWith(
      ym: ym,
      usedDate: usedDate,
      approvalNo: _approvalController.text.trim(),
      merchantName: _merchantController.text.trim(),
      totalAmount: participantsSum,
      participants: rebuiltParticipants,
      participantsCount: rebuiltParticipants.length,
      participantsSum: participantsSum,
    );
  }

  List<String> _participantsSignature(List<MealParticipant> ps) {
    // userId+amount 기준으로 정렬/서명 생성 (순서 차이 무시)
    final items = ps
      .map((p) => '${p.userId}:${p.amount}')
      .toList(growable: false)..sort();
    return items;
  }

  bool _isDirty() {
    if (!_isEdit) return false;
    final origin = _editOrigin;
    if (origin == null) return false;

    final draft = _buildDraftFromControllers();

    // 기본 필드 비교
    final sameBasic =
        origin.usedDate == draft.usedDate &&
        origin.approvalNo.trim() == draft.approvalNo.trim() &&
        origin.merchantName.trim() == draft.merchantName.trim() &&
        origin.totalAmount == draft.totalAmount;
    if (!sameBasic) return true;

    // 대상자( userId + amount ) 비교
    return !listEquals(
      _participantsSignature(origin.participants),
      _participantsSignature(draft.participants),
    );
  }

  bool _isNewDraftDirty() {
    // 신규 화면인데, 편집 시작 원본이 없을 때만 의미 있음
    if (!_isNew) return false;

    final approval = _approvalController.text.trim();
    final merchant = _merchantController.text.trim();

    // 대상자 금액은 컨트롤러 기준 확정(이미 함수 있음)
    final participants = _participantsFromControllers();

    // 신규 기본값(_buildNewItem)과 비교: "뭔가 썼다"의 기준을 넓게 잡음
    final participantsSum = _sumParticipants(participants);
    final hasAnyText =
        approval.isNotEmpty || merchant.isNotEmpty || participantsSum > 0;
    final hasParticipants = participants.isNotEmpty;

    // 사용일은 기본으로 오늘이 들어가니 dirty 기준에서 제외하는 게 자연스러움
    // (원하면 usedDate 변경까지 포함해도 됨)
    return hasAnyText || hasParticipants;
  }

  Future<bool> _confirmDiscardChanges({required bool isNew}) async {
    final title = isNew ? '입력 사항을 폐기할까요?' : '수정 사항을 폐기할까요?';
    final keepLabel = isNew ? '계속 입력' : '계속 수정';
    final result = await showCupertinoDialog<bool>(
      context: context,
      useRootNavigator: false,
      builder: (dialogContext) {
        return CupertinoAlertDialog(
          title: Text(title),
          content: const Text('변경한 내용이 저장되지 않습니다.'),
          actions: [
            CupertinoDialogAction(
              onPressed: () {
                // 1) pop 직전에 선제 주차 -> 복원 자체를 최대한 막음(깜박임 제거)
                if (mounted) _parkFocus();
                Navigator.of(dialogContext).pop(false);
                // 2) (안전) pop 직후 한 프레임 뒤에 한 번 더 주차
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (!mounted) return;
                  _parkFocus();
                });
              },
              child: Text(keepLabel, style: TextStyle(fontSize: 14)),
            ),
            CupertinoDialogAction(
              isDestructiveAction: true,
              onPressed: () {
                Navigator.of(dialogContext).pop(true);
              },
              child: const Text('폐기', style: TextStyle(fontSize: 14)),
            ),
          ],
        );
      },
    );
    return result == true;
  }

  Future<void> _onCancelPressed() async {
    if (!_isEdit) return;
    final dirty = _isDirty() || _isNewDraftDirty();
    if (dirty) {
      final ok = await _confirmDiscardChanges(isNew: _isNew);
      if (!ok) return;
    }
    _onCancel();
  }

  // 로그인 폼 톤과 맞춘 Decoration
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

  /// ----- Participants Logic -----
  MealClaimItem _buildItemFromForm() {
    final usedDate =
        DateTime.tryParse(_usedDateController.text.trim()) ?? _item.usedDate;

    final baseParticipants = _item.participants;
    final participantsSum = baseParticipants.fold<int>(
      0,
      (sum, p) => sum + p.amount,
    );
    final ym = '${usedDate.year}${usedDate.month.toString().padLeft(2, '0')}';

    return _item.copyWith(
      ym: ym,
      usedDate: usedDate,
      approvalNo: _approvalController.text.trim(),
      merchantName: _merchantController.text.trim(),
      totalAmount: participantsSum,
      participantsCount: baseParticipants.length,
      participantsSum: participantsSum,
      participants: baseParticipants,
    );
  }

  int _sumParticipants(List<MealParticipant> participants) {
    return participants.fold<int>(0, (sum, p) => sum + p.amount);
  }

  String _formatUsedDate(DateTime date) =>
      DateFormat('yyyy-MM-dd').format(date);

  bool _isSameCalendarDate(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  MealClaimItem _copyItemWithParticipants(
    MealClaimItem source,
    List<MealParticipant> participants, {
    DateTime? usedDate,
  }) {
    final effectiveUsedDate = usedDate ?? source.usedDate;
    final sum = _sumParticipants(participants);
    return source.copyWith(
      ym: DateFormat('yyyyMM').format(effectiveUsedDate),
      usedDate: effectiveUsedDate,
      totalAmount: sum,
      participants: participants,
      participantsCount: participants.length,
      participantsSum: sum,
    );
  }

  Future<MealOptions> _loadMealOptionsForDate(
    DateTime usedDate, {
    bool forceReload = false,
  }) async {
    final usedDateKey = _formatUsedDate(usedDate);
    if (!forceReload &&
        _cachedMealOptions != null &&
        _cachedMealOptionsDateKey == usedDateKey) {
      return _cachedMealOptions!;
    }

    final options = await ref
        .read(mealRepoProvider)
        .getMealOptions(
          usedDate: usedDateKey,
          ym: DateFormat('yyyyMM').format(usedDate),
        );
    _cachedMealOptions = options;
    _cachedMealOptionsDateKey = usedDateKey;
    return options;
  }

  String _removedParticipantsMessage(List<MealParticipant> removed) {
    final names = removed
        .map((p) => p.name.trim())
        .where((name) => name.isNotEmpty)
        .toList(growable: false);
    final previewNames = names.take(3).toList(growable: false);
    final preview = previewNames.isEmpty ? '이름 미확인' : previewNames.join(', ');
    final extraCount = removed.length - previewNames.length;
    final suffix = extraCount > 0 ? ' 외 $extraCount명' : '';
    final noun = removed.length == 1 ? '1명이' : '${removed.length}명이';
    return '사용일 변경으로 선택할 수 없는 대상자 $noun 제외되었습니다. ($preview$suffix)';
  }

  Future<void> _onUsedDateChanged(DateTime nextDate) async {
    final normalized = DateTime(nextDate.year, nextDate.month, nextDate.day);
    final current = DateTime(
      _item.usedDate.year,
      _item.usedDate.month,
      _item.usedDate.day,
    );
    if (_isSameCalendarDate(current, normalized)) {
      _usedDateController.text = _formatUsedDate(normalized);
      return;
    }

    final currentParticipants = _participantsFromControllers();

    try {
      final options = await _loadMealOptionsForDate(
        normalized,
        forceReload: true,
      );
      if (!mounted) return;

      final allowedUserIds =
          options.users
              .where((user) => user.id > 0)
              .map((user) => user.id)
              .toSet();
      final nextParticipants = currentParticipants
          .where((participant) => allowedUserIds.contains(participant.userId))
          .toList(growable: false);
      final removed = currentParticipants
          .where((participant) => !allowedUserIds.contains(participant.userId))
          .toList(growable: false);
      final nextItem = _copyItemWithParticipants(
        _item,
        nextParticipants,
        usedDate: normalized,
      );

      setState(() {
        _item = nextItem;
        _usedDateController.text = _formatUsedDate(normalized);
        if (_editingUserId != null &&
            !nextParticipants.any((p) => p.userId == _editingUserId)) {
          _editingUserId = null;
        }
      });
      _participantAmountManager.syncFromParticipants(nextParticipants);

      if (removed.isNotEmpty) {
        AppToast.show(
          context,
          _removedParticipantsMessage(removed),
          backgroundColor: Colors.orange.shade700,
          duration: const Duration(milliseconds: 2600),
        );
      }
    } catch (error) {
      if (!mounted) return;
      AppToast.show(
        context,
        humanizeErrorMessage(error),
        backgroundColor: Colors.redAccent,
      );
    }
  }

  // 저장 직전에 컨트롤러 텍스트를 기준으로 participants.amount를 확정한다.
  // (IME/포커스 타이밍 이슈로 onChanged가 마지막 입력을 state에 반영하기 전에 저장될 수 있음)
  List<MealParticipant> _participantsFromControllers() {
    return _participantAmountManager.applyControllersToParticipants(
      _item.participants,
    );
  }

  /// ----- API / Save / Delete -----
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
    final payload = {
      'used_date': DateFormat('yyyy-MM-dd').format(updated.usedDate),
      'amount': updated.participantsSum,
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
      final resolvedSum = _sumParticipants(resolvedParticipants);
      final resolvedItem = serverItem.copyWith(
        totalAmount: resolvedSum,
        participants: resolvedParticipants,
        participantsCount: resolvedParticipants.length,
        participantsSum: resolvedSum,
      );
      _switchToView(updated: resolvedItem);
      _participantAmountManager.syncFromParticipants(resolvedParticipants);
      widget.onSaved?.call(resolvedItem);
      AppToast.show(context, '저장되었습니다.');
    } catch (error) {
      if (!mounted) return;
      AppToast.show(
        context,
        humanizeMealClaimSaveError(error),
        backgroundColor: Colors.redAccent,
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
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

  /// ----- UI Builders & Build -----
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
      await _onUsedDateChanged(picked);
    }
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
          MealParticipantsReadOnlyBox(participants: participants),
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

            return Row(
              children: [
                Expanded(
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
                // 분배방식 선택 UI는 현재 사용하지 않음.
                Text(
                  '총액 : ${formatMealAmount(sum)}원',
                  maxLines: 1,
                  softWrap: false,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            );
          },
        ),
        Gaps.v8,
        MealParticipantsEditor(
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

  Future<void> _onPickParticipants() async {
    final usedDate = _item.usedDate;

    try {
      final options = await _loadMealOptionsForDate(usedDate);
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

      final next = participants;
      setState(() {
        _item = _copyItemWithParticipants(_item, next);
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
    final updated = next;
    setState(() {
      _item = _item.copyWith(
        totalAmount: _sumParticipants(updated),
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
      _item = _item.copyWith(
        totalAmount: _sumParticipants(next),
        participants: next,
        participantsCount: next.length,
        participantsSum: _sumParticipants(next),
      );
    });
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
                  MealClaimViewContent(
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
                        // 순서: 사용일 → 승인번호 → 가맹점명
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
                        Gaps.v8,

                        _buildParticipantsSection(editable: true),
                      ],
                    ),
                  ),

                // 하단 액션
                if (!_isEdit)
                  MealClaimViewActions(
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
                          onPressed: _onCancelPressed,
                          child: const Text(
                            '취소',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                      Gaps.h12,
                      Expanded(
                        child: FilledButton(
                          // 신규 입력(_isNew)에서는 dirty 체크로 막지 않는다.
                          // 수정 모드에서만 "변경 없음"이면 저장 비활성화
                          onPressed:
                              (_saving || (!_isNew && !_isDirty()))
                                  ? null
                                  : _onSave,
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
