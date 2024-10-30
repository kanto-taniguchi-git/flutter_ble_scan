import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:io' show Platform;
import 'dart:async';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      home: BLEScanner(),
    );
  }
}

class BLEScanner extends StatefulWidget {
  const BLEScanner({Key? key}) : super(key: key);

  @override
  _BLEScannerState createState() => _BLEScannerState();
}

class _BLEScannerState extends State<BLEScanner> {
  List<ScanResult> scanResults = [];
  bool isScanning = false;
  String message = '';
  Map<String, String> permissionsStatus = {}; // 表示用の権限ステータス
  StreamSubscription? scanSubscription;

  @override
  void initState() {
    super.initState();
    requestPermissionsAndStartScan();
  }

  // パーミッションのリクエストとスキャン開始
  Future<void> requestPermissionsAndStartScan() async {
    Map<Permission, PermissionStatus> statuses;

    if (Platform.isAndroid) {
      statuses = await [
        Permission.bluetoothScan,
        Permission.bluetoothConnect,
        Permission.location,
      ].request();
    } else if (Platform.isIOS) {
      statuses = await [
        Permission.bluetooth,
      ].request();
    } else {
      statuses = {};
    }

    setState(() {
      // 各パーミッションの状態を共通の表示フォーマットに合わせる
      permissionsStatus = {
        "(Android)Bluetooth Scan": Platform.isAndroid
            ? (statuses[Permission.bluetoothScan]?.isGranted ?? false) ? '許可' : '未許可'
            : "サポートされていません",
        "(Android)Bluetooth Connect": Platform.isAndroid
            ? (statuses[Permission.bluetoothConnect]?.isGranted ?? false) ? '許可' : '未許可'
            : "サポートされていません",
        "(Android)位置情報": Platform.isAndroid || Platform.isIOS
            ? (statuses[Permission.location]?.isGranted ?? false) ? '許可' : '未許可'
            : "サポートされていません",
        "(iPhone)Bluetooth": Platform.isIOS
            ? (statuses[Permission.bluetooth]?.isGranted ?? false) ? '許可' : '未許可'
            : "サポートされていません",
      };
    });

    bool allGranted = statuses.values.every((status) => status.isGranted);

    if (allGranted) {
      startScan();
    } else {
      setState(() {
        message = 'パーミッションが許可されていません';
      });
    }
  }

  // BLEスキャンを開始
  void startScan() async {
    if (isScanning) return;

    bool isBluetoothEnabled = await FlutterBluePlus.isOn;
    if (!isBluetoothEnabled) {
      setState(() {
        message = 'Bluetoothが有効化されていません。';
      });
      return;
    }

    ServiceStatus locationStatus = await Permission.location.serviceStatus;
    if (locationStatus != ServiceStatus.enabled) {
      setState(() {
        message = '位置情報サービスが有効になっていません。デバイスの設定で有効にしてください。';
      });
      return;
    }

    setState(() {
      isScanning = true;
      message = '';
      scanResults.clear();
    });

    try {
      FlutterBluePlus.startScan(timeout: const Duration(seconds: 3));
      scanSubscription = FlutterBluePlus.scanResults.listen((results) {
        setState(() {
          scanResults = results;
        });
        for (ScanResult r in results) {
          print('${r.device.name} found! rssi: ${r.rssi}');
        }
      });

      await Future.delayed(const Duration(seconds: 3));
      FlutterBluePlus.stopScan();
      scanSubscription?.cancel();

      setState(() {
        isScanning = false;
        message = scanResults.isEmpty ? 'デバイスが見つかりませんでした' : 'スキャン完了';
      });
    } catch (e) {
      setState(() {
        isScanning = false;
        message = 'スキャン中にエラーが発生しました: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('BLEデバイススキャナ'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: ElevatedButton(
              onPressed: !isScanning ? startScan : null,
              child: const Text('スキャン開始'),
            ),
          ),
          if (isScanning)
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: CircularProgressIndicator(),
            ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              message,
              style: const TextStyle(fontSize: 16, color: Colors.red),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: permissionsStatus.entries.map((entry) {
                return Text(
                  '${entry.key} パーミッション: ${entry.value}',
                  style: TextStyle(
                    fontSize: 16,
                    color: entry.value == '許可' ? Colors.green : Colors.red,
                  ),
                );
              }).toList(),
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: scanResults.length,
              itemBuilder: (context, index) {
                final result = scanResults[index];
                final name = result.device.name.isNotEmpty ? result.device.name : '不明なデバイス';
                return ListTile(
                  title: Text('名前: $name'),
                  subtitle: Text('アドレス: ${result.device.id.id}, RSSI: ${result.rssi}'),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
