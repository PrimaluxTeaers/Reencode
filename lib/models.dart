import "dart:math" as math;

import "package:ffmpeg_kit_flutter_new/media_information.dart";
import "package:ffmpeg_kit_flutter_new/stream_information.dart";
import "package:material_ui/material_ui.dart";
import "package:path/path.dart" as p;

import "hardware_profile.dart";
import "l10n.dart";

enum WorkMode { remux, transcode, compress, custom }

extension WorkModeInfo on WorkMode {
  String get label => switch (this) {
    WorkMode.remux => S.t("Remux", "只换容器"),
    WorkMode.transcode => S.t("Container + codec", "换容器 / 换编码"),
    WorkMode.compress => S.t("Bitrate only", "压码率"),
    WorkMode.custom => S.t("Custom", "自定义"),
  };

  String get hint => switch (this) {
    WorkMode.remux => S.t(
      "Copy streams, change the wrapper. No quality loss.",
      "复制音视频流，只换封装。画质不变。",
    ),
    WorkMode.transcode => S.t(
      "Change the container and codecs. Bitrate follows the source; use Custom to set every value.",
      "换容器和编码。码率沿用源；要逐项改就切“自定义”。",
    ),
    WorkMode.compress => S.t(
      "Only the video bitrate is editable. Container and codecs are fixed for compatibility.",
      "只改视频码率。容器和编码固定为兼容档，其余不动。",
    ),
    WorkMode.custom => S.t(
      "Every video and audio control is available.",
      "视频、音频的所有参数都能调。",
    ),
  };

  IconData get icon => switch (this) {
    WorkMode.remux => Icons.swap_horiz_rounded,
    WorkMode.transcode => Icons.tune_rounded,
    WorkMode.compress => Icons.compress_rounded,
    WorkMode.custom => Icons.dashboard_customize_outlined,
  };
}

enum TargetContainer { mp4, mkv, mov, webm }

extension TargetContainerInfo on TargetContainer {
  String get label => switch (this) {
    TargetContainer.mp4 => "MP4",
    TargetContainer.mkv => "MKV",
    TargetContainer.mov => "MOV",
    TargetContainer.webm => "WebM",
  };

  String get extension => name;

  String get note => switch (this) {
    TargetContainer.mp4 => S.t("Phones, TVs, browsers", "手机、电视、浏览器"),
    TargetContainer.mkv => S.t("Archive-friendly, many codecs", "归档友好，编码兼容广"),
    TargetContainer.mov => S.t("Apple editing workflows", "Apple 剪辑工作流"),
    TargetContainer.webm => S.t("Web, VP9 + Opus", "网页，VP9 + Opus"),
  };
}

enum VideoCodec { h264, h265, vp9, av1, mpeg4 }

extension VideoCodecInfo on VideoCodec {
  String get label => switch (this) {
    VideoCodec.h264 => "H.264",
    VideoCodec.h265 => "H.265 / HEVC",
    VideoCodec.vp9 => "VP9",
    VideoCodec.av1 => "AV1",
    VideoCodec.mpeg4 => "MPEG-4",
  };

  String get shortLabel => switch (this) {
    VideoCodec.h264 => "H.264",
    VideoCodec.h265 => "H.265",
    VideoCodec.vp9 => "VP9",
    VideoCodec.av1 => "AV1",
    VideoCodec.mpeg4 => "MPEG-4",
  };

  String get ffmpegName => switch (this) {
    VideoCodec.h264 => "libx264",
    VideoCodec.h265 => "libx265",
    VideoCodec.vp9 => "libvpx-vp9",
    VideoCodec.av1 => "libaom-av1",
    VideoCodec.mpeg4 => "mpeg4",
  };

  String get note => switch (this) {
    VideoCodec.h264 => S.t("Widest device support", "设备兼容最广"),
    VideoCodec.h265 => S.t("Smaller files, slower encode", "同画质更小，编码更慢"),
    VideoCodec.vp9 => S.t("Open codec for WebM", "WebM 常用的开放编码"),
    VideoCodec.av1 => S.t(
      "Best compression, very slow on phones",
      "压缩最好，手机编码很慢",
    ),
    VideoCodec.mpeg4 => S.t("Legacy compatibility", "老设备兼容"),
  };
}

enum PixelDepth { auto, eight, ten, twelve }

extension PixelDepthInfo on PixelDepth {
  String get label => switch (this) {
    PixelDepth.auto => S.t("Preserve", "保留"),
    PixelDepth.eight => "8-bit",
    PixelDepth.ten => "10-bit",
    PixelDepth.twelve => "12-bit",
  };

  int? get bits => switch (this) {
    PixelDepth.auto => null,
    PixelDepth.eight => 8,
    PixelDepth.ten => 10,
    PixelDepth.twelve => 12,
  };
}

enum AudioCodec { aac, opus, mp3, copy }

enum HardwareAcceleration { auto, software, mediaCodec }

extension HardwareAccelerationInfo on HardwareAcceleration {
  String get label => switch (this) {
    HardwareAcceleration.auto => S.t("Auto", "自动"),
    HardwareAcceleration.software => S.t("CPU only", "仅 CPU"),
    HardwareAcceleration.mediaCodec => S.t("Hardware", "硬件加速"),
  };

  String get note => switch (this) {
    HardwareAcceleration.auto => S.t(
      "Use MediaCodec when the phone exposes a working encoder; otherwise stay on CPU.",
      "手机有可用硬件编码器时走 MediaCodec，否则留在 CPU。",
    ),
    HardwareAcceleration.software => S.t(
      "libx264 / libx265 / libaom on the CPU. Most predictable output.",
      "libx264 / libx265 / libaom 纯 CPU，输出最可预测。",
    ),
    HardwareAcceleration.mediaCodec => S.t(
      "Ask Android MediaCodec to encode H.264 / H.265. AV1 stays software because these chips do not expose an AV1 encoder.",
      "让 Android MediaCodec 编 H.264 / H.265。AV1 仍走软件，因为这些芯片没有开放 AV1 编码器。",
    ),
  };
}

