import 'dart:io';
import 'package:dio/dio.dart';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:vibration/vibration.dart';
import 'package:intl/intl.dart';
import '../view_models/settings_view_model.dart';
import '../repos/authentication_repo.dart';

bool isDarkMode(WidgetRef ref) => ref.watch(settingsProvider).darkMode;

// 텍스트 편집 업데이트를 처리하기 위해 formatEditUpdate 메서드를 재정의
class PhoneInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digits = newValue.text.replaceAll(RegExp(r'\D'), '');

    String formatted = digits;
    if (digits.length > 4) {
      formatted =
          '${digits.substring(0, 4)}-${digits.substring(4, digits.length)}';
    }

    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}

// initialUsername 을 가져올때 포맷팅하는 유틸함수
String? formatInitialPhone(String? fullPhone) {
  if (fullPhone == null) return null;
  final digits = fullPhone.replaceAll(RegExp(r'\D'), '');
  if (digits.length == 11 && digits.startsWith('010')) {
    final body = digits.substring(3); // '12345678'
    return PhoneInputFormatter()
        .formatEditUpdate(
          const TextEditingValue(text: ''),
          TextEditingValue(text: body),
        )
        .text;
  }
  return null;
}

void triggerHaptic(BuildContext context) async {
  try {
    if (Theme.of(context).platform == TargetPlatform.iOS) {
      HapticFeedback.heavyImpact();
    } else {
      if (await Vibration.hasVibrator()) {
        Vibration.vibrate(duration: 40);
      }
    }
  } catch (_) {
    // 플랫폼 예외 무시
  }
}

String formatTime(DateTime? time) {
  if (time == null) return "-";
  return DateFormat('HH:mm:ss').format(time);
}

TimeOfDay parseTimeOfDay(String timeStr) {
  final parts = timeStr.split(":");
  return TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
}

Future<void> openPrivacy(WidgetRef ref) async {
  final authRepository = ref.read(authRepo);
  final baseUrl =
      authRepository.dio.options.baseUrl; // ex) https://wsnuni.co.kr/
  final uri = Uri.parse(
    '${baseUrl}wtm/privacy/',
  ); // → https://wsnuni.co.kr/wtm/privacy/

  final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);

  if (!ok) {
    // 필요하면 스낵바 등으로 안내
    throw '개인정보처리방침 페이지를 열 수 없습니다.';
  }
}

/// ---------------------------------------------------------------------------
/// 에러 메시지(사용자 노출용) 변환
/// - Dio/Socket 기반 네트워크 오류를 깔끔한 한국어로 매핑
/// - 화면에는 이 메시지만 노출하고, 원문 에러는 디버그에서만 확인 권장
/// ---------------------------------------------------------------------------
String humanizeErrorMessage(Object error) {
  // Dio 에러 우선
  if (error is DioException) {
    final status = error.response?.statusCode;

    // 401/403은 UX 관점에서 "새로고침"보다는 재로그인을 유도하는 메시지가 적합
    if (status == 401 || status == 403) {
      return '로그인 정보가 만료되었습니다. 다시 로그인해 주세요.';
    }

    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return '요청 시간이 초과되었습니다. 네트워크 상태를 확인한 뒤 다시 시도해 주세요.';
      case DioExceptionType.badResponse:
        if (status != null) {
          if (status >= 500) return '서버 오류가 발생했습니다. 잠시 후 다시 시도해 주세요.';
          if (status == 404) return '요청한 정보를 찾을 수 없습니다. 잠시 후 다시 시도해 주세요.';
          return '요청을 처리할 수 없습니다. 잠시 후 다시 시도해 주세요.';
        }
        return '요청을 처리할 수 없습니다. 잠시 후 다시 시도해 주세요.';
      case DioExceptionType.cancel:
        return '요청이 취소되었습니다. 다시 시도해 주세요.';
      case DioExceptionType.connectionError:
      case DioExceptionType.unknown:
        final msg = error.message ?? '';
        if (msg.contains('Connection refused') || msg.contains('errno = 61')) {
          return '서버에 연결할 수 없습니다. 서버가 점검 중이거나 일시적으로 중단되었을 수 있습니다.';
        }
        return '서버에 연결할 수 없습니다. 네트워크 상태를 확인한 뒤 다시 시도해 주세요.';
      case DioExceptionType.badCertificate:
        return '보안 연결에 실패했습니다. 네트워크 환경을 확인해 주세요.';
    }
  }

  // SocketException
  if (error is SocketException) {
    return '서버에 연결할 수 없습니다. 네트워크 상태를 확인한 뒤 다시 시도해 주세요.';
  }

  // 문자열 기반(예외를 wrapping 하는 경우)
  final msg = error.toString();
  if (msg.contains('Connection refused') || msg.contains('errno = 61')) {
    return '서버에 연결할 수 없습니다. 서버가 점검 중이거나 일시적으로 중단되었을 수 있습니다.';
  }
  if (msg.toLowerCase().contains('timeout')) {
    return '요청 시간이 초과되었습니다. 잠시 후 다시 시도해 주세요.';
  }

  return '일시적인 오류가 발생했습니다. 잠시 후 다시 시도해 주세요.';
}
