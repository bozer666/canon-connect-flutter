# CanonConnect (Flutter)

Canon Camera Connect 的 Flutter 重写 —— 通过 Wi-Fi PTP/IP 直连佳能相机，
不依赖佳能官方 SDK。目标机型：EOS R7（首批验证）。

## 协议结论（已从官方 App 逆向实锤）

- **发现**：SSDP，**主动** M-SEARCH（单播 socket 发查询，不加组播组），
  Canon 私有 schema，服务类型 `urn:schemas-canon-com:service:ICPO-WFTEOSSystemService:1`
- **传输**：PTP/IP（CIPA DC-005），TCP 15740；Dart 的 `dart:io` 纯用户态实现即可
- **配网/遥控**：BLE 私有 GATT（UUID 基 `d8492fffa821`），做 Wi-Fi handover + 蓝牙快门
- **入网**：iOS `NEHotspotConfiguration`（Swift 平台通道）

## 仓库结构

- `lib/` — Flutter UI 与业务逻辑
- `ios/` — iOS 工程（含 Swift 平台通道）
- 协议层依赖 `bozer666/camera_control_dart`（fork，已改主动 M-SEARCH 发现）

## 路线图

- Phase 0：协议地基（已有，`camera_control_dart` fork）
- Phase 1：MVP —— 发现 + 连接 + 遥控拍摄（含 Swift 入网通道）
- Phase 2：图片浏览 / 下载 / 自动传输
- Phase 3：BLE 配对 / handover / 蓝牙遥控快门
- Phase 4（可选）：GPS 日志、固件升级、image.canon、有线 USB

## 构建

push 到 `main` 自动打未签名 IPA（Actions），用 AltStore / Sideloadly
以自己的 Apple ID 侧载安装。
