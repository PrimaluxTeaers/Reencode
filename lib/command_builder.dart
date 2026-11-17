import "dart:io";

import "hardware_profile.dart";
import "models.dart";

/// Builds FFmpeg argument arrays. Keeping this pure makes the parameter rules
/// testable without loading the native engine.
class CommandBuilder {
  static List<String> build({
    required MediaSummary media,
    required ConversionRecipe recipe,
    required String outputPath,
  }) {
    final bool useHardwareDecode =
        recipe.hardwareDecode && Platform.isAndroid && _decoderAvailable(media);
    final List<String> args = <String>["-y"];
    if (useHardwareDecode) {
      args.addAll(<String>["-hwaccel", "mediacodec"]);
    }
    args.addAll(<String>["-i", media.path, "-map", "0:v:0"]);
    if (media.hasAudio) {
      args.addAll(<String>["-map", "0:a?"]);
    } else {
      args.add("-an");
    }
    if (recipe.keepMetadata) {
      args.addAll(<String>["-map_metadata", "0"]);
    } else {
      args.addAll(<String>["-map_metadata", "-1"]);
    }
    if (recipe.keepChapters) {
      args.addAll(<String>["-map_chapters", "0"]);
    } else {
      args.addAll(<String>["-map_chapters", "-1"]);
    }

    if (recipe.mode == WorkMode.remux) {
      args.addAll(<String>["-c", "copy"]);
      if (recipe.memoryBudgetMb > 0) {
        final int queue = (recipe.memoryBudgetMb ~/ 4).clamp(64, 2048).toInt();
        args.addAll(<String>["-max_muxing_queue_size", "$queue"]);
      }
      if (recipe.fastStart &&
          (recipe.container == TargetContainer.mp4 ||
              recipe.container == TargetContainer.mov)) {
        args.addAll(<String>["-movflags", "+faststart"]);
      }
      args.add(outputPath);
      return args;
    }

    final HardwareProfile hardware = HardwareProfile.current;
    final bool hardwareEncoderPresent = recipe.videoCodec == VideoCodec.h264
        ? hardware.avcEncode
        : recipe.videoCodec == VideoCodec.h265
        ? hardware.hevcEncode
        : false;
    final bool useMediaCodec =
        recipe.hardwareAcceleration != HardwareAcceleration.software &&
        (recipe.videoCodec == VideoCodec.h264 ||
            recipe.videoCodec == VideoCodec.h265) &&
        hardwareEncoderPresent;
    final String? windowsEncoder =
        Platform.isWindows &&
            recipe.hardwareAcceleration != HardwareAcceleration.software
        ? hardware.hardwareEncoderFor(recipe.videoCodec.name)
        : null;
    final bool useGpuEncoder = windowsEncoder != null;
    final String encoderName = useMediaCodec
        ? (recipe.videoCodec == VideoCodec.h265
              ? "hevc_mediacodec"
              : "h264_mediacodec")
        : useGpuEncoder
        ? windowsEncoder
        : recipe.videoCodec.ffmpegName;
    args.addAll(<String>["-c:v", encoderName]);
    if (recipe.threadLimit > 0 && !useMediaCodec && !useGpuEncoder) {
      args.addAll(<String>["-threads", "${recipe.threadLimit}"]);
    }
    final int targetBits = _targetBits(recipe, media);
    if (useMediaCodec || useGpuEncoder) {
      args.addAll(<String>[
        "-b:v",
        "${recipe.videoBitrateKbps}k",
        "-maxrate",
        "${recipe.videoBitrateKbps * 3 ~/ 2}k",
        "-bufsize",
        "${recipe.videoBitrateKbps * 2}k",
        "-pix_fmt",
        _pixelFormat(targetBits),
      ]);
      if (useGpuEncoder) {
        args.addAll(<String>[
          if (windowsEncoder!.endsWith("_nvenc")) ...<String>["-preset", "p5"],
          if (windowsEncoder.endsWith("_amf")) ...<String>[
            "-quality",
            "balanced",
          ],
        ]);
      }
      if (recipe.videoCodec == VideoCodec.h265) {
        args.addAll(<String>["-tag:v", "hvc1"]);
      }
      if (recipe.targetWidth > 0 && recipe.targetHeight > 0) {
        args.addAll(<String>[
          "-vf",
          "scale=${recipe.targetWidth}:${recipe.targetHeight}",
        ]);
      } else if (recipe.targetHeight > 0) {
        args.addAll(<String>["-vf", "scale=-2:${recipe.targetHeight}"]);
      }
      if (recipe.frameRateMode == FrameRateMode.cfr) {
        args.addAll(<String>["-vsync", "cfr"]);
        if (recipe.targetFps > 0) {
          args.addAll(<String>["-r", "${recipe.targetFps}"]);
        }
      }
      if (media.hasAudio) {
        if (recipe.audioCodec == AudioCodec.copy) {
          args.addAll(<String>["-c:a", "copy"]);
        } else {
          args.addAll(<String>[
            "-c:a",
            recipe.audioCodec.ffmpegName,
            "-b:a",
            "${recipe.audioBitrateKbps}k",
          ]);
        }
      }
      if (recipe.fastStart &&
          (recipe.container == TargetContainer.mp4 ||
              recipe.container == TargetContainer.mov)) {
        args.addAll(<String>["-movflags", "+faststart"]);
      }
      args.add(outputPath);
      return args;
    }
    switch (recipe.videoCodec) {
      case VideoCodec.h264:
        args.addAll(<String>[
          "-preset",
          recipe.ffmpegPreset,
          "-b:v",
          "${recipe.videoBitrateKbps}k",
          "-maxrate",
          "${recipe.videoBitrateKbps * 3 ~/ 2}k",
          "-bufsize",
          "${recipe.videoBitrateKbps * 2}k",
          "-pix_fmt",
          "yuv420p",
        ]);
        break;
      case VideoCodec.h265:
        final List<String> x265 = <String>["log-level=error"];
        final StreamSummary? video = media.video;
        if (recipe.preserveHdr10 && (video?.isHdr ?? false)) {
          final String transfer = video?.colorTransfer == "arib-std-b67"
              ? "arib-std-b67"
              : "smpte2084";
          args.addAll(<String>[
            "-color_primaries",
            video?.colorPrimaries.isNotEmpty == true
                ? video!.colorPrimaries
                : "bt2020",
            "-color_trc",
            transfer,
            "-colorspace",
            video?.colorSpace.isNotEmpty == true
                ? video!.colorSpace
                : "bt2020nc",
          ]);
          if (video?.masteringDisplay.isNotEmpty == true) {
            x265.add("master-display=${video!.masteringDisplay}");
          }
          if ((video?.maxCll ?? 0) > 0 || (video?.maxFall ?? 0) > 0) {
            x265.add("max-cll=${video?.maxCll ?? 0},${video?.maxFall ?? 0}");
          }
        }
        args.addAll(<String>[
          "-preset",
          recipe.ffmpegPreset,
          "-b:v",
          "${recipe.videoBitrateKbps}k",
          "-maxrate",
          "${recipe.videoBitrateKbps * 3 ~/ 2}k",
          "-bufsize",
          "${recipe.videoBitrateKbps * 2}k",
          "-pix_fmt",
          _pixelFormat(targetBits),
          "-tag:v",
          "hvc1",
          "-x265-params",
          x265.join(":"),
        ]);
        break;
      case VideoCodec.vp9:
        args.addAll(<String>[
          "-b:v",
          "${recipe.videoBitrateKbps}k",
          "-maxrate",
          "${recipe.videoBitrateKbps * 3 ~/ 2}k",
          "-bufsize",
          "${recipe.videoBitrateKbps * 2}k",
          "-deadline",
          "good",
          "-cpu-used",
          "2",
          "-row-mt",
          "1",
          "-pix_fmt",
          _pixelFormat(targetBits),
        ]);
        break;
      case VideoCodec.av1:
        if (recipe.preserveHdr10 && (media.video?.isHdr ?? false)) {
          final StreamSummary video = media.video!;
          args.addAll(<String>[
            "-color_primaries",
            video.colorPrimaries.isNotEmpty ? video.colorPrimaries : "bt2020",
            "-color_trc",
            video.colorTransfer == "arib-std-b67"
                ? "arib-std-b67"
                : "smpte2084",
            "-colorspace",
            video.colorSpace.isNotEmpty ? video.colorSpace : "bt2020nc",
          ]);
        }
        args.addAll(<String>[
          "-b:v",
          "${recipe.videoBitrateKbps}k",
          "-maxrate",
          "${recipe.videoBitrateKbps * 3 ~/ 2}k",
          "-bufsize",
          "${recipe.videoBitrateKbps * 2}k",
          "-cpu-used",
          _av1CpuUsed(recipe),
          "-row-mt",
          "1",
          "-tile-columns",
          "2",
          "-lag-in-frames",
          "0",
          "-g",
          "240",
          "-pix_fmt",
          _pixelFormat(targetBits),
        ]);
        break;
      case VideoCodec.mpeg4:
        args.addAll(<String>[
          "-b:v",
          "${recipe.videoBitrateKbps}k",
          "-pix_fmt",
          "yuv420p",
        ]);
        break;
    }

    if (recipe.targetWidth > 0 && recipe.targetHeight > 0) {
      args.addAll(<String>[
        "-vf",
        "scale=${recipe.targetWidth}:${recipe.targetHeight}",
      ]);
    } else if (recipe.targetHeight > 0) {
      args.addAll(<String>["-vf", "scale=-2:${recipe.targetHeight}"]);
    }
    if (recipe.frameRateMode == FrameRateMode.cfr) {
      args.addAll(<String>["-vsync", "cfr"]);
      if (recipe.targetFps > 0) {
        args.addAll(<String>["-r", "${recipe.targetFps}"]);
      }
    }

    if (media.hasAudio) {
      if (recipe.audioCodec == AudioCodec.copy) {
        args.addAll(<String>["-c:a", "copy"]);
      } else {
        args.addAll(<String>[
          "-c:a",
          recipe.audioCodec.ffmpegName,
          "-b:a",
          "${recipe.audioBitrateKbps}k",
        ]);
      }
    }

    if (recipe.memoryBudgetMb > 0) {
      final int queue = (recipe.memoryBudgetMb ~/ 4).clamp(64, 2048).toInt();
      args.addAll(<String>["-max_muxing_queue_size", "$queue"]);
    }
    if (recipe.fastStart &&
        (recipe.container == TargetContainer.mp4 ||
            recipe.container == TargetContainer.mov)) {
      args.addAll(<String>["-movflags", "+faststart"]);
    }
    args.add(outputPath);
    return args;
  }

  static bool _decoderAvailable(MediaSummary media) {
    final String codec = media.video?.codec ?? "";
    if (codec == "av1") return HardwareProfile.current.av1Decode;
    if (codec == "hevc" || codec == "h265") return true;
    if (codec == "h264" || codec == "avc") return true;
    return false;
  }

  static String _av1CpuUsed(ConversionRecipe recipe) {
    if (recipe.encoderPreset == EncoderPreset.custom) {
      final int? value = int.tryParse(recipe.customPreset.trim());
      if (value != null && value >= 0 && value <= 8) return value.toString();
      return "6";
    }
    return switch (recipe.encoderPreset) {
      EncoderPreset.fast => "8",
      EncoderPreset.balanced => "6",
      EncoderPreset.slow => "4",
      EncoderPreset.custom => "6",
    };
  }

  static int _targetBits(ConversionRecipe recipe, MediaSummary media) {
    final int? requested = recipe.pixelDepth.bits;
    if (requested != null) return requested;
    return media.video?.bitDepth ?? 8;
  }

  static String _pixelFormat(int bits) {
    return switch (bits) {
      12 => "yuv420p12le",
      10 => "yuv420p10le",
      _ => "yuv420p",
    };
  }
}
