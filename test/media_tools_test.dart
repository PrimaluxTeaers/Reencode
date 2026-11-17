import "package:flutter_test/flutter_test.dart";
import "package:reencode/media_tools.dart";
import "package:reencode/models.dart";

MediaSummary _summary({
  String videoCodec = "h264",
  String audioCodec = "aac",
  bool hasVideo = true,
}) {
  return MediaSummary(
    path: "/tmp/input.mp4",
    name: "input.mp4",
    format: "mp4",
    durationSeconds: 10,
    sizeBytes: 1000,
    bitrateKbps: 1000,
    video: hasVideo
        ? StreamSummary(
            codec: videoCodec,
            width: 1920,
            height: 1080,
            pixelFormat: "yuv420p",
            fps: 30,
            bitrateKbps: 900,
          )
        : null,
    audio: StreamSummary(codec: audioCodec, bitrateKbps: 128),
  );
}

void main() {
  test("split copies video and audio separately", () {
    final List<String> video = splitVideoArgs("/tmp/in.mp4", "/tmp/v.mp4");
    expect(video, containsAllInOrder(<String>["-map", "0:v:0"]));
    expect(video, containsAllInOrder(<String>["-c:v", "copy"]));
    expect(video, contains("-an"));

    final List<String> audio = splitAudioArgs("/tmp/in.mp4", "/tmp/a.m4a");
    expect(audio, containsAllInOrder(<String>["-map", "0:a:0"]));
    expect(audio, containsAllInOrder(<String>["-c:a", "copy"]));
    expect(audio, contains("-vn"));
  });

  test("merge keeps the video stream and can re-encode audio", () {
    final List<String> copy = mergeArgs(
      "/tmp/v.mp4",
      "/tmp/a.m4a",
      "/tmp/out.mp4",
      copyAudio: true,
      target: AudioTarget.aac,
      audioBitrate: 192,
    );
    expect(copy, containsAllInOrder(<String>["-map", "0:v:0"]));
    expect(copy, containsAllInOrder(<String>["-map", "1:a:0"]));
    expect(copy, containsAllInOrder(<String>["-c:v", "copy"]));
    expect(copy, containsAllInOrder(<String>["-c:a", "copy"]));
    expect(copy, contains("-shortest"));

    final List<String> encode = mergeArgs(
      "/tmp/v.mp4",
      "/tmp/a.wav",
      "/tmp/out.mp4",
      copyAudio: false,
      target: AudioTarget.aac,
      audioBitrate: 192,
    );
    expect(encode, containsAllInOrder(<String>["-c:a", "aac"]));
    expect(encode, containsAllInOrder(<String>["-b:a", "192k"]));
  });

  test("split can re-encode video and audio before writing", () {
    final List<String> video = splitVideoArgs(
      "/tmp/in.mp4",
      "/tmp/v.mp4",
      target: SplitVideoTarget.h264Mp4,
    );
    expect(video, containsAllInOrder(<String>["-c:v", "libx264"]));
    expect(video, containsAllInOrder(<String>["-crf", "20"]));

    final List<String> audio = splitAudioArgs(
      "/tmp/in.mp4",
      "/tmp/a.mp3",
      copy: false,
      target: AudioTarget.mp3,
      bitrateKbps: 192,
    );
    expect(audio, containsAllInOrder(<String>["-c:a", "libmp3lame"]));
    expect(audio, containsAllInOrder(<String>["-b:a", "192k"]));
  });

  test("merge can set volume for re-encoded audio", () {
    final List<String> merged = mergeArgs(
      "/tmp/v.mp4",
      "/tmp/a.wav",
      "/tmp/out.mp4",
      copyAudio: false,
      target: AudioTarget.aac,
      audioBitrate: 192,
      volume: 1.5,
    );
    expect(merged, containsAllInOrder(<String>["-af", "volume=1.50"]));
  });

  test("audio-only writes the chosen codec", () {
    final List<String> mp3 = audioOnlyArgs(
      "/tmp/in.mp4",
      "/tmp/out.mp3",
      target: AudioTarget.mp3,
      bitrateKbps: 192,
    );
    expect(mp3, containsAllInOrder(<String>["-c:a", "libmp3lame"]));
    expect(mp3, containsAllInOrder(<String>["-b:a", "192k"]));
    expect(mp3, contains("-vn"));

    final List<String> flac = audioOnlyArgs(
      "/tmp/in.mp4",
      "/tmp/out.flac",
      target: AudioTarget.flac,
      bitrateKbps: 192,
    );
    expect(flac, containsAllInOrder(<String>["-c:a", "flac"]));
    expect(flac, isNot(contains("-b:a")));
  });

  test("merge container follows codec compatibility", () {
    expect(mergeContainer(_summary(), _summary(), false), "mp4");
    expect(
      mergeContainer(
        _summary(videoCodec: "vp9", audioCodec: "opus"),
        _summary(videoCodec: "vp9", audioCodec: "opus"),
        false,
      ),
      "webm",
    );
    expect(
      mergeContainer(
        _summary(videoCodec: "vp9", audioCodec: "aac"),
        _summary(videoCodec: "vp9", audioCodec: "aac"),
        false,
      ),
      "mkv",
    );
  });
}
