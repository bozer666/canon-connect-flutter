import 'dart:math';
import 'dart:typed_data';

import 'package:camera_control_dart/camera_control_dart.dart';

/// 相机协议层封装：SSDP 主动发现 → 配对 → PTP/IP 连接。
class CameraService {
  final CameraControl _control = CameraControl.init()
      .withDiscovery((setup) => setup.withEosPtpIp())
      .create();

  Camera? _camera;

  Camera? get camera => _camera;

  /// 持续发现局域网内的佳能相机（alive / byeBye 事件流）。
  Stream<CameraDiscoveryEvent> discover() => _control.discover();

  CameraConnectionHandle buildHandle(
      DiscoveryHandle discoveryHandle, String clientName) {
    final eosHandle = discoveryHandle as EosPtpIpDiscoveryHandle;
    return CameraConnectionHandle(
      id: eosHandle.id,
      model: eosHandle.model,
      pairingData: EosPtpIpCameraPairingData(
        address: eosHandle.address,
        guid: Uint8List.fromList(
            List.generate(16, (_) => Random().nextInt(256))),
        clientName: clientName,
      ),
    );
  }

  /// 配对：相机会弹窗要求确认，有 3 分钟超时。
  Future<void> pair(CameraConnectionHandle handle) =>
      _control.pair(handle);

  Future<Camera> connect(CameraConnectionHandle handle) async {
    _camera = await _control.connect(handle);
    return _camera!;
  }

  Future<void> disconnect() async {
    await _camera?.disconnect();
    _camera = null;
  }
}
