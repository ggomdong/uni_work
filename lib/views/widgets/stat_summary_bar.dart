import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../constants/gaps.dart';
import '../../status_theme.dart';
import '../../utils.dart';

class StatSummaryBar extends ConsumerWidget {
  final String holidayValue;
  final bool holidayLong;

  final String overtimeValue;
  final bool overtimeLong;

  final String lateValue;
  final bool lateLong;

  final String earlyValue;
  final bool earlyLong;

  const StatSummaryBar({
    super.key,
    required this.holidayValue,
    required this.holidayLong,
    required this.overtimeValue,
    required this.overtimeLong,
    required this.lateValue,
    required this.lateLong,
    required this.earlyValue,
    required this.earlyLong,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = isDarkMode(ref);
    final bg = isDark ? const Color(0xFF15171A) : Colors.white;
    final border = isDark ? const Color(0xFF2A2E33) : const Color(0xFFE9EDF1);

    return Row(
      children: [
        Expanded(
          child: _StatCard(bg: bg, border: border, child: _LegendCard()),
        ),
        Gaps.h8,
        Expanded(
          child: _StatCard(
            bg: bg,
            border: border,
            child: _DoubleMetricCard(
              topColor: themeOf("HOLIDAY").fg,
              topTitle: "휴근",
              topValue: holidayValue,
              topLong: holidayLong,
              bottomColor: themeOf("OVERTIME").fg,
              bottomTitle: "연장",
              bottomValue: overtimeValue,
              bottomLong: overtimeLong,
            ),
          ),
        ),
        Gaps.h8,
        Expanded(
          child: _StatCard(
            bg: bg,
            border: border,
            child: _DoubleMetricCard(
              topColor: themeOf("LATE").fg,
              topTitle: "지각",
              topValue: lateValue,
              topLong: lateLong,
              bottomColor: themeOf("EARLY").fg,
              bottomTitle: "조퇴",
              bottomValue: earlyValue,
              bottomLong: earlyLong,
            ),
          ),
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final Color bg;
  final Color border;
  final Widget child;

  const _StatCard({
    required this.bg,
    required this.border,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: border),
      ),
      child: child,
    );
  }
}

class _LegendCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final normal = themeOf("NORMAL").fg;
    final error = themeOf("ERROR").fg;
    const leave = Color(0xFF9AA3AB);

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: const []),
        Row(
          children: [
            Expanded(child: _DotLabel(color: normal, text: "정상")),
            Expanded(child: _DotLabel(color: error, text: "오류")),
          ],
        ),
        Gaps.v6,
        _DotLabel(color: leave, text: "유급/무급휴가"),
      ],
    );
  }
}

class _DoubleMetricCard extends StatelessWidget {
  final Color topColor;
  final String topTitle;
  final String topValue;
  final bool topLong;

  final Color bottomColor;
  final String bottomTitle;
  final String bottomValue;
  final bool bottomLong;

  const _DoubleMetricCard({
    required this.topColor,
    required this.topTitle,
    required this.topValue,
    required this.topLong,
    required this.bottomColor,
    required this.bottomTitle,
    required this.bottomValue,
    required this.bottomLong,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _MetricRow(
          color: topColor,
          title: topTitle,
          value: topValue,
          isLong: topLong,
        ),
        Gaps.v6,
        _MetricRow(
          color: bottomColor,
          title: bottomTitle,
          value: bottomValue,
          isLong: bottomLong,
        ),
      ],
    );
  }
}

class _MetricRow extends StatelessWidget {
  final Color color;
  final String title;
  final String value;
  final bool isLong;

  const _MetricRow({
    required this.color,
    required this.title,
    required this.value,
    required this.isLong,
  });

  @override
  Widget build(BuildContext context) {
    final valueText = Text(
      value,
      maxLines: 1,
      softWrap: false,
      overflow: TextOverflow.visible,
      style: const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w700,
        height: 1.0,
      ).copyWith(letterSpacing: isLong ? -0.2 : 0.0),
    );

    final compressed =
        isLong
            ? Transform(
              transform: Matrix4.diagonal3Values(0.94, 1.0, 1.0),
              alignment: Alignment.centerRight,
              child: valueText,
            )
            : valueText;

    return Row(
      children: [
        _DotLabel(color: color, text: title),
        Gaps.h6,
        Expanded(
          child: Tooltip(
            message: value,
            child: Align(
              alignment: Alignment.centerRight,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerRight,
                child: compressed,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _DotLabel extends StatelessWidget {
  final Color color;
  final String text;

  const _DotLabel({required this.color, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        Gaps.h6,
        Text(
          text,
          style: TextStyle(
            color: Colors.grey.shade600,
            fontSize: 10,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}
