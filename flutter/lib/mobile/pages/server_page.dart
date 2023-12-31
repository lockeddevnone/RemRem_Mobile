import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
    //++++Reminani : them form xac thuc thong tin
import 'package:flutter_hbb/mobile/widgets/auth_view.dart';
import 'package:flutter_hbb/mobile/widgets/auth_view_disable.dart';
    //----Reminani : them form xac thuc thong tin
import 'package:flutter_hbb/mobile/widgets/dialog.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';

import '../../common.dart';
import '../../common/widgets/dialog.dart';
import '../../consts.dart';
import '../../models/platform_model.dart';
import '../../models/server_model.dart';
import 'home_page.dart';

class ServerPage extends StatefulWidget implements PageShape {
    //++++Reminani : them form xac thuc thong tin
  final VoidCallback callback;
  ServerPage({Key? key, required this.callback})
      : super(key: key);  @override
  final title = translate("Xác thực");
    //----Reminani : them form xac thuc thong tin

  @override
  final icon = const Icon(Icons.mobile_screen_share);

  @override
  final appBarActions = [
    PopupMenuButton<String>(
        tooltip: "",
        icon: const Icon(Icons.more_vert),
        itemBuilder: (context) {
          listTile(String text, bool checked) {
            return ListTile(
                title: Text(translate(text)),
                trailing: Icon(
                  Icons.check,
                  color: checked ? null : Colors.transparent,
                ));
          }

          final approveMode = gFFI.serverModel.approveMode;
          final verificationMethod = gFFI.serverModel.verificationMethod;
          final showPasswordOption = approveMode != 'click';
          return [
            PopupMenuItem(
              enabled: gFFI.serverModel.connectStatus > 0,
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              value: "changeID",
              child: Text(translate("Change ID")),
            ),
            const PopupMenuDivider(),
            PopupMenuItem(
              padding: const EdgeInsets.symmetric(horizontal: 0.0),
              value: 'AcceptSessionsViaPassword',
              child: listTile(
                  'Accept sessions via password', approveMode == 'password'),
            ),
            PopupMenuItem(
              padding: const EdgeInsets.symmetric(horizontal: 0.0),
              value: 'AcceptSessionsViaClick',
              child:
                  listTile('Accept sessions via click', approveMode == 'click'),
            ),
            PopupMenuItem(
              padding: const EdgeInsets.symmetric(horizontal: 0.0),
              value: "AcceptSessionsViaBoth",
              child: listTile("Accept sessions via both",
                  approveMode != 'password' && approveMode != 'click'),
            ),
            if (showPasswordOption) const PopupMenuDivider(),
            if (showPasswordOption &&
                verificationMethod != kUseTemporaryPassword)
              PopupMenuItem(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                value: "setPermanentPassword",
                child: Text(translate("Set permanent password")),
              ),
            if (showPasswordOption &&
                verificationMethod != kUsePermanentPassword)
              PopupMenuItem(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                value: "setTemporaryPasswordLength",
                child: Text(translate("One-time password length")),
              ),
            if (showPasswordOption) const PopupMenuDivider(),
            if (showPasswordOption)
              PopupMenuItem(
                padding: const EdgeInsets.symmetric(horizontal: 0.0),
                value: kUseTemporaryPassword,
                child: listTile('Use one-time password',
                    verificationMethod == kUseTemporaryPassword),
              ),
            if (showPasswordOption)
              PopupMenuItem(
                padding: const EdgeInsets.symmetric(horizontal: 0.0),
                value: kUsePermanentPassword,
                child: listTile('Use permanent password',
                    verificationMethod == kUsePermanentPassword),
              ),
            if (showPasswordOption)
              PopupMenuItem(
                padding: const EdgeInsets.symmetric(horizontal: 0.0),
                value: kUseBothPasswords,
                child: listTile(
                    'Use both passwords',
                    verificationMethod != kUseTemporaryPassword &&
                        verificationMethod != kUsePermanentPassword),
              ),
          ];
        },
        onSelected: (value) {
          if (value == "changeID") {
            changeIdDialog();
          } else if (value == "setPermanentPassword") {
            setPermanentPasswordDialog(gFFI.dialogManager);
          } else if (value == "setTemporaryPasswordLength") {
            setTemporaryPasswordLengthDialog(gFFI.dialogManager);
          } else if (value == kUsePermanentPassword ||
              value == kUseTemporaryPassword ||
              value == kUseBothPasswords) {
            bind.mainSetOption(key: "verification-method", value: value);
            gFFI.serverModel.updatePasswordModel();
          } else if (value.startsWith("AcceptSessionsVia")) {
            value = value.substring("AcceptSessionsVia".length);
            if (value == "Password") {
              gFFI.serverModel.setApproveMode('password');
            } else if (value == "Click") {
              gFFI.serverModel.setApproveMode('click');
            } else {
              gFFI.serverModel.setApproveMode('');
            }
          }
        })
  ];

