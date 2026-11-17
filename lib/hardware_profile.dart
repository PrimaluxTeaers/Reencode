import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;

/// Hardware facts used by the UI and the command builder.
///
/// Android answers through `reencode/device`, which reads Build, ActivityManager
/// and MediaCodecList. Desktop answers from the Windows port's WMI probe. If a
/// field cannot be read it stays empty and the UI says unknown instead of
/// inventing a model.
class HardwareProfile {
  const HardwareProfile({
    this.platform = 'unknown',
    this.soc = '',
    this.socVendor = '',
    this.gpu = '',
    this.model = '',
    this.manufacturer = '',
    this.cores = 0,
    this.totalRamMb = 0,
    this.cpuName = '',
    this.physicalCores = 0,
    this.logicalCores = 0,
    this.gpuVendor = '',
    this.nvencAvailable = false,
    this.amfAvailable = false,
    this.av1Decode = false,
    this.av1Encode = false,
    this.avcEncode = false,
    this.hevcEncode = false,
    this.lowRam = false,
    this.error = '',
  });

  final String platform;
  final String soc;
  final String socVendor;
  final String gpu;
  final String model;
  final String manufacturer;
  final int cores;
  final int totalRamMb;
  final String cpuName;
  final int physicalCores;
  final int logicalCores;
  final String gpuVendor;
  final bool nvencAvailable;
  final bool amfAvailable;
  final bool av1Decode;
  final bool av1Encode;
  final bool avcEncode;
  final bool hevcEncode;
  final bool lowRam;
  final String error;

  bool get isAndroid => platform == 'android';
  bool get isWindows => platform == 'windows';
  bool get hasHardwareEncoder =>
      avcEncode || hevcEncode || nvencAvailable || amfAvailable;
  String get cpuLabel =>
      cpuName.trim().isNotEmpty ? cpuName : (isWindows ? '可用，但型号未知' : socLabel);
  String? hardwareEncoderFor(String codec) {
    final bool hevc = codec.contains('265') || codec == 'hevc';
    if (nvencAvailable) return hevc ? 'hevc_nvenc' : 'h264_nvenc';
    if (amfAvailable) return hevc ? 'hevc_amf' : 'h264_amf';
    return null;
  }

  bool get socKnown => soc.trim().isNotEmpty && soc.trim() != 'unknown';
  bool get gpuKnown => gpu.trim().isNotEmpty && gpu.trim() != 'Unknown GPU';

  String get socLabel => socKnown ? soc : '可用，但型号未知';
  String get gpuLabel => gpuKnown ? gpu : 'GPU 未知';

  String get av1Text {
    if (av1Encode) return 'AV1 硬解 + 硬编';
    if (av1Decode) return 'AV1 硬解，编码走软件';
    return '未发现 AV1 硬件解码';
  }

  static HardwareProfile _cached = const HardwareProfile();
  static bool _loaded = false;

  static HardwareProfile get current => _cached;

  static Future<HardwareProfile> load({bool force = false}) async {
    if (_loaded && !force) return _cached;
    if (Platform.isWindows) {
      _cached = await _readWindows();
      _loaded = true;
      return _cached;
    }
    if (!Platform.isAndroid) {
      _cached = const HardwareProfile(platform: 'desktop');
      _loaded = true;
      return _cached;
    }
    try {
      const MethodChannel channel = MethodChannel('reencode/device');
      final Map<Object?, Object?>? raw = await channel
          .invokeMapMethod<Object?, Object?>('profile');
      if (raw == null) {
        _cached = const HardwareProfile(
          platform: 'android',
          error: '系统没有返回硬件信息。',
        );
      } else {
        _cached = HardwareProfile(
          platform: 'android',
          soc: _str(raw['socModel']),
          socVendor: _str(raw['socManufacturer']),
          gpu: _str(raw['gpu']),
          model: _str(raw['model']),
          manufacturer: _str(raw['manufacturer']),
          cores: _int(raw['cores']),
          totalRamMb: _int(raw['totalRamMb']),
          av1Decode: raw['av1Decode'] == true,
          av1Encode: raw['av1Encode'] == true,
          avcEncode: raw['avcEncode'] == true,
          hevcEncode: raw['hevcEncode'] == true,
          lowRam: raw['lowRam'] == true,
        );
      }
    } catch (error) {
      _cached = HardwareProfile(platform: 'android', error: '$error');
    }
    _loaded = true;
    return _cached;
  }

