import "dart:async";
import "dart:convert";
import "dart:io";

import "package:path/path.dart" as p;

import "command_builder.dart";
import "engine.dart" show ConversionResult, ProbeException;
import "hardware_profile.dart";
import "models.dart";

/// Locates the FFmpeg binaries that ship beside the executable.
///
/// Release builds place `ffmpeg.exe` and `ffprobe.exe` in an `ffmpeg` folder
/// next to the application, so nothing depends on the machine's PATH.
class WindowsTools {
  static String? _folder;

  static String get _dir {
    if (_folder != null) return _folder!;
    final String exeDir = p.dirname(Platform.resolvedExecutable);
    for (final String candidate in <String>[
      p.join(exeDir, "ffmpeg"),
      p.join(exeDir, "data", "ffmpeg"),
      exeDir,
    ]) {
      if (File(p.join(candidate, "ffmpeg.exe")).existsSync()) {
        _folder = candidate;
        return _folder!;
      }
    }
    _folder = "";
    return _folder!;
  }

  static String get ffmpeg =>
      _dir.isEmpty ? "ffmpeg.exe" : p.join(_dir, "ffmpeg.exe");

  static String get ffprobe =>
      _dir.isEmpty ? "ffprobe.exe" : p.join(_dir, "ffprobe.exe");

  static bool get bundled => _dir.isNotEmpty;

  /// Returns the encoder names this build actually exposes.
  static Future<Set<String>> availableEncoders() async {
    try {
      final ProcessResult result = await Process.run(ffmpeg, <String>[
        "-hide_banner",
        "-encoders",
      ]).timeout(const Duration(seconds: 20));
      final String text = "${result.stdout}";
      final Set<String> names = <String>{};
      for (final RegExpMatch match in RegExp(
        r"^\s*[VAS][FSTXBD.]{5}\s+(\S+)",
        multiLine: true,
      ).allMatches(text)) {
        names.add(match.group(1)!);
      }
      return names;
    } catch (_) {
      return <String>{};
    }
  }

  /// Proves a hardware encoder works instead of trusting its advertisement.
  static Future<bool> encoderWorks(String encoder) async {
    if (encoder.isEmpty) return false;
    try {
      final ProcessResult result = await Process.run(ffmpeg, <String>[
        "-hide_banner",
        "-loglevel",
        "error",
        "-f",
        "lavfi",
        "-i",
        "color=c=black:s=256x144:r=30:d=0.2",
        "-frames:v",
        "1",
        "-c:v",
        encoder,
        "-f",
        "null",
        "-",
      ]).timeout(const Duration(seconds: 25));
      return result.exitCode == 0;
    } catch (_) {
      return false;
    }
  }
}

/// Reads media information through `ffprobe -print_format json`.
class WindowsMediaProbe {
  static Future<MediaSummary> read(String path) async {
    int fallbackSize = 0;
    try {
      fallbackSize = await File(path).length();
    } catch (_) {}

    ProcessResult result;
    try {
      result = await Process.run(
        WindowsTools.ffprobe,
        <String>[
          "-v",
          "error",
          "-print_format",
          "json",
          "-show_format",
          "-show_streams",
          path,
        ],
        stdoutEncoding: utf8,
        stderrEncoding: utf8,
      ).timeout(const Duration(seconds: 30));
    } catch (error) {
      throw ProbeException("FFprobe could not start: $error");
    }

    if (result.exitCode != 0) {
      final String message = "${result.stderr}".trim();
      throw ProbeException(
        message.isNotEmpty
            ? message.split("\n").last.trim()
            : "FFprobe exited with code ${result.exitCode}.",
      );
    }

    Map<String, dynamic> json;
    try {
      json = jsonDecode("${result.stdout}") as Map<String, dynamic>;
    } catch (error) {
      throw ProbeException("Could not read FFprobe output: $error");
    }

    final MediaSummary summary = _toSummary(json, path, fallbackSize);
    if (!summary.hasVideo) {
      throw ProbeException("No video stream in this file.");
    }
    return summary;
  }

  static MediaSummary _toSummary(
    Map<String, dynamic> json,
    String path,
    int fallbackSize,
  ) {
    final Map<String, dynamic> format =
        (json["format"] as Map<String, dynamic>?) ?? <String, dynamic>{};
    final List<Map<String, dynamic>> streams =
        ((json["streams"] as List<dynamic>?) ?? <dynamic>[])
            .cast<Map<String, dynamic>>();

    Map<String, dynamic>? video;
    Map<String, dynamic>? audio;
    for (final Map<String, dynamic> stream in streams) {
      final String type = "${stream["codec_type"]}";
      if (video == null && type == "video") {
        video = stream;
      } else if (audio == null && type == "audio") {
        audio = stream;
      }
    }

    return MediaSummary(
      path: path,
      name: p.basename(path),
      format: "${format["format_name"] ?? ""}",
      durationSeconds: _double(format["duration"]),
      sizeBytes: _int(format["size"]) ?? fallbackSize,
      bitrateKbps: (_int(format["bit_rate"]) ?? 0) ~/ 1000,
      video: video == null ? null : _stream(video, isVideo: true),
      audio: audio == null ? null : _stream(audio, isVideo: false),
    );
  }

  static StreamSummary _stream(
    Map<String, dynamic> stream, {
    required bool isVideo,
  }) {
    final int rotation = _rotation(stream);
    return StreamSummary(
      codec: "${stream["codec_name"] ?? ""}",
      width: _int(stream["width"]) ?? 0,
      height: _int(stream["height"]) ?? 0,
      pixelFormat: "${stream["pix_fmt"] ?? ""}",
      fps: isVideo ? _fps("${stream["r_frame_rate"] ?? ""}") : 0,
      bitrateKbps: (_int(stream["bit_rate"]) ?? 0) ~/ 1000,
      channels: _int(stream["channels"]) ?? 0,
      sampleRate: _int(stream["sample_rate"]) ?? 0,
      channelLayout: "${stream["channel_layout"] ?? ""}",
      rotation: rotation,
    );
  }