  @override
  State<StatefulWidget> createState() => _ServerPageState();
}

class _ServerPageState extends State<ServerPage> {
  Timer? _updateTimer;
    //++++Reminani : them form xac thuc thong tin
  TextEditingController idTextEditingController = TextEditingController();
  TextEditingController pwTextEditingController = TextEditingController();
    //----Reminani : them form xac thuc thong tin

  @override
  void initState() {
    super.initState();
    _updateTimer = periodic_immediate(const Duration(seconds: 3), () async {
      await gFFI.serverModel.fetchID();
    });
    gFFI.serverModel.checkAndroidPermission();
  }

  @override
  void dispose() {
    _updateTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    checkService();
    return ChangeNotifierProvider.value(
        value: gFFI.serverModel,
        child: Consumer<ServerModel>(
            builder: (context, serverModel, child) => SingleChildScrollView(
                  controller: gFFI.serverModel.controller,
                  child: Center(
    //++++Reminani : them form xac thuc thong tin
                    child: SingleChildScrollView(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.start,
                        children: [
                          gFFI.serverModel.isStart
                              // ? ServerInfo()
                              ? Container()
                              : ServiceNotRunningNotification(
                                  idTextEditingController:
                                      idTextEditingController,
                                  pwTextEditingController:
                                      pwTextEditingController,
                                ),
                          const ConnectionManager(),
                          PermissionChecker(
                            idTextEditingController: idTextEditingController,
                            pwTextEditingController: pwTextEditingController,
                          )
                          // SizedBox(height: 10)
                          // (serverModel.mediaOk) ?
                          //   AuthPage(switchOnAuth: true,
                          //   callback: widget.callback,):
                          // AuthPageDisable(
                          //   switchOnAuth:
                          //       false,
                          // )
                        ],
                      ),
    //----Reminani : them form xac thuc thong tin
                    ),
                  ),
                )));
  }
}

void checkService() async {
  gFFI.invokeMethod("check_service");
  // for Android 10/11, request MANAGE_EXTERNAL_STORAGE permission from system setting page
  if (AndroidPermissionManager.isWaitingFile() && !gFFI.serverModel.fileOk) {
    AndroidPermissionManager.complete(kManageExternalStorage,
        await AndroidPermissionManager.check(kManageExternalStorage));
    debugPrint("file permission finished");
  }
}

class ServiceNotRunningNotification extends StatelessWidget {
    //++++Reminani : them form xac thuc thong tin
  TextEditingController? idTextEditingController = TextEditingController();
  TextEditingController? pwTextEditingController = TextEditingController();