  static Future<HardwareProfile> _readWindows() async {
    String cpuName = '';
    int physical = 0;
    int logical = 0;
    int ramMb = 0;
    String gpuName = '';
    String vendor = '';
    try {
      final String cpuRaw = await _powershell(
        'Get-CimInstance Win32_Processor | Select-Object Name,NumberOfCores,NumberOfLogicalProcessors | ConvertTo-Json -Compress',
      );
      final Object? decoded = jsonDecode(cpuRaw);
      final Map<String, dynamic> row = decoded is List
          ? (decoded.first as Map).cast<String, dynamic>()
          : (decoded as Map).cast<String, dynamic>();
      cpuName = '${row['Name'] ?? ''}'.trim();
      physical = _int(row['NumberOfCores']);
      logical = _int(row['NumberOfLogicalProcessors']);
    } catch (_) {}
    try {
      final String ramRaw = await _powershell(
        'Get-CimInstance Win32_ComputerSystem | Select-Object TotalPhysicalMemory | ConvertTo-Json -Compress',
      );
      final dynamic decoded = jsonDecode(ramRaw);
      final Map<String, dynamic> row = decoded is List
          ? (decoded.first as Map).cast<String, dynamic>()
          : (decoded as Map).cast<String, dynamic>();
      ramMb = (_int(row['TotalPhysicalMemory']) / (1024 * 1024)).round();
    } catch (_) {}
    try {
      final String gpuRaw = await _powershell(
        'Get-CimInstance Win32_VideoController | Select-Object Name,PNPDeviceID | ConvertTo-Json -Compress',
      );
      final dynamic decoded = jsonDecode(gpuRaw);
      final List rows = decoded is List ? decoded : <dynamic>[decoded];
      for (final dynamic item in rows) {
        final Map<String, dynamic> row = (item as Map).cast<String, dynamic>();
        final String pnp = '${row['PNPDeviceID'] ?? ''}'.toUpperCase();
        final String name = '${row['Name'] ?? ''}'.trim();
        if (pnp.contains('VEN_10DE')) {
          vendor = 'NVIDIA';
          gpuName = name;
          break;
        }
        if (pnp.contains('VEN_1002')) {
          vendor = 'AMD';
          gpuName = name;
          break;
        }
        if (pnp.contains('VEN_8086') && vendor.isEmpty) {
          vendor = 'Intel';
          gpuName = name;
        }
        if (vendor.isEmpty && name.isNotEmpty) {
          vendor = 'Unknown';
          gpuName = name;
        }
      }
    } catch (_) {}
    bool nvenc = false;
    bool amf = false;
    final String? ffmpeg = _findFfmpeg();
    if (ffmpeg != null) {
      final String encoders = await _run(ffmpeg, <String>[
        '-hide_banner',
        '-encoders',
      ]);
      nvenc =
          encoders.contains('h264_nvenc') || encoders.contains('hevc_nvenc');
      amf = encoders.contains('h264_amf') || encoders.contains('hevc_amf');
    }
    return HardwareProfile(
      platform: 'windows',
      cpuName: cpuName,
      physicalCores: physical,
      logicalCores: logical,
      cores: logical > 0 ? logical : physical,
      totalRamMb: ramMb,
      gpu: gpuName,
      gpuVendor: vendor,
      nvencAvailable: nvenc,
      amfAvailable: amf,
      error: cpuName.isEmpty ? 'CPU 型号读取失败。' : '',
    );
  }

  static Future<String> _powershell(String script) async {
    final ProcessResult result = await Process.run('powershell', <String>[
      '-NoProfile',
      '-NonInteractive',
      '-Command',
      script,
    ]).timeout(const Duration(seconds: 12));
    if (result.exitCode != 0) throw StateError('${result.stderr}');
    return '${result.stdout}'.trim();
  }

  static Future<String> _run(String exe, List<String> args) async {
    try {
      final ProcessResult result = await Process.run(
        exe,
        args,
      ).timeout(const Duration(seconds: 15));
      return '${result.stdout}\n${result.stderr}';
    } catch (_) {
      return '';
    }
  }

  static String? _findFfmpeg() {
    final List<String> candidates = <String>[
      p.join(p.dirname(Platform.resolvedExecutable), 'ffmpeg', 'ffmpeg.exe'),
      p.join(Directory.current.path, 'ffmpeg', 'ffmpeg.exe'),
      p.join(Directory.current.path, 'windows', 'ffmpeg', 'ffmpeg.exe'),
      'ffmpeg.exe',
    ];
    for (final String path in candidates) {
      if (path == 'ffmpeg.exe' || File(path).existsSync()) return path;
    }
    return null;
  }

  static String _str(Object? value) => value is String ? value : '';
  static int _int(Object? value) => value is num ? value.toInt() : 0;
}