enum EncoderPreset { fast, balanced, slow, custom }

extension EncoderPresetInfo on EncoderPreset {
  String get label => switch (this) {
    EncoderPreset.fast => S.t("Fast", "快"),
    EncoderPreset.balanced => S.t("Balanced", "均衡"),
    EncoderPreset.slow => S.t("Slow", "慢"),
    EncoderPreset.custom => S.t("Custom", "自定义"),
  };

  String get ffmpegName => switch (this) {
    EncoderPreset.fast => "veryfast",
    EncoderPreset.balanced => "medium",
    EncoderPreset.slow => "slow",
    EncoderPreset.custom => "medium",
  };
}

enum FrameRateMode { passthrough, cfr }

extension FrameRateModeInfo on FrameRateMode {
  String get label => switch (this) {
    FrameRateMode.passthrough => S.t("Passthrough", "跟随源"),
    FrameRateMode.cfr => S.t("CFR", "固定帧率"),
  };
}

extension AudioCodecInfo on AudioCodec {
  String get label => switch (this) {
    AudioCodec.aac => "AAC",
    AudioCodec.opus => "Opus",
    AudioCodec.mp3 => "MP3",
    AudioCodec.copy => S.t("Copy", "原样复制"),
  };

  String get ffmpegName => switch (this) {
    AudioCodec.aac => "aac",
    AudioCodec.opus => "libopus",
    AudioCodec.mp3 => "libmp3lame",
    AudioCodec.copy => "copy",
  };

  String get note => switch (this) {
    AudioCodec.aac => S.t("Default for MP4 and phones", "MP4 和手机默认"),
    AudioCodec.opus => S.t("Efficient, best in WebM", "效率高，WebM 最合适"),
    AudioCodec.mp3 => S.t("Legacy players", "老播放器"),
    AudioCodec.copy => S.t("No re-encode", "不重新编码"),
  };
}

class StreamSummary {
  final String codec;
  final int width;
  final int height;
  final String pixelFormat;
  final double fps;
  final int bitrateKbps;
  final int channels;
  final int sampleRate;
  final String channelLayout;
  final int rotation;
  final String colorPrimaries;
  final String colorTransfer;
  final String colorSpace;
  final String masteringDisplay;
  final int maxCll;
  final int maxFall;
  final bool hasHdr10Plus;
  final bool hasDolbyVision;

  const StreamSummary({
    this.codec = "",
    this.width = 0,
    this.height = 0,
    this.pixelFormat = "",
    this.fps = 0,
    this.bitrateKbps = 0,
    this.channels = 0,
    this.sampleRate = 0,
    this.channelLayout = "",
    this.rotation = 0,
    this.colorPrimaries = "",
    this.colorTransfer = "",
    this.colorSpace = "",
    this.masteringDisplay = "",
    this.maxCll = 0,
    this.maxFall = 0,
    this.hasHdr10Plus = false,
    this.hasDolbyVision = false,
  });

  bool get isTenBit => bitDepth >= 10;

  bool get hasHdrMetadata =>
      masteringDisplay.isNotEmpty || maxCll > 0 || maxFall > 0;

  bool get isHdr =>
      hasHdrMetadata ||
      colorTransfer == "smpte2084" ||
      colorTransfer == "arib-std-b67";

  bool get hasHdr10PlusMetadata => hasHdr10Plus;

  bool get hasDolbyVisionMetadata => hasDolbyVision;

  String get hdrLabel {
    final List<String> tags = <String>[];
    if (hasDolbyVision) tags.add("Dolby Vision");
    if (hasHdr10Plus) tags.add("HDR10+");
    if (isHdr) tags.add("HDR10");
    return tags.join(" · ");
  }

  int get bitDepth {
    if (pixelFormat.contains("12le") || pixelFormat.contains("12be")) {
      return 12;
    }
    if (pixelFormat.contains("10le") || pixelFormat.contains("10be")) {
      return 10;
    }
    return 8;
  }

  bool get hasKnownDepth => pixelFormat.isNotEmpty;

  String get resolution => width > 0 && height > 0 ? "$width×$height" : "—";

  String get fpsLabel =>
      fps > 0 ? "${fps.toStringAsFixed(fps >= 10 ? 0 : 2)} fps" : "—";
}

class MediaSummary {
  final String path;
  final String name;
  final String format;
  final double durationSeconds;
  final int sizeBytes;
  final int bitrateKbps;
  final StreamSummary? video;
  final StreamSummary? audio;

  const MediaSummary({
    required this.path,
    required this.name,
    required this.format,
    required this.durationSeconds,
    required this.sizeBytes,
    required this.bitrateKbps,
    this.video,
    this.audio,
  });

  bool get hasVideo => video != null;
  bool get hasAudio => audio != null;

  String get durationLabel {
    final int total = durationSeconds.round();
    final int hours = total ~/ 3600;
    final int minutes = (total % 3600) ~/ 60;
    final int seconds = total % 60;
    if (hours > 0) {
      return "$hours:${minutes.toString().padLeft(2, "0")}:${seconds.toString().padLeft(2, "0")}";
    }
    return "$minutes:${seconds.toString().padLeft(2, "0")}";
  }

  String get sizeLabel => formatBytes(sizeBytes);

  String get formatLabel {
    final String first = format.split(",").first.trim();
    return first.isEmpty ? "—" : first.toUpperCase();
  }