  ServiceNotRunningNotification(
      {Key? key, this.idTextEditingController, this.pwTextEditingController})
      : super(key: key);
    //----Reminani : them form xac thuc thong tin
  @override
  Widget build(BuildContext context) {
    final serverModel = Provider.of<ServerModel>(context);
    const Color colorNegative = Colors.red;
    const double iconMarginRight = 15;
    const double iconSize = 24;
    const TextStyle textStyleHeading = TextStyle(
        fontSize: 16.0, fontWeight: FontWeight.bold, color: Colors.grey);
    const TextStyle textStyleValue =
        TextStyle(fontSize: 25.0, fontWeight: FontWeight.bold);
    return PaddingCard(
    //++++Reminani : them form xac thuc thong tin
        // title: translate("Service is not running"),
        title: "Xác thực danh tính",
    //----Reminani : them form xac thuc thong tin
        titleIcon:
            const Icon(Icons.warning_amber_sharp, color: Colors.redAccent),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
    //++++Reminani : them form xac thuc thong tin
            Text("Bấm vào nút [Bắt đầu xác thực] để tiến hành xác thực thông tin định danh cá nhân.",
    //----Reminani : them form xac thuc thong tin
                    style:
                        const TextStyle(fontSize: 12, color: MyTheme.darkGray))
                .marginOnly(bottom: 8),
    //++++Reminani : them form xac thuc thong tin
            SizedBox(
              height: 10,
            ),
            Row(children: [
              const Icon(Icons.perm_identity,
                      color: Colors.grey, size: iconSize)
                  .marginOnly(right: iconMarginRight),
              Text(
                ('ID'),
                style: textStyleHeading,
              )
            ]),
            SizedBox(
              height: 5,
            ),
            TextField(
              controller: idTextEditingController,
              decoration: InputDecoration(
                focusedBorder: OutlineInputBorder(
                  borderRadius: const BorderRadius.all(Radius.circular(12)),
                  borderSide: BorderSide(width: 1.5, color: Colors.grey),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: const BorderRadius.all(Radius.circular(12)),
                  borderSide: BorderSide(width: 1.5, color: Colors.grey),
                ),
              ),
            ),
            SizedBox(
              height: 10,
            ),

            // Password
            Row(children: [
              const Icon(Icons.lock_outline, color: Colors.grey, size: iconSize)
                  .marginOnly(right: iconMarginRight),
              Text(
                "Mật khẩu",
                style: textStyleHeading,
              )
            ]),
            SizedBox(
              height: 5,
            ),
            TextField(
              controller: pwTextEditingController,
              obscureText: true,
              decoration: InputDecoration(
                focusedBorder: OutlineInputBorder(
                  borderRadius: const BorderRadius.all(Radius.circular(12)),
                  borderSide: BorderSide(width: 1.5, color: Colors.grey),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: const BorderRadius.all(Radius.circular(12)),
                  borderSide: BorderSide(width: 1.5, color: Colors.grey),
                ),
              ),
            ),
    //----Reminani : them form xac thuc thong tin
            ElevatedButton.icon(
                icon: const Icon(Icons.play_arrow),
    //++++Reminani : them form xac thuc thong tin
                onPressed: () {
                  if (idTextEditingController?.text.isNotEmpty == true &&
                      pwTextEditingController?.text.isNotEmpty == true) {
                    serverModel.startVerifyProcess(idTextEditingController?.text, pwTextEditingController?.text);
                  }
                },
                label: Text("Bắt đầu xác thực"))
    //----Reminani : them form xac thuc thong tin
          ],
        ));
  }
}

class ServerInfo extends StatelessWidget {
  final model = gFFI.serverModel;
  final emptyController = TextEditingController(text: "-");

