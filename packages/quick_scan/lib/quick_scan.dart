import 'dart:async';
import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';

const scanViewType = 'scan_view';

typedef ScanResultCallback = void Function(String result);

class ScanView extends StatefulWidget {
  final ScanResultCallback callback;

  const ScanView({
    Key? key,
    required this.callback,
  }): super(key: key);

  @override
  State<StatefulWidget> createState() => _ScanViewState();
}

class _ScanViewState extends State<ScanView> {
  StreamSubscription? scanResultSubscription;

  void onPlatformViewCreated(int id) {
    var stream = EventChannel('quick_scan/scanview_$id/event').receiveBroadcastStream();
    scanResultSubscription = stream.listen((result) {
      widget.callback(result);
    });
  }

  @override
  void dispose() {
    super.dispose();
    scanResultSubscription?.cancel();
  }

  @override
  Widget build(BuildContext context) {
    if (Platform.isAndroid) {
      return AndroidView(
        viewType: scanViewType,
        onPlatformViewCreated: onPlatformViewCreated,
      );
    } else if (Platform.isIOS) {
      return UiKitView(
        viewType: scanViewType,
        onPlatformViewCreated: onPlatformViewCreated,
      );
    }
    throw UnimplementedError('Unknown platform: ${Platform.operatingSystem}');
  }
}