  factory MediaSummary.fromInformation(
    MediaInformation info,
    String path, {
    int fallbackSize = 0,
  }) {
    final List<StreamInformation> streams = info.getStreams();
    StreamInformation? videoStream;
    StreamInformation? audioStream;
    for (final StreamInformation stream in streams) {
      if (videoStream == null && stream.getType() == "video") {
        videoStream = stream;
      } else if (audioStream == null && stream.getType() == "audio") {
        audioStream = stream;
      }
    }

    final double duration = _toDouble(info.getDuration()) ?? 0;
    final int size = _toInt(info.getSize()) ?? fallbackSize;
    final int totalBitrate = _toInt(info.getBitrate()) ?? 0;

    final StreamSummary? video = videoStream == null
        ? null
        : _videoSummary(videoStream);
    final StreamSummary? audio = audioStream == null
        ? null
        : StreamSummary(
            codec: (audioStream.getCodec() ?? "").toLowerCase(),
            bitrateKbps: (_toInt(audioStream.getBitrate()) ?? 0) ~/ 1000,
            channels: _toInt(audioStream.getNumberProperty("channels")) ?? 0,
            sampleRate: _toInt(audioStream.getSampleRate()) ?? 0,
            channelLayout: (audioStream.getChannelLayout() ?? "").toLowerCase(),
          );

    return MediaSummary(
      path: path,
      name: p.basename(path),
      format: info.getFormat() ?? "",
      durationSeconds: duration,
      sizeBytes: size,
      bitrateKbps: totalBitrate ~/ 1000,
      video: video,
      audio: audio,
    );
  }

  static StreamSummary _videoSummary(StreamInformation stream) {
    final List<Map<dynamic, dynamic>> sideData = _sideDataOf(stream);
    Map<dynamic, dynamic>? mastering;
    Map<dynamic, dynamic>? light;
    bool hdr10Plus = false;
    bool dolbyVision = false;
    for (final Map<dynamic, dynamic> item in sideData) {
      final String type = (item["side_data_type"] ?? "")
          .toString()
          .toLowerCase();
      if (type.contains("mastering display")) mastering = item;
      if (type.contains("content light")) light = item;
      if (type.contains("hdr10+") ||
          type.contains("smpte2094-40") ||
          type.contains("hdr dynamic")) {
        hdr10Plus = true;
      }
      if (type.contains("dolby vision") || type.contains("dovi")) {
        dolbyVision = true;
      }
    }
    return StreamSummary(
      codec: (stream.getCodec() ?? "").toLowerCase(),
      width: stream.getWidth() ?? 0,
      height: stream.getHeight() ?? 0,
      pixelFormat: (stream.getFormat() ?? "").toLowerCase(),
      fps: _parseRate(
        stream.getAverageFrameRate() ?? stream.getRealFrameRate(),
      ),
      bitrateKbps: (_toInt(stream.getBitrate()) ?? 0) ~/ 1000,
      rotation: _rotationOf(stream),
      colorPrimaries: (stream.getStringProperty("color_primaries") ?? "")
          .toLowerCase(),
      colorTransfer: (stream.getStringProperty("color_transfer") ?? "")
          .toLowerCase(),
      colorSpace: (stream.getStringProperty("color_space") ?? "").toLowerCase(),
      masteringDisplay: mastering == null ? "" : _masteringDisplay(mastering),
      maxCll: _toInt(light?["max_content"]) ?? 0,
      maxFall: _toInt(light?["max_average"]) ?? 0,
      hasHdr10Plus: hdr10Plus,
      hasDolbyVision: dolbyVision,
    );
  }

  static List<Map<dynamic, dynamic>> _sideDataOf(StreamInformation stream) {
    final dynamic raw = stream.getProperty("side_data_list");
    if (raw is! List) return const <Map<dynamic, dynamic>>[];
    return raw.whereType<Map>().map((Map item) => item).toList();
  }

  static String _masteringDisplay(Map<dynamic, dynamic> data) {
    final int gx = _scaled(data["green_x"], 50000);
    final int gy = _scaled(data["green_y"], 50000);
    final int bx = _scaled(data["blue_x"], 50000);
    final int by = _scaled(data["blue_y"], 50000);
    final int rx = _scaled(data["red_x"], 50000);
    final int ry = _scaled(data["red_y"], 50000);
    final int wx = _scaled(data["white_point_x"], 50000);
    final int wy = _scaled(data["white_point_y"], 50000);
    final int maxLum = _scaled(data["max_luminance"], 10000);
    final int minLum = _scaled(data["min_luminance"], 10000);
    if (gx <= 0 || gy <= 0 || bx <= 0 || by <= 0 || rx <= 0 || ry <= 0) {
      return "";
    }
    return "G($gx,$gy)B($bx,$by)R($rx,$ry)WP($wx,$wy)L($maxLum,$minLum)";
  }

  static int _scaled(dynamic value, int scale) {
    if (value is num) {
      return value <= 1.0 ? (value * scale).round() : value.round();
    }
    final String text = value?.toString() ?? "";
    final String numerator = text.split("/").first;
    final double? parsed = double.tryParse(numerator);
    if (parsed == null) return 0;
    return parsed <= 1.0 ? (parsed * scale).round() : parsed.round();
  }

  static int _rotationOf(StreamInformation stream) {
    final dynamic rotate = stream.getProperty("rotate");
    if (rotate is num) return rotate.toInt();
    if (rotate is String) return int.tryParse(rotate) ?? 0;
    final dynamic tags = stream.getTags();
    if (tags is Map) {
      final dynamic value = tags["rotate"];
      if (value is num) return value.toInt();
      if (value is String) return int.tryParse(value) ?? 0;
    }
    return 0;
  }

  static double? _toDouble(String? value) => double.tryParse(value ?? "");

