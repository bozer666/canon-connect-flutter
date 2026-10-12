import 'dart:async';
import 'dart:typed_data';

import 'package:camera_control_dart/camera_control_dart.dart';
import 'package:flutter/material.dart';

import '../camera_service.dart';

/// 遥控拍摄页：实时取景 + 快门 + 常用参数展示。
class RemotePage extends StatefulWidget {
  final CameraService service;
  final CameraConnectionHandle cameraHandle;

  const RemotePage({
    super.key,
    required this.service,
    required this.cameraHandle,
  });

  @override
  State<RemotePage> createState() => _RemotePageState();
}

class _RemotePageState extends State<RemotePage> {
  Camera? _camera;
  Uint8List? _liveViewBytes;
  Timer? _liveViewTimer;
  bool _capturing = false;
  String? _error;
  String _status = '连接中…';

  static const _props = [
    ControlPropType.iso,
    ControlPropType.aperture,
    ControlPropType.shutterSpeed,
    ControlPropType.whiteBalance,
  ];

  @override
  void initState() {
    super.initState();
    _connect();
  }

  Future<void> _connect() async {
    try {
      _camera = await widget.service.connect(widget.cameraHandle);
      await _camera!.startLiveView();
      setState(() => _status = '已连接');
      _liveViewTimer =
          Timer.periodic(const Duration(milliseconds: 500), (_) async {
        try {
          final data = await _camera?.getLiveViewData();
          if (data != null && mounted) {
            setState(() => _liveViewBytes = data.imageBytes);
          }
        } catch (_) {
          // 单帧失败不打断轮询
        }
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _status = '连接失败';
          _error = '$e';
        });
      }
    }
  }

  Future<void> _capture() async {
    if (_capturing) return;
    setState(() => _capturing = true);
    try {
      await _camera?.captureImage();
    } catch (e) {
      if (mounted) setState(() => _error = '拍摄失败：$e');
    } finally {
      if (mounted) setState(() => _capturing = false);
    }
  }

  @override
  void dispose() {
    _liveViewTimer?.cancel();
    widget.service.disconnect();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.cameraHandle.model.name),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(child: Text(_status)),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: Container(
              color: Colors.black,
              width: double.infinity,
              child: _liveViewBytes != null
                  ? Image.memory(_liveViewBytes!, fit: BoxFit.contain)
                  : const Center(
                      child: Text('等待实时取景…',
                          style: TextStyle(color: Colors.white54)),
                    ),
            ),
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.all(8),
              child: Text(_error!,
                  style: const TextStyle(color: Colors.red, fontSize: 12)),
            ),
          SizedBox(
            height: 64,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              children: _props.map((propType) {
                return FutureBuilder<ControlProp?>(
                  future: _camera?.getProp(propType),
                  builder: (context, snapshot) {
                    final prop = snapshot.data;
                    return Container(
                      margin: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 10),
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(propType.name,
                              style: const TextStyle(
                                  fontSize: 10, color: Colors.grey)),
                          Text(
                            prop?.currentValue.toString() ?? '—',
                            style: const TextStyle(fontSize: 14),
                          ),
                        ],
                      ),
                    );
                  },
                );
              }).toList(),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(bottom: 32, top: 8),
            child: FloatingActionButton.large(
              onPressed: _capturing ? null : _capture,
              child: _capturing
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Icon(Icons.camera, size: 36),
            ),
          ),
        ],
      ),
    );
  }
}
