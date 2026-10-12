import 'dart:async';

import 'package:camera_control_dart/camera_control_dart.dart';
import 'package:flutter/material.dart';

import '../camera_service.dart';
import 'diag_page.dart';
import 'pairing_page.dart';

/// 相机列表：订阅 SSDP 发现流，点相机进入配对。
class CameraListPage extends StatefulWidget {
  final CameraService service;

  const CameraListPage({super.key, required this.service});

  @override
  State<CameraListPage> createState() => _CameraListPageState();
}

class _CameraListPageState extends State<CameraListPage> {
  final Map<String, DiscoveryHandle> _cameras = {};
  StreamSubscription<CameraDiscoveryEvent>? _subscription;

  @override
  void initState() {
    super.initState();
    _subscription = widget.service.discover().listen((event) {
      setState(() {
        if (event is CameraDiscoveryEventAlive) {
          _cameras[event.id] = event.handle;
        } else if (event is CameraDiscoveryEventByeBye) {
          _cameras.remove(event.id);
        }
      });
    });
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cameras = _cameras.values.toList();
    return Scaffold(
      appBar: AppBar(
        title: const Text('CanonConnect'),
        actions: [
          IconButton(
            icon: const Icon(Icons.bug_report),
            tooltip: '发现诊断',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const DiagPage()),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            color: Colors.amber.shade100,
            child: const Text(
              '请先让 iPhone 连上相机的 Wi-Fi（相机端：无线设置 → 连接智能手机）',
              style: TextStyle(fontSize: 13),
            ),
          ),
          Expanded(
            child: cameras.isEmpty
                ? const Center(child: Text('正在搜索相机…'))
                : ListView.builder(
                    itemCount: cameras.length,
                    itemBuilder: (context, index) {
                      final handle = cameras[index];
                      final address = handle is EosPtpIpDiscoveryHandle
                          ? handle.address
                          : '';
                      return ListTile(
                        leading: const Icon(Icons.camera_alt),
                        title: Text(handle.model.name),
                        subtitle: Text(address),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => PairingPage(
                              service: widget.service,
                              discoveryHandle: handle,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
