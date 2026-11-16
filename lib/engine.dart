import "dart:async";
import "dart:io";

import "package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart";
import "package:ffmpeg_kit_flutter_new/ffmpeg_session.dart";
import "package:ffmpeg_kit_flutter_new/ffprobe_kit.dart";
import "package:ffmpeg_kit_flutter_new/media_information.dart";
import "package:ffmpeg_kit_flutter_new/media_information_session.dart";
import "package:ffmpeg_kit_flutter_new/return_code.dart";
import "package:ffmpeg_kit_flutter_new/statistics.dart";

import "command_builder.dart";
import "engine_windows.dart";
import "models.dart";

class ProbeException implements Exception {
  final String message;
  ProbeException(this.message);
  @override
  String toString() => message;
}

class ConversionResult {
  final int? returnCode;
  final String? log;

  const ConversionResult(this.returnCode, this.log);

  bool get success => returnCode == ReturnCode.success;
  bool get canceled => returnCode == ReturnCode.cancel;
  String get summary {
    if (success) return "success";
    if (canceled) return "canceled";
    final String? last = _lastMeaningfulLine(log);
    return last ?? "FFmpeg exited with code $returnCode";
  }

  static String? _lastMeaningfulLine(String? log) {
    if (log == null) return null;
    final List<String> lines = log
        .split("\n")
        .map((String line) => line.trim())
        .where((String line) => line.isNotEmpty)
        .toList();
    for (final String line in lines.reversed) {
      if (line.toLowerCase().contains("error") ||
          line.toLowerCase().contains("invalid") ||
          line.toLowerCase().contains("failed")) {
        return line.length > 240 ? line.substring(line.length - 240) : line;
      }
    }
    return lines.isEmpty ? null : lines.last;
  }
}

class MediaProbe {
  static Future<MediaSummary> read(String path) async {
    if (Platform.isWindows) {
      return WindowsMediaProbe.read(path);
    }
    int fallbackSize = 0;
    try {
      fallbackSize = await File(path).length();
    } catch (_) {}
    try {
      final MediaInformationSession session =
          await FFprobeKit.getMediaInformation(path, 5000);
      final MediaInformation? information = session.getMediaInformation();
      if (information == null) {
        final String? output = await session.getOutput();
        throw ProbeException(
          output?.trim().isNotEmpty == true
              ? output!.trim()
              : "FFprobe could not read this file.",
        );
      }
      final MediaSummary summary = MediaSummary.fromInformation(
        information,
        path,
        fallbackSize: fallbackSize,
      );
      if (!summary.hasVideo) {
        throw ProbeException("No video stream in this file.");
      }
      return summary;
    } on ProbeException {
      rethrow;
    } catch (error) {
      throw ProbeException("Could not read media information: $error");
    }
  }
}

class ConversionRunner {
  final WindowsConversionRunner _windows = WindowsConversionRunner();
  FFmpegSession? _session;
  bool _cancelRequested = false;

  bool get isRunning => Platform.isWindows
      ? _windows.isRunning
      : _session != null;

  Future<ConversionResult> run({
    required MediaSummary media,
    required ConversionRecipe recipe,
    required String outputPath,
    required void Function(double progress) onProgress,
  }) async {
    if (Platform.isWindows) {
      return _windows.run(
        media: media,
        recipe: recipe,
        outputPath: outputPath,
        onProgress: onProgress,
      );
    }
    _cancelRequested = false;
    final List<String> args = CommandBuilder.build(
      media: media,
      recipe: recipe,
      outputPath: outputPath,
    );
    final Completer<ConversionResult> completer = Completer<ConversionResult>();
    DateTime lastTick = DateTime.fromMillisecondsSinceEpoch(0);
    final double durationMs = media.durationSeconds * 1000;

    final FFmpegSession session = await FFmpegKit.executeWithArgumentsAsync(
      args,
      (FFmpegSession finished) async {
        _session = finished;
        final int? code = (await finished.getReturnCode())?.getValue();
        final String? logs = await finished.getAllLogsAsString();
        if (!completer.isCompleted) {
          completer.complete(ConversionResult(code, logs));
        }
      },
      null,
      (Statistics stats) {
        final int timeMs = stats.getTime();
        if (durationMs <= 0 || timeMs <= 0) return;
        final DateTime now = DateTime.now();
        if (now.difference(lastTick).inMilliseconds < 180) return;
        lastTick = now;
        final double progress = (timeMs / durationMs).clamp(0.0, 0.99);
        onProgress(progress);
      },
    );
    _session = session;

    if (_cancelRequested) {
      final int? id = session.getSessionId();
      if (id != null) FFmpegKit.cancel(id);
    }

    return completer.future;
  }

  void cancel() {
    if (Platform.isWindows) {
      _windows.cancel();
      return;
    }
    _cancelRequested = true;
    final int? id = _session?.getSessionId();
    if (id != null) {
      FFmpegKit.cancel(id);
    } else {
      FFmpegKit.cancel();
    }
  }
}
