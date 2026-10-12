import 'package:flutter/material.dart';

void main() {
  runApp(const CanonConnectApp());
}

/// Canon Camera Connect 的 Flutter 重写 —— 骨架版。
/// Phase 1 会在这里接入 camera_control_dart 的发现与 PTP/IP 连接。
class CanonConnectApp extends StatelessWidget {
  const CanonConnectApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'CanonConnect',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.red),
        useMaterial3: true,
      ),
      home: const CameraListPage(),
    );
  }
}

class CameraListPage extends StatelessWidget {
  const CameraListPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('CanonConnect')),
      body: const Center(
        child: Text('未发现相机\n\n请先让 iPhone 连上相机的 Wi-Fi', textAlign: TextAlign.center),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // Phase 1: 在这里启动 SSDP 主动发现
        },
        tooltip: '搜索相机',
        child: const Icon(Icons.search),
      ),
    );
  }
}
