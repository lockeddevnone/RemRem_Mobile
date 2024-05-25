import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_hbb/common/widgets/setting_widgets.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';
import 'package:settings_ui/settings_ui.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:url_launcher/url_launcher_string.dart';

import '../../common.dart';
import '../../common/widgets/dialog.dart';
import '../../common/widgets/login.dart';
import '../../common/widgets/webview_page.dart';
import '../../consts.dart';
import '../../models/model.dart';
import '../../models/platform_model.dart';

class AppBarRemoteButton extends StatelessWidget {
  final VoidCallback onButtonPressed;

  CustomButton({required this.onButtonPressed});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Icon(Icons.mobile_screen_share),
      onPressed: onButtonPressed,
    );
  }
}