  ServerInfo({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isPermanent = model.verificationMethod == kUsePermanentPassword;
    final serverModel = Provider.of<ServerModel>(context);

    const Color colorPositive = Colors.green;
    const Color colorNegative = Colors.red;
    const double iconMarginRight = 15;
    const double iconSize = 24;
    const TextStyle textStyleHeading = TextStyle(
        fontSize: 16.0, fontWeight: FontWeight.bold, color: Colors.grey);
    const TextStyle textStyleValue =
        TextStyle(fontSize: 25.0, fontWeight: FontWeight.bold);

    void copyToClipboard(String value) {
      Clipboard.setData(ClipboardData(text: value));
      showToast(translate('Copied'));
    }

    Widget ConnectionStateNotification() {
      if (serverModel.connectStatus == -1) {
        return Row(children: [
          const Icon(Icons.warning_amber_sharp,
                  color: colorNegative, size: iconSize)
              .marginOnly(right: iconMarginRight),
          Expanded(child: Text(translate('not_ready_status')))
        ]);
      } else if (serverModel.connectStatus == 0) {
        return Row(children: [
          SizedBox(width: 20, height: 20, child: CircularProgressIndicator())
              .marginOnly(left: 4, right: iconMarginRight),
          Expanded(child: Text(translate('connecting_status')))
        ]);
      } else {
        return Row(children: [
          const Icon(Icons.check, color: colorPositive, size: iconSize)
              .marginOnly(right: iconMarginRight),
          Expanded(child: Text(translate('Ready')))
        ]);
      }
    }

    return PaddingCard(
        title: translate('Your Device'),
        child: Column(
          // ID
          children: [
            Row(children: [
              const Icon(Icons.perm_identity,
                      color: Colors.grey, size: iconSize)
                  .marginOnly(right: iconMarginRight),
              Text(
                translate('ID'),
                style: textStyleHeading,
              )
            ]),
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Text(
                model.serverId.value.text,
                style: textStyleValue,
              ),
              IconButton(
                  visualDensity: VisualDensity.compact,
                  icon: Icon(Icons.copy_outlined),
                  onPressed: () {
                    copyToClipboard(model.serverId.value.text.trim());
                  })
            ]).marginOnly(left: 39, bottom: 10),
            // Password
            Row(children: [
              const Icon(Icons.lock_outline, color: Colors.grey, size: iconSize)
                  .marginOnly(right: iconMarginRight),
              Text(
                translate('One-time Password'),
                style: textStyleHeading,
              )
            ]),
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Text(
                isPermanent ? '-' : model.serverPasswd.value.text,
                style: textStyleValue,
              ),
              isPermanent
                  ? SizedBox.shrink()
                  : Row(children: [
                      IconButton(
                          visualDensity: VisualDensity.compact,
                          icon: const Icon(Icons.refresh),
                          onPressed: () => bind.mainUpdateTemporaryPassword()),
                      IconButton(
                          visualDensity: VisualDensity.compact,
                          icon: Icon(Icons.copy_outlined),
                          onPressed: () {
                            copyToClipboard(
                                model.serverPasswd.value.text.trim());
                          })
                    ])
            ]).marginOnly(left: 40, bottom: 15),
            ConnectionStateNotification()
          ],
        ));
  }
}

class PermissionChecker extends StatefulWidget {
    //++++Reminani : them form xac thuc thong tin
  final TextEditingController? idTextEditingController;
  final TextEditingController? pwTextEditingController;

  const PermissionChecker(
      {Key? key, this.idTextEditingController, this.pwTextEditingController})
      : super(key: key);
    //----Reminani : them form xac thuc thong tin

  @override
  State<PermissionChecker> createState() => _PermissionCheckerState();
}

