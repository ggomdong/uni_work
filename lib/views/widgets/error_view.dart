import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../utils.dart';

/// 공통 에러 UI
/// - 사용자에게는 깔끔한 한국어 메시지만 노출
/// - 디버그 모드에서는 상세 에러를 펼쳐서 확인 가능
class ErrorView extends StatelessWidget {
  final String title;
  final Object error;
  final StackTrace? stackTrace;
  final VoidCallback onRetry;
  final String retryLabel;
  final IconData icon;

  const ErrorView({
    super.key,
    required this.title,
    required this.error,
    this.stackTrace,
    required this.onRetry,
    this.retryLabel = '새로고침',
    this.icon = Icons.cloud_off,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final message = humanizeErrorMessage(error);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 44, color: theme.colorScheme.onSurfaceVariant),
              const SizedBox(height: 12),
              Text(
                title,
                textAlign: TextAlign.center,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                message,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: Text(retryLabel),
              ),

              // 개발 중에는 원문 에러/스택을 펼쳐서 확인 가능(사용자에게는 숨김)
              if (kDebugMode) ...[
                const SizedBox(height: 16),
                _DebugDetails(error: error, stackTrace: stackTrace),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _DebugDetails extends StatelessWidget {
  final Object error;
  final StackTrace? stackTrace;

  const _DebugDetails({required this.error, this.stackTrace});

  @override
  Widget build(BuildContext context) {
    return ExpansionTile(
      tilePadding: EdgeInsets.zero,
      childrenPadding: EdgeInsets.zero,
      title: Text('디버그 정보(개발용)', style: Theme.of(context).textTheme.labelLarge),
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(12),
          ),
          child: SelectableText(
            [
              error.toString(),
              if (stackTrace != null) '\n\n$stackTrace',
            ].join(),
            style: Theme.of(context).textTheme.labelSmall,
          ),
        ),
      ],
    );
  }
}
