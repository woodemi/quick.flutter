import 'package:flutter/material.dart';

import 'package:quick_notify/quick_notify.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({Key? key}) : super(key: key);

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
                  child: const Text('hasPermission'),
                  onPressed: () async {
                    var hasPermission = await QuickNotify.hasPermission();
                    print('hasPermission $hasPermission');
                  },
                ),
                ElevatedButton(
                  child: const Text('requestPermission'),
                  onPressed: () async {
                    var requestPermission =
                        await QuickNotify.requestPermission();
                    print('requestPermission $requestPermission');
                  },
                ),
              ],
            ),
            ElevatedButton(
              child: const Text('notify'),
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
