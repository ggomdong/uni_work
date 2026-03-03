import 'package:flutter/material.dart';

import '../../models/meal_participant.dart';

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
      // 사용자가 입력 중일 때 덮어쓰기 방지를 위해 필요한 시점에만 동기화.
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
