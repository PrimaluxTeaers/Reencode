# Reencode

A video converter for Android and Windows. Three jobs: change the container, change the codec, change the bitrate. A file can be changed one way or several ways at once. Runs offline. No ads, no analytics.

Reencode transcodes with FFmpeg 8.1.2. Remuxing copies streams without re-encoding. Codec changes and bitrate compression re-encode the video, and the UI says so before work starts.

## Platforms

Android: arm64-v8a, minimum Android 7.0 (API 24).

Windows: x64, Windows 10 and 11. The release is a zip; unzip it and run `reencode.exe`. `ffmpeg.exe` and `ffprobe.exe` sit in the adjacent `ffmpeg` folder, not on the system PATH. Windows source lives on the `windows-port` branch; the build is published as `windows-v1.0.0`.

Windows 7, 8 and 8.1 are not built. Flutter's Windows runtime starts at Windows 10; those systems would need a separate shell that does not exist yet.

64-bit only. macOS, iPhone and iPad are not planned.

## What it does

- Containers: MP4, MKV, MOV, WebM.
- Video codecs: H.264, H.265 / HEVC, VP9, MPEG-4.
- Audio codecs: AAC, Opus, MP3, stream copy.
- Target video bitrate, resolution (source / 2160 / 1440 / 1080 / 720 / 480), frame rate (source / 60 / 30 / 24), audio bitrate. Video bitrate goes down to 1 kbps; below 64 kbps the app flags the experimental range. Audio goes down to 8 kbps.
- Multi-file import, per-file probing, a sequential queue, live progress and cancellation.
- 10-bit sources keep a 10-bit pixel format in H.265 / VP9 outputs. HDR metadata is not preserved.
- Preflight checks block incompatible container / codec pairs, out-of-range bitrates and source audio that cannot be copied into the target container.
- Settings can grant a persistent output folder through Android SAF. Results are written there and the grant survives a restart. The result card then shows only Done, with no share button.
- Chinese / English runtime switch. Theme, accent colour and output folder live in Settings.

Windows can use NVIDIA NVENC and AMD AMF for H.264 / H.265. It checks the PCI vendor ID first, then runs one real frame to confirm the encoder starts. Intel, Arc and other vendors fall back to CPU encoding, with the reason shown in Settings. CPU tiers use physical core count and L3 cache, with six cores as the minimum. The Android build does not expose MediaCodec hardware encoding.

## Install

Android: download `Reencode-1.0.0-arm64-v8a-newicon.apk` from [Releases](https://github.com/PrimaluxTeaers/Reencode/releases). Minimum Android 7.0. Not on any app store.

Windows: download `Reencode-windows-x64.zip` from [windows-v1.0.0](https://github.com/PrimaluxTeaers/Reencode/releases/tag/windows-v1.0.0) and unzip it. Windows 10/11 x64 only.

The first Android release ships arm64-v8a only. armeabi-v7a and x86_64 are not included.

The APK uses this project's own signing key, separate from Timbre. The two apps cannot overwrite each other.

## Build

Android needs Flutter 3.50.0, Dart 3.14, JDK 17 and Android SDK 35.

```bash
flutter pub get
flutter build apk --release --target-platform android-arm64 --split-per-abi
```

Windows needs Flutter 3.50.0 and the Visual Studio 2022 C++ desktop workload, x64 only. CI runs `flutter create --platforms=windows`, builds the runner, then places `ffmpeg.exe` and `ffprobe.exe` in the output `ffmpeg` folder.

The FFmpegKit Flutter package lives in `third_party/ffmpeg_kit_flutter_new`. It is a copy of upstream 4.6.8; the Dart API and native code are unchanged. Only `android/build.gradle` was edited for the AGP version and repository list. Windows does not use FFmpegKit; it launches `ffmpeg.exe` as a child process, so this copy's `pubspec.yaml` drops the Windows and Linux platform declarations.

## License

Reencode is distributed under GPL-3.0, not LGPL.

It uses the Full GPL build of FFmpegKit Flutter 4.6.8, which bundles x264, x265, xvidcore and vid.stab. Including those GPL codec libraries makes the combined application GPL-3.0. The FFmpeg binary in the Windows package is BtbN's GPL build, under the same licence.

- Full application licence: [LICENSE](LICENSE)
- Third-party components, versions and licences: [THIRD_PARTY.md](THIRD_PARTY.md)
- Every Android release includes a source archive containing the exact build code.

## Privacy

The release APK does not request the `INTERNET` permission. There is no ad SDK, no analytics SDK, and no upload of videos, filenames, device identifiers or conversion logs. Files are read from the path you pick and written to the folder you pick or to the app cache.

The Windows build calls local WMI once to read CPU and GPU names for hardware detection. It does not use the network, store the result, or upload it.

## Known limits

- Only the first video stream and all audio streams are processed. Subtitle and attachment streams are not copied.
- Chapters and global metadata are copied when the target container supports them. Complex chapter layouts may be simplified.
- Multiple video tracks, HDR metadata and Dolby Vision are not preserved.
- The Android build uses software encoding only and does not expose MediaCodec hardware encoding. Windows follows the NVENC / AMF whitelist; other GPUs use software encoding.
- Large files need roughly twice their size in free space while the temporary output exists.
- Preflight catches clearly incompatible combinations. Whether the final mux succeeds is still decided by FFmpeg.

## Development

```bash
flutter analyze
flutter test
```

`lib/models.dart` holds media summaries, codec and container enums, recipes and preflight checks. `lib/command_builder.dart` only builds FFmpeg arguments. `lib/engine.dart` handles FFprobe, FFmpeg execution, progress and cancellation. The argument rules can be tested without loading the native library.

The Windows engine is in `lib/engine_windows.dart`; hardware detection is in `lib/hardware_profile.dart`. `main` and `windows-port` are not auto-merged.
