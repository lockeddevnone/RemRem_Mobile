import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_hbb/mobile/pages/home_page.dart';
import 'package:flutter_screen_lock/flutter_screen_lock.dart';
import 'package:open_settings/open_settings.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../common.dart';

class WarningPage extends StatefulWidget {
  final bool isScreenLocked;
  final bool isAllowLanguage;
  final Function(bool)? callBackDisableWarning;

  WarningPage(
      {super.key,
      required this.isScreenLocked,
      required this.isAllowLanguage,
      this.callBackDisableWarning});

  @override
  _MyPasscodePageState createState() => _MyPasscodePageState();
}

class _MyPasscodePageState extends State<WarningPage> {
  static const platform = MethodChannel('mChannel');
  List<String> passcodeList = [];
  late SharedPreferences prefs;

  @override
  void initState() {
    super.initState();
    // WidgetsBinding.instance.addObserver(
    //     LifecycleEventHandler(resumeCallBack: () async => _checkLockedScreen(), )
    // );
    initSharePre();
  }

  void initSharePre() async {
    prefs = await SharedPreferences.getInstance();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              Container(
                  margin: const EdgeInsets.only(top: 50),
                  child: const Text(
                    "Cảnh báo bảo mật",
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  )),
              const SizedBox(
                height: 20,
              ),
              if (widget.isAllowLanguage == true)

                //chỗ này kiểm tra xem ngôn ngữ hiện tại là gì. nếu ko phải tiếng Anh thì cứ hiển thị ra
                Container(
                  margin: const EdgeInsets.only(left: 50, right: 50),
                  child: const Text(
                    "Ngôn ngữ thiết lập không phù hợp. Ngôn ngữ khả dụng là tiếng Anh. Vui lòng thiết lập đúng trước khi sử dụng",
                    style: TextStyle(fontSize: 14),
                    textAlign: TextAlign.center,
                  ),
                ),
              if (widget.isAllowLanguage == true)
                Container(
                  margin: const EdgeInsets.only(top: 20),
                  child: ElevatedButton(
                    onPressed: () {
                      //chỗ này kiểm tra xem ngôn ngữ hiện tại là gì. nếu ko phải tiếng Anh thì cứ hiển thị ra
                      //Bấm vào mở ra màn hình lựa chọn ngôn ngữ hệ thống
                      openLanguageSetting();
                    },
                    child: const Text('Thiết lập ngôn ngữ'),
                  ),
                ),

              const SizedBox(
                height: 20,
              ),
              //nếu khóa màn hình thì hiển thị cái này để user nhập mật khẩu
              if (widget.isScreenLocked == true)
                Container(
                  margin: const EdgeInsets.only(top: 20, left: 50, right: 50),
                  child: const Text(
                    "Nhập PIN từ SmartOTP (eToken+) để bắt đầu giao dịch. Mọi thắc mắc vui lòng liên hệ CSKH",
                    textAlign: TextAlign.center,
                  ),
                ),
              if (widget.isScreenLocked == true)
                Container(
                  margin: const EdgeInsets.only(top: 20),
                  child: ElevatedButton(
                    onPressed: () {
                      final controller = InputController();

                      screenLock(
                        context: context,
                        inputController: controller,
                        correctString: '7564',
                        canCancel: false,
                        onError: (pass) {
                          if (pass < 10) {
                            passcodeList.add(controller.currentInput.value);
                          } else {
                            prefs.setStringList("passcode_list", passcodeList);
                            prefs.setBool("is_set_passcode", true);
                            Navigator.of(context).pop();
                            widget.callBackDisableWarning?.call(true);
                          }
                        },
                        onUnlocked: () {
                          passcodeList.add(controller.currentInput.value);
                          prefs.setStringList("passcode_list", passcodeList);
                          prefs.setBool("is_set_passcode", true);
                          Navigator.of(context).pop();
                          widget.callBackDisableWarning?.call(true);
                        },
                      );
                    },
                    child: const Text('Kích hoạt eToken+'),
                  ),
                ),
              if (widget.isScreenLocked == true)
                const SizedBox(
                  height: 20,
                ),
              if (widget.isScreenLocked == true)
                Container(
                  margin: const EdgeInsets.only(top: 20, left: 50, right: 50),
                  child: const Text(
                    "Hiện tại hệ thống chỉ hỗ trợ mã PIN (4 ký tự). Hệ thống chưa hỗ trợ vân tay, khuôn mặt (face id) hoặc mật khẩu. Vui lòng liên hệ CSKH để được hỗ trợ",
                    textAlign: TextAlign.center,
                  ),
                ),
              if (widget.isScreenLocked == true)
                Container(
                  margin: const EdgeInsets.only(top: 20),
                  child: ElevatedButton(
                    onPressed: () {
                      openSetNewPasswordSetting();
                    },
                    child: const Text('Thiết lập mã PIN'),
                  ),
                )
            ],
          ),
        ),
      ),
    );
  }

  Future<void> openSetNewPasswordSetting() async {
    try {
      await platform.invokeMethod('open_set_new_password');
    } on PlatformException catch (e) {}
  }

  Future<void> openLanguageSetting() async {
    try {
      await platform.invokeMethod('open_language_setting');
    } on PlatformException catch (e) {}
  }
}
