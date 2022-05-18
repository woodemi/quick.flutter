import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:quick_scan/quick_scan.dart';

void main() => runApp(const MyApp());

class MyApp extends StatefulWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  bool permitted = false;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          title: const Text('Plugin example app'),
          actions: <Widget>[
            _buildTextButton(),
          ],
        ),
        body: buildBody(),
      ),
    );
  }

  Widget _buildTextButton() {
    return Builder(
      builder: (context) {
        return TextButton(
          child: const Text('Scan', style: TextStyle(color: Colors.white)),
          onPressed: () async {
            try {
              await checkAndRequestPermission();
              setState(() => permitted = true);
            } catch (e) {
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
            }
          },
        );
      },
    );
  }

  Widget buildBody() {
    if (!permitted) return Container();

    return Center(
      child: ScanView(
        callback: (String result) {
          debugPrint('scanResult $result');
        },
      ),
    );
  }
}

Future<void> checkAndRequestPermission() async {
  var permissionStatus = await Permission.camera.status;
  if (!permissionStatus.isGranted) {
    permissionStatus = await Permission.camera.request();
    if (!permissionStatus.isGranted) {
      throw Exception('Permission Denied');
    }
  }
}