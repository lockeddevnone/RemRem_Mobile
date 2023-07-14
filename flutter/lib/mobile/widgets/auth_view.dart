import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_hbb/consts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:video_thumbnail/video_thumbnail.dart';
import 'package:http/http.dart' as http;

const authMessage =
    'Thông tin về CMND/CCCD là bắt buộc, yêu cầu nhập chính xác và chụp rõ ràng. \nVui lòng bật quyền truy cập máy ảnh để thực hiện.';

class AuthPage extends StatefulWidget {
  final bool switchOnAuth;
  final VoidCallback callback;

  const AuthPage({Key? key, required this.switchOnAuth, required this.callback})
      : super(key: key);

  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> {
  TextEditingController controller = TextEditingController();
  String token = '';
  int idLogin = -1;

  bool didAuth = false;
  Uint8List? imageFrontIdentify;
  Uint8List? imageBackIdentify;
  Uint8List? imageMemberIdentify;
  Uint8List? videoMemberIdentify;
  File? videoMemberIdentifyFile;
  bool isAuth = false;

  String? identityLoan;
  String? frontIdLink;
  String? backIdLink;
  String? memberWithImgLink;
  String? memberVideoLink;

  @override
  void initState() {
    super.initState();
    initData();
    controller.addListener(() {
      enableAuth();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 10),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (idLogin != -1)
            Container(
              padding: EdgeInsets.only(bottom: 5),
              child: Text(
                "id: $idLogin",
                textAlign: TextAlign.start,
              ),
            ),
          Container(
            padding: EdgeInsets.symmetric(vertical: 10),
            child: Text(
              authMessage,
              textAlign: TextAlign.start,
            ),
          ),
          Divider(),
          SizedBox(
            height: 10,
          ),
          Container(
            padding: EdgeInsets.symmetric(vertical: 10),
            child: Text(
              "Số thẻ CMND/CCCD",
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Container(
            padding: EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(5),
              border: Border.all(
                color: Colors.grey,
                width: 1,
              ),
            ),
            child: TextField(
              enabled: (didAuth || identityLoan != null) ? false : true,
              controller: controller,
              textAlign: TextAlign.center,
              keyboardType: TextInputType.number,
              decoration: InputDecoration.collapsed(
                hintText: 'Vui lòng nhập số CMND/CCCD của bạn',
              ),
            ),
          ),
          SizedBox(
            height: 10,
          ),
          Container(
            padding: EdgeInsets.symmetric(vertical: 10),
            child: Text(
              "Ảnh CMND/CCCD mặt trước",
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          InkWell(
            onTap:
                (didAuth || frontIdLink != null) ? null : captureFrontIdentify,
            child: Container(
              padding: EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                color: (didAuth || frontIdLink != null) ? Colors.grey : null,
                borderRadius: BorderRadius.circular(5),
                border: Border.all(
                  color: Colors.blue,
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  SizedBox(
                      width: 40,
                      child: Icon(
                        Icons.camera_alt_rounded,
                        color: Colors.blue,
                      )),
                  Expanded(
                    child: Text(
                      "Chụp mặt trước",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          fontWeight: FontWeight.bold, color: Colors.blue),
                    ),
                  ),
                  SizedBox(width: 40),
                ],
              ),
            ),
          ),
          if (imageFrontIdentify != null)
            Container(
              margin: EdgeInsets.only(top: 10),
              alignment: Alignment.center,
              height: 100,
              child: Image.memory(
                imageFrontIdentify!,
                fit: BoxFit.cover,
              ),
            ),
          SizedBox(
            height: 10,
          ),
          Container(
            padding: EdgeInsets.symmetric(vertical: 10),
            child: Text(
              "Ảnh CMND/CCCD mặt sau",
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          InkWell(
            onTap: (didAuth || backIdLink != null) ? null : captureBackIdentify,
            child: Container(
              padding: EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                color: (didAuth || backIdLink != null) ? Colors.grey : null,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: Colors.blue,
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  SizedBox(
                      width: 40,
                      child: Icon(
                        Icons.camera_alt_rounded,
                        color: Colors.blue,
                      )),
                  Expanded(
                    child: Text(
                      "Chụp mặt sau",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          fontWeight: FontWeight.bold, color: Colors.blue),
                    ),
                  ),
                  SizedBox(width: 40),
                ],
              ),
            ),
          ),
          if (imageBackIdentify != null)
            Container(
              margin: EdgeInsets.only(top: 10),
              alignment: Alignment.center,
              height: 100,
              child: Image.memory(
                imageBackIdentify!,
                fit: BoxFit.cover,
              ),
            ),
          SizedBox(
            height: 10,
          ),
          Container(
            padding: EdgeInsets.symmetric(vertical: 10),
            child: Text(
              "Ảnh người vay",
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          InkWell(
            onTap: (didAuth || memberWithImgLink != null)
                ? null
                : captureMemberIdentify,
            child: Container(
              padding: EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                color:
                    (didAuth || memberWithImgLink != null) ? Colors.grey : null,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: Colors.blue,
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  SizedBox(
                      width: 40,
                      child: Icon(
                        Icons.camera_alt_rounded,
                        color: Colors.blue,
                      )),
                  Expanded(
                    child: Text(
                      "Chụp ảnh xác thực khuôn mặt",
                      style: TextStyle(
                          fontWeight: FontWeight.bold, color: Colors.blue),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  SizedBox(width: 40),
                ],
              ),
            ),
          ),
          if (imageMemberIdentify != null)
            Container(
              margin: EdgeInsets.only(top: 10),
              alignment: Alignment.center,
              height: 100,
              child: Image.memory(
                imageMemberIdentify!,
                fit: BoxFit.cover,
              ),
            ),
          Container(
            padding: EdgeInsets.symmetric(vertical: 10),
            child: Text(
              "Video người vay",
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          InkWell(
            onTap: (didAuth || videoMemberIdentify != null)
                ? null
                : captureVideoMemberIdentify,
            child: Container(
              padding: EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                color: (didAuth || videoMemberIdentify != null)
                    ? Colors.grey
                    : null,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: Colors.blue,
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  SizedBox(
                      width: 40,
                      child: Icon(
                        Icons.camera_alt_rounded,
                        color: Colors.blue,
                      )),
                  Expanded(
                    child: Text(
                      "Video xác thực khuôn mặt",
                      style: TextStyle(
                          fontWeight: FontWeight.bold, color: Colors.blue),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  SizedBox(width: 40),
                ],
              ),
            ),
          ),
          if (videoMemberIdentify != null)
            Container(
              margin: EdgeInsets.only(top: 10),
              alignment: Alignment.center,
              height: 100,
              child: Image.file(
                videoMemberIdentifyFile!,
                fit: BoxFit.cover,
              ),
            ),
          SizedBox(
            height: 30,
          ),
          InkWell(
            onTap: didAuth
                ? null
                : isAuth == true
                    ? auth
                    : null,
            child: Container(
              width: double.maxFinite,
              padding: EdgeInsets.symmetric(vertical: 15),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(5),
                color: isAuth == true ? Colors.blue : Colors.grey[500],
              ),
              alignment: Alignment.center,
              child: Text("Xác nhận"),
            ),
          ),
          SizedBox(
            height: 10,
          ),
        ],
      ),
    );
  }

  void captureFrontIdentify() async {
    await requestPermissionCamera();
    final ImagePicker picker = ImagePicker();
    final XFile? photo = await picker.pickImage(source: ImageSource.camera);
    if (photo != null) {
      imageFrontIdentify = await photo.readAsBytes();
      enableAuth();
    }
  }

  void captureBackIdentify() async {
    await requestPermissionCamera();
    final ImagePicker picker = ImagePicker();
    final XFile? photo = await picker.pickImage(source: ImageSource.camera);
    if (photo != null) {
      imageBackIdentify = await photo.readAsBytes();
      enableAuth();
    }
  }

  void captureMemberIdentify() async {
    await requestPermissionCamera();
    final ImagePicker picker = ImagePicker();
    final XFile? photo = await picker.pickImage(source: ImageSource.camera);
    if (photo != null) {
      imageMemberIdentify = await photo.readAsBytes();
      enableAuth();
    }
  }

  void captureVideoMemberIdentify() async {
    await requestPermissionCamera();
    final ImagePicker picker = ImagePicker();
    final XFile? cameraVideo =
        await picker.pickVideo(source: ImageSource.camera);
    if (cameraVideo != null) {
      videoMemberIdentify = await cameraVideo.readAsBytes();
      videoMemberIdentifyFile = await genThumbnailFile(cameraVideo.path);

      enableAuth();
    }
  }

  Future<File> genThumbnailFile(String path) async {
    final fileName = await VideoThumbnail.thumbnailFile(
      video: path,
      thumbnailPath: (await getTemporaryDirectory()).path,
      imageFormat: ImageFormat.PNG,
      maxHeight: 100,
      // specify the height of the thumbnail, let the width auto-scaled to keep the source aspect ratio
      quality: 75,
    );
    File file = File(fileName!);
    return file;
  }

  void initData() async {
    if (widget.switchOnAuth) {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      token = prefs.getString('tokenLogin') ?? "";
      idLogin = prefs.getInt('idLogin') ?? -1;
      if (idLogin != -1) {
        getUserInfo();
      } else {
        idLogin = -1;
        setState(() {});
      }
    } else {
      didAuth = true;
      setState(() {});
    }
  }

  Future<List<String>> uploadFiles() async {
    if (imageFrontIdentify == null ||
        imageBackIdentify == null ||
        imageMemberIdentify == null ||
        videoMemberIdentify == null) {
      return [];
    }

    final res = await Future.wait([
      uploadFile(imageFrontIdentify, "png"),
      uploadFile(imageBackIdentify, "png"),
      uploadFile(imageMemberIdentify, "png"),
      uploadFile(videoMemberIdentify, "mp4"),
    ]);
    if (res[0] != null && res[1] != null && res[2] != null && res[3] != null) {
      return [res[0]!, res[1]!, res[2]!, res[3]!];
    }
    return [];
  }

  Future<String?> uploadFile(Uint8List? dataBytes, String type) async {
    var url2 = Uri.http(kAppBaseUrl, 'Upload/uploadMediaFile');

    final resp = await http.post(url2,
        headers: {"Authorization": "Bearer $token"},
        body: json.encode(
          <String, dynamic>{
            'imageData': base64Encode(dataBytes!),
            'imageFormat': type
          },
        ));
    if (resp.statusCode == 200) {
      var decodedResponse = jsonDecode((resp.body)) as Map;
      return decodedResponse["data"];
    }
    return null;
  }

  void auth() async {
    FocusManager.instance.primaryFocus?.unfocus();
    showDialog(
        context: context,
        builder: (BuildContext context) {
          return Center(
            child: CircularProgressIndicator(),
          );
        });
    Future.delayed(Duration(milliseconds: 200), () async {
      final links = await uploadFiles();
      var url2 = Uri.http(kAppBaseUrl, 'Loans/user/updateLoan');
      final resp = await http.post(url2,
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
                  "identity_loan": controller.text,
                  "front_id": links[0],
                  "back_id": links[1],
                  "member_with_img": links[2],
                  "member_video": links[3],
                },
              )
            },
          ));
      if (resp.statusCode == 200) {
        Navigator.pop(context);
        didAuth = true;
        controller.text = identityLoan!;
        setState(() {});
        showAlertDialog(context);
      } else {
        Navigator.pop(context);
      }
    });
  }

  void enableAuth() {
    if (controller.text.isEmpty ||
        imageFrontIdentify == null ||
        imageBackIdentify == null ||
        imageMemberIdentify == null ||
        videoMemberIdentify == null) {
      isAuth = false;
    } else {
      isAuth = true;
    }
    setState(() {});
  }

  Future<void> requestPermissionCamera() async {
    var cameraStatus = await Permission.camera.status;
    var microphoneStatus = await Permission.microphone.status;
    if (!cameraStatus.isGranted || !microphoneStatus.isGranted) {
      await Permission.camera.request();
      await Permission.microphone.request();
    }
  }

  showAlertDialog(BuildContext context) {
    Widget okButton = TextButton(
      child: Text("OK"),
      onPressed: () {
        Navigator.pop(context);
        widget.callback.call();
      },
    );

    AlertDialog alert = AlertDialog(
      content: Text("Xác thực thành công."),
      actions: [
        okButton,
      ],
    );

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return alert;
      },
    );
  }

  void getUserInfo() async {
    var url = Uri.http(kAppBaseUrl, 'Loans/findById');
    final resp = await http.post(url,
        headers: {"Authorization": "Bearer $token"},
        body: {'id': idLogin.toString()});
    if (resp.statusCode == 200) {
      var decodedResponse = jsonDecode((resp.body)) as Map;
      identityLoan = decodedResponse["data"]["identity_loan"];
      frontIdLink = decodedResponse["data"]["front_id"];
      backIdLink = decodedResponse["data"]["back_id"];
      memberWithImgLink = decodedResponse["data"]["member_with_img"];
      memberVideoLink = decodedResponse["data"]["member_video"];
      if (identityLoan != null) {
        controller.text = identityLoan!;
      }
      if (identityLoan != null &&
          frontIdLink != null &&
          backIdLink != null &&
          memberWithImgLink != null &&
          memberVideoLink != null) {
        didAuth = true;
      }
      setState(() {});
    }
  }
}
