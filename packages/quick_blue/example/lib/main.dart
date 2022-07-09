import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:logging/logging.dart';
import 'package:quick_blue/quick_blue.dart';

import 'peripheral_detail_page.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  StreamSubscription<BlueScanResult>? _scanResultSubscription;
  StreamSubscription<AvailabilityState>? _availabilitySubscription;

  @override
  void initState() {
    super.initState();

    QuickBlue.availabilityChangeStream.listen((state) {
      debugPrint('Bluetooth state: ${state.toString()}');
    });

    if (kDebugMode) {
      QuickBlue.setLogger(Logger('quick_blue_example'));
    }
    _scanResultSubscription = QuickBlue.scanResultStream.listen((result) {
      if (!_scanResults.any((r) => r.deviceId == result.deviceId)) {
        setState(() => _scanResults.add(result));
      }
    });
  }

  @override
  void dispose() {
    super.dispose();
    _scanResultSubscription?.cancel();
    _availabilitySubscription?.cancel();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          title: const Text('Plugin example app'),
        ),
        body: Column(
          children: [
            StreamBuilder<AvailabilityState>(
              stream: QuickBlue.availabilityChangeStream,
              builder: (context, snapshot) {
                return Text('Bluetooth state: ${snapshot.data?.toString()}');
              },
            ),
            FutureBuilder(
              future: QuickBlue.isBluetoothAvailable(),
              builder: (context, snapshot) {
                var poweredOn = snapshot.data?.toString() ?? '...';
                return Text('Bluetooth powered on: $poweredOn');
              },
            ),
            _buildButtons(),
            const Divider(color: Colors.blue),
            _buildListView(),
            _buildPermissionWarning(),
          ],
        ),
      ),
    );
  }

  Widget _buildButtons() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: <Widget>[
        ElevatedButton(
          child: const Text('startScan'),
          onPressed: () {
            QuickBlue.startScan();
          },
        ),
        ElevatedButton(
          child: const Text('stopScan'),
          onPressed: () {
            QuickBlue.stopScan();
          },
        ),
      ],
    );
  }

  final _scanResults = <BlueScanResult>[];

  Widget _buildListView() {
    return Expanded(
      child: ListView.separated(
        itemBuilder: (context, index) => ListTile(
          title:
              Text('${_scanResults[index].name}(${_scanResults[index].rssi})'),
          subtitle: Text(_scanResults[index].deviceId),
          onTap: () {
            Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => PeripheralDetailPage(
                      deviceId: _scanResults[index].deviceId),
                ));
          },
        ),
        separatorBuilder: (context, index) => const Divider(),
        itemCount: _scanResults.length,
      ),
    );
  }

  Widget _buildPermissionWarning() {
    if (Platform.isAndroid) {
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 10),
        child: const Text('BLUETOOTH_SCAN/ACCESS_FINE_LOCATION needed'),
      );
    }
    return Container();
  }
}