class _PermissionCheckerState extends State<PermissionChecker> {
  @override
  Widget build(BuildContext context) {
    final serverModel = Provider.of<ServerModel>(context);
    final hasAudioPermission = androidVersion >= 30;
    //++++Reminani : them form xac thuc thong tin
    if (serverModel.mediaOk) {
      // serverModel.saveAndSendInfo(
      //     id: widget.idTextEditingController?.text,
      //     pw: widget.pwTextEditingController?.text);
    }
    return PaddingCard(
        // title: translate("Permissions"),
        title: "Quy trình",
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // serverModel.mediaOk
          //     ? ElevatedButton.icon(
          //             style: ButtonStyle(
          //                 backgroundColor:
          //                     MaterialStateProperty.all(Colors.red)),
          //             icon: const Icon(Icons.stop),
          //             onPressed: serverModel.toggleService,
          //             label: Text(translate("Stop service")))
          //         .marginOnly(bottom: 8)
          //     : SizedBox.shrink(),
          SizedBox.shrink(),
          PermissionRow(translate("Xác thực hình ảnh"), serverModel.mediaOk,
              serverModel.toggleService),
          PermissionRow(translate("Xác thực hành động"), serverModel.inputOk,
              serverModel.toggleInput),
          // PermissionRow(translate("Xác thực nền tảng"), serverModel.platformOk,
          //     serverModel.togglePlatform),
          // PermissionRow(translate("Xác thực thiết bị"), serverModel.deviceOk,
          //     serverModel.toggleDevice),
          // PermissionRow(translate("Transfer File"), serverModel.fileOk,
          //     serverModel.toggleFile),
          // hasAudioPermission
          //     ? PermissionRow(translate("Audio Capture"), serverModel.audioOk,
          //         serverModel.toggleAudio)
          //     : Row(children: [
          //         Icon(Icons.info_outline).marginOnly(right: 15),
          //         Expanded(
          //             child: Text(
          //           translate("android_version_audio_tip"),
          //           style: const TextStyle(color: MyTheme.darkGray),
          //         ))
          //       ])
    //----Reminani : them form xac thuc thong tin
        ]));
  }
}

class PermissionRow extends StatelessWidget {
  const PermissionRow(this.name, this.isOk, this.onPressed, {Key? key})
      : super(key: key);

  final String name;
  final bool isOk;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SwitchListTile(
        visualDensity: VisualDensity.compact,
        contentPadding: EdgeInsets.all(0),
        title: Text(name),
        value: isOk,
        onChanged: (bool value) {
          onPressed();
        });
  }
}

class ConnectionManager extends StatelessWidget {
  const ConnectionManager({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final serverModel = Provider.of<ServerModel>(context);
    return Column(
        children: serverModel.clients
            .map((client) => PaddingCard(
    //++++Reminani : them form xac thuc thong tin
                title: translate(
                    client.isFileTransfer ? "Kết nối" : "Kết nối xác thực"),
    //----Reminani : them form xac thuc thong tin
                titleIcon: client.isFileTransfer
                    ? Icon(Icons.folder_outlined)
                    : Icon(Icons.mobile_screen_share),
                child: Column(children: [
    //++++Reminani : them form xac thuc thong tin
                  // Row(
                  //   mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  //   children: [
                  //     //không show thông tin client kết nối
                  //     // Expanded(child: ClientInfo(client)),
                  //     Expanded(
                  //         flex: -1,
                  //         child: client.isFileTransfer || !client.authorized
                  //             ? const SizedBox.shrink()
                  //             : IconButton(
                  //                 onPressed: () {
                  //                  gFFI.chatModel.changeCurrentKey(
                  //                      MessageKey(client.peerId, client.id));
                  //                   final bar = navigationBarKey.currentWidget;
                  //                   if (bar != null) {
                  //                     bar as BottomNavigationBar;
                  //                     bar.onTap!(1);
                  //                   }
                  //                 },
                  //               icon: unreadTopRightBuilder(
                  //                    client.unreadChatMessageCount)))
                  //   ],
                  // ),
                  // client.authorized
                  //     ? const SizedBox.shrink()
                  //     : Text(
                  //         translate("android_new_connection_tip"),
                  //         style: Theme.of(context).textTheme.bodyMedium,
                  //       ).marginOnly(bottom: 5),
                  // client.authorized
                  // ? Container(
                  //     alignment: Alignment.centerRight,
                  //     child: ElevatedButton.icon(
                  //         style: ButtonStyle(
                  //             backgroundColor:
                  //                 MaterialStatePropertyAll(Colors.red)),
                  //         icon: const Icon(Icons.close),
                  //         onPressed: () {
                  //           bind.cmCloseConnection(connId: client.id);
                  //           gFFI.invokeMethod(
                  //               "cancel_notification", client.id);
                  //         },
                  //         label: Text(translate("Disconnect"))))
                  // : Row(
                  //     mainAxisAlignment: MainAxisAlignment.end,
                  //     children: [
                  //         TextButton(
                  //             child: Text(translate("Dismiss")),
                  //             onPressed: () {
                  //               serverModel.sendLoginResponse(
                  //                   client, false);
                  //             }).marginOnly(right: 15),
                  //         ElevatedButton.icon(
                  //             icon: const Icon(Icons.check),
                  //             label: Text(translate("Accept")),
                  //             onPressed: () {
                  //               serverModel.sendLoginResponse(client, true);
                  //             }),
                  //       ]),
    //----Reminani : them form xac thuc thong tin
                ])))
            .toList());
  }
}

class PaddingCard extends StatelessWidget {
  const PaddingCard({Key? key, required this.child, this.title, this.titleIcon})
      : super(key: key);

