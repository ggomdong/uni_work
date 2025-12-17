// 로고이미지
const String logo = 'assets/images/logo_transparent.png';

// 비콘 기본 설정값
class BeaconConfig {
  // 거리/신호 기본값
  static const double maxDistanceMeters = 3.0; // 3m 이내면 OK
  static const int minRssiDbm = -65; // -65dBm 이상이면 OK

  // 비콘 자체 설정 기본값 : 아직은 사용안함
  static const int defaultTxPower = -59;
  static const int defaultStabilizeCount = 1;
  static const int defaultTimeoutSeconds = 10;
}

// 개인정보처리방침 URL
const attendancePrivacyUrl = '/wtm/privacy/';
