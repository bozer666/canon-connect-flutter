import 'package:camera_control_dart/camera_control_dart.dart';
import 'package:flutter/material.dart';

import '../camera_service.dart';
import 'remote_page.dart';

/// 配对页：输入客户端名称，发起配对（相机端需确认）。
class PairingPage extends StatefulWidget {
  final CameraService service;
  final DiscoveryHandle discoveryHandle;

  const PairingPage({
    super.key,
    required this.service,
    required this.discoveryHandle,
  });

  @override
  State<PairingPage> createState() => _PairingPageState();
}

class _PairingPageState extends State<PairingPage> {
  final _nameController = TextEditingController(text: 'CanonConnect');
  bool _pairing = false;
  String? _error;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _pair() async {
    setState(() {
      _pairing = true;
      _error = null;
    });
    try {
      final handle = widget.service.buildHandle(
        widget.discoveryHandle,
        _nameController.text.trim().isEmpty
            ? 'CanonConnect'
            : _nameController.text.trim(),
      );
      await widget.service.pair(handle);
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => RemotePage(
            service: widget.service,
            cameraHandle: handle,
          ),
        ),
      );
    } catch (e) {
      setState(() => _error = '配对失败：$e');
    } finally {
      if (mounted) setState(() => _pairing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('配对相机')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              widget.discoveryHandle.model.name,
              style: const TextStyle(
                  fontSize: 28, fontWeight: FontWeight.w300),
            ),
            const SizedBox(height: 8),
            const Text(
              '点配对后，请在相机屏幕上确认连接（3 分钟内有效）。',
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 24),
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: '客户端名称（相机会显示这个名字）',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(_error!,
                    style: const TextStyle(color: Colors.red)),
              ),
            ElevatedButton(
              onPressed: _pairing ? null : _pair,
              child: _pairing
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('配对'),
            ),
          ],
        ),
      ),
    );
  }
}
