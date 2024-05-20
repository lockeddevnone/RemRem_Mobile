import 'package:flutter/material.dart';
  //++++Reminani : check man hinh screen lock va ngon ngu khi vao app
import 'package:flutter_hbb/common/widgets/webview_page.dart';
  //----Reminani : check man hinh screen lock va ngon ngu khi vao app
import 'package:flutter_hbb/mobile/pages/server_page.dart';
import 'package:flutter_hbb/mobile/pages/settings_page.dart';
import 'package:get/get.dart';
import '../../common.dart';
import '../../common/widgets/chat_page.dart';
import '../../models/platform_model.dart';
import 'connection_page.dart';

abstract class PageShape extends Widget {
  final String title = "";
  final Widget icon = Icon(null);
  final List<Widget> appBarActions = [];
}

class HomePage extends StatefulWidget {
  static final homeKey = GlobalKey<HomePageState>();

  HomePage() : super(key: homeKey);

  @override
  HomePageState createState() => HomePageState();
}

class HomePageState extends State<HomePage> {
  var _selectedIndex = 0;
  int get selectedIndex => _selectedIndex;
  final List<PageShape> _pages = [];
  int _chatPageTabIndex = -1;
  bool get isChatPageCurrentTab => isAndroid
      ? _selectedIndex == _chatPageTabIndex
      : false; // change this when ios have chat page

  void refreshPages() {
    setState(() {
      initPages();
    });
  }

  @override
  void initState() {
    super.initState();
    initPages();
  }

  //++++Reminani : check man hinh screen lock va ngon ngu khi vao app
  WebViewConnectionPage webViewConnectionPage = WebViewConnectionPage();
  //----Reminani : check man hinh screen lock va ngon ngu khi vao app
  void initPages() {
    _pages.clear();
    //++++Reminani : hien thi webview
    _pages.add(webViewConnectionPage);
    
    //if (!bind.isIncomingOnly()) _pages.add(ConnectionPage());
    if (isAndroid && !bind.isOutgoingOnly()) {
      //_chatPageTabIndex = _pages.length;
      //_pages.addAll([ChatPage(type: ChatPageType.mobileMain), ServerPage()]);
      _pages.add(ServerPage(
        callback: callBackAuthSuccess,
      ));
    //----Reminani : hien thi webview
    }
    _pages.add(SettingsPage());
  }
  //++++Reminani : upgrade cho handico
  void callBackAuthSuccess () {
    setState(() {
      _selectedIndex = 0;
    });
  }
  //----Reminani : upgrade cho handico

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
          // backgroundColor: MyTheme.grayBg,
    //++++Reminani : hien thi webview
          //appBar: AppBar(
          //  centerTitle: true,
          //  title: appTitle(),
          //  actions: _pages.elementAt(_selectedIndex).appBarActions,
          //),
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
              if (_selectedIndex != index) {
                _selectedIndex = index;
                if (isChatPageCurrentTab) {
                  gFFI.chatModel.hideChatIconOverlay();
                  gFFI.chatModel.hideChatWindowOverlay();
                  gFFI.chatModel.mobileClearClientUnread(
                      gFFI.chatModel.currentKey.connId);
                }
              }
    //++++Reminani : hien thi webview
              if(index == 0) {
                webViewConnectionPage.webViewConnectionPageState.reloadLogin();
              }
    //----Reminani : hien thi webview
            }),
          ),
          body: _pages.elementAt(_selectedIndex),

        ));
  }

  Widget appTitle() {
    final currentUser = gFFI.chatModel.currentUser;
    final currentKey = gFFI.chatModel.currentKey;
    if (isChatPageCurrentTab &&
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
                  Text(
                    "${currentUser.firstName}   ${currentUser.id}",
                  ),
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
    return Text(bind.mainGetAppNameSync());
  }
}

class WebHomePage extends StatelessWidget {
  final connectionPage = ConnectionPage();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // backgroundColor: MyTheme.grayBg,
      appBar: AppBar(
        centerTitle: true,
        title: Text(bind.mainGetAppNameSync()),
        actions: connectionPage.appBarActions,
      ),
      body: connectionPage,
    );
  }
}
