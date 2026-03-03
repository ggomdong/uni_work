import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../constants/sizes.dart';
import '../../models/meal_participant.dart';
import '../../utils/meal_utils.dart';

class MealParticipantsReadOnlyBox extends StatelessWidget {
  final List<MealParticipant> participants;

  const MealParticipantsReadOnlyBox({
    super.key,
    required this.participants,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.black.withValues(alpha: 0.08)),
        color: Colors.black.withValues(alpha: 0.02),
      ),
      child: Column(
        children: [
          for (int i = 0; i < participants.length; i++) ...[
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: Sizes.size12,
                vertical: Sizes.size10,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      participants[i].name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Text('${formatMealAmount(participants[i].amount)}원'),
                ],
              ),
            ),
            if (i != participants.length - 1)
              Divider(
                height: 1,
                thickness: 1,
                color: Colors.black.withValues(alpha: 0.06),
              ),
          ],
        ],
      ),
    );
  }
}

class MealParticipantsEditor extends StatelessWidget {
  final List<MealParticipant> participants;
  final TextEditingController Function(MealParticipant p) ensureController;
  final FocusNode Function(MealParticipant p) ensureFocusNode;
  final void Function(int userId, String value) onAmountChanged;
  final ValueChanged<int> onRemove;
  final ValueChanged<int> onSelectEditingUser;
  final ValueChanged<int> onStopEditingUser;
  final int? editingUserId;

  const MealParticipantsEditor({
    super.key,
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
              bottom: Sizes.size32,
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
                                                WidgetsBinding.instance
                                                    .addPostFrameCallback((_) {
                                                      if (!fieldCtx.mounted) {
                                                        return;
                                                      }
                                                      Scrollable.ensureVisible(
                                                        fieldCtx,
                                                        alignment: 0.25,
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