  static int? _toInt(Object? value) {
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? "");
  }

  static double _parseRate(String? rate) {
    if (rate == null || rate.isEmpty) return 0;
    final List<String> parts = rate.split("/");
    if (parts.length == 2) {
      final double? numerator = double.tryParse(parts[0]);
      final double? denominator = double.tryParse(parts[1]);
      if (numerator != null && denominator != null && denominator != 0) {
        final double value = numerator / denominator;
        if (value.isFinite && value > 0 && value < 1000) return value;
      }
    }
    final double? single = double.tryParse(rate);
    return single != null && single.isFinite && single > 0 && single < 1000
        ? single
        : 0;
  }
}

class RecipeIssue {
  final String message;
  final bool blocking;

  const RecipeIssue(this.message, {this.blocking = true});
}

class ConversionRecipe {
  final WorkMode mode;
  final TargetContainer container;
  final VideoCodec videoCodec;
  final AudioCodec audioCodec;
  final int videoBitrateKbps;
  final int audioBitrateKbps;
  final int targetWidth;
  final int targetHeight;
  final int targetFps;
  final PixelDepth pixelDepth;
  final FrameRateMode frameRateMode;
  final bool preserveHdr10;
  final bool preserveHdr10Plus;
  final bool preserveDolbyVision;
  final bool keepMetadata;
  final bool keepChapters;
  final bool fastStart;
  final EncoderPreset encoderPreset;
  final String customPreset;
  final HardwareAcceleration hardwareAcceleration;

  /// 0 means let FFmpeg decide. Android settings cap this at 8.
  final int threadLimit;

  /// Experimental Android decode through MediaCodec. Older phones can refuse
  /// the pixel format, so the UI must keep a software fallback.
  final bool hardwareDecode;

  /// Soft app-side budget. 0 means no app-imposed queue limit.
  final int memoryBudgetMb;

  const ConversionRecipe({
    this.mode = WorkMode.transcode,
    this.container = TargetContainer.mp4,
    this.videoCodec = VideoCodec.h264,
    this.audioCodec = AudioCodec.aac,
    this.videoBitrateKbps = 2000,
    this.audioBitrateKbps = 128,
    this.targetWidth = 0,
    this.targetHeight = 0,
    this.targetFps = 0,
    this.pixelDepth = PixelDepth.auto,
    this.frameRateMode = FrameRateMode.passthrough,
    this.preserveHdr10 = true,
    this.preserveHdr10Plus = true,
    this.preserveDolbyVision = true,
    this.keepMetadata = true,
    this.keepChapters = true,
    this.fastStart = true,
    this.encoderPreset = EncoderPreset.balanced,
    this.customPreset = "medium",
    this.hardwareAcceleration = HardwareAcceleration.software,
    this.threadLimit = 0,
    this.hardwareDecode = false,
    this.memoryBudgetMb = 0,
  });

  String get ffmpegPreset => encoderPreset == EncoderPreset.custom
      ? (customPreset.trim().isEmpty ? "medium" : customPreset.trim())
      : encoderPreset.ffmpegName;

  ConversionRecipe copyWith({
    WorkMode? mode,
    TargetContainer? container,
    VideoCodec? videoCodec,
    AudioCodec? audioCodec,
    int? videoBitrateKbps,
    int? audioBitrateKbps,
    int? targetWidth,
    int? targetHeight,
    int? targetFps,
    PixelDepth? pixelDepth,
    FrameRateMode? frameRateMode,
    bool? preserveHdr10,
    bool? preserveHdr10Plus,
    bool? preserveDolbyVision,
    bool? keepMetadata,
    bool? keepChapters,
    bool? fastStart,
    EncoderPreset? encoderPreset,
    String? customPreset,
    HardwareAcceleration? hardwareAcceleration,
    int? threadLimit,
    bool? hardwareDecode,
    int? memoryBudgetMb,
  }) {
    return ConversionRecipe(
      mode: mode ?? this.mode,
      container: container ?? this.container,
      videoCodec: videoCodec ?? this.videoCodec,
      audioCodec: audioCodec ?? this.audioCodec,
      videoBitrateKbps: videoBitrateKbps ?? this.videoBitrateKbps,
      audioBitrateKbps: audioBitrateKbps ?? this.audioBitrateKbps,
      targetWidth: targetWidth ?? this.targetWidth,
      targetHeight: targetHeight ?? this.targetHeight,
      targetFps: targetFps ?? this.targetFps,
      pixelDepth: pixelDepth ?? this.pixelDepth,
      frameRateMode: frameRateMode ?? this.frameRateMode,
      preserveHdr10: preserveHdr10 ?? this.preserveHdr10,
      preserveHdr10Plus: preserveHdr10Plus ?? this.preserveHdr10Plus,
      preserveDolbyVision: preserveDolbyVision ?? this.preserveDolbyVision,
      keepMetadata: keepMetadata ?? this.keepMetadata,
      keepChapters: keepChapters ?? this.keepChapters,
      fastStart: fastStart ?? this.fastStart,
      encoderPreset: encoderPreset ?? this.encoderPreset,
      customPreset: customPreset ?? this.customPreset,
      hardwareAcceleration:
          hardwareAcceleration ?? this.hardwareAcceleration,
      threadLimit: threadLimit ?? this.threadLimit,
      hardwareDecode: hardwareDecode ?? this.hardwareDecode,
      memoryBudgetMb: memoryBudgetMb ?? this.memoryBudgetMb,
    );
  }

