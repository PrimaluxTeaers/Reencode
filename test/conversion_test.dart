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
}
