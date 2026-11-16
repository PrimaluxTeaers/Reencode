import "dart:convert";
import "dart:io";

import "engine_windows.dart";

/// Hardware profile used to pick encoder threads, job concurrency and whether a
/// hardware encoder is even worth trying on this machine.
///
/// Nothing here is a model whitelist. The tier comes from four measurable
/// values: physical cores, logical cores, L3 cache size, and the GPU vendor id.
class HardwareProfile {
  /// CPU marketing name, shown in the about panel. Never used for decisions.
  final String cpuName;
  final int physicalCores;
  final int logicalCores;
  final int l3Mb;

  /// GPU name, shown only. Decisions use [gpuVendor].
  final String gpuName;

  /// `nvidia`, `amd`, `intel`, `other` or `none`.
  final String gpuVendor;

  final bool nvencAvailable;
  final bool amfAvailable;

  const HardwareProfile({
    this.cpuName = "",
    this.physicalCores = 4,
    this.logicalCores = 4,
    this.l3Mb = 0,
    this.gpuName = "",
    this.gpuVendor = "none",
    this.nvencAvailable = false,
    this.amfAvailable = false,
  });

  static const HardwareProfile unknown = HardwareProfile();

  bool get isWindows => Platform.isWindows;

  /// Zen 4/5 X3D parts carry 96 MB or more of L3. Big cache helps decode,
  /// filter chains and task switching, not encode throughput itself.
  bool get bigCache => l3Mb >= 64;

  /// Intel P/E hybrid: logical cores are more than twice the physical ones and
  /// the part is not an SMT-only AMD layout.
  bool get hybridCores => logicalCores > physicalCores * 2;

  /// Threads handed to one encode. Six cores is the documented floor: every
  /// tier stays usable there, and below four cores we stop pretending.
  int get encodeThreads {
    if (physicalCores <= 0) return 2;
    if (physicalCores <= 3) return physicalCores;
    if (physicalCores <= 8) return physicalCores;
    return (physicalCores * 0.75).floor();
  }

  /// How many files may encode at once. Small machines stay serial.
  int get parallelJobs {
    if (physicalCores < 6) return 1;
    if (bigCache) return physicalCores >= 12 ? 3 : 2;
    if (physicalCores >= 12) return 2;
    return 1;
  }

  String get cpuTier {
    if (bigCache && hybridCores) return "big-cache-hybrid";
    if (bigCache) return "big-cache";
    if (hybridCores) return "hybrid";
    if (physicalCores < 4) return "minimal";
    return "standard";
  }

  /// `null` means software encoding only.
  String? hardwareEncoderFor(String softwareCodec) {
    final bool hevc = softwareCodec.contains("265") || softwareCodec == "hevc";
    if (nvencAvailable) return hevc ? "hevc_nvenc" : "h264_nvenc";
    if (amfAvailable) return hevc ? "hevc_amf" : "h264_amf";
    return null;
  }

  bool get hardwareSupported => gpuVendor == "nvidia" || gpuVendor == "amd";

  String get gpuSupportNote {
    if (gpuVendor == "nvidia") {
      return nvencAvailable
          ? "NVIDIA NVENC available"
          : "NVIDIA GPU detected, NVENC did not start";
    }
    if (gpuVendor == "amd") {
      return amfAvailable ? "AMD AMF available" : "AMD GPU detected, AMF did not start";
    }
    if (gpuVendor == "intel") {
      return "Intel graphics detected. Hardware acceleration is not supported on Intel or Arc; CPU encoding only.";
    }
    if (gpuVendor == "other") {
      return "Unsupported GPU vendor. Hardware acceleration is disabled; CPU encoding only.";
    }
    return "No discrete GPU detected. CPU encoding only.";
  }
}

/// Reads the profile once and caches it. Every probe is best-effort: a machine
/// that refuses WMI still gets a usable default.
class HardwareProbe {
  static HardwareProfile? _cached;

  static Future<HardwareProfile> read({bool refresh = false}) async {
    if (!refresh && _cached != null) return _cached!;
    if (!Platform.isWindows) {
      _cached = HardwareProfile.unknown;
      return _cached!;
    }

    String cpuName = "";
    int physical = 0;
    int logical = 0;
    int l3 = 0;
    String gpuName = "";
    String vendor = "none";

    final Map<String, dynamic>? cpu = await _wmi(
      "Win32_Processor",
      "Name,NumberOfCores,NumberOfLogicalProcessors,L3CacheSize",
    );
    if (cpu != null) {
      cpuName = "${cpu["Name"] ?? ""}".trim();
      physical = _int(cpu["NumberOfCores"]) ?? 0;
      logical = _int(cpu["NumberOfLogicalProcessors"]) ?? 0;
      l3 = ((_int(cpu["L3CacheSize"]) ?? 0) / 1024).round();
    }

    final List<Map<String, dynamic>> gpus = await _wmiList(
      "Win32_VideoController",
      "Name,PNPDeviceID,AdapterCompatibility",
    );
    for (final Map<String, dynamic> gpu in gpus) {
      final String pnp = "${gpu["PNPDeviceID"] ?? ""}".toUpperCase();
      final String name = "${gpu["Name"] ?? ""}";
      if (pnp.contains("VEN_10DE")) {
        vendor = "nvidia";
        gpuName = name;
        break;
      }
      if (pnp.contains("VEN_1002")) {
        vendor = "amd";
        gpuName = name;
        break;
      }
      if (pnp.contains("VEN_8086")) {
        if (vendor == "none") {
          vendor = "intel";
          gpuName = name;
        }
        continue;
      }
      if (vendor == "none" && name.isNotEmpty) {
        vendor = "other";
        gpuName = name;
      }
    }

    bool nvenc = false;
    bool amf = false;
    if (vendor == "nvidia") {
      nvenc = await WindowsTools.encoderWorks("h264_nvenc");
    } else if (vendor == "amd") {
      amf = await WindowsTools.encoderWorks("h264_amf");
    }

    _cached = HardwareProfile(
      cpuName: cpuName,
      physicalCores: physical > 0 ? physical : logical,
      logicalCores: logical > 0 ? logical : physical,
      l3Mb: l3,
      gpuName: gpuName,
      gpuVendor: vendor,
      nvencAvailable: nvenc,
      amfAvailable: amf,
    );
    return _cached!;
  }

  static Future<Map<String, dynamic>?> _wmi(
    String className,
    String properties,
  ) async {
    final List<Map<String, dynamic>> rows = await _wmiList(className, properties);
    return rows.isEmpty ? null : rows.first;
  }

  static Future<List<Map<String, dynamic>>> _wmiList(
    String className,
    String properties,
  ) async {
    try {
      final ProcessResult result = await Process.run(
        "powershell",
        <String>[
          "-NoProfile",
          "-NonInteractive",
          "-Command",
          "Get-WmiObject -Class $className | Select-Object $properties | ConvertTo-Json -Compress",
        ],
      ).timeout(const Duration(seconds: 20));
      final String text = "${result.stdout}".trim();
      if (text.isEmpty || result.exitCode != 0) return <Map<String, dynamic>>[];
      final dynamic decoded = jsonDecode(text);
      if (decoded is List) {
        return decoded.cast<Map<String, dynamic>>();
      }
      if (decoded is Map<String, dynamic>) return <Map<String, dynamic>>[decoded];
    } catch (_) {}
    return <Map<String, dynamic>>[];
  }

  static int? _int(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.round();
    return int.tryParse("${value ?? ""}");
  }
}