  factory ConversionRecipe.defaultsFor(MediaSummary media) {
    final StreamSummary? video = media.video;
    final StreamSummary? audio = media.audio;
    final String sourceCodec = video?.codec ?? "";
    final TargetContainer container =
        sourceCodec == "h264" ||
            sourceCodec == "hevc" ||
            sourceCodec == "av1" ||
            sourceCodec == "mpeg4"
        ? TargetContainer.mp4
        : TargetContainer.mkv;
    final int sourceVideoKbps = video?.bitrateKbps ?? 0;
    final int sourceAudioKbps = audio?.bitrateKbps ?? 0;
    final int fallbackVideo = sourceVideoKbps > 0
        ? sourceVideoKbps
        : math.max(800, media.bitrateKbps - sourceAudioKbps);
    return ConversionRecipe(
      mode: WorkMode.transcode,
      container: container,
      videoCodec: VideoCodec.h264,
      audioCodec: AudioCodec.aac,
      videoBitrateKbps: fallbackVideo > 0 ? fallbackVideo : 2000,
      audioBitrateKbps: sourceAudioKbps > 0 ? sourceAudioKbps : 128,
      targetWidth: 0,
      targetHeight: 0,
      targetFps: AppPreferences.defaultForceCfr ? AppPreferences.defaultTargetFps : 0,
      frameRateMode: AppPreferences.defaultForceCfr
          ? FrameRateMode.cfr
          : FrameRateMode.passthrough,
      hardwareAcceleration: AppPreferences.hardwareEncoding
          ? HardwareAcceleration.auto
          : HardwareAcceleration.software,
      threadLimit: AppPreferences.threadLimit,
      memoryBudgetMb: AppPreferences.memoryBudgetMb,
      preserveHdr10: video?.isHdr ?? false,
      preserveHdr10Plus: video?.hasHdr10PlusMetadata ?? false,
      preserveDolbyVision: video?.hasDolbyVisionMetadata ?? false,
    );
  }

  ConversionRecipe forMode(WorkMode mode, MediaSummary media) {
    if (mode == WorkMode.remux) {
      final String codec = media.video?.codec ?? "";
      final TargetContainer container =
          codec == "h264" ||
              codec == "hevc" ||
              codec == "av1" ||
              codec == "mpeg4"
          ? TargetContainer.mp4
          : TargetContainer.mkv;
      return copyWith(
        mode: mode,
        container: container,
        audioCodec: AudioCodec.copy,
        targetWidth: 0,
        targetHeight: 0,
        targetFps: 0,
        frameRateMode: FrameRateMode.passthrough,
      );
    }
    if (mode == WorkMode.compress) {
      final int source = videoBitrateKbps > 0 ? videoBitrateKbps : 2000;
      final int target = source > 2500
          ? math.max(800, source * 2 ~/ 3)
          : math.max(500, source ~/ 2);
      return copyWith(
        mode: mode,
        container: TargetContainer.mp4,
        videoCodec: VideoCodec.h264,
        audioCodec: AudioCodec.aac,
        videoBitrateKbps: target,
        audioBitrateKbps: 128,
        targetWidth: 0,
        targetHeight: 0,
        targetFps: 0,
        frameRateMode: FrameRateMode.passthrough,
      );
    }
    final int sourceVideoKbps = media.video?.bitrateKbps ?? 0;
    return copyWith(
      mode: mode,
      container: container,
      audioCodec: AudioCodec.aac,
      videoBitrateKbps: mode == WorkMode.transcode && sourceVideoKbps > 0
          ? sourceVideoKbps
          : videoBitrateKbps,
      targetWidth: 0,
      targetHeight: 0,
      targetFps: 0,
      frameRateMode: FrameRateMode.passthrough,
      pixelDepth: PixelDepth.auto,
    );
  }

  int estimatedBytesFor(MediaSummary media) {
    if (mode == WorkMode.remux) return media.sizeBytes;
    final int audio = media.hasAudio ? audioBitrateKbps : 0;
    final int totalKbps = videoBitrateKbps + audio;
    final double raw = totalKbps * media.durationSeconds * 1000 / 8;
    return raw.isFinite && raw > 0 ? (raw * 1.04).round() : 0;
  }

