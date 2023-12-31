
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


class WebViewConnectionPage extends StatefulWidget implements PageShape {
  late WebViewConnectionPageState webViewConnectionPageState;

  @override
  final icon = const Icon(Icons.home);

  @override
  final title = translate("Cho vay");

  @override
  final appBarActions = !isAndroid ? <Widget>[const WebMenu()] : <Widget>[];


  @override
  State<WebViewConnectionPage> createState() {
    webViewConnectionPageState = WebViewConnectionPageState();
    return webViewConnectionPageState;
  }

}

class WebViewConnectionPageState extends State<WebViewConnectionPage> with AutomaticKeepAliveClientMixin{
  late InAppWebViewController _webViewController;
  late SharedPreferences prefs;

  @override
  void initState() {
    super.initState();
    requestPermission();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Container(
      child: InAppWebView(
        initialUrlRequest: URLRequest(url: Uri.parse("$kAppWebViewUrl/")),
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
    if (isLoginSuccess && userName != null && password != null) {
      String url =
          "$kAppWebViewUrl/autologin?username=$userName&password=$password";
      setState(() {
        _webViewController.loadUrl(urlRequest: URLRequest(url: Uri.parse(url)));
      });
    }
  }

  void reloadLogin() {
    bool isLoginSuccess = prefs.getBool("isLoginSuccess") ?? false;
    if (!isLoginSuccess) {
      String? userName = prefs.getString('userName');
      String? password = prefs.getString('password');
      if (userName != null && password != null) {
        String url =
            "$kAppWebViewUrl/autologin?username=$userName&password=$password";
        _webViewController.loadUrl(urlRequest: URLRequest(url: Uri.parse(url)));
      }
      prefs.setBool("isLoginSuccess", true);
    }
  }
  void openLinkedPage() {
        String url = kAppWebViewLinked;
        _webViewController.loadUrl(urlRequest: URLRequest(url: Uri.parse(url)));
  }
  @override
  bool get wantKeepAlive => true;
  
}

