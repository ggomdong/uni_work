import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:go_router/go_router.dart';
import '../utils.dart';
import '../constants/sizes.dart';
import '../view_models/beacon_view_model.dart';
import '../views/home_screen.dart';
import '../views/profile_screen.dart';
import '../views/stat_screen.dart';
import '../views/widgets/nav_tab.dart';

class MainNavigationScreen extends ConsumerStatefulWidget {
  static const String routeName = "mainNavigation";
  const MainNavigationScreen({super.key, required this.tab});

  final String tab;

  @override
  ConsumerState<MainNavigationScreen> createState() =>
      _MainNavigationScreenState();
}

class _MainNavigationScreenState extends ConsumerState<MainNavigationScreen>
    with WidgetsBindingObserver {
  final List<String> _tabs = ["home", "calendar", "stat", "profile"];

  late int _selectedIndex =
      _tabs.contains(widget.tab) ? _tabs.indexOf(widget.tab) : 0;

  BeaconNotifier? _beacon;
  bool _beaconHolding = false;
  bool _appForeground = true;

  bool get _shouldScan => _appForeground && _selectedIndex == 0; // 홈 탭만 스캔

  void _syncBeacon() {
    if (_beacon == null) return;

    if (_shouldScan) {
      if (!_beaconHolding) {
        _beacon!.addListenerRef();
        _beaconHolding = true;
      }
    } else {
      if (_beaconHolding) {
        _beacon!.removeListenerRef();
        _beaconHolding = false;
      }
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _beacon = ref.read(beaconProvider.notifier);
      _syncBeacon();
    });
  }

  //최초 로딩시 라우팅을 적용함. url을 직접 쳤을때 대응을 위함
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final currentTab = GoRouterState.of(context).matchedLocation.split('/')[1];
    if (_tabs.contains(currentTab)) {
      _selectedIndex = _tabs.indexOf(currentTab);
    } else {
      _selectedIndex = 0;
    }
    _syncBeacon(); // 중요: URL로 들어왔을 때도 스캔 상태 동기화
  }

  void _onTap(int index) {
    context.go("/${_tabs[index]}");
    setState(() {
      _selectedIndex = index;
    });
    _syncBeacon(); // 탭 변경 즉시 ON/OFF
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _appForeground = (state == AppLifecycleState.resumed);
    _syncBeacon(); // 백그라운드면 OFF, 복귀하면(홈 탭일 때만) ON
  }

  @override
  void dispose() {
    if (_beaconHolding) {
      _beacon?.removeListenerRef();
      _beaconHolding = false;
    }
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = isDarkMode(ref);
    return Scaffold(
      resizeToAvoidBottomInset: false,
      backgroundColor: isDark ? Colors.black : Colors.white,
      body: Stack(
        children: [
          Offstage(offstage: _selectedIndex != 0, child: const HomeScreen()),
          // Offstage(offstage: _selectedIndex != 1, child: IBeaconScanner()),
          Offstage(offstage: _selectedIndex != 2, child: StatScreen()),
          Offstage(offstage: _selectedIndex != 3, child: ProfileScreen()),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: isDark ? Colors.black : Colors.white,
          border: Border(
            top: BorderSide(
              color: isDark ? Colors.white : Colors.black,
              width: Sizes.size2,
            ),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.only(
            left: Sizes.size12,
            right: Sizes.size12,
            top: Sizes.size24,
            bottom: Sizes.size52,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              NavTab(
                isSelected: _selectedIndex == 0,
                icon: FontAwesomeIcons.house,
                selectedIcon: FontAwesomeIcons.house,
                onTap: () => _onTap(0),
                selectedIndex: _selectedIndex,
              ),
              // NavTab(
              //   isSelected: _selectedIndex == 1,
              //   icon: FontAwesomeIcons.solidClock,
              //   selectedIcon: FontAwesomeIcons.solidClock,
              //   onTap: () => _onTap(1),
              //   selectedIndex: _selectedIndex,
              // ),
              NavTab(
                isSelected: _selectedIndex == 2,
                icon: FontAwesomeIcons.chartSimple,
                selectedIcon: FontAwesomeIcons.chartSimple,
                onTap: () => _onTap(2),
                selectedIndex: _selectedIndex,
              ),
              NavTab(
                isSelected: _selectedIndex == 3,
                icon: FontAwesomeIcons.solidUser,
                selectedIcon: FontAwesomeIcons.solidUser,
                onTap: () => _onTap(3),
                selectedIndex: _selectedIndex,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