  List<RecipeIssue> validate(MediaSummary media) {
    final List<RecipeIssue> issues = <RecipeIssue>[];
    if (!media.hasVideo) {
      issues.add(
        RecipeIssue(
          S.t("No video stream was found in this file.", "这个文件里没有视频流。"),
        ),
      );
      return issues;
    }
    if (media.durationSeconds <= 0) {
      issues.add(
        RecipeIssue(
          S.t(
            "Duration is unknown; progress will be estimated.",
            "读不出时长，进度只能估算。",
          ),
          blocking: false,
        ),
      );
    }
    if (mode == WorkMode.remux) {
      final String sourceVideo = media.video?.codec ?? "";
      if (!_containerAcceptsVideo(container, sourceVideo)) {
        issues.add(
          RecipeIssue(
            S.t(
              "This container cannot carry the source video codec. Choose MKV or switch to Re-encode.",
              "这个容器装不下源视频编码。换 MKV，或者改用“换编码”。",
            ),
          ),
        );
      }
      final String sourceAudio = media.audio?.codec ?? "";
      if (media.hasAudio && !_containerAcceptsAudio(container, sourceAudio)) {
        issues.add(
          RecipeIssue(
            S.t(
              "This container cannot carry the source audio codec. Choose MKV or re-encode audio.",
              "这个容器装不下源音频编码。换 MKV，或者重新编码音频。",
            ),
          ),
        );
      }
      return issues;
    }

    if (!_containerAcceptsVideo(container, videoCodec.ffmpegName)) {
      issues.add(
        RecipeIssue(
          S.t(
            "The selected video codec is not valid for this container.",
            "当前容器不支持所选视频编码。",
          ),
        ),
      );
    }
    if (media.hasAudio) {
      final String targetAudio = audioCodec == AudioCodec.copy
          ? (media.audio?.codec ?? "")
          : audioCodec.ffmpegName;
      if (!_containerAcceptsAudio(container, targetAudio)) {
        issues.add(
          RecipeIssue(
            S.t(
              "The selected audio codec is not valid for this container.",
              "当前容器不支持所选音频编码。",
            ),
          ),
        );
      }
    }
    if ((media.video?.hasHdr10PlusMetadata ?? false) &&
        preserveHdr10Plus &&
        mode != WorkMode.remux) {
      issues.add(
        RecipeIssue(
          S.t(
            "HDR10+ dynamic metadata cannot be injected by this build. Only “Remux” keeps it untouched; turn the option off or use Remux.",
            "这版写不了 HDR10+ 动态元数据。只有“只换容器”能原样保留；关掉这个选项，或者改用“只换容器”。",
          ),
          blocking: true,
        ),
      );
    }
    if ((media.video?.hasDolbyVisionMetadata ?? false) &&
        preserveDolbyVision &&
        mode != WorkMode.remux) {
      issues.add(
        RecipeIssue(
          S.t(
            "Dolby Vision is only preserved by stream copy. Re-encoding this build would drop it.",
            "杜比视界只有流复制能保留。这版重新编码会丢掉它。",
          ),
          blocking: true,
        ),
      );
    }
    if (mode == WorkMode.transcode &&
        (media.video?.isHdr ?? false) &&
        preserveHdr10 &&
        videoCodec != VideoCodec.h265 &&
        videoCodec != VideoCodec.av1) {
      issues.add(
        RecipeIssue(
          S.t(
            "HDR10 static metadata needs H.265 or AV1 in this build. Switch codec or turn the option off.",
            "这版只有 H.265 和 AV1 能处理 HDR10 静态信息。换编码，或者关掉这个选项。",
          ),
          blocking: true,
        ),
      );
    }
    if (mode == WorkMode.transcode &&
        preserveHdr10 &&
        (media.video?.isHdr ?? false) &&
        videoCodec == VideoCodec.av1) {
      issues.add(
        RecipeIssue(
          S.t(
            "AV1 writes HDR10 colour tags, but this build does not write Mastering Display / MaxCLL metadata.",
            "AV1 会写 HDR10 色彩标记，但这一版不写 Mastering Display / MaxCLL 元数据。",
          ),
          blocking: false,
        ),
      );
    }
    if (mode == WorkMode.transcode &&
        preserveHdr10 &&
        (media.video?.isHdr ?? false) &&
        videoCodec == VideoCodec.h265 &&
        !(media.video?.hasHdrMetadata ?? false)) {
      issues.add(
        RecipeIssue(
          S.t(
            "The source is HDR, but its Mastering Display / CLL side data could not be read. HDR10 metadata will not be written.",
            "源是 HDR，但读不到 Mastering Display / CLL 侧数据。不会写 HDR10 元数据。",
          ),
          blocking: false,
        ),
      );
    }
    if (targetWidth > 0 || targetHeight > 0) {
      if (targetWidth <= 0 || targetHeight <= 0) {
        issues.add(
          RecipeIssue(
            S.t(
              "Custom size needs both width and height.",
              "自定义分辨率需要同时填写宽度和高度。",
            ),
          ),
        );
      } else if (targetWidth < 16 ||
          targetHeight < 16 ||
          targetWidth > 7680 ||
          targetHeight > 7680) {
        issues.add(
          RecipeIssue(
            S.t(
              "Custom size must be between 16 and 7680 pixels on each side.",
              "自定义分辨率的宽高要在 16 到 7680 像素之间。",
            ),
          ),
        );
      } else if (targetWidth.isOdd || targetHeight.isOdd) {
        issues.add(
          RecipeIssue(
            S.t(
              "H.264 / H.265 need even dimensions. Round both sides to an even number.",
              "H.264 / H.265 需要偶数尺寸，把宽高都改成偶数。",
            ),
          ),
        );
      }
    }
    if (videoBitrateKbps < 1 || videoBitrateKbps > 100000) {
      issues.add(
        RecipeIssue(
          S.t(
            "Video bitrate must be between 1 and 100000 kbps.",
            "视频码率要在 1 到 100000 kbps 之间。",
          ),
        ),
      );
    } else if (videoBitrateKbps < 64) {
      issues.add(
        RecipeIssue(
          S.t(
            "Below 64 kbps is experimental: the encoder may drop detail or fail on some sources.",
            "低于 64 kbps 属于实验档：编码器可能大量丢细节，个别源会直接失败。",
          ),
          blocking: false,
        ),
      );
    }
    if (media.hasAudio && (audioBitrateKbps < 8 || audioBitrateKbps > 512)) {
      issues.add(
        RecipeIssue(
          S.t(
            "Audio bitrate must be between 8 and 512 kbps.",
            "音频码率要在 8 到 512 kbps 之间。",
          ),
        ),
      );
    }
    if (targetHeight > 0 &&
        media.video != null &&
        media.video!.height > 0 &&
        targetHeight > media.video!.height) {
      issues.add(
        RecipeIssue(
          S.t(
            "Upscaling above the source height is allowed, but it cannot add detail.",
            "可以放大到高于源分辨率，但不会增加细节。",
          ),
          blocking: false,
        ),
      );
    }
    if (videoCodec == VideoCodec.h264 && targetHeight > 2160) {
      issues.add(
        RecipeIssue(
          S.t(
            "H.264 above 4K is not a practical target on phones.",
            "手机上把 H.264 做到 4K 以上不实用。",
          ),
          blocking: false,
        ),
      );
    }
    if (hardwareAcceleration == HardwareAcceleration.mediaCodec &&
        (videoCodec == VideoCodec.h264 || videoCodec == VideoCodec.h265)) {
      final bool present = videoCodec == VideoCodec.h264
          ? HardwareProfile.current.avcEncode
          : HardwareProfile.current.hevcEncode;
      if (!present) {
        issues.add(
          RecipeIssue(
            S.t(
              "No usable MediaCodec encoder was found for this codec. The job will fall back to CPU; hardware mode is not a guarantee.",
              "没有找到该编码可用的 MediaCodec 编码器。任务会回退到 CPU；硬件模式不是保证。",
            ),
            blocking: false,
          ),
        );
      }
    }
    if (hardwareDecode && media.video != null) {
      final String codec = media.video!.codec;
      final bool present = codec == "av1"
          ? HardwareProfile.current.av1Decode
          : (codec == "hevc" || codec == "h265" || codec == "h264" || codec == "avc");
      if (!present) {
        issues.add(
          RecipeIssue(
            S.t(
              "Hardware decode is not available for this source. The job will use software decode.",
              "这个源没有可用的硬件解码。任务会使用软件解码。",
            ),
            blocking: false,
          ),
        );
      }
    }
    if (hardwareAcceleration == HardwareAcceleration.mediaCodec &&
        videoCodec == VideoCodec.av1) {
      issues.add(
        RecipeIssue(
          S.t(
            "AV1 has no MediaCodec encoder on the phones this build targets. The job stays on libaom software encoding; hardware mode only accelerates H.264 / H.265.",
            "这版覆盖的手机上没有可用的 AV1 MediaCodec 编码器。任务仍走 libaom 软件编码；硬件模式只加速 H.264 / H.265。",
          ),
          blocking: false,
        ),
      );
    }
    if (hardwareAcceleration == HardwareAcceleration.mediaCodec &&
        (videoCodec == VideoCodec.h264 || videoCodec == VideoCodec.h265) &&
        (pixelDepth.bits ?? media.video?.bitDepth ?? 8) > 8) {
      issues.add(
        RecipeIssue(
          S.t(
            "MediaCodec 10-bit output depends on the phone's encoder. If it refuses, switch to CPU or 8-bit.",
            "MediaCodec 的 10-bit 输出取决于手机编码器。如果被拒绝，切回 CPU 或 8-bit。",
          ),
          blocking: false,
        ),
      );
    }
    if (threadLimit == 1) {
      issues.add(
        RecipeIssue(
          S.t(
            "One thread keeps the phone responsive but can be extremely slow. It is useful only for a small file or a long background job.",
            "单线程能让手机保持响应，但会非常慢。只适合小文件或长时间后台任务。",
          ),
          blocking: false,
        ),
      );
    } else if (threadLimit >= 6) {
      issues.add(
        RecipeIssue(
          S.t(
            "Six to eight threads can starve the foreground app. The point of a background queue is to leave room for other work; use 1–4 unless you know the phone can spare it.",
            "6 到 8 线程会抢前台资源。后台队列本来就是为了留出余量，除非确定手机扛得住，建议 1–4。",
          ),
          blocking: false,
        ),
      );
    }
    if (videoCodec == VideoCodec.av1) {
      if (targetHeight > 1080) {
        issues.add(
          RecipeIssue(
            S.t(
              "AV1 software encoding is extremely slow on phones. 1080p or lower is the practical target; 4K may take hours.",
              "AV1 软件编码在手机上非常慢。1080p 及以下比较现实，4K 可能要跑几个小时。",
            ),
            blocking: false,
          ),
        );
      } else if (media.video != null &&
          media.video!.height > 1080 &&
          targetHeight == 0) {
        issues.add(
          RecipeIssue(
            S.t(
              "The source is above 1080p and AV1 will keep that height. Consider 1080p for a usable encode time.",
              "源高于 1080p，AV1 会按原高度编码。想要可接受的耗时，建议选 1080p。",
            ),
            blocking: false,
          ),
        );
      }
    }
    if (targetHeight == 1220) {
      issues.add(
        RecipeIssue(
          S.t(
            "1.5K is an experimental height for 2712×1220-class phone screens. It scales to the source aspect and does not add detail.",
            "1.5K 是给 2712×1220 这类手机屏的实验档，按源比例缩放，不会增加细节。",
          ),
          blocking: false,
        ),
      );
    }
    final int? requestedBits = pixelDepth.bits;
    final int sourceBits = media.video?.bitDepth ?? 8;
    if (requestedBits == null &&
        media.video?.hasKnownDepth == true &&
        sourceBits > 8 &&
        (videoCodec == VideoCodec.h264 || videoCodec == VideoCodec.mpeg4)) {
      issues.add(
        RecipeIssue(
          S.t(
            "This codec writes 8-bit; the $sourceBits-bit source will lose depth.",
            "这个编码只写 8-bit；$sourceBits-bit 源会掉位深。",
          ),
          blocking: false,
        ),
      );
    }
    if (requestedBits == null &&
        media.video?.hasKnownDepth == true &&
        sourceBits == 12) {
      issues.add(
        RecipeIssue(
          S.t(
            "The 12-bit source is kept, but phone playback support is uncommon.",
            "保留了 12-bit 源，但手机能正常播放的设备不多。",
          ),
          blocking: false,
        ),
      );
    }
    if (requestedBits != null) {
      if (videoCodec == VideoCodec.h264 || videoCodec == VideoCodec.mpeg4) {
        if (requestedBits > 8) {
          issues.add(
            RecipeIssue(
              S.t(
                "H.264 and MPEG-4 output 8-bit only.",
                "H.264 和 MPEG-4 只能输出 8-bit。",
              ),
            ),
          );
        }
      } else if (videoCodec == VideoCodec.vp9 && requestedBits > 10) {
        issues.add(
          RecipeIssue(
            S.t(
              "VP9 in this build supports 8-bit and 10-bit, not 12-bit.",
              "这版 VP9 只支持 8-bit 和 10-bit，不做 12-bit。",
            ),
          ),
        );
      } else if (requestedBits == 12 && videoCodec != VideoCodec.h265) {
        issues.add(
          RecipeIssue(
            S.t(
              "12-bit output is only available for H.265 in this build.",
              "这版只有 H.265 能输出 12-bit。",
            ),
          ),
        );
      }
      if (media.video?.hasKnownDepth == true && requestedBits > sourceBits) {
        issues.add(
          RecipeIssue(
            S.t(
              "The source is $sourceBits-bit. Higher output depth does not add real detail.",
              "源是 $sourceBits-bit，提高输出位深不会增加真实细节。",
            ),
            blocking: false,
          ),
        );
      }
      if (media.video?.hasKnownDepth == true && requestedBits < sourceBits) {
        issues.add(
          RecipeIssue(
            S.t(
              "The source is $sourceBits-bit. This target will reduce the depth.",
              "源是 $sourceBits-bit，这个目标会降低位深。",
            ),
            blocking: false,
          ),
        );
      }
    }
    if (videoCodec == VideoCodec.h265 && requestedBits == 12) {
      issues.add(
        RecipeIssue(
          S.t(
            "12-bit H.265 is experimental; playback support is uncommon.",
            "12-bit H.265 属于实验档，能正常播放的设备不多。",
          ),
          blocking: false,
        ),
      );
    }
    return issues;
  }

