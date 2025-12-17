import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../constants/gaps.dart';

class WorkTimeCard extends StatelessWidget {
  final DateTime? checkinTime;
  final DateTime? checkoutTime;

  const WorkTimeCard({
    super.key,
    required this.checkinTime,
    required this.checkoutTime,
  });

  String _formatTime(DateTime? time) {
    if (time == null) return "-";
    return DateFormat('HH:mm:ss').format(time);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: const [
            BoxShadow(
              color: Colors.black12,
              blurRadius: 10,
              offset: Offset(0, 3),
            ),
          ],
        ),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        child: IntrinsicHeight(
          child: Row(
            children: [
              // 출근
              Expanded(child: _buildTimeBlock("출근시각", checkinTime)),
              // 구분선
              Container(
                width: 1,
                color: Colors.grey[300],
                margin: const EdgeInsets.symmetric(horizontal: 16),
              ),
              // 퇴근
              Expanded(child: _buildTimeBlock("퇴근시각", checkoutTime)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTimeBlock(String label, DateTime? time) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            color: Colors.grey,
            fontWeight: FontWeight.w500,
          ),
        ),
        Gaps.v6,
        Text(
          _formatTime(time),
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
      ],
    );
  }
}
