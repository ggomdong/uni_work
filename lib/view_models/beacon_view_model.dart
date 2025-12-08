import 'package:flutter/foundation.dart';
import 'dart:async';
import 'dart:io' show Platform;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dchs_flutter_beacon/dchs_flutter_beacon.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:logger/logger.dart';
import '../models/beacon_model.dart';
import '../repos/beacon_repo.dart';

// ===== 상태 =====
class BeaconState {
  final bool isDetected;
  final List<Beacon> beacons;
  final bool isScanning;
  final String? error;

  const BeaconState({
    required this.isDetected,
    required this.beacons,
    required this.isScanning,
    this.error,
  });

  BeaconState copy({
    bool? isDetected,
    List<Beacon>? beacons,
    bool? isScanning,
    String? error, // null을 주면 null로 바꿈(초기화 허용)
    bool clearError = false, // true면 error를 강제로 null로
  }) {
    return BeaconState(
      isDetected: isDetected ?? this.isDetected,
      beacons: beacons ?? this.beacons,
      isScanning: isScanning ?? this.isScanning,
      error: clearError ? null : (error ?? this.error),
    );
  }

  factory BeaconState.initial() => const BeaconState(
    isDetected: false,
    beacons: [],
    isScanning: false,
    error: null,
  );
}

// ===== Notifier =====
class BeaconNotifier extends StateNotifier<BeaconState> {
  BeaconNotifier(this._ref) : super(BeaconState.initial()) {
    _repo = _ref.read(beaconRepo);
  }

  final Ref _ref;
  late final BeaconRepository _repo;

  /// 서버에서 내려온 비콘 설정 (현재 지점 기준)
  List<BeaconModel> _configs = [];

  StreamSubscription<RangingResult>? _subRanging;
  StreamSubscription<BluetoothState>? _subBt;
  StreamSubscription<AuthorizationStatus>? _subAuth;

  bool _prepared = false;
  int _activeListeners = 0;

  Logger logger = Logger();

  // 아주 얕은 완충 장치(깜빡임만 줄임)
  int _hitStreak = 0; // 연속 "감지" 프레임 수
  int _missStreak = 0; // 연속 "미감지" 프레임 수
  static const int _needHitsForOn = 1; // 프레임 연속 감지되면 ON 되는 기준
  static const int _needMissForOff = 5; // 프레임 연속 미감지되면 OFF 되는 기준

  /// 외부(화면)에서 첫 구독 시 호출
  void addListenerRef() {
    _activeListeners++;
    logger.d('[BEACON] addListenerRef(): active = $_activeListeners');
    if (_activeListeners == 1) {
      _boot();
    }
  }

  /// 외부(화면) dispose 시 호출
  void removeListenerRef() {
    _activeListeners--;
    if (_activeListeners <= 0) {
      _activeListeners = 0;
      _stop();
    }
  }

  /// 서버에서 해당 직원이 속한 지점의 비콘 정보를 로드
  Future<void> _ensureConfigsLoaded() async {
    if (_configs.isNotEmpty) return;

    logger.d('[BEACON] 서버 비콘 설정 로드 시도');
    final configs = await _repo.fetchBeacons(); // GET api/beacons/

    logger.d('[BEACON] 서버 비콘 설정 응답: ${configs.length}개');

    if (configs.isEmpty) {
      throw '서버에 설정된 비콘 정보가 없습니다.\n관리자에게 문의해주세요.';
    }
    _configs = configs;
    for (final c in _configs) {
      logger.d(
        '[BEACON] CONFIG: id=${c.id},'
        ' branch=${c.branchCode},'
        ' name=${c.name},'
        ' uuid=${c.uuid},'
        ' major=${c.major}, minor=${c.minor},'
        ' maxDist=${c.maxDistanceMeters}, rssi=${c.rssiThreshold}',
      );
    }
  }

  BeaconModel? _findConfigFor(Beacon beacon) {
    final uuid = beacon.proximityUUID.toUpperCase();
    final major = beacon.major;
    final minor = beacon.minor;

    try {
      return _configs.firstWhere(
        (c) =>
            c.uuid.toUpperCase() == uuid &&
            c.major == major &&
            c.minor == minor,
      );
    } catch (_) {
      return null;
    }
  }

