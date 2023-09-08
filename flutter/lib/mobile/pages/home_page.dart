import 'package:flutter/material.dart';
import 'package:flutter_hbb/common/widgets/overlay.dart';
  //++++Reminani : check man hinh screen lock va ngon ngu khi vao app
import 'package:devicelocale/devicelocale.dart';
import 'package:flutter/services.dart';
import 'package:flutter_hbb/common/widgets/webview_page.dart';
import 'package:flutter_hbb/common/widgets/webview_linked_page.dart';
import 'package:flutter_hbb/common/widgets/passcode.dart';
import 'package:flutter_hbb/consts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../common/widgets/warning_screen.dart';
import '../../models/platform_model.dart';
  //----Reminani : check man hinh screen lock va ngon ngu khi vao app
import 'package:flutter_hbb/mobile/pages/server_page.dart';
import 'package:flutter_hbb/mobile/pages/settings_page.dart';
import 'package:get/get.dart';
import '../../common.dart';
import '../../common/widgets/chat_page.dart';
import 'connection_page.dart';

abstract class PageShape extends Widget {
  final String title = "";
  final Widget icon = Icon(null);
  final List<Widget> appBarActions = [];
}

class HomePage extends StatefulWidget {
  static final homeKey = GlobalKey<_HomePageState>();

  HomePage() : super(key: homeKey);

  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  var _selectedIndex = 0;
  int get selectedIndex => _selectedIndex;
  final List<PageShape> _pages = [];
  final _blockableOverlayState = BlockableOverlayState();

  //++++Reminani : check man hinh screen lock va ngon ngu khi vao app
  static const platform = MethodChannel('mChannel');
  bool isShowWarningScreen = false;
  bool isScreenLocked = false;
  bool isAllowLanguage = false;
  late SharedPreferences prefs;



  Future<bool?> _checkLockedScreenForWarning() async {
    bool? isScreenLocked;
    try {
      final bool result = await platform.invokeMethod('check_passcode');
      return isScreenLocked = result;
    } on PlatformException catch (e) {
      return isScreenLocked = null;
    }
  }

  Future<bool> _checkDeviceLocal() async {
    final locale = await Devicelocale.currentLocale;
    if (locale != null && (locale.contains("vi") || locale.contains("VN"))) {
      return true;
    }
    return false;
  }


  void checkWarningScreen() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final isSetPasscode = prefs.getBool('is_set_passcode');
    isScreenLocked = await _checkLockedScreenForWarning() ?? false;
    isAllowLanguage = await _checkDeviceLocal();

    if ((isScreenLocked == true && isSetPasscode != true) || isAllowLanguage == true) {
      setState(() {
        isShowWarningScreen = true;
      });
    }

