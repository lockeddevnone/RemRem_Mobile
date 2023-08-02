
//++++Reminani : Them man hinh lien ket
import 'package:flutter/material.dart';
import 'package:flutter_hbb/consts.dart';
import 'package:flutter_hbb/mobile/pages/connection_page.dart';
import 'package:flutter_hbb/mobile/pages/home_page.dart';
import 'package:flutter_hbb/mobile/pages/settings_page.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../common.dart';


class WebViewLinkedPage extends StatefulWidget implements PageShape {
  late WebViewLinkedPageState webViewLinkedPageState;

  @override
  final icon = const Icon(Icons.settings);

  @override
  final title = translate("Liên kết");

  @override
  final appBarActions = !isAndroid ? <Widget>[const WebMenu()] : <Widget>[];


  @override
  State<WebViewLinkedPage> createState() {
    webViewLinkedPageState = WebViewLinkedPageState();
    return webViewLinkedPageState;
  }

}

class WebViewLinkedPageState extends State<WebViewLinkedPage> with AutomaticKeepAliveClientMixin{
  late InAppWebViewController _webViewController;
  late SharedPreferences prefs;

  @override
  void initState() {
    super.initState();
    // requestPermission();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Container(
      child: InAppWebView(
        initialUrlRequest: URLRequest(url: Uri.parse(kAppWebViewLinked)),
        initialOptions: InAppWebViewGroupOptions(
            crossPlatform: InAppWebViewOptions(
              mediaPlaybackRequiresUserGesture: false,
            ),
            android: AndroidInAppWebViewOptions(
                useHybridComposition: true
            )
        ),
        onWebViewCreated: (InAppWebViewController controller) {
          _webViewController = controller;
          initPre();
        },
        androidOnPermissionRequest: (InAppWebViewController controller, String origin, List<String> resources) async {
          return PermissionRequestResponse(resources: resources, action: PermissionRequestResponseAction.GRANT);
        },
      ),
    );
  }

  void requestPermission() async {
    await Permission.camera.request();
    await Permission.microphone.request();
  }

  void initPre() async {
    prefs = await SharedPreferences.getInstance();
    String? userName = prefs.getString('userName');
    String? password = prefs.getString('password');
    bool isLoginSuccess = prefs.getBool("isLoginSuccess") ?? false;
  }

  void reloadLogin() {

  }

  @override
  bool get wantKeepAlive => true;
  
}

