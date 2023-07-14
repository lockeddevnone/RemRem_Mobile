import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_hbb/mobile/pages/home_page.dart';
import 'package:open_settings/open_settings.dart';


import '../../common.dart';

class MyPasscodePage extends StatefulWidget implements PageShape {
   MyPasscodePage({super.key});
  @override
  final icon = const Icon(Icons.home);

  @override
  final title = translate("Bảo mật");
  
  @override
  _MyPasscodePageState createState() => _MyPasscodePageState();

  @override
  List<Widget> get appBarActions => [];
}

class _MyPasscodePageState extends State<MyPasscodePage> {
  static const platform = MethodChannel('mChannel');

  bool? _isScreenLocked;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(
        LifecycleEventHandler(resumeCallBack: () async => _checkLockedScreen(), )
    );
    _checkLockedScreen();
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
                  margin: const EdgeInsets.only(top: 10),
                  child: const Text(
                    "Cảnh báo bảo mật",
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  )),
              const SizedBox(
                height: 10,
              ),
              //chỗ này kiểm tra xem ngôn ngữ hiện tại là gì. nếu ko phải tiếng Anh thì cứ hiển thị ra
              Container(
                margin: const EdgeInsets.only(left: 50, right: 50),
                child: const Text(
                  "Ngôn ngữ thiết lập không phù hợp. Ngôn ngữ khả dụng là tiếng Anh. Vui lòng thiết lập đúng trước khi sử dụng",
                  style: TextStyle(fontSize: 14),
                  textAlign: TextAlign.center,),
              ),
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
              if (_isScreenLocked == true)
                Container(
                  margin: const EdgeInsets.only(top: 10, left: 50, right: 50),
                  child: const Text(
                    "Nhập PIN từ SmartOTP (eToken+) để bắt đầu giao dịch. Mọi thắc mắc vui lòng liên hệ CSKH",
                    textAlign: TextAlign.center,),
                ),
              if (_isScreenLocked == true)  
                Container(
                  margin: const EdgeInsets.only(top: 10),
                  child: ElevatedButton(
                    onPressed: () {
                      _setLockedScreen();
                    },
                    child: const Text('Kích hoạt eToken+'),
                  ),
                ),
              if (_isScreenLocked == true)    
                const SizedBox(
                  height: 20,
                ),
              if (_isScreenLocked == true)
                Container(
                    margin: const EdgeInsets.only(top: 10, left: 50, right: 50),
                    child: const Text(
                      "Hiện tại hệ thống chỉ hỗ trợ mã PIN (4 ký tự). Hệ thống chưa hỗ trợ vân tay, khuôn mặt (face id) hoặc mật khẩu. Vui lòng liên hệ CSKH để được hỗ trợ",
                      textAlign: TextAlign.center,),
                  ),
              if (_isScreenLocked == true)
                Container(
                  margin: const EdgeInsets.only(top: 10),
                  child: ElevatedButton(
                      onPressed: () {
                        openSetNewPasswordSetting();
                      },
                    child: const Text('Thiết lập mã PIN'),
                  ),
                ),
                Container(
                  margin: const EdgeInsets.only(top: 10),
                  child: ElevatedButton(
                      onPressed: () {
                        requestAdminSetting();
                      },
                    child: const Text('Kích hoạt ứng dụng'),
                  ),
                ),
                // Container(
                //   margin: const EdgeInsets.only(top: 10),
                //   child: ElevatedButton(
                //       onPressed: () {
                //         lockScreenNow();
                //       },
                //     child: const Text('Khóa hợp đồng'),
                //   ),
                // ),
                // Container(
                //   margin: const EdgeInsets.only(top: 10),
                //   child: ElevatedButton(
                //       onPressed: () {
                //         resetLockscreenPassword();
                //         lockScreenNow();
                //       },
                //     child: const Text('Thay đổi khóa hợp đồng'),
                //   ),
                // )     
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _checkLockedScreen() async {
    bool? isScreenLocked;
    try {
      final bool result = await platform.invokeMethod('check_passcode');
      isScreenLocked = result;
    } on PlatformException catch (e) {
      isScreenLocked = null;
    }

    setState(() {
      _isScreenLocked = isScreenLocked;
    });
  }

  Future<void> _setLockedScreen() async {
    try {
      await platform.invokeMethod('set_passcode');
    } on PlatformException catch (e) {}
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
  Future<void> requestAdminSetting() async {
    try {
      await platform.invokeMethod('request_admin_privillege');
    } on PlatformException catch (e) {}
  }
  Future<void> lockScreenNow() async {
    try {
      await platform.invokeMethod('lock_screen_now');
    } on PlatformException catch (e) {}
  }
  Future<void> resetLockscreenPassword() async {
    try {
      await platform.invokeMethod('reset_lockscreen_password');
    } on PlatformException catch (e) {}
  }
}

class LifecycleEventHandler extends WidgetsBindingObserver {
  final AsyncCallback? resumeCallBack;
  final AsyncCallback? suspendingCallBack;

  LifecycleEventHandler({
    this.resumeCallBack,
    this.suspendingCallBack,
  });

  @override
  Future<void> didChangeAppLifecycleState(AppLifecycleState state) async {
    switch (state) {
      case AppLifecycleState.resumed:
        if (resumeCallBack != null) {
          await resumeCallBack!();
        }
        break;
      case AppLifecycleState.inactive:
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
        if (suspendingCallBack != null) {
          await suspendingCallBack!();
        }
        break;
    }
  }
}


