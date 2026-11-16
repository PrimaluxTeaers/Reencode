# Reencode

An Android video converter built around three jobs: change the container, change the codec, change the bitrate. A single file can be changed one way or several ways at once. Runs offline. No ads, no analytics.

Reencode actually transcodes with FFmpeg 8.1.2. It is not a demo shell. Remuxing copies the streams without re-encoding; changing codecs or bitrate re-encodes the video, and the UI says so before you start.

## What it does

- Containers: MP4, MKV, MOV, WebM.
- Video codecs: H.264, H.265 / HEVC, VP9, MPEG-4.
- Audio codecs: AAC, Opus, MP3, stream copy.
- Target video bitrate, resolution (source / 2160 / 1440 / 1080 / 720 / 480), frame rate (source / 60 / 30 / 24), audio bitrate. Video bitrate goes down to 1 kbps; below 64 kbps is flagged as the experimental low-bitrate range. Audio goes down to 8 kbps.
- Multi-file import, per-file probing, a sequential queue, live progress and cancellation.
- 10-bit sources keep a 10-bit pixel format in H.265 / VP9 outputs. HDR metadata is not preserved.
- Preflight checks block incompatible container / codec pairs, out-of-range bitrates and source audio that cannot be copied into the target container.
- Settings can grant a persistent output folder through Android's Storage Access Framework. Once granted, results are written there and the grant survives a restart. The result card then shows only “Done”, with no share button.
- Chinese / English runtime switch. Theme, accent colour and output folder live in Settings.

## Install

Download the arm64-v8a APK from [Releases](https://github.com/PrimaluxTeaers/Reencode/releases). Minimum Android 7.0 (API 24). Not on any app store.

The first release ships arm64-v8a only. armeabi-v7a and x86_64 are not included.

The APK is signed with this project's own key, not the old Timbre key. The two apps cannot overwrite each other.

## Build

Flutter 3.50.0, Dart 3.14, JDK 17 and Android SDK 35 are required.

```bash
flutter pub get
flutter build apk --release --target-platform android-arm64 --split-per-abi
```

The FFmpegKit Flutter package lives in `third_party/ffmpeg_kit_flutter_new`. It is a copy of upstream 4.6.8 with no changes to the Dart API or native code. Only `android/build.gradle` was changed: the AGP version and repository list, so it builds with the current Flutter / Gradle combination. Check that file before upgrading Flutter, AGP or Gradle.

## License

Reencode is distributed under **GPL-3.0**, not LGPL.

It uses the Full GPL build of FFmpegKit Flutter 4.6.8, which bundles x264, x265, xvidcore and vid.stab. Those are GPL codec libraries, so the combined application must be distributed under GPL-3.0. This is deliberate: H.264 and H.265 software encoding remain available when a device has no hardware encoder, or when its hardware encoder is unreliable.

- Full application license: [LICENSE](LICENSE)
- Third-party components, versions, licenses and links: [THIRD_PARTY.md](THIRD_PARTY.md)
- Every release includes a source archive containing the exact code used to build that APK.

## Privacy

The release APK does not request the `INTERNET` permission. There is no ad SDK, no analytics SDK, and no upload of videos, filenames, device identifiers or conversion logs. Files are read from the path you pick and written to the folder you pick or to the app cache.

## Known limits

- Only the first video stream and all audio streams are processed. Subtitle and attachment streams are not copied.
- Chapters and global metadata are copied when the target container supports them. Complex chapter layouts may be simplified.
- Multiple video tracks, HDR metadata and Dolby Vision are not preserved.
- The Full GPL build uses software encoding. MediaCodec hardware encoding is not exposed in this release.
- Large files need roughly twice their size in free space while the temporary output exists.
- Preflight catches clearly incompatible combinations. Whether the final mux succeeds is still decided by FFmpeg.

## Development

```bash
flutter analyze
flutter test
```

`lib/models.dart` holds media summaries, the codec / container enums, recipes and preflight checks; `lib/command_builder.dart` only builds FFmpeg arguments and never touches the native layer; `lib/engine.dart` handles FFprobe, FFmpeg execution, progress and cancellation. The argument rules can be tested without loading the native library.
