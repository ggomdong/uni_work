import '../constants/constants.dart';

class BeaconModel {
  final int id;
  final String branchCode;
  final String branchName;
  final String name;
  final String uuid;
  final int major;
  final int minor;
  final double maxDistanceMeters;
  final int rssiThreshold;
  final int txPower;
  final int stabilizeCount;
  final int timeoutSeconds;
  final bool isActive;
  final DateTime? validFrom;
  final DateTime? validTo;

  BeaconModel({
    required this.id,
    required this.branchCode,
    required this.branchName,
    required this.name,
    required this.uuid,
    required this.major,
    required this.minor,
    required this.maxDistanceMeters,
    required this.rssiThreshold,
    required this.txPower,
    required this.stabilizeCount,
    required this.timeoutSeconds,
    required this.isActive,
    this.validFrom,
    this.validTo,
  });

  factory BeaconModel.fromJson(Map<String, dynamic> json) {
    return BeaconModel(
      id: json['id'] as int,
      branchCode: json['branch_code'] as String? ?? '',
      branchName: json['branch_name'] as String? ?? '',
      name: json['name'] as String? ?? '',
      uuid: json['uuid'] as String? ?? '',
      major: json['major'] as int,
      minor: json['minor'] as int,
      maxDistanceMeters:
          (json['max_distance_meters'] as num?)?.toDouble() ??
          BeaconConfig.maxDistanceMeters,
      rssiThreshold: json['rssi_threshold'] as int? ?? BeaconConfig.minRssiDbm,
      txPower: json['tx_power'] as int? ?? BeaconConfig.defaultTxPower,
      stabilizeCount:
          json['stabilize_count'] as int? ?? BeaconConfig.defaultStabilizeCount,
      timeoutSeconds:
          json['timeout_seconds'] as int? ?? BeaconConfig.defaultTimeoutSeconds,
      isActive: json['is_active'] as bool? ?? true,
      validFrom:
          json['valid_from'] != null
              ? DateTime.tryParse(json['valid_from'] as String)
              : null,
      validTo:
          json['valid_to'] != null
              ? DateTime.tryParse(json['valid_to'] as String)
              : null,
    );
  }
}