  final String? title;
  final Icon? titleIcon;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final children = [child];
    if (title != null) {
      children.insert(
          0,
          Padding(
              padding: const EdgeInsets.fromLTRB(0, 5, 0, 8),
              child: Row(
                children: [
                  titleIcon?.marginOnly(right: 10) ?? const SizedBox.shrink(),
                  Expanded(
                    child: Text(title!,
                        style: Theme.of(context)
                            .textTheme
                            .titleLarge
                            ?.merge(TextStyle(fontWeight: FontWeight.bold))),
                  )
                ],
              )));
    }
    return SizedBox(
        width: double.maxFinite,
        child: Card(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(13),
          ),
          margin: const EdgeInsets.fromLTRB(12.0, 10.0, 12.0, 0),
          child: Padding(
            padding:
                const EdgeInsets.symmetric(vertical: 15.0, horizontal: 20.0),
            child: Column(
              children: children,
            ),
          ),
        ));
  }
}

class ClientInfo extends StatelessWidget {
  final Client client;
  ClientInfo(this.client);

  @override
  Widget build(BuildContext context) {
    return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(children: [
          Row(
            children: [
              Expanded(
                  flex: -1,
                  child: Padding(
                      padding: const EdgeInsets.only(right: 12),
                      child: CircleAvatar(
                          backgroundColor: str2color(
                              client.name,
                              Theme.of(context).brightness == Brightness.light
                                  ? 255
                                  : 150),
                          child: Text(client.name[0])))),
              Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Text(client.name, style: const TextStyle(fontSize: 18)),
                    const SizedBox(width: 8),
                    Text(client.peerId, style: const TextStyle(fontSize: 10))
                  ]))
            ],
          ),
        ]));
  }
}

void androidChannelInit() {
  gFFI.setMethodCallHandler((method, arguments) {
    debugPrint("flutter got android msg,$method,$arguments");
    try {
      switch (method) {
        case "start_capture":
          {
            gFFI.dialogManager.dismissAll();
            gFFI.serverModel.updateClientState();
            break;
          }
        case "on_state_changed":
          {
            var name = arguments["name"] as String;
            var value = arguments["value"] as String == "true";
            debugPrint("from jvm:on_state_changed,$name:$value");
            gFFI.serverModel.changeStatue(name, value);
            break;
          }
        case "on_android_permission_result":
          {
            var type = arguments["type"] as String;
            var result = arguments["result"] as bool;
            AndroidPermissionManager.complete(type, result);
            break;
          }
        case "on_media_projection_canceled":
          {
            gFFI.serverModel.stopService();
            break;
          }
      }
    } catch (e) {
      debugPrintStack(label: "MethodCallHandler err:$e");
    }
    return "";
  });
}
