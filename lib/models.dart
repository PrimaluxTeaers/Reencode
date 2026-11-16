import "dart:math" as math;

import "package:ffmpeg_kit_flutter_new/media_information.dart";
import "package:ffmpeg_kit_flutter_new/stream_information.dart";
import "package:material_ui/material_ui.dart";
import "package:path/path.dart" as p;

import "l10n.dart";

enum WorkMode { remux, transcode, compress }

extension WorkModeInfo on WorkMode {
  String get label => switch (this) {
    WorkMode.remux => S.t("Remux", "只换容器"),
    WorkMode.transcode => S.t("Re-encode", "换编码"),
    WorkMode.compress => S.t("Compress", "压码率"),
  };

  String get hint => switch (this) {
    WorkMode.remux => S.t(
      "Copy streams, change the wrapper. No quality loss.",
      "复制音视频流，只换封装。画质不变。",
    ),
    WorkMode.transcode => S.t(
      "Change codec and container. Re-encodes video.",
      "换视频编码和容器，视频会重新编码。",
    ),
    WorkMode.compress => S.t(
      "Lower a chosen bitrate, optionally resize.",
      "按目标码率重编码，可顺带降分辨率。",
    ),
  };

  IconData get icon => switch (this) {
    WorkMode.remux => Icons.swap_horiz_rounded,
    WorkMode.transcode => Icons.tune_rounded,
    WorkMode.compress => Icons.compress_rounded,
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

enum VideoCodec { h264, h265, vp9, mpeg4 }

extension VideoCodecInfo on VideoCodec {
  String get label => switch (this) {
    VideoCodec.h264 => "H.264",
    VideoCodec.h265 => "H.265 / HEVC",
    VideoCodec.vp9 => "VP9",
    VideoCodec.mpeg4 => "MPEG-4",
  };

  String get shortLabel => switch (this) {
    VideoCodec.h264 => "H.264",
    VideoCodec.h265 => "H.265",
    VideoCodec.vp9 => "VP9",
    VideoCodec.mpeg4 => "MPEG-4",
  };

  String get ffmpegName => switch (this) {
    VideoCodec.h264 => "libx264",
    VideoCodec.h265 => "libx265",
    VideoCodec.vp9 => "libvpx-vp9",
    VideoCodec.mpeg4 => "mpeg4",
  };

  String get note => switch (this) {
    VideoCodec.h264 => S.t("Widest device support", "设备兼容最广"),
    VideoCodec.h265 => S.t("Smaller files, slower encode", "同画质更小，编码更慢"),
    VideoCodec.vp9 => S.t("Open codec for WebM", "WebM 常用的开放编码"),
    VideoCodec.mpeg4 => S.t("Legacy compatibility", "老设备兼容"),
  };
}

enum AudioCodec { aac, opus, mp3, copy }

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
  });

  bool get isTenBit =>
      pixelFormat.contains("10le") ||
      pixelFormat.contains("10be") ||
      pixelFormat.contains("12le") ||
      pixelFormat.contains("12be");

  String get resolution => width > 0 && height > 0 ? "${width}×$height" : "—";

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
        : StreamSummary(
            codec: (videoStream.getCodec() ?? "").toLowerCase(),
            width: videoStream.getWidth() ?? 0,
            height: videoStream.getHeight() ?? 0,
            pixelFormat: (videoStream.getFormat() ?? "").toLowerCase(),
            fps: _parseRate(
              videoStream.getAverageFrameRate() ??
                  videoStream.getRealFrameRate(),
            ),
            bitrateKbps: (_toInt(videoStream.getBitrate()) ?? 0) ~/ 1000,
            rotation: _rotationOf(videoStream),
          );
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
  final int targetHeight;
  final int targetFps;

  const ConversionRecipe({
    this.mode = WorkMode.transcode,
    this.container = TargetContainer.mp4,
    this.videoCodec = VideoCodec.h264,
    this.audioCodec = AudioCodec.aac,
    this.videoBitrateKbps = 2000,
    this.audioBitrateKbps = 128,
    this.targetHeight = 0,
    this.targetFps = 0,
  });

  ConversionRecipe copyWith({
    WorkMode? mode,
    TargetContainer? container,
    VideoCodec? videoCodec,
    AudioCodec? audioCodec,
    int? videoBitrateKbps,
    int? audioBitrateKbps,
    int? targetHeight,
    int? targetFps,
  }) {
    return ConversionRecipe(
      mode: mode ?? this.mode,
      container: container ?? this.container,
      videoCodec: videoCodec ?? this.videoCodec,
      audioCodec: audioCodec ?? this.audioCodec,
      videoBitrateKbps: videoBitrateKbps ?? this.videoBitrateKbps,
      audioBitrateKbps: audioBitrateKbps ?? this.audioBitrateKbps,
      targetHeight: targetHeight ?? this.targetHeight,
      targetFps: targetFps ?? this.targetFps,
    );
  }

  factory ConversionRecipe.defaultsFor(MediaSummary media) {
    final StreamSummary? video = media.video;
    final StreamSummary? audio = media.audio;
    final String sourceCodec = video?.codec ?? "";
    final TargetContainer container =
        sourceCodec == "h264" || sourceCodec == "hevc" || sourceCodec == "mpeg4"
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
      targetHeight: 0,
      targetFps: 0,
    );
  }

  ConversionRecipe forMode(WorkMode mode, MediaSummary media) {
    if (mode == WorkMode.remux) {
      final String codec = media.video?.codec ?? "";
      final TargetContainer container =
          codec == "h264" || codec == "hevc" || codec == "mpeg4"
          ? TargetContainer.mp4
          : TargetContainer.mkv;
      return copyWith(
        mode: mode,
        container: container,
        audioCodec: AudioCodec.copy,
        targetHeight: 0,
        targetFps: 0,
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
      );
    }
    return copyWith(
      mode: mode,
      container: container,
      audioCodec: AudioCodec.aac,
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
    if (videoBitrateKbps < 64 || videoBitrateKbps > 100000) {
      issues.add(
        RecipeIssue(
          S.t(
            "Video bitrate must be between 64 and 100000 kbps.",
            "视频码率要在 64 到 100000 kbps 之间。",
          ),
        ),
      );
    }
    if (media.hasAudio && (audioBitrateKbps < 24 || audioBitrateKbps > 512)) {
      issues.add(
        RecipeIssue(
          S.t(
            "Audio bitrate must be between 24 and 512 kbps.",
            "音频码率要在 24 到 512 kbps 之间。",
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
    return issues;
  }

  bool _containerAcceptsVideo(TargetContainer container, String codec) {
    final String normalized = codec.toLowerCase();
    if (normalized == "libx264")
      return container == TargetContainer.mp4 ||
          container == TargetContainer.mkv ||
          container == TargetContainer.mov;
    if (normalized == "libx265")
      return container == TargetContainer.mp4 ||
          container == TargetContainer.mkv ||
          container == TargetContainer.mov;
    if (normalized == "libvpx-vp9")
      return container == TargetContainer.mkv ||
          container == TargetContainer.webm;
    if (normalized == "mpeg4")
      return container == TargetContainer.mp4 ||
          container == TargetContainer.mkv ||
          container == TargetContainer.mov;
    if (normalized == "h264")
      return container == TargetContainer.mp4 ||
          container == TargetContainer.mkv ||
          container == TargetContainer.mov;
    if (normalized == "hevc")
      return container == TargetContainer.mp4 ||
          container == TargetContainer.mkv ||
          container == TargetContainer.mov;
    if (normalized == "vp9" || normalized == "vp8")
      return container == TargetContainer.mkv ||
          container == TargetContainer.webm;
    if (normalized == "av1")
      return container == TargetContainer.mp4 ||
          container == TargetContainer.mkv ||
          container == TargetContainer.webm;
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
  bool removeWhenDone;

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
    this.removeWhenDone = false,
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
  };
  return "$base-$suffix.${recipe.container.extension}";
}
