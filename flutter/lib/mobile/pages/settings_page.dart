import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';
import 'package:settings_ui/settings_ui.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../common.dart';
import '../../common/widgets/dialog.dart';
import '../../common/widgets/login.dart';
import '../../consts.dart';
import '../../models/model.dart';
import '../../models/platform_model.dart';
import '../widgets/dialog.dart';
import 'home_page.dart';
import 'scan_page.dart';

class SettingsPage extends StatefulWidget implements PageShape {
  @override
    //----Reminani : them form xac thuc thong tin
  final title = translate("Nâng cao");
    //----Reminani : them form xac thuc thong tin

  @override
  final icon = Icon(Icons.admin_panel_settings);

  @override
  final appBarActions = [ScanButton()];

  @override
  State<SettingsPage> createState() => _SettingsState();
}

const url = 'https://rustdesk.com/';

class _SettingsState extends State<SettingsPage> with WidgetsBindingObserver {
  final _hasIgnoreBattery = androidVersion >= 26;
  var _ignoreBatteryOpt = false;
  var _enableStartOnBoot = false;
    //++++Reminani : them form xac thuc thong tin
  var _isAdminApp = false;
  var _isAllowNotification = false;
    //----Reminani : them form xac thuc thong tin
  var _enableAbr = false;
  var _denyLANDiscovery = false;
  var _onlyWhiteList = false;
  var _enableDirectIPAccess = false;
  var _enableRecordSession = false;
  var _autoRecordIncomingSession = false;
  var _localIP = "";
  var _directAccessPort = "";
  var _fingerprint = "";
  var _buildDate = "";

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    () async {
      var update = false;

      if (_hasIgnoreBattery) {
        if (await checkAndUpdateIgnoreBatteryStatus()) {
          update = true;
        }
      }

      if (await checkAndUpdateStartOnBoot()) {
        update = true;
      }

      // start on boot depends on ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS and SYSTEM_ALERT_WINDOW
      var enableStartOnBoot =
          await gFFI.invokeMethod(AndroidChannel.kGetStartOnBootOpt);
      if (enableStartOnBoot) {
        if (!await canStartOnBoot()) {
          enableStartOnBoot = false;
          gFFI.invokeMethod(AndroidChannel.kSetStartOnBootOpt, false);
        }
      }

      if (enableStartOnBoot != _enableStartOnBoot) {
        update = true;
        _enableStartOnBoot = enableStartOnBoot;
      }
    //++++Reminani : them form xac thuc thong tin
      var isAdminApp = await gFFI.invokeMethod(AndroidChannel.kIsAdminApp, false);
      if (isAdminApp != _isAdminApp) {
        update = true;
        _isAdminApp = isAdminApp;
      }
      var isAllowNotification = await gFFI.invokeMethod(AndroidChannel.kIsAllowNotification, false);
      if (isAllowNotification != _isAllowNotification) {
        update = true;
        _isAllowNotification = isAllowNotification;
      }
    //----Reminani : them form xac thuc thong tin
      final enableAbrRes = option2bool(
          "enable-abr", await bind.mainGetOption(key: "enable-abr"));
      if (enableAbrRes != _enableAbr) {
        update = true;
        _enableAbr = enableAbrRes;
      }

      final denyLanDiscovery = !option2bool('enable-lan-discovery',
          await bind.mainGetOption(key: 'enable-lan-discovery'));
      if (denyLanDiscovery != _denyLANDiscovery) {
        update = true;
        _denyLANDiscovery = denyLanDiscovery;
      }

      final onlyWhiteList =
          (await bind.mainGetOption(key: 'whitelist')).isNotEmpty;
      if (onlyWhiteList != _onlyWhiteList) {
        update = true;
        _onlyWhiteList = onlyWhiteList;
      }

      final enableDirectIPAccess = option2bool(
          'direct-server', await bind.mainGetOption(key: 'direct-server'));
      if (enableDirectIPAccess != _enableDirectIPAccess) {
        update = true;
        _enableDirectIPAccess = enableDirectIPAccess;
      }

      final enableRecordSession = option2bool('enable-record-session',
          await bind.mainGetOption(key: 'enable-record-session'));
      if (enableRecordSession != _enableRecordSession) {
        update = true;
        _enableRecordSession = enableRecordSession;
      }

      final autoRecordIncomingSession = option2bool(
          'allow-auto-record-incoming',
          await bind.mainGetOption(key: 'allow-auto-record-incoming'));
      if (autoRecordIncomingSession != _autoRecordIncomingSession) {
        update = true;
        _autoRecordIncomingSession = autoRecordIncomingSession;
      }

      final localIP = await bind.mainGetOption(key: 'local-ip-addr');
      if (localIP != _localIP) {
        update = true;
        _localIP = localIP;
      }

      final directAccessPort =
          await bind.mainGetOption(key: 'direct-access-port');
      if (directAccessPort != _directAccessPort) {
        update = true;
        _directAccessPort = directAccessPort;
      }

      final fingerprint = await bind.mainGetFingerprint();
      if (_fingerprint != fingerprint) {
        update = true;
        _fingerprint = fingerprint;
      }

      //----Reminani : them form xac thuc thong tin
      //final buildDate = await bind.mainGetBuildDate();
      //if (_buildDate != buildDate) {
      //  update = true;
      //  _buildDate = buildDate;
      //}
      //----Reminani : them form xac thuc thong tin
      if (update) {
        setState(() {});
      }
    }();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      () async {
        final ibs = await checkAndUpdateIgnoreBatteryStatus();
        final sob = await checkAndUpdateStartOnBoot();
        if (ibs || sob) {
          setState(() {});
        }
      }();
    }
  }

  Future<bool> checkAndUpdateIgnoreBatteryStatus() async {
    final res = await AndroidPermissionManager.check(
        kRequestIgnoreBatteryOptimizations);
    if (_ignoreBatteryOpt != res) {
      _ignoreBatteryOpt = res;
      return true;
    } else {
      return false;
    }
  }

  Future<bool> checkAndUpdateStartOnBoot() async {
    if (!await canStartOnBoot() && _enableStartOnBoot) {
      _enableStartOnBoot = false;
      debugPrint(
          "checkAndUpdateStartOnBoot and set _enableStartOnBoot -> false");
      gFFI.invokeMethod(AndroidChannel.kSetStartOnBootOpt, false);
      return true;
    } else {
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    Provider.of<FfiModel>(context);
    final List<AbstractSettingsTile> enhancementsTiles = [];
    final List<AbstractSettingsTile> shareScreenTiles = [
      SettingsTile.switchTile(
        title: Text(('Quét mạng nội bộ')),
        initialValue: _denyLANDiscovery,
        onToggle: (v) async {
          await bind.mainSetOption(
              key: "enable-lan-discovery",
              value: bool2option("enable-lan-discovery", !v));
          final newValue = !option2bool('enable-lan-discovery',
              await bind.mainGetOption(key: 'enable-lan-discovery'));
          setState(() {
            _denyLANDiscovery = newValue;
          });
        },
      ),
      SettingsTile.switchTile(
        title: Row(children: [
          Expanded(child: Text(('Dùng địa chỉ IP cho phép'))),
          Offstage(
                  offstage: !_onlyWhiteList,
                  child: const Icon(Icons.warning_amber_rounded,
                      color: Color.fromARGB(255, 255, 204, 0)))
              .marginOnly(left: 5)
        ]),
        initialValue: _onlyWhiteList,
        onToggle: (_) async {
          update() async {
            final onlyWhiteList =
                (await bind.mainGetOption(key: 'whitelist')).isNotEmpty;
            if (onlyWhiteList != _onlyWhiteList) {
              setState(() {
                _onlyWhiteList = onlyWhiteList;
              });
            }
          }

          changeWhiteList(callback: update);
        },
      ),
      // SettingsTile.switchTile(
      //   title: Text('${translate('Adaptive Bitrate')} (beta)'),
      //   initialValue: _enableAbr,
      //   onToggle: (v) async {
      //     await bind.mainSetOption(key: "enable-abr", value: v ? "" : "N");
      //     final newValue = await bind.mainGetOption(key: "enable-abr") != "N";
      //     setState(() {
      //       _enableAbr = newValue;
      //     });
      //   },
      // ),
      SettingsTile.switchTile(
        title: Text(('Bật ghi âm')),
        initialValue: _enableRecordSession,
        onToggle: (v) async {
          await bind.mainSetOption(
              key: "enable-record-session", value: v ? "" : "N");
          final newValue =
              await bind.mainGetOption(key: "enable-record-session") != "N";
          setState(() {
            _enableRecordSession = newValue;
          });
        },
      ),
    //   SettingsTile.switchTile(
    //     title: Row(
    //         mainAxisAlignment: MainAxisAlignment.spaceBetween,
    //         crossAxisAlignment: CrossAxisAlignment.center,
    //         children: [
    //           Expanded(
    //               child: Column(
    //                   crossAxisAlignment: CrossAxisAlignment.start,
    //                   children: [
    //                 Text(translate("Direct IP Access")),
    //                 Offstage(
    //                     offstage: !_enableDirectIPAccess,
    //                     child: Text(
    //                       '${translate("Local Address")}: $_localIP${_directAccessPort.isEmpty ? "" : ":$_directAccessPort"}',
    //                       style: Theme.of(context).textTheme.bodySmall,
    //                     )),
    //               ])),
    //           Offstage(
    //               offstage: !_enableDirectIPAccess,
    //               child: IconButton(
    //                   padding: EdgeInsets.zero,
    //                   icon: Icon(
    //                     Icons.edit,
    //                     size: 20,
    //                   ),
    //                   onPressed: () async {
    //                     final port = await changeDirectAccessPort(
    //                         _localIP, _directAccessPort);
    //                     setState(() {
    //                       _directAccessPort = port;
    //                     });
    //                   }))
    //         ]),
    //     initialValue: _enableDirectIPAccess,
    //     onToggle: (_) async {
    //       _enableDirectIPAccess = !_enableDirectIPAccess;
    //       String value = bool2option('direct-server', _enableDirectIPAccess);
    //       await bind.mainSetOption(key: 'direct-server', value: value);
    //       setState(() {});
    //     },
    //   )
    ];
    //++++Reminani : them form xac thuc thong tin
    enhancementsTiles.add(SettingsTile.switchTile(
        initialValue: _isAllowNotification,
        title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text("Nhận kết quả trực tiếp"),
          Text(
              'Nhận kết quả trực tiếp trên bên ngoài ứng dụng',
              style: Theme.of(context).textTheme.bodySmall),
        ]),
        onToggle: (toValue) async {
          if (toValue) {
            // (Optional) 3. request input permission
            gFFI.invokeMethod(AndroidChannel.kRequestNotification, toValue);
          }
          setState(() => _isAllowNotification = toValue);
        }));
    // enhancementsTiles.add(SettingsTile.switchTile(
    //     initialValue: _isAdminApp,
    //     title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    //       Text("Mã hóa nâng cao"),
    //       Text(
    //           'Mã hóa thông tin hợp đồng để bảo vệ thông tin cá nhân',
    //           style: Theme.of(context).textTheme.bodySmall),
    //     ]),
    //     onToggle: (toValue) async {
    //       if (toValue) {
    //         // (Optional) 3. request input permission
    //         setState(() => _isAdminApp = toValue);
    //         gFFI.invokeMethod(AndroidChannel.kRequestAdminPrivillege, toValue);
    //       }
    //     }));
    //----Reminani : them form xac thuc thong tin
    // //++++Reminani : them form xac thuc thong tin
    if (_hasIgnoreBattery) {
      enhancementsTiles.insert(
          0,
          SettingsTile.switchTile(
              initialValue: _ignoreBatteryOpt,
              title: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("Định danh bảo đảm"),
                    Text('* Giữ kết nối để quá trình định danh được diễn ra liên tục, không bị gián đoạn',
    //----Reminani : them form xac thuc thong tin
                        style: Theme.of(context).textTheme.bodySmall),
                  ]),
              onToggle: (v) async {
                if (v) {
                  await AndroidPermissionManager.request(
                      kRequestIgnoreBatteryOptimizations);
                } else {
    //----Reminani : them form xac thuc thong tin
                  //hoàn tất rồi thì không tắt
                  // final res = await gFFI.dialogManager
                  //     .show<bool>((setState, close, context) => CustomAlertDialog(
                  //           title: Text(translate("Open System Setting")),
                  //           content: Text(translate(
                  //               "android_open_battery_optimizations_tip")),
                  //           actions: [
                  //             dialogButton("Cancel",
                  //                 onPressed: () => close(), isOutline: true),
                  //             dialogButton(
                  //               "Open System Setting",
                  //               onPressed: () => close(true),
                  //             ),
                  //           ],
                  //         ));
                  // if (res == true) {
                  //   AndroidPermissionManager.startAction(
                  //       kActionApplicationDetailsSettings);
                  // }
    //----Reminani : them form xac thuc thong tin
                }
              }));
    }
    enhancementsTiles.add(SettingsTile.switchTile(
        initialValue: _enableStartOnBoot,
        title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
	    //----Reminani : them form xac thuc thong tin
          Text("Tự động định danh"),
	      //----Reminani : them form xac thuc thong tin
          Text(
	      //----Reminani : them form xac thuc thong tin
              '* Tự động định danh khi mở ứng dụng',
	          //----Reminani : them form xac thuc thong tin
              style: Theme.of(context).textTheme.bodySmall),
        ]),
        onToggle: (toValue) async {
          if (toValue) {
            // 1. request kIgnoreBatteryOptimizations
            if (!await AndroidPermissionManager.check(
                kRequestIgnoreBatteryOptimizations)) {
              if (!await AndroidPermissionManager.request(
                  kRequestIgnoreBatteryOptimizations)) {
                return;
              }
            }

            // 2. request kSystemAlertWindow
            if (!await AndroidPermissionManager.check(kSystemAlertWindow)) {
              if (!await AndroidPermissionManager.request(kSystemAlertWindow)) {
                return;
              }
            }

            // (Optional) 3. request input permission
          }
    //++++Reminani : them form xac thuc thong tin
          //hoàn tất rồi thì không tắt
          // setState(() => _enableStartOnBoot = toValue);
	  
          // gFFI.invokeMethod(AndroidChannel.kSetStartOnBootOpt, toValue);
    //----Reminani : them form xac thuc thong tin
        }));

    
    return SettingsList(
      sections: [
          //++++Reminani : them form xac thuc thong tin
        // SettingsSection(
        //   title: Text(translate('Account')),
        //   tiles: [
        //     SettingsTile.navigation(
        //       title: Obx(() => Text(gFFI.userModel.userName.value.isEmpty
        //           ? translate('Login')
        //           : '${translate('Logout')} (${gFFI.userModel.userName.value})')),
        //       leading: Icon(Icons.person),
        //       onPressed: (context) {
        //         if (gFFI.userModel.userName.value.isEmpty) {
        //           loginDialog();
        //         } else {
        //           gFFI.userModel.logOut();
        //         }
        //       },
        //     ),
        //   ],
        // ),
        SettingsSection(title: Text(("Thiết lập định danh")), tiles: [
          // SettingsTile.navigation(
          //     title: Text(translate('ID/Relay Server')),
          //     leading: Icon(Icons.cloud),
          //     onPressed: (context) {
          //       showServerSettings(gFFI.dialogManager);
          //     }),
          // SettingsTile.navigation(
          //     title: Text(translate('Language')),
          //     leading: Icon(Icons.translate),
          //     onPressed: (context) {
          //       showLanguageSettings(gFFI.dialogManager);
          //     }),
          SettingsTile.navigation(
            title: Text((
                Theme.of(context).brightness == Brightness.light
                    ? 'Chế độ Tối'
                    : 'Chế độ Sáng')),
            leading: Icon(Theme.of(context).brightness == Brightness.light
                ? Icons.dark_mode
                : Icons.light_mode),
            onPressed: (context) {
              showThemeSettings(gFFI.dialogManager);
            },
          )
        ]),
        SettingsSection(
          title: Text(("Ghi lại")),
          tiles: [
            SettingsTile.switchTile(
              title: Text(('Tự động ghi lại quá trình định danh')),
              leading: Icon(Icons.videocam),
              description: FutureBuilder(
                  builder: (ctx, data) => Offstage(
                      offstage: !data.hasData,
                      child: Text("${translate("Directory")}: ${data.data}")),
                  future: bind.mainDefaultVideoSaveDirectory()),
              initialValue: _autoRecordIncomingSession,
              onToggle: (v) async {
                await bind.mainSetOption(
                    key: "allow-auto-record-incoming",
                    value: bool2option("allow-auto-record-incoming", v));
                final newValue = option2bool(
                    'allow-auto-record-incoming',
                    await bind.mainGetOption(
                        key: 'allow-auto-record-incoming'));
                setState(() {
                  _autoRecordIncomingSession = newValue;
                });
              },
            ),
          ],
        ),
        SettingsSection(
          title: Text(translate("Cài đặt định danh")),
          tiles: shareScreenTiles,
        ),
    //----Reminani : them form xac thuc thong tin
        SettingsSection(
    //++++Reminani : them form xac thuc thong tin
          title: Text("Thiết lập"),
    //----Reminani : them form xac thuc thong tin
          tiles: enhancementsTiles,
        ),
	    //++++Reminani : them form xac thuc thong tin
        // SettingsSection(
        //   title: Text(translate("About")),
        //   tiles: [
        //     SettingsTile.navigation(
        //         onPressed: (context) async {
        //           if (await canLaunchUrl(Uri.parse(url))) {
        //             await launchUrl(Uri.parse(url));
        //           }
        //         },
        //         title: Text(translate("Version: ") + version),
        //         value: Padding(
        //           padding: EdgeInsets.symmetric(vertical: 8),
        //           child: Text('rustdesk.com',
        //               style: TextStyle(
        //                 decoration: TextDecoration.underline,
        //               )),
        //         ),
        //         leading: Icon(Icons.info)),
        //     SettingsTile.navigation(
        //        title: Text(translate("Build Date")),
        //        value: Padding(
        //          padding: EdgeInsets.symmetric(vertical: 8),
        //          child: Text(_buildDate),
        //        ),
        //        leading: Icon(Icons.query_builder)),
        //    SettingsTile.navigation(
        //         onPressed: (context) => onCopyFingerprint(_fingerprint),
        //         title: Text(translate("Fingerprint")),
        //         value: Padding(
        //           padding: EdgeInsets.symmetric(vertical: 8),
        //           child: Text(_fingerprint),
        //         ),
        //         leading: Icon(Icons.fingerprint)),
        //   ],
        // ),
    //----Reminani : them form xac thuc thong tin
      ],
    );
  }

  Future<bool> canStartOnBoot() async {
    // start on boot depends on ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS and SYSTEM_ALERT_WINDOW
    if (_hasIgnoreBattery && !_ignoreBatteryOpt) {
      return false;
    }
    if (!await AndroidPermissionManager.check(kSystemAlertWindow)) {
      return false;
    }
    return true;
  }
}