  bool _containerAcceptsVideo(TargetContainer container, String codec) {
    final String normalized = codec.toLowerCase();
    if (normalized == "libx264") {
      return container == TargetContainer.mp4 ||
          container == TargetContainer.mkv ||
          container == TargetContainer.mov;
    }
    if (normalized == "libx265") {
      return container == TargetContainer.mp4 ||
          container == TargetContainer.mkv ||
          container == TargetContainer.mov;
    }
    if (normalized == "libvpx-vp9") {
      return container == TargetContainer.mkv ||
          container == TargetContainer.webm;
    }
    if (normalized == "mpeg4") {
      return container == TargetContainer.mp4 ||
          container == TargetContainer.mkv ||
          container == TargetContainer.mov;
    }
    if (normalized == "h264") {
      return container == TargetContainer.mp4 ||
          container == TargetContainer.mkv ||
          container == TargetContainer.mov;
    }
    if (normalized == "hevc") {
      return container == TargetContainer.mp4 ||
          container == TargetContainer.mkv ||
          container == TargetContainer.mov;
    }
    if (normalized == "vp9" || normalized == "vp8") {
      return container == TargetContainer.mkv ||
          container == TargetContainer.webm;
    }
    if (normalized == "av1" || normalized == "libaom-av1") {
      return container == TargetContainer.mp4 ||
          container == TargetContainer.mkv ||
          container == TargetContainer.webm;
    }
    return container == TargetContainer.mkv;
  }

