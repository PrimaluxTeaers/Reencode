import "models.dart";

/// Builds FFmpeg argument arrays. Keeping this pure makes the parameter rules
/// testable without loading the native engine.
class CommandBuilder {
  static List<String> build({
    required MediaSummary media,
    required ConversionRecipe recipe,
    required String outputPath,
    String? hardwareVideoEncoder,
  }) {
    final List<String> args = <String>["-y", "-i", media.path, "-map", "0:v:0"];
    if (media.hasAudio) {
      args.addAll(<String>["-map", "0:a?"]);
    } else {
      args.add("-an");
    }
    args.addAll(<String>["-map_metadata", "0", "-map_chapters", "0"]);

    if (recipe.mode == WorkMode.remux) {
      args.addAll(<String>["-c", "copy"]);
      if (recipe.container == TargetContainer.mp4 ||
          recipe.container == TargetContainer.mov) {
        args.addAll(<String>["-movflags", "+faststart"]);
      }
      args.add(outputPath);
      return args;
    }

    if (hardwareVideoEncoder != null) {
      args.addAll(_hardwareArgs(hardwareVideoEncoder, recipe));
    } else {
      args.addAll(<String>["-c:v", recipe.videoCodec.ffmpegName]);
      switch (recipe.videoCodec) {
        case VideoCodec.h264:
          args.addAll(<String>[
            "-preset",
            "medium",
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
          args.addAll(<String>[
            "-preset",
            "medium",
            "-b:v",
            "${recipe.videoBitrateKbps}k",
            "-maxrate",
            "${recipe.videoBitrateKbps * 3 ~/ 2}k",
            "-bufsize",
            "${recipe.videoBitrateKbps * 2}k",
            "-pix_fmt",
            media.video?.isTenBit == true ? "yuv420p10le" : "yuv420p",
            "-tag:v",
            "hvc1",
            "-x265-params",
            "log-level=error",
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
            media.video?.isTenBit == true ? "yuv420p10le" : "yuv420p",
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
    }

    if (recipe.targetHeight > 0) {
      args.addAll(<String>["-vf", "scale=-2:${recipe.targetHeight}"]);
    }
    if (recipe.targetFps > 0) {
      args.addAll(<String>["-r", "${recipe.targetFps}"]);
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

    if (recipe.container == TargetContainer.mp4 ||
        recipe.container == TargetContainer.mov) {
      args.addAll(<String>["-movflags", "+faststart"]);
    }
    args.add(outputPath);
    return args;
  }

  /// Hardware encoders take their own quality knobs. The bitrate ceilings stay
  /// identical so the size promise does not change between the CPU and GPU path.
  static List<String> _hardwareArgs(
    String encoder,
    ConversionRecipe recipe,
  ) {
    final List<String> args = <String>["-c:v", encoder];
    if (encoder.contains("nvenc")) {
      args.addAll(<String>["-preset", "p4", "-rc", "vbr"]);
    } else {
      args.addAll(<String>["-quality", "balanced", "-rc", "vbr_peak"]);
    }
    args.addAll(<String>[
      "-b:v",
      "${recipe.videoBitrateKbps}k",
      "-maxrate",
      "${recipe.videoBitrateKbps * 3 ~/ 2}k",
      "-bufsize",
      "${recipe.videoBitrateKbps * 2}k",
      "-pix_fmt",
      "yuv420p",
    ]);
    if (encoder.contains("hevc") || encoder.contains("265")) {
      args.addAll(<String>["-tag:v", "hvc1"]);
    }
    return args;
  }
}