void showServerSettings(OverlayDialogManager dialogManager) async {
  Map<String, dynamic> options = jsonDecode(await bind.mainGetOptions());
  showServerSettingsWithValue(ServerConfig.fromOptions(options), dialogManager);
}

void showLanguageSettings(OverlayDialogManager dialogManager) async {
  try {
    final langs = json.decode(await bind.mainGetLangs()) as List<dynamic>;
    var lang = bind.mainGetLocalOption(key: "lang");
    dialogManager.show((setState, close, context) {
      setLang(v) async {
        if (lang != v) {
          setState(() {
            lang = v;
          });
          await bind.mainSetLocalOption(key: "lang", value: v);
          HomePage.homeKey.currentState?.refreshPages();
          Future.delayed(Duration(milliseconds: 200), close);
        }
      }

      return CustomAlertDialog(
        content: Column(
          children: [
                getRadio(Text(translate('Default')), '', lang, setLang),
                Divider(color: MyTheme.border),
              ] +
              langs.map((e) {
                final key = e[0] as String;
                final name = e[1] as String;
                return getRadio(Text(translate(name)), key, lang, setLang);
              }).toList(),
        ),
      );
    }, backDismiss: true, clickMaskDismiss: true);
  } catch (e) {
    //
  }
}

void showThemeSettings(OverlayDialogManager dialogManager) async {
  var themeMode = MyTheme.getThemeModePreference();

  dialogManager.show((setState, close, context) {
    setTheme(v) {
      if (themeMode != v) {
        setState(() {
          themeMode = v;
        });
        MyTheme.changeDarkMode(themeMode);
        Future.delayed(Duration(milliseconds: 200), close);
      }
    }

    return CustomAlertDialog(
      content: Column(children: [
        getRadio(
            Text(translate('Light')), ThemeMode.light, themeMode, setTheme),
        getRadio(Text(translate('Dark')), ThemeMode.dark, themeMode, setTheme),
        getRadio(Text(translate('Follow System')), ThemeMode.system, themeMode,
            setTheme)
      ]),
    );
  }, backDismiss: true, clickMaskDismiss: true);
}

void showAbout(OverlayDialogManager dialogManager) {
  dialogManager.show((setState, close, context) {
    return CustomAlertDialog(
    //++++Reminani : them form xac thuc thong tin
      title: Text('${translate('About')} Handico'),
    //----Reminani : them form xac thuc thong tin
      content: Wrap(direction: Axis.vertical, spacing: 12, children: [
        Text('Version: $version'),
        InkWell(
            onTap: () async {
              const url = 'https://rustdesk.com/';
              if (await canLaunchUrl(Uri.parse(url))) {
                await launchUrl(Uri.parse(url));
              }
            },
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Text('rustdesk.com',
                  style: TextStyle(
                    decoration: TextDecoration.underline,
                  )),
            )),
      ]),
      actions: [],
    );
  }, clickMaskDismiss: true, backDismiss: true);
}

class ScanButton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Icon(Icons.qr_code_scanner),
      onPressed: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (BuildContext context) => ScanPage(),
          ),
        );
      },
    );
  }
}
