import 'package:flutter/material.dart';

import 'src/camera_service.dart';
import 'src/pages/camera_list_page.dart';

void main() {
  runApp(const CanonConnectApp());
}

/// Canon Camera Connect 的 Flutter 重写。
/// Phase 1：SSDP 发现 → 配对 → PTP/IP 遥控拍摄。
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
      home: CameraListPage(service: CameraService()),
    );
  }
}
