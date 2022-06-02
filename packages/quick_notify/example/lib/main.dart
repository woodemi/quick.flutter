import 'package:flutter/material.dart';

import 'package:quick_notify/quick_notify.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatefulWidget {
  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          title: const Text('Plugin example app'),
        ),
        body: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton(
                  child: Text('hasPermission'),
                  onPressed: () async {
                    var hasPermission = await QuickNotify.hasPermission();
                    print('hasPermission $hasPermission');
                  },
                ),
                ElevatedButton(
                  child: Text('requestPermission'),
                  onPressed: () async {
                    var requestPermission = await QuickNotify.requestPermission();
                    print('requestPermission $requestPermission');
                  },
                ),
              ],
            ),
            ElevatedButton(
              child: Text('notify'),
              onPressed: () {
                QuickNotify.notify(
                  title: 'My title',
                  content: 'My content',
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