  /// 거리/신호세기 기준으로 비콘 필터링
  List<Beacon> _filterByDistanceAndRssi(List<Beacon> beacons) {
    final filtered = <Beacon>[];

    for (final b in beacons) {
      final conf = _findConfigFor(b);
      if (conf == null) {
        // 이론상 없어야 하지만, 혹시라도 서버 설정과 안 맞는 비콘이면 스킵
        if (kDebugMode) {
          logger.d(
            '[BEACON] FILTER OUT (no config): '
            'uuid=${b.proximityUUID}, major=${b.major}, minor=${b.minor}, '
            'acc=${b.accuracy.toStringAsFixed(2)}, rssi=${b.rssi}',
          );
        }
        continue;
      }

      // 서버 설정값이 있으면 그걸, 없으면 기본값 사용(BeaconModel에서 설정하고 있음)
      final maxDist = conf.maxDistanceMeters;
      final minRssi = conf.rssiThreshold;

      final distance = b.accuracy; // 미터 추정값 (음수면 의미 없음)
      final rssi = b.rssi; // dBm (0 이거나 극단값이면 노이즈일 수 있음)

      // 1) 거리 조건: 0m < 거리 <= maxDist
      final hasValidDistance = distance > 0 && distance <= maxDist;

      // 2) 신호 조건: rssiThreshold 이상 (예: -65 이상)
      //    rssi == 0 인 경우는 "측정 실패"로 많이 나오니까 일단 제외
      final hasStrongRssi = rssi != 0 && rssi >= minRssi;

      if (hasValidDistance || hasStrongRssi) {
        // 최종 후보
        filtered.add(b);
        if (kDebugMode) {
          logger.d(
            '[BEACON] PASS: uuid=${b.proximityUUID}, major=${b.major}, minor=${b.minor}, '
            'acc=${distance.toStringAsFixed(2)} / max=$maxDist, '
            'rssi=$rssi / min=$minRssi',
          );
        }
      } else {
        if (kDebugMode) {
          logger.d(
            '[BEACON] FILTER OUT (dist/RSSI): uuid=${b.proximityUUID}, '
            'major=${b.major}, minor=${b.minor}, '
            'acc=${distance.toStringAsFixed(2)} / max=$maxDist, '
            'rssi=$rssi / min=$minRssi',
          );
        }
      }
    }

    return filtered;
  }

  Future<void> _boot() async {
    logger.d('[BEACON] >>> ENTER _boot()');
    try {
      state = state.copy(clearError: true);

      // 1) 서버에서 사용자의 지점 비콘 설정 가져오기
      await _ensureConfigsLoaded();

      // 2) OS 권한 / 위치 / 블루투스 준비
      await _ensurePermissionsAndServices();
      _prepared = true;

      // 3) 블루투스/권한 상태 변화 감시 → 바뀌면 재시작
      _subBt ??= flutterBeacon.bluetoothStateChanged().listen(
        (_) => _restart(),
      );
      _subAuth ??= flutterBeacon.authorizationStatusChanged().listen(
        (_) => _restart(),
      );

      logger.d('[BEACON] >>> _boot(): _prepared = true, calling _start()');
      await _start();
    } catch (e) {
      logger.d('[BEACON] >>> _boot() ERROR:');
      state = state.copy(isScanning: false, error: e.toString());
    }
  }

  Future<void> _start() async {
    logger.d('[BEACON] >>> ENTER _start()');
    if (!_prepared || state.isScanning) return;

    // 안드로이드 깜빡임만 살짝 줄이는 주기 (iOS 영향 거의 없음)
    await flutterBeacon.setScanPeriod(900);
    await flutterBeacon.setBetweenScanPeriod(500);

    if (_configs.isEmpty) {
      logger.w('[BEACON] _start() 시점에 _configs가 비어있습니다.');
      return;
    }

    // Region 구성
    final regions = <Region>[];
    for (final conf in _configs) {
      regions.add(
        Region(
          identifier: 'B:${conf.id}', // 혹은 conf.name
          proximityUUID: conf.uuid,
          major: conf.major,
          minor: conf.minor,
        ),
      );
    }

    logger.d('[BEACON] 스캔 시작 - region 수=${regions.length}');
    for (final r in regions) {
      logger.d(
        '[BEACON] REGION: id=${r.identifier}, uuid=${r.proximityUUID}, major=${r.major}, minor=${r.minor}',
      );
    }

    state = state.copy(isScanning: true);

    _subRanging = flutterBeacon
        .ranging(regions)
        .listen(
          (result) {
            // 1) 기본 로그
            if (kDebugMode) {
              logger.d(
                '[BEACON] ranging: region=${result.region.identifier}, '
                'rawCount=${result.beacons.length}',
              );

              for (final b in result.beacons) {
                logger.d(
                  '[BEACON] RAW: uuid=${b.proximityUUID}, major=${b.major}, minor=${b.minor},'
                  ' acc=${b.accuracy.toStringAsFixed(2)}, rssi=${b.rssi}',
                );
              }
            }

            // 2) 거리/신호 기준으로 필터링
            final candidates = _filterByDistanceAndRssi(result.beacons);

            if (kDebugMode) {
              logger.d(
                '[BEACON] FILTERED: region=${result.region.identifier}, '
                'filteredCount=${candidates.length}',
              );
            }

            final seen = candidates.isNotEmpty;

            if (seen) {
              _hitStreak++;
              _missStreak = 0;

              if (!state.isDetected) {
                if (_hitStreak >= _needHitsForOn) {
                  logger.d('[BEACON] DETECTED ON (hitStreak=$_hitStreak)');
                  state = state.copy(isDetected: true, beacons: candidates);
                }
              } else {
                state = state.copy(beacons: candidates);
              }
            } else {
              _hitStreak = 0;
              _missStreak++;

              if (state.isDetected && _missStreak >= _needMissForOff) {
                logger.d('[BEACON] DETECTED OFF (missStreak=$_missStreak)');
                state = state.copy(isDetected: false, beacons: []);
              }
            }
          },
          onError: (err) {
            state = state.copy(isScanning: false, error: '비콘 스캔 오류: $err');
          },
        );
  }

