# Reencode

An Android video converter that runs offline, with no ads and no analytics. Three entries: change the container, change the codec, change the bitrate.

The home screen lists all four video codecs: H.264, H.265 / HEVC, VP9 and MPEG-4. MPEG-4 is not a hidden option. Transcoding is done by FFmpeg 8.1.2. Remuxing copies streams; re-encoding and bitrate compression re-encode the video.

[中文说明](README.md)

## What it does

- Containers: MP4, MKV, MOV, WebM.
- Video codecs: H.264, H.265 / HEVC, VP9, MPEG-4.
- Audio codecs: AAC, Opus, MP3, stream copy.
- Video bitrate from 1 to 100000 kbps, up to the equivalent of 100 Mbps. Type an exact value, drag the slider for a rough value, and tap the unit to switch between kbps and Mbps. Below 64 kbps is marked as the experimental low-bitrate range.
- Resolution: source, 4K (2160p), 2K (1440p), 1.5K (1220p, experimental), 1080p, 720p, 480p. This only changes output dimensions; it does not restore detail the source never had.
- Bit depth: preserve, 8-bit, 10-bit, 12-bit. H.265 and VP9 can keep 10-bit; H.265 adds a 12-bit experimental option; H.264 and MPEG-4 are fixed at 8-bit. Depths the source does not contain are disabled.
- Frame rate: passthrough or constant frame rate (CFR). 24–60 is continuous. 90 and 120 appear after “Experimental features” is enabled in Settings. 144 unlocks only after tapping 120 four times and reading the warning.
- CFR only drops frames or repeats duplicates; it does not interpolate. 90 / 120 / 144 are experimental and may overheat, stutter or fail. 60 fps is the sensible ceiling for ordinary phone use.
- Multi-file import, per-file probing, a sequential queue, live progress and cancellation.
- Preflight stops incompatible container / codec pairs, out-of-range bitrates and source audio that cannot be copied into the target container.
- Settings can grant a persistent output folder through Android's Storage Access Framework. The grant survives a restart; the result card then shows “Done” and no share button.
- Chinese / English runtime switch. Theme, accent colour, output folder and experimental features live in Settings.

## Install

Download the arm64-v8a APK from [Releases](https://github.com/PrimaluxTeaers/Reencode/releases). Minimum Android 7.0 (API 24). Not on any app store.

Only arm64-v8a is shipped. armeabi-v7a and x86_64 are not included.

Package name is `com.teacers.reencode`. The APK uses this project's own signing key, not Timbre's. The two apps cannot overwrite each other.

## Build

Flutter 3.50.0, Dart 3.14, JDK 17 and Android SDK 36 are required.

```bash
flutter pub get
flutter build apk --release --target-platform android-arm64 --split-per-abi
```

The FFmpegKit Flutter package lives in `third_party/ffmpeg_kit_flutter_new`. It is a copy of upstream 4.6.8 with no changes to the Dart API or native code. Only `android/build.gradle` was changed: the AGP version and repository list, so it builds with the current Flutter / Gradle combination. Check that file before upgrading Flutter, AGP or Gradle.

## License

Reencode is distributed under **GPL-3.0**.

It uses the Full GPL build of FFmpegKit Flutter 4.6.8, which bundles x264, x265, xvidcore and vid.stab. Those are GPL codec libraries, so the combined application is distributed under GPL-3.0. This is deliberate: H.264 and H.265 software encoding remain available when a device has no hardware encoder, or when its hardware encoder is unreliable.

- Full application license: [LICENSE](LICENSE)
- Third-party components, versions, licenses and links: [THIRD_PARTY.md](THIRD_PARTY.md)
- Every release includes a source archive containing the code used to build that APK.

## Privacy

The release APK does not request the `INTERNET` permission. There is no ad SDK, no analytics SDK, and no upload of videos, filenames, device identifiers or conversion logs. Files are read from the path you pick and written to the folder you pick or to the app cache.

## Known limits

- Only the first video stream and all audio streams are processed. Subtitles and attachments are not copied.
- Chapters and global metadata are copied when the target container supports them. Complex chapter layouts may be simplified.
- 10-bit / 12-bit means pixel depth, not HDR. HDR10 static metadata (Mastering Display, CLL), HDR10+ dynamic metadata and Dolby Vision are not written to the output in 1.5. To keep Dolby Vision untouched, use remux with stream copy.
- No MediaCodec hardware encoding, GPU encoding or GPU filters are exposed. The current path is FFmpeg software encoding.
- `libaom-av1` is present in the bundle, but 1.5 does not expose AV1 in the UI. H.266 / VVC has a decoder path only when the device or FFmpeg provides one; there is no `libvvenc`, so it cannot encode, and H.266 stays out of the stable release.
- Multiple video tracks are not handled.
- Large files need roughly twice their size in free space while the temporary output exists.
- Preflight catches clearly incompatible combinations. Whether the final mux succeeds is still decided by FFmpeg.

## Development

```bash
flutter analyze lib test
flutter test
```

`lib/models.dart` holds media summaries, the codec / container enums, recipes and preflight checks; `lib/command_builder.dart` only builds FFmpeg arguments; `lib/engine.dart` handles FFprobe, FFmpeg execution, progress and cancellation. The argument rules can be tested without loading the native library.