  bool _containerAcceptsAudio(TargetContainer container, String codec) {
    final String normalized = codec.toLowerCase();
    if (container == TargetContainer.mkv) return true;
    if (normalized == "aac" || normalized == "mp3") {
      return container == TargetContainer.mp4 ||
          container == TargetContainer.mov;
    }
    if (normalized == "libopus" ||
        normalized == "opus" ||
        normalized == "vorbis") {
      return container == TargetContainer.webm;
    }
    if (normalized == "ac3" || normalized == "eac3" || normalized == "alac") {
      return container == TargetContainer.mp4 ||
          container == TargetContainer.mov;
    }
    return false;
  }

  String get targetLine {
    if (mode == WorkMode.remux) {
      return "${container.label} · ${S.t("stream copy", "流复制")}";
    }
    final List<String> parts = <String>[
      container.label,
      videoCodec.shortLabel,
      "$videoBitrateKbps kbps",
      audioCodec == AudioCodec.copy
          ? S.t("audio copy", "音频复制")
          : audioCodec.label,
    ];
    if (pixelDepth != PixelDepth.auto) {
      parts.insert(3, pixelDepth.label);
    }
    if (frameRateMode == FrameRateMode.cfr && targetFps > 0) {
      parts.insert(3, "CFR $targetFps");
    }
    if (targetHeight > 0) parts.insert(2, "${targetHeight}p");
    return parts.join(" · ");
  }
}

enum JobStatus { probing, ready, running, completed, failed, canceled }

class VideoJob {
  final String path;
  final String name;
  MediaSummary? media;
  JobStatus status;
  double progress;
  String? error;
  String? outputPath;
  String? publishedName;
  String? publishedUri;
  DateTime? finishedAt;

  VideoJob({
    required this.path,
    required this.name,
    this.media,
    this.status = JobStatus.probing,
    this.progress = 0,
    this.error,
    this.outputPath,
    this.publishedName,
    this.publishedUri,
    this.finishedAt,
  });

  bool get isDone => status == JobStatus.completed;
  bool get isBusy => status == JobStatus.probing || status == JobStatus.running;
  bool get hasOutputFolder => publishedName != null;
}

String formatBytes(int bytes) {
  if (bytes <= 0) return "—";
  const List<String> units = <String>["B", "KB", "MB", "GB"];
  double value = bytes.toDouble();
  int unit = 0;
  while (value >= 1024 && unit < units.length - 1) {
    value /= 1024;
    unit++;
  }
  return "${value.toStringAsFixed(value >= 100 ? 0 : 1)} ${units[unit]}";
}

String outputNameFor(VideoJob job, ConversionRecipe recipe) {
  final String base = p.basenameWithoutExtension(job.path);
  final String suffix = switch (recipe.mode) {
    WorkMode.remux => "remux",
    WorkMode.transcode => recipe.videoCodec.name,
    WorkMode.compress => "${recipe.videoBitrateKbps}k",
    WorkMode.custom => "custom",
  };
  return "$base-$suffix.${recipe.container.extension}";
}
