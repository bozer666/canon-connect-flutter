import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

/// 发现诊断页：原始 SSDP 抓包视角。
/// 不经过 camera_control_dart，直接用 dart:io 发 M-SEARCH，
/// 把收到的每个回包原文和设备描述抓取结果打到屏幕上，
/// 一次定位"列表为空"卡在哪一环。
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
    'urn:schemas-canon-com:service:ICPO-SmartPhoneEOSSystemService:1',
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

  Future<void> _scan() async {
    if (_scanning) return;
    setState(() {
      _scanning = true;
      _log.clear();
    });
    try {
      final socket =
          await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
      _add('本机 socket 端口: ${socket.port}');

      final responses = <String, String>{};
      final sub = socket.listen((event) {
        if (event != RawSocketEvent.read) return;
        final dg = socket.receive();
        if (dg == null) return;
        final text = utf8.decode(dg.data, allowMalformed: true);
        final key = '${dg.address.address}:${dg.port}';
        // 同一发送方只记第一包原文，避免刷屏
        if (!responses.containsKey(key)) {
          responses[key] = text;
          _add('── 收到回包 [$key] ──');
          for (final line in text.split('\n').take(12)) {
            _add(line.trim());
          }
        }
      });

      for (final st in _searchTargets) {
        final msg = 'M-SEARCH * HTTP/1.1\r\n'
            'HOST: 239.255.255.250:1900\r\n'
            'MAN: "ns=01"\r\n'
            'ST: $st\r\n'
            'MX: 3\r\n'
            '\r\n';
        final data = utf8.encode(msg);
        socket.send(data, InternetAddress('239.255.255.250'), 1900);
        _add('已发 M-SEARCH [组播] ST=$st');
        try {
          socket.send(data, InternetAddress('255.255.255.255'), 1900);
          _add('已发 M-SEARCH [广播] ST=$st');
        } catch (e) {
          _add('广播发送失败: $e');
        }
        await Future.delayed(const Duration(seconds: 1));
      }

      _add('等待回包 8 秒…');
      await Future.delayed(const Duration(seconds: 8));
      await sub.cancel();
      socket.close();

      _add('＝＝ 共收到 ${responses.length} 个发送方的回包 ＝＝');

      // 对每个回包的 LOCATION 抓设备描述，看 modelName 到底是什么
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
          final body = resp.body;
          final model = _xmlTag(body, 'modelName');
          final friendly = _xmlTag(body, 'friendlyName');
          _add('  → modelName=[$model] friendlyName=[$friendly]');
        } catch (e) {
          _add('  → 设备描述抓取失败: $e');
        }
      }
      if (responses.isEmpty) {
        _add('！！一个回包都没收到：iOS 可能拦了 UDP，或相机根本没回 M-SEARCH');
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
        title: const Text('发现诊断'),
        actions: [
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
