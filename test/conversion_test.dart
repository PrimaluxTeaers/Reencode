import "package:flutter_test/flutter_test.dart";
import "package:reencode/command_builder.dart";
import "package:reencode/models.dart";

MediaSummary sample({
  String videoCodec = "h264",
  String audioCodec = "aac",
  int height = 1080,
}) {
  return MediaSummary(
    path: "/tmp/clip one.mp4",
    name: "clip one.mp4",
    format: "mov,mp4,m4a,3gp,3g2,mj2",
    durationSeconds: 10,
    sizeBytes: 12 * 1024 * 1024,
    bitrateKbps: 10000,
    video: StreamSummary(
      codec: videoCodec,
      width: height * 16 ~/ 9,
      height: height,
      pixelFormat: "yuv420p",
      fps: 30,
      bitrateKbps: 9000,
    ),
    audio: StreamSummary(
      codec: audioCodec,
      bitrateKbps: 128,
      channels: 2,
      sampleRate: 48000,
      channelLayout: "stereo",
    ),
  );
}

void main() {
  test("remux copies the first video and all audio streams", () {
    final List<String> args = CommandBuilder.build(
      media: sample(),
      recipe: const ConversionRecipe(
        mode: WorkMode.remux,
        container: TargetContainer.mkv,
      ),
      outputPath: "/tmp/out.mkv",
    );
    expect(args, containsAllInOrder(<String>["-i", "/tmp/clip one.mp4"]));
    expect(args, containsAllInOrder(<String>["-map", "0:v:0"]));
    expect(args, containsAllInOrder(<String>["-map", "0:a?"]));
    expect(args, contains("copy"));
    expect(args.last, "/tmp/out.mkv");
  });

  test("H.264 recipe contains bitrate, scale and audio settings", () {
    final List<String> args = CommandBuilder.build(
      media: sample(),
      recipe: const ConversionRecipe(
        mode: WorkMode.compress,
        container: TargetContainer.mp4,
        videoCodec: VideoCodec.h264,
        videoBitrateKbps: 2500,
        audioBitrateKbps: 128,
        targetHeight: 720,
      ),
      outputPath: "/tmp/out.mp4",
    );
    expect(args, containsAllInOrder(<String>["-c:v", "libx264"]));
    expect(args, containsAllInOrder(<String>["-b:v", "2500k"]));
    expect(args, containsAllInOrder(<String>["-vf", "scale=-2:720"]));
    expect(args, containsAllInOrder(<String>["-c:a", "aac"]));
    expect(args, containsAllInOrder(<String>["-movflags", "+faststart"]));
  });

  test("WebM rejects H.264 in preflight", () {
    final MediaSummary media = sample();
    final List<RecipeIssue> issues = const ConversionRecipe(
      mode: WorkMode.transcode,
      container: TargetContainer.webm,
      videoCodec: VideoCodec.h264,
      audioCodec: AudioCodec.opus,
    ).validate(media);
    expect(issues.any((RecipeIssue issue) => issue.blocking), isTrue);
  });

  test("MP4 accepts H.265 and AAC", () {
    final MediaSummary media = sample();
    final List<RecipeIssue> issues = const ConversionRecipe(
      mode: WorkMode.transcode,
      container: TargetContainer.mp4,
      videoCodec: VideoCodec.h265,
      audioCodec: AudioCodec.aac,
    ).validate(media);
    expect(issues.where((RecipeIssue issue) => issue.blocking), isEmpty);
  });

  test("audio copy is checked against the source codec", () {
    final MediaSummary media = sample(audioCodec: "opus");
    final List<RecipeIssue> issues = const ConversionRecipe(
      mode: WorkMode.transcode,
      container: TargetContainer.mp4,
      videoCodec: VideoCodec.h264,
      audioCodec: AudioCodec.copy,
    ).validate(media);
    expect(issues.any((RecipeIssue issue) => issue.blocking), isTrue);
  });

  test("low kbps compression is allowed with a non-blocking warning", () {
    final MediaSummary media = sample();
    final List<RecipeIssue> issues = const ConversionRecipe(
      mode: WorkMode.compress,
      videoBitrateKbps: 16,
      audioBitrateKbps: 32,
    ).validate(media);
    expect(issues.where((RecipeIssue issue) => issue.blocking), isEmpty);
    expect(issues.any((RecipeIssue issue) => !issue.blocking), isTrue);
  });

  test("H.265 keeps 10-bit and offers 12-bit with yuv420p12le", () {
    final MediaSummary media = sample(videoCodec: "hevc");
    final StreamSummary tenBit = StreamSummary(
      codec: "hevc",
      width: 1920,
      height: 1080,
      pixelFormat: "yuv420p10le",
      fps: 30,
      bitrateKbps: 9000,
    );
    final MediaSummary tenBitMedia = MediaSummary(
      path: media.path,
      name: media.name,
      format: media.format,
      durationSeconds: media.durationSeconds,
      sizeBytes: media.sizeBytes,
      bitrateKbps: media.bitrateKbps,
      video: tenBit,
      audio: media.audio,
    );
    final List<String> automatic = CommandBuilder.build(
      media: tenBitMedia,
      recipe: const ConversionRecipe(
        videoCodec: VideoCodec.h265,
        videoBitrateKbps: 8000,
      ),
      outputPath: "/tmp/out.mp4",
    );
    expect(automatic, containsAllInOrder(<String>["-pix_fmt", "yuv420p10le"]));

    final List<String> twelve = CommandBuilder.build(
      media: tenBitMedia,
      recipe: const ConversionRecipe(
        videoCodec: VideoCodec.h265,
        videoBitrateKbps: 8000,
        pixelDepth: PixelDepth.twelve,
      ),
      outputPath: "/tmp/out.mp4",
    );
    expect(twelve, containsAllInOrder(<String>["-pix_fmt", "yuv420p12le"]));
  });

  test("CFR mode writes vsync cfr and the target rate", () {
    final List<String> args = CommandBuilder.build(
      media: sample(),
      recipe: const ConversionRecipe(
        videoCodec: VideoCodec.h265,
        frameRateMode: FrameRateMode.cfr,
        targetFps: 144,
      ),
      outputPath: "/tmp/out.mp4",
    );
    expect(args, containsAllInOrder(<String>["-vsync", "cfr"]));
    expect(args, containsAllInOrder(<String>["-r", "144"]));
  });

  test("100 Mbps bitrate is valid and reaches the command", () {
    final MediaSummary media = sample();
    final List<RecipeIssue> issues = const ConversionRecipe(
      videoCodec: VideoCodec.h265,
      videoBitrateKbps: 100000,
    ).validate(media);
    expect(issues.where((RecipeIssue issue) => issue.blocking), isEmpty);
    final List<String> args = CommandBuilder.build(
      media: media,
      recipe: const ConversionRecipe(
        videoCodec: VideoCodec.h265,
        videoBitrateKbps: 100000,
      ),
      outputPath: "/tmp/out.mp4",
    );
    expect(args, containsAllInOrder(<String>["-b:v", "100000k"]));
  });

  test("2K and 1.5K tiers scale by height without changing aspect", () {
    final List<String> twoK = CommandBuilder.build(
      media: sample(),
      recipe: const ConversionRecipe(
        videoCodec: VideoCodec.h265,
        targetHeight: 1440,
      ),
      outputPath: "/tmp/out.mp4",
    );
    expect(twoK, containsAllInOrder(<String>["-vf", "scale=-2:1440"]));
    final List<String> onePointFiveK = CommandBuilder.build(
      media: sample(),
      recipe: const ConversionRecipe(
        videoCodec: VideoCodec.h265,
        targetHeight: 1220,
      ),
      outputPath: "/tmp/out.mp4",
    );
    expect(onePointFiveK, containsAllInOrder(<String>["-vf", "scale=-2:1220"]));
  });

  test("output name keeps the source stem and target extension", () {
    final VideoJob job = VideoJob(
      path: "/tmp/clip one.mkv",
      name: "clip one.mkv",
    );
    expect(
      outputNameFor(
        job,
        const ConversionRecipe(
          mode: WorkMode.remux,
          container: TargetContainer.mp4,
        ),
      ),
      "clip one-remux.mp4",
    );
  });

  test("estimate uses bitrate and duration", () {
    final MediaSummary media = sample();
    final int estimate = const ConversionRecipe(
      mode: WorkMode.compress,
      videoBitrateKbps: 2000,
      audioBitrateKbps: 128,
    ).estimatedBytesFor(media);
    expect(estimate, greaterThan(2 * 1000 * 1000));
    expect(estimate, lessThan(4 * 1000 * 1000));
  });

  test("H.265 writes HDR10 color tags, mastering display and CLL", () {
    final MediaSummary media = sample(videoCodec: "hevc");
    final MediaSummary hdr = MediaSummary(
      path: media.path,
      name: media.name,
      format: media.format,
      durationSeconds: media.durationSeconds,
      sizeBytes: media.sizeBytes,
      bitrateKbps: media.bitrateKbps,
      video: const StreamSummary(
        codec: "hevc",
        width: 3840,
        height: 2160,
        pixelFormat: "yuv420p10le",
        fps: 60,
        bitrateKbps: 40000,
        colorPrimaries: "bt2020",
        colorTransfer: "smpte2084",
        colorSpace: "bt2020nc",
        masteringDisplay: "G(13250,34500)B(7500,3000)R(34000,16000)WP(15635,16450)L(10000000,1)",
        maxCll: 1000,
        maxFall: 400,
      ),
      audio: media.audio,
    );
    final List<String> args = CommandBuilder.build(
      media: hdr,
      recipe: const ConversionRecipe(
        videoCodec: VideoCodec.h265,
        videoBitrateKbps: 30000,
      ),
      outputPath: "/tmp/hdr.mp4",
    );
    expect(args, containsAllInOrder(<String>["-color_primaries", "bt2020"]));
    expect(args, containsAllInOrder(<String>["-color_trc", "smpte2084"]));
    expect(args, containsAllInOrder(<String>["-colorspace", "bt2020nc"]));
    expect(args.join(" "), contains("master-display="));
    expect(args.join(" "), contains("max-cll=1000,400"));
  });

  test("HDR10+ and Dolby Vision block re-encoding", () {
    final MediaSummary media = sample(videoCodec: "hevc");
    final MediaSummary hdr = MediaSummary(
      path: media.path,
      name: media.name,
      format: media.format,
      durationSeconds: media.durationSeconds,
      sizeBytes: media.sizeBytes,
      bitrateKbps: media.bitrateKbps,
      video: const StreamSummary(
        codec: "hevc",
        width: 3840,
        height: 2160,
        pixelFormat: "yuv420p10le",
        fps: 60,
        bitrateKbps: 40000,
        colorPrimaries: "bt2020",
        colorTransfer: "smpte2084",
        colorSpace: "bt2020nc",
        hasHdr10Plus: true,
        hasDolbyVision: true,
      ),
      audio: media.audio,
    );
    final List<RecipeIssue> issues = const ConversionRecipe(
      videoCodec: VideoCodec.h265,
      videoBitrateKbps: 30000,
    ).validate(hdr);
    expect(
      issues.where((RecipeIssue issue) => issue.blocking).length,
      greaterThanOrEqualTo(2),
    );
  });

  test("AV1 uses libaom and exposes software presets", () {
    final List<String> args = CommandBuilder.build(
      media: sample(),
      recipe: const ConversionRecipe(
        container: TargetContainer.mp4,
        videoCodec: VideoCodec.av1,
        videoBitrateKbps: 2500,
        encoderPreset: EncoderPreset.fast,
      ),
      outputPath: "/tmp/out.mp4",
    );
    expect(args, containsAllInOrder(<String>["-c:v", "libaom-av1"]));
    expect(args, containsAllInOrder(<String>["-b:v", "2500k"]));
    expect(args, containsAllInOrder(<String>["-cpu-used", "8"]));
    expect(args, containsAllInOrder(<String>["-row-mt", "1"]));
    expect(args, containsAllInOrder(<String>["-pix_fmt", "yuv420p"]));
  });

  test("AV1 is valid in MP4, MKV and WebM", () {
    final MediaSummary media = sample();
    for (final TargetContainer container in <TargetContainer>[
      TargetContainer.mp4,
      TargetContainer.mkv,
      TargetContainer.webm,
    ]) {
      final List<RecipeIssue> issues = ConversionRecipe(
        container: container,
        videoCodec: VideoCodec.av1,
        audioCodec: container == TargetContainer.webm
            ? AudioCodec.opus
            : AudioCodec.aac,
      ).validate(media);
      expect(
        issues.where((RecipeIssue issue) => issue.blocking),
        isEmpty,
        reason: container.label,
      );
    }
  });

  test("AV1 blocks 12-bit and warns about slow 4K", () {
    final MediaSummary media = sample(height: 2160);
    final List<RecipeIssue> twelveBit = const ConversionRecipe(
      videoCodec: VideoCodec.av1,
      pixelDepth: PixelDepth.twelve,
    ).validate(media);
    expect(twelveBit.any((RecipeIssue issue) => issue.blocking), isTrue);
    final List<RecipeIssue> slow = const ConversionRecipe(
      videoCodec: VideoCodec.av1,
    ).validate(media);
    expect(slow.any((RecipeIssue issue) => !issue.blocking), isTrue);
  });

  test("custom size writes exact even dimensions", () {
    final List<String> args = CommandBuilder.build(
      media: sample(),
      recipe: const ConversionRecipe(
        targetWidth: 1280,
        targetHeight: 720,
      ),
      outputPath: "/tmp/out.mp4",
    );
    expect(args, containsAllInOrder(<String>["-vf", "scale=1280:720"]));
  });

  test("custom size rejects odd or one-sided dimensions", () {
    final MediaSummary media = sample();
    final List<RecipeIssue> odd = const ConversionRecipe(
      targetWidth: 1279,
      targetHeight: 720,
    ).validate(media);
    expect(odd.any((RecipeIssue issue) => issue.blocking), isTrue);
    final List<RecipeIssue> oneSide = const ConversionRecipe(
      targetWidth: 1280,
    ).validate(media);
    expect(oneSide.any((RecipeIssue issue) => issue.blocking), isTrue);
  });

  test("hardware request falls back to CPU when the platform has no encoder", () {
    final List<String> args = CommandBuilder.build(
      media: sample(),
      recipe: const ConversionRecipe(
        videoCodec: VideoCodec.h264,
        hardwareAcceleration: HardwareAcceleration.mediaCodec,
      ),
      outputPath: "/tmp/out.mp4",
    );
    expect(args, containsAllInOrder(<String>["-c:v", "libx264"]));
  });

  test("memory budget adds a bounded muxing queue", () {
    final List<String> args = CommandBuilder.build(
      media: sample(),
      recipe: const ConversionRecipe(memoryBudgetMb: 512),
      outputPath: "/tmp/out.mp4",
    );
    expect(args, containsAllInOrder(<String>["-max_muxing_queue_size", "128"]));
  });
}