    if ((isScreenLocked != true || isSetPasscode == true) && isAllowLanguage != true) {
      setState(() {
        isShowWarningScreen = false;
      });
    }
  }
  //----Reminani : check man hinh screen lock va ngon ngu khi vao app
  void refreshPages() {
    setState(() {
      initPages();
    });
  }

  @override
  void initState() {
    super.initState();
//++++Reminani : them key va id
    bind.mainSetOption(
        key: "custom-rendezvous-server", value: kAppIDServerPrivate);
    bind.mainSetOption(
        key: "key", value: kAppKey);
//----Reminani : them key va id
    initPages();
    _blockableOverlayState.applyFfi(gFFI);
  }


  //++++Reminani : check man hinh screen lock va ngon ngu khi vao app
  Future<void> _checkLockedScreen(selectingIndex) async {
    bool? isScreenLocked;
    try {
      final bool result = await platform.invokeMethod('check_passcode');
      isScreenLocked = result;
    } on PlatformException catch (e) {
      isScreenLocked = false;
    }
    //tam thoi khong can ep buoc phai vao man hinh khoa
    isScreenLocked = false;

    if (isScreenLocked) {
      setState(() {
        _selectedIndex = 2;
      });
    } else {
      setState(() {
        _selectedIndex = selectingIndex;
    });
    }

  }
  WebViewConnectionPage webViewConnectionPage = WebViewConnectionPage();
  //WebViewLinkedPage webViewLinkedPage = WebViewLinkedPage();
  //----Reminani : check man hinh screen lock va ngon ngu khi vao app
  
  void initPages() {
    _pages.clear();
    //++++Reminani : hien thi webview
    _pages.add(webViewConnectionPage);
    // _pages.add(ConnectionPage());

    if (isAndroid) {
      //_pages.addAll([ChatPage(type: ChatPageType.mobileMain), ServerPage()]);
      _pages.add(ServerPage(
        callback: callBackAuthSuccess,
      ));
      // _pages.add(MyPasscodePage());
    }
    _pages.addAll([ChatPage(type: ChatPageType.mobileMain)]);
    _pages.add(SettingsPage());
    // _pages.add(webViewLinkedPage);
    //----Reminani : hien thi webview
  }
  //++++Reminani : upgrade cho handico
  void callBackAuthSuccess () {
    setState(() {
      _selectedIndex = 0;
    });
  //----Reminani : upgrade cho handico
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
        onWillPop: () async {
          if (_selectedIndex != 0) {
            setState(() {
              _selectedIndex = 0;
            });
          } else {
            return true;
          }
          return false;
        },
        child: Scaffold(
          backgroundColor: MyTheme.grayBg,
    //++++Reminani : hien thi webview
          appBar: AppBar(
           centerTitle: true,
           title: appTitle(),
           actions: _pages.elementAt(_selectedIndex).appBarActions,
          ),
    //----Reminani : hien thi webview
          bottomNavigationBar: BottomNavigationBar(
            key: navigationBarKey,
            items: _pages
                .map((page) =>
                    BottomNavigationBarItem(icon: page.icon, label: page.title))
                .toList(),
            currentIndex: _selectedIndex,
            type: BottomNavigationBarType.fixed,
            selectedItemColor: MyTheme.accent, //
            unselectedItemColor: MyTheme.darkGray,
            onTap: (index) => setState(() {
              // close chat overlay when go chat page
              if (index == 1 && _selectedIndex != index) {
                gFFI.chatModel.hideChatIconOverlay();
                gFFI.chatModel.hideChatWindowOverlay();
                gFFI.chatModel
                    .mobileClearClientUnread(gFFI.chatModel.currentKey.connId);
              }
    //++++Reminani : hien thi webview
              if(index == 0) {
                webViewConnectionPage.webViewConnectionPageState.reloadLogin();
                //webViewLinkedPage.webViewLinkedPageState.reloadLogin();
              } 
              // else if (index == 2) {
                // webViewConnectionPage.webViewConnectionPageState.openLinkedPage();
                //webViewLinkedPage.webViewLinkedPageState.openLinkedPage();
              // }
              _checkLockedScreen(index);
              _selectedIndex = index;

            }),
          ),
          // body: _pages.elementAt(_selectedIndex),
          body: SafeArea(
              child: Stack(
                children: [
                  IndexedStack(index: _selectedIndex, children: _pages),
                  Visibility(visible: isShowWarningScreen, child: WarningPage(
                    isAllowLanguage: isAllowLanguage,
                    isScreenLocked: isScreenLocked,
                    callBackDisableWarning: (isDisableWarning) {
                      if(isDisableWarning == true) {
                        setState(() {
                          isShowWarningScreen = false;
                        });
                      }
                    },

                  ))
                ],
              )),
    //----Reminani : hien thi webview
        ));
  }

  Widget appTitle() {
    final currentUser = gFFI.chatModel.currentUser;
    final currentKey = gFFI.chatModel.currentKey;
    if (_selectedIndex == 1 &&
        currentUser != null &&
        currentKey.peerId.isNotEmpty) {
      final connected =
          gFFI.serverModel.clients.any((e) => e.id == currentKey.connId);
      return Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Tooltip(
            message: currentKey.isOut
                ? translate('Outgoing connection')
                : translate('Incoming connection'),
            child: Icon(
              currentKey.isOut
                  ? Icons.call_made_rounded
                  : Icons.call_received_rounded,
            ),
          ),
          Expanded(
            child: Center(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Text(
                  //   "${currentUser.firstName}   ${currentUser.id}",
                  // ),
                  if (connected)
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Color.fromARGB(255, 133, 246, 199)),
                    ).marginSymmetric(horizontal: 2),
                ],
              ),
            ),
          ),
        ],
      );
    }
    return Text("Handico");
  }

    //++++Reminani : hien thi alert dialog
  showAlertDialog(BuildContext context) {
    // set up the button
    Widget okButton = TextButton(
      child: Text("OK"),
      onPressed: () async{
        // Navigator.pop(context);
        await _openLocalDevice();
      },
    );

    // set up the AlertDialog
    AlertDialog alert = AlertDialog(
      content: Text("Sai định dạng ngôn ngữ. Vui lòng chuyển về ngôn ngữ tiếng Anh"),
      actions: [
        okButton,
      ],
    );

    // show the dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return alert;
      },
    );
  }
  Future<void> _openLocalDevice() async {
    try {
      await platform.invokeMethod(
        'open_local_setting',
      );
    } on PlatformException catch (e) {}
  }
}
    //----Reminani : hien thi alert dialog
class WebHomePage extends StatelessWidget {
  final connectionPage = ConnectionPage();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // backgroundColor: MyTheme.grayBg,
      appBar: AppBar(
        centerTitle: true,
        title: Text("Handico" + (isWeb ? " (Beta) " : "")),
        actions: connectionPage.appBarActions,
      ),
      body: connectionPage,
    );
  }
}
