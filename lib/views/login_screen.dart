import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
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
  Map<String, String> formData = {};

  // Keyboard 외의 영역 클릭시 Keyboard가 사라지도록 처리
  void _onScaffoldTap() {
    FocusScope.of(context).unfocus();
  }

  // password 비식별 처리 토글
  void _toggleObscureText() {
    _obscureText = !_obscureText;
    setState(() {});
  }

  void _onSubmitForm() {
    if (_formKey.currentState != null) {
      if (_formKey.currentState!.validate()) {
        _formKey.currentState!.save();
        ref
            .read(loginProvider.notifier)
            .login(formData['username']!, formData['password']!, context);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _onScaffoldTap,
      child: Scaffold(
        resizeToAvoidBottomInset: true,
        body: Padding(
          padding: const EdgeInsets.all(Sizes.size20),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Gaps.v96,
                Center(
                  child: Image.asset(
                    logo,
                    width: 186,
                    height: 70,
                    alignment: Alignment.center,
                  ),
                ),
                Gaps.v52,
                TextFormField(
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
                      formData['username'] = '010${value.replaceAll('-', '')}';
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
                Gaps.v32,
                FormButton(
                  disabled: ref.watch(loginProvider).isLoading,
                  text: "로그인",
                  onTap: _onSubmitForm,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