  Future<void> _stop() async {
    await _subRanging?.cancel();
    _subRanging = null;
    state = state.copy(isScanning: false, isDetected: false, beacons: []);
  }

  Future<void> _restart() async {
    await _stop();
    // 재확인 (권한/토글 바뀌었으면 prepare가 invalid일 수 있음)
    try {
      state = state.copy(clearError: true);

      await _ensurePermissionsAndServices();
      _prepared = true;
      await _start();
    } catch (e) {
      state = state.copy(isScanning: false, error: e.toString());
    }
  }

  // ===== 권한/서비스 준비 (SDK 분기) =====
  Future<void> _ensurePermissionsAndServices() async {
    logger.d('[BEACON] >>> ENTER _ensurePermissionsAndServices');
    await flutterBeacon.initializeScanning;

    // 블루투스 켜질 때까지 짧게 대기
    if (await flutterBeacon.bluetoothState != BluetoothState.stateOn) {
      await for (final s in flutterBeacon.bluetoothStateChanged()) {
        if (s == BluetoothState.stateOn) break;
      }
    }

    int sdkInt = 0;
    if (Platform.isAndroid) {
      final info = await DeviceInfoPlugin().androidInfo;
      sdkInt = info.version.sdkInt;
      logger.d('sdk버젼정보입니다~~~~~~~~~~~~~~~~~~~~~~ $sdkInt');
    }

    if (Platform.isAndroid) {
      if (sdkInt >= 31) {
        // Android 12+
        logger.d('🔐 [Beacon] Android 12+ 권한 확인');

        // 1. 블루투스 스캔 권한
        var scan = await Permission.bluetoothScan.status;
        // print('   bluetoothScan 초기 상태: $scan');
        if (!scan.isGranted) {
          scan = await Permission.bluetoothScan.request();
          // print('   bluetoothScan 요청 후: $scan');
          if (scan.isPermanentlyDenied) {
            throw '블루투스 스캔 권한이 거부되었습니다.\n설정에서 "주변 기기" 권한을 허용해주세요.';
          }
          if (!scan.isGranted) {
            throw '블루투스 스캔 권한이 필요합니다.\n비콘 인식을 위해 권한을 허용해주세요.';
          }
        }

        // 2. 블루투스 연결 권한
        var conn = await Permission.bluetoothConnect.status;
        // print('   bluetoothConnect 초기 상태: $conn');
        if (!conn.isGranted) {
          conn = await Permission.bluetoothConnect.request();
          // print('   bluetoothConnect 요청 후: $conn');
        }

        // 3. 위치 권한 (정확한 위치 필수!)
        var loc = await Permission.location.status;
        logger.d('   location 초기 상태: $loc');

        if (!loc.isGranted) {
          // 먼저 기본 위치 권한 요청
          loc = await Permission.location.request();
          logger.d('   location 요청 후: $loc');

          if (loc.isPermanentlyDenied) {
            throw '위치 권한이 거부되었습니다.\n\n비콘 인식을 위해 설정에서:\n1. 위치 권한을 "앱 사용 중에만 허용"으로 설정\n2. "정확한 위치" 사용 켜기';
          }

          if (!loc.isGranted) {
            throw '위치 권한이 필요합니다.\n비콘 인식을 위해 권한을 허용해주세요.';
          }
        }

        // 정확한 위치 권한 확인 (Android 12+)
        var locWhenInUse = await Permission.locationWhenInUse.status;
        logger.d('   locationWhenInUse 상태: $locWhenInUse');
        if (!locWhenInUse.isGranted) {
          locWhenInUse = await Permission.locationWhenInUse.request();
          logger.d('   locationWhenInUse 요청 후: $locWhenInUse');
        }

        if (loc.isGranted && !locWhenInUse.isGranted) {
          logger.d(
            '   locationWhenInUse 상태: ${loc.isGranted}, ${locWhenInUse.isGranted}',
          );
          state = state.copy(
            error:
                '현재 "대략적인 위치"만 허용되어 있어\n'
                '비콘 인식이 불안정할 수 있습니다.\n\n'
                '설정 > 위치 > 앱 권한에서 이 앱을 선택하고\n'
                '"정확한 위치"를 켜주세요.',
          );
        }

        // 4. 위치 서비스 확인
        try {
          final locServiceEnabled =
              await flutterBeacon.checkLocationServicesIfEnabled;
          // print('   위치 서비스: $locServiceEnabled');
          if (!locServiceEnabled) {
            throw '위치 서비스가 꺼져 있습니다.\n\n기기 설정에서 위치를 켜주세요.';
          }
        } catch (e) {
          if (e.toString().contains('위치 서비스')) rethrow;
          // print('   ⚠️ 위치 서비스 확인 실패: $e');
        }
      } else if (sdkInt >= 29) {
        // Android 10, 11
        logger.d('🔐 [Beacon] Android 10-11 권한 확인');

        // 정확한 위치 권한 필수
        var loc = await Permission.location.status;
        // print('   location 초기 상태: $loc');

        if (!loc.isGranted) {
          loc = await Permission.location.request();
          // print('   location 요청 후: $loc');

          if (loc.isPermanentlyDenied) {
            throw '위치 권한이 거부되었습니다.\n\n비콘 인식을 위해 설정에서 위치 권한을 허용해주세요.';
          }
          if (!loc.isGranted) {
            throw '위치 권한이 필요합니다.\n비콘 인식을 위해 권한을 허용해주세요.';
          }
        }

        // 위치 서비스 확인
        final locServiceEnabled =
            await flutterBeacon.checkLocationServicesIfEnabled;
        // print('   위치 서비스: $locServiceEnabled');
        if (!locServiceEnabled) {
          throw '위치 서비스가 꺼져 있습니다.\n\n기기 설정에서 위치를 켜주세요.';
        }
      } else {
        // Android 9 이하
        // print('🔐 [Beacon] Android 9 이하 권한 확인');

        var loc = await Permission.location.status;
        // print('   location 초기 상태: $loc');

        if (!loc.isGranted) {
          loc = await Permission.location.request();
          // print('   location 요청 후: $loc');

          if (loc.isPermanentlyDenied) {
            throw '위치 권한이 거부되었습니다.\n\n설정에서 위치 권한을 허용해주세요.';
          }
          if (!loc.isGranted) {
            throw '위치 권한이 필요합니다';
          }
        }

        final locServiceEnabled =
            await flutterBeacon.checkLocationServicesIfEnabled;
        // print('   위치 서비스: $locServiceEnabled');
        if (!locServiceEnabled) {
          throw '위치 서비스가 꺼져 있습니다.\n\n기기 설정에서 위치를 켜주세요.';
        }
      }
    } else if (Platform.isIOS) {
      // print('🔐 [Beacon] iOS 권한 확인');

      var status = await flutterBeacon.authorizationStatus;
      // print('   authorizationStatus: $status');

      if (status == AuthorizationStatus.notDetermined) {
        // print('   권한 요청 중...');
        await flutterBeacon.requestAuthorization;
        status = await flutterBeacon.authorizationStatus;
        // print('   권한 요청 결과: $status');
      }

      if (status == AuthorizationStatus.denied ||
          status == AuthorizationStatus.restricted) {
        throw '위치 권한이 필요합니다';
      }
    } else {
      throw '지원되지 않는 플랫폼';
    }

    logger.d('✅ [Beacon] 모든 권한 및 서비스 준비 완료');
  }

  @override
  Future<void> dispose() async {
    await _stop();
    await _subBt?.cancel();
    await _subAuth?.cancel();
    super.dispose();
  }
}

// ===== Providers =====
final beaconProvider = StateNotifierProvider<BeaconNotifier, BeaconState>((
  ref,
) {
  return BeaconNotifier(ref);
});

final isBeaconDetectedProvider = Provider<bool>((ref) {
  return ref.watch(beaconProvider).isDetected;
});
final beaconListProvider = Provider<List<Beacon>>((ref) {
  return ref.watch(beaconProvider).beacons;
});
final beaconScanningProvider = Provider<bool>((ref) {
  return ref.watch(beaconProvider).isScanning;
});
final beaconErrorProvider = Provider<String?>((ref) {
  return ref.watch(beaconProvider).error;
});