  static int _rotation(Map<String, dynamic> stream) {
    final List<dynamic> sideData =
        (stream["side_data_list"] as List<dynamic>?) ?? <dynamic>[];
    for (final dynamic item in sideData) {
      if (item is Map<String, dynamic> && item["rotation"] != null) {
        return _int(item["rotation"]) ?? 0;
      }
    }
    final Map<String, dynamic> tags =
        (stream["tags"] as Map<String, dynamic>?) ?? <String, dynamic>{};
    return _int(tags["rotate"]) ?? 0;
  }

  static double _fps(String raw) {
    final List<String> parts = raw.split("/");
    if (parts.length == 2) {
      final double numerator = double.tryParse(parts[0]) ?? 0;
      final double denominator = double.tryParse(parts[1]) ?? 0;
      if (denominator != 0 && numerator > 0) return numerator / denominator;
    }
    return double.tryParse(raw) ?? 0;
  }

  static double _double(dynamic value) =>
      double.tryParse("${value ?? ""}") ?? 0;

  static int? _int(dynamic value) => int.tryParse("${value ?? ""}");
}

/// Runs ffmpeg as a child process and parses `-progress` output for the UI.
class WindowsConversionRunner {
  Process? _process;
  bool _cancelRequested = false;

  bool get isRunning => _process != null;

  Future<ConversionResult> run({
    required MediaSummary media,
    required ConversionRecipe recipe,
    required String outputPath,
    required void Function(double progress) onProgress,
  }) async {
    final ConversionResult first = await _runOnce(
      media: media,
      recipe: recipe,
      outputPath: outputPath,
      onProgress: onProgress,
    );
    if (!first.success &&
        !first.canceled &&
        recipe.hardwareAcceleration != HardwareAcceleration.software &&
        (recipe.videoCodec == VideoCodec.h264 ||
            recipe.videoCodec == VideoCodec.h265)) {
      try {
        final File output = File(outputPath);
        if (output.existsSync()) output.deleteSync();
      } catch (_) {}
      final ConversionResult retry = await _runOnce(
        media: media,
        recipe: recipe.copyWith(
          hardwareAcceleration: HardwareAcceleration.software,
          hardwareDecode: false,
        ),
        outputPath: outputPath,
        onProgress: onProgress,
      );
      if (retry.success) {
        return ConversionResult(
          retry.returnCode,
          "Hardware encoder failed; retried on CPU.\n${retry.log ?? ""}",
        );
      }
    }
    return first;
  }

  Future<ConversionResult> _runOnce({
    required MediaSummary media,
    required ConversionRecipe recipe,
    required String outputPath,
    required void Function(double progress) onProgress,
  }) async {
    _cancelRequested = false;
    await HardwareProfile.load();
    final List<String> args = CommandBuilder.build(
      media: media,
      recipe: recipe,
      outputPath: outputPath,
    );

    final List<String> full = <String>[
      "-hide_banner",
      "-progress",
      "pipe:1",
      "-nostats",
      ...args,
    ];

    final Process process = await Process.start(WindowsTools.ffmpeg, full);
    _process = process;

    final StringBuffer stderr = StringBuffer();
    final double durationUs = media.durationSeconds * 1000000;
    DateTime lastTick = DateTime.fromMillisecondsSinceEpoch(0);

    final Completer<void> stdoutDone = Completer<void>();
    process.stdout
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen(
          (String line) {
            final int index = line.indexOf("=");
            if (index <= 0) return;
            final String key = line.substring(0, index);
            final String value = line.substring(index + 1).trim();
            if (key == "out_time_us" ||
                key == "out_time_ms" ||
                key == "out_time") {
              double micros = double.tryParse(value) ?? 0;
              if (micros <= 0 && value.contains(":")) {
                micros = _clockToMicros(value);
              }
              if (durationUs <= 0 || micros <= 0) return;
              final DateTime now = DateTime.now();
              if (now.difference(lastTick).inMilliseconds < 200) return;
              lastTick = now;
              onProgress((micros / durationUs).clamp(0.0, 0.99));
            } else if (key == "progress" && value == "end") {
              onProgress(1.0);
            }
          },
          onDone: () {
            if (!stdoutDone.isCompleted) stdoutDone.complete();
          },
        );

    process.stderr.transform(utf8.decoder).listen((String chunk) {
      if (stderr.length > 20000) return;
      stderr.write(chunk);
    });

    final int code = await process.exitCode;
    _process = null;
    await stdoutDone.future.timeout(
      const Duration(seconds: 3),
      onTimeout: () {},
    );

    if (_cancelRequested) {
      return ConversionResult(255, stderr.toString());
    }

    try {
      final File output = File(outputPath);
      if (code == 0 && !output.existsSync()) {
        return ConversionResult(
          1,
          "${stderr.toString()}\nNo output file written.",
        );
      }
    } catch (_) {}

    return ConversionResult(code, stderr.toString());
  }

  void cancel() {
    _cancelRequested = true;
    _process?.kill();
  }

  static double _clockToMicros(String value) {
    final List<String> parts = value.split(":");
    if (parts.length != 3) return 0;
    final double hours = double.tryParse(parts[0]) ?? 0;
    final double minutes = double.tryParse(parts[1]) ?? 0;
    final double seconds = double.tryParse(parts[2]) ?? 0;
    return (hours * 3600 + minutes * 60 + seconds) * 1000000;
  }
}
