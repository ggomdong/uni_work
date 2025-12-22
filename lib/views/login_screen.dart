import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../repos/authentication_repo.dart';
import '../views/widgets/snackbar.dart';
import '../view_models/login_view_model.dart';
import '../constants/constants.dart';
import '../constants/gaps.dart';
import '../constants/sizes.dart';
import '../utils.dart';
import '../views/widgets/form_button.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  bool _obscureText = true;
  // username: 휴대폰 번호 ('01012345678' 형식)
  Map<String, String> formData = {};
  bool _rememberUsername = false;
  String? _initialUsername;

  @override
  void initState() {
    super.initState();

    _loadSavedId();
  }

  Future<void> _loadSavedId() async {
    final prefs = ref.read(sharedPreferencesProvider);
    final savedUsername = prefs.getString('saved_username');
    if (savedUsername != null && mounted) {
      setState(() {
        _initialUsername = savedUsername;
        _rememberUsername = true;
      });
    }
  }

  // Keyboard 외의 영역 클릭시 Keyboard가 사라지도록 처리
  void _onScaffoldTap() {
    FocusScope.of(context).unfocus();
  }

  // password 비식별 처리 토글
  void _toggleObscureText() {
    _obscureText = !_obscureText;
    setState(() {});
  }

  void _onSubmitForm() async {
    if (_formKey.currentState?.validate() ?? false) {
      _formKey.currentState!.save();

      final prefs = ref.read(sharedPreferencesProvider);
      if (_rememberUsername) {
        await prefs.setString('saved_username', formData['username']!);
      } else {
        await prefs.remove('saved_username');
      }

      final success = await ref
          .read(loginProvider.notifier)
          .login(formData['username']!, formData['password']!);

      if (mounted) {
        if (success) {
          showSnackBar(context, '로그인 되었습니다.', Colors.blue);
          return;
        } else {
          final async = ref.read(loginProvider);
          final err = async.error;

          String message = '로그인 실패';
          if (err is String) {
            message = err;
          } else if (err is DioException) {
            final data = err.response?.data;
            if (data is Map<String, dynamic>) {
              message =
                  (data['message'] as String?) ??
                  (data['detail'] as String?) ??
                  message;
            }
          }

          showSnackBar(context, message, Colors.red);
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // 폰 크기에 따른 Gap 사이즈 반응형 처리
    final screenHeight = MediaQuery.of(context).size.height;
    final isSmallScreen = screenHeight < 650;

    final topGap = isSmallScreen ? Gaps.v48 : Gaps.v96;
    final logoGap = isSmallScreen ? Gaps.v24 : Gaps.v52;
    final bottomGap = isSmallScreen ? Gaps.v24 : Gaps.v32;

    return GestureDetector(
      onTap: _onScaffoldTap,
      child: Scaffold(
        resizeToAvoidBottomInset: true,
        body: Padding(
          padding: const EdgeInsets.all(Sizes.size20),
          child: Form(
            key: _formKey,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  topGap,
                  Center(
                    child: Image.asset(
                      logo,
                      width: 186,
                      height: 70,
                      alignment: Alignment.center,
                    ),
                  ),
                  logoGap,
                  TextFormField(
                    initialValue: formatInitialPhone(_initialUsername),
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(8),
                      PhoneInputFormatter(),
                    ],
                    decoration: InputDecoration(
                      border: const OutlineInputBorder(),
                      labelText: 'ID (휴대폰 번호)',
                      prefixText: '010-',
                      prefixStyle: TextStyle(
                        color: Colors.black,
                        fontSize: Sizes.size16,
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderSide: BorderSide(
                          color: Theme.of(context).primaryColor,
                          width: 2,
                        ),
                      ),
                    ),
                    validator: (value) {
                      if (value == null ||
                          value.trim().isEmpty ||
                          value.trim().length != 9) {
                        return 'ID를 정확히 입력해주세요.';
                      }
                      return null;
                    },
                    onSaved: (value) {
                      if (value != null) {
                        // '010' 추가 및 하이픈 제거
                        formData['username'] =
                            '010${value.replaceAll('-', '')}';
                      }
                    },
                  ),
                  Gaps.v10,
                  TextFormField(
                    obscureText: _obscureText,
                    decoration: InputDecoration(
                      suffix: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          GestureDetector(
                            onTap: _toggleObscureText,
                            child: FaIcon(
                              _obscureText
                                  ? FontAwesomeIcons.eye
                                  : FontAwesomeIcons.eyeSlash,
                              color: Colors.grey.shade500,
                              size: Sizes.size20,
                            ),
                          ),
                        ],
                      ),
                      border: const OutlineInputBorder(),
                      labelText: 'Password',
                      focusedBorder: OutlineInputBorder(
                        borderSide: BorderSide(
                          color: Theme.of(context).primaryColor,
                          width: Sizes.size2,
                        ),
                      ),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Password를 입력해주세요.';
                      }
                      return null;
                    },
                    onSaved: (value) {
                      if (value != null) {
                        formData['password'] = value;
                      }
                    },
                  ),
                  Row(
                    children: [
                      Checkbox(
                        value: _rememberUsername,
                        onChanged: (value) {
                          setState(() {
                            _rememberUsername = value ?? false;
                          });
                        },
                        checkColor: Colors.white,
                        fillColor: WidgetStateProperty.resolveWith<Color>((
                          states,
                        ) {
                          if (states.contains(WidgetState.selected)) {
                            return Theme.of(context).primaryColor; // 체크된 경우
                          }
                          return Colors.white; // 미선택 시 회색
                        }),
                      ),
                      const Text('ID 기억하기'),
                    ],
                  ),
                  bottomGap,
                  FormButton(
                    disabled: ref.watch(loginProvider).isLoading,
                    text: "로그인",
                    onTap: _onSubmitForm,
                  ),
                  Gaps.v10,
                  TextButton(
                    onPressed: () => openPrivacy(ref),
                    child: const Text(
                      '개인정보처리방침',
                      style: TextStyle(fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
