import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

/// 发现诊断页 v2：组播疑似走了错误的出口（iOS 多网卡），
/// 改为：枚举本机 IP → 推算相机候选 IP → 逐个单播 M-SEARCH。
class DiagPage extends StatefulWidget {
  const DiagPage({super.key});

  @override
  State<DiagPage> createState() => _DiagPageState();
}

class _DiagPageState extends State<DiagPage> {
  final List<String> _log = [];
  bool _scanning = false;

  static const _searchTargets = [
    'urn:schemas-canon-com:service:ICPO-WFTEOSSystemService:1',
    'ssdp:all',
  ];

  @override
  void initState() {
    super.initState();
    _scan();
  }

  void _add(String line) {
    if (mounted) setState(() => _log.add(line));
  }

  String _mSearch(String st) => 'M-SEARCH * HTTP/1.1\r\n'
      'HOST: 239.255.255.250:1900\r\n'
      'MAN: "ns=01"\r\n'
      'ST: $st\r\n'
      'MX: 3\r\n'
      '\r\n';

  Future<void> _scan() async {
    if (_scanning) return;
    setState(() {
      _scanning = true;
      _log.clear();
    });
    try {
      // 1. 本机网卡
      final ifaces = await NetworkInterface.list(
        includeLoopback: false,
        type: InternetAddressType.IPv4,
      );
      String? wifiIp;
      for (final iface in ifaces) {
        for (final addr in iface.addresses) {
          _add('网卡 ${iface.name}: ${addr.address}');
          // Wi-Fi 通常是 en0
          if (iface.name == 'en0') wifiIp = addr.address;
        }
      }
      wifiIp ??= ifaces
          .expand((i) => i.addresses)
          .firstOrNull
          ?.address;
      if (wifiIp == null) {
        _add('!! 取不到本机 IPv4，无法继续');
        return;
      }
      _add('选用本机 IP: $wifiIp');

      // 2. 候选相机 IP：同网段 .1（网关，相机 AP 通常就是它）+ 网段广播
      final prefix = wifiIp.split('.').take(3).join('.');
      final candidates = <InternetAddress>[
        InternetAddress('$prefix.1'),
        InternetAddress('$prefix.255'),
        InternetAddress('239.255.255.250'), // 组播对照
      ];
      _add('候选目标: ${candidates.map((c) => c.address).join(', ')}');

      // 3. 绑定到 Wi-Fi IP（显式出口，替代官方的 IP_MULTICAST_IFINDEX）
      final socket = await RawDatagramSocket.bind(
          InternetAddress(wifiIp), 0);
      _add('socket 绑定 ${socket.address.address}:${socket.port}');

      final responses = <String, String>{};
      final sub = socket.listen((event) {
        if (event != RawSocketEvent.read) return;
        final dg = socket.receive();
        if (dg == null) return;
        final text = utf8.decode(dg.data, allowMalformed: true);
        final key = '${dg.address.address}:${dg.port}';
        if (!responses.containsKey(key)) {
          responses[key] = text;
          _add('── 收到回包 [$key] ──');
          for (final line in text.split('\n').take(12)) {
            _add(line.trim());
          }
        }
      });

      for (final target in candidates) {
        for (final st in _searchTargets) {
          final data = utf8.encode(_mSearch(st));
          try {
            socket.send(data, target, 1900);
            _add('已发 → ${target.address} ST=$st');
          } catch (e) {
            _add('发送失败 ${target.address}: $e');
          }
          await Future.delayed(const Duration(milliseconds: 400));
        }
      }

      _add('等待回包 8 秒…');
      await Future.delayed(const Duration(seconds: 8));
      await sub.cancel();
      socket.close();

      _add('＝＝ 共收到 ${responses.length} 个发送方的回包 ＝＝');
      for (final entry in responses.entries) {
        final location = _headerValue(entry.value, 'location');
        if (location == null || location.isEmpty) {
          _add('[${entry.key}] 无 LOCATION 头');
          continue;
        }
        _add('[${entry.key}] LOCATION=$location');
        try {
          final resp = await http
              .get(Uri.parse(location.trim()))
              .timeout(const Duration(seconds: 5));
          final model = _xmlTag(resp.body, 'modelName');
          final friendly = _xmlTag(resp.body, 'friendlyName');
          _add('  → modelName=[$model] friendlyName=[$friendly]');
        } catch (e) {
          _add('  → 设备描述抓取失败: $e');
        }
      }
      if (responses.isEmpty) {
        _add('！！单播/组播全都没回包：相机 SSDP 可能没起，或仍有系统层拦截');
      }
    } catch (e) {
      _add('诊断异常: $e');
    } finally {
      if (mounted) setState(() => _scanning = false);
    }
  }

  String? _headerValue(String raw, String name) {
    for (final line in raw.split('\n')) {
      final idx = line.indexOf(':');
      if (idx > 0 &&
          line.substring(0, idx).trim().toLowerCase() ==
              name.toLowerCase()) {
        return line.substring(idx + 1).trim();
      }
    }
    return null;
  }

  String _xmlTag(String xml, String tag) {
    final m =
        RegExp('<$tag>(.*?)</$tag>', dotAll: true).firstMatch(xml);
    return m?.group(1)?.trim() ?? '';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('发现诊断 v2'),
        actions: [
          IconButton(
            icon: const Icon(Icons.copy),
            tooltip: '复制全部日志',
            onPressed: _log.isEmpty
                ? null
                : () {
                    Clipboard.setData(
                        ClipboardData(text: _log.join('\n')));
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                          content: Text(
                              '已复制 ${_log.length} 行日志')),
                    );
                  },
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _scanning ? null : _scan,
          ),
        ],
      ),
      body: _log.isEmpty && _scanning
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: _log.length,
              itemBuilder: (context, i) => SelectableText(
                _log[i],
                style: const TextStyle(
                    fontFamily: 'monospace', fontSize: 12),
              ),
            ),
    );
  }
